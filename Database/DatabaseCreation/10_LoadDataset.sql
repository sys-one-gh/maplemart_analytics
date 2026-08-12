-- 10_LoadDataset.sql
-- Defines dbo.uspLoadDataset, then runs it. BULK INSERT reads CSVs from
-- /workspace/Dataset inside the sqlserver container (see docker-compose.yml
-- volume mount) - paths are container-side, not host-side.
--
-- Three source files carry lookup TEXT values instead of surrogate FK IDs
-- (LoyaltyMemberships.MembershipLevel, MarketingCampaigns.Channel,
-- SalesTransactions.PaymentMethod), so those three are staged into #temp
-- tables first, any not-yet-seen lookup value is added to the matching
-- reference table, then the final INSERT resolves the FK by name.
--
-- Re-running this script is safe: it clears previously loaded rows first
-- (children before parents) so row counts never double up.

USE CustomerCampaignAnalytics;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.uspLoadDataset', 'P') IS NOT NULL DROP PROCEDURE dbo.uspLoadDataset;
GO
CREATE PROCEDURE dbo.uspLoadDataset
    @DatasetPath NVARCHAR(260) = '/workspace/Dataset'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX);

    ----------------------------------------------------------------------
    -- 0. Clear anything from a previous load (children first)
    ----------------------------------------------------------------------
    DELETE FROM dbo.CustomerPrediction;
    DELETE FROM dbo.AIReport;
    DELETE FROM dbo.CampaignResponse;
    DELETE FROM dbo.SalesTransactionItem;
    DELETE FROM dbo.SalesTransaction;
    DELETE FROM dbo.MarketingCampaign;
    DELETE FROM dbo.LoyaltyMembership;
    DELETE FROM dbo.Employee;
    DELETE FROM dbo.Product;
    DELETE FROM dbo.Customer;
    DELETE FROM dbo.Store;
    DELETE FROM dbo.ProductCategory;

    ----------------------------------------------------------------------
    -- 1. Stores
    ----------------------------------------------------------------------
    SET @sql = N'BULK INSERT dbo.Store FROM ''' + @DatasetPath + N'/Stores.csv''
        WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', TABLOCK);';
    EXEC (@sql);

    ----------------------------------------------------------------------
    -- 2. ProductCategories
    ----------------------------------------------------------------------
    SET @sql = N'BULK INSERT dbo.ProductCategory FROM ''' + @DatasetPath + N'/ProductCategories.csv''
        WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', TABLOCK);';
    EXEC (@sql);

    ----------------------------------------------------------------------
    -- 3. Products
    ----------------------------------------------------------------------
    SET @sql = N'BULK INSERT dbo.Product FROM ''' + @DatasetPath + N'/Products.csv''
        WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', TABLOCK);';
    EXEC (@sql);

    ----------------------------------------------------------------------
    -- 4. Customers
    ----------------------------------------------------------------------
    SET @sql = N'BULK INSERT dbo.Customer FROM ''' + @DatasetPath + N'/Customers.csv''
        WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', TABLOCK);';
    EXEC (@sql);

    ----------------------------------------------------------------------
    -- 5. LoyaltyMemberships (stage -> resolve MembershipLevel -> insert)
    ----------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#StageLoyalty') IS NOT NULL DROP TABLE #StageLoyalty;
    CREATE TABLE #StageLoyalty (
        LoyaltyNumber NVARCHAR(20), CustomerID INT, MembershipLevel NVARCHAR(50),
        JoinDate DATE, CurrentPoints INT, LifetimePointsEarned INT, LifetimePointsRedeemed INT
    );
    SET @sql = N'BULK INSERT #StageLoyalty FROM ''' + @DatasetPath + N'/LoyaltyMemberships.csv''
        WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', TABLOCK);';
    EXEC (@sql);

    INSERT INTO dbo.LoyaltyLevel (LevelName)
    SELECT DISTINCT s.MembershipLevel FROM #StageLoyalty s
    WHERE NOT EXISTS (SELECT 1 FROM dbo.LoyaltyLevel ll WHERE ll.LevelName = s.MembershipLevel);

    INSERT INTO dbo.LoyaltyMembership (CustomerID, LoyaltyNumber, LoyaltyLevelID, JoinDate, CurrentPoints, LifetimePointsEarned, LifetimePointsRedeemed)
    SELECT s.CustomerID, s.LoyaltyNumber, ll.LoyaltyLevelID, s.JoinDate, s.CurrentPoints, s.LifetimePointsEarned, s.LifetimePointsRedeemed
    FROM #StageLoyalty s
    JOIN dbo.LoyaltyLevel ll ON ll.LevelName = s.MembershipLevel;

    ----------------------------------------------------------------------
    -- 6. Employees
    ----------------------------------------------------------------------
    SET @sql = N'BULK INSERT dbo.Employee FROM ''' + @DatasetPath + N'/Employees.csv''
        WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', TABLOCK);';
    EXEC (@sql);

    ----------------------------------------------------------------------
    -- 7. MarketingCampaigns (stage -> resolve Channel + derive CampaignType -> insert)
    ----------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#StageCampaign') IS NOT NULL DROP TABLE #StageCampaign;
    CREATE TABLE #StageCampaign (
        CampaignID INT, CampaignName NVARCHAR(150), Channel NVARCHAR(50),
        StartDate DATE, EndDate DATE, DiscountPercent DECIMAL(5,2)
    );
    SET @sql = N'BULK INSERT #StageCampaign FROM ''' + @DatasetPath + N'/MarketingCampaigns.csv''
        WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', TABLOCK);';
    EXEC (@sql);

    INSERT INTO dbo.MarketingChannel (ChannelName)
    SELECT DISTINCT s.Channel FROM #StageCampaign s
    WHERE NOT EXISTS (SELECT 1 FROM dbo.MarketingChannel mc WHERE mc.ChannelName = s.Channel);

    -- CampaignType has no source column - derived from DiscountPercent (documented in Documentation/DataDictionary).
    INSERT INTO dbo.MarketingCampaign (CampaignID, CampaignName, MarketingChannelID, CampaignTypeID, StartDate, EndDate, DiscountPercent)
    SELECT
        s.CampaignID, s.CampaignName, mch.MarketingChannelID,
        ct.CampaignTypeID,
        s.StartDate, s.EndDate, s.DiscountPercent
    FROM #StageCampaign s
    JOIN dbo.MarketingChannel mch ON mch.ChannelName = s.Channel
    CROSS APPLY (
        SELECT TOP 1 CampaignTypeID FROM dbo.CampaignType
        WHERE TypeName = CASE
            WHEN s.DiscountPercent >= 30 THEN 'Deep Discount'
            WHEN s.DiscountPercent >= 15 THEN 'Standard Discount'
            WHEN s.DiscountPercent > 0  THEN 'Loyalty/Retention'
            ELSE 'Awareness'
        END
    ) ct;

    ----------------------------------------------------------------------
    -- 8. SalesTransactions (stage -> resolve PaymentMethod -> insert)
    ----------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#StageTxn') IS NOT NULL DROP TABLE #StageTxn;
    CREATE TABLE #StageTxn (
        TransactionID INT, CustomerID INT, StoreID INT, TransactionDate DATETIME2,
        PaymentMethod NVARCHAR(50), TransactionTotal DECIMAL(10,2)
    );
    SET @sql = N'BULK INSERT #StageTxn FROM ''' + @DatasetPath + N'/SalesTransactions.csv''
        WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', TABLOCK);';
    EXEC (@sql);

    INSERT INTO dbo.PaymentMethod (MethodName)
    SELECT DISTINCT s.PaymentMethod FROM #StageTxn s
    WHERE NOT EXISTS (SELECT 1 FROM dbo.PaymentMethod pm WHERE pm.MethodName = s.PaymentMethod);

    INSERT INTO dbo.SalesTransaction (TransactionID, CustomerID, StoreID, TransactionDate, PaymentMethodID, TransactionTotal)
    SELECT s.TransactionID, s.CustomerID, s.StoreID, s.TransactionDate, pm.PaymentMethodID, s.TransactionTotal
    FROM #StageTxn s
    JOIN dbo.PaymentMethod pm ON pm.MethodName = s.PaymentMethod;

    ----------------------------------------------------------------------
    -- 9. SalesTransactionItems
    ----------------------------------------------------------------------
    SET @sql = N'BULK INSERT dbo.SalesTransactionItem FROM ''' + @DatasetPath + N'/SalesTransactionItems.csv''
        WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', TABLOCK);';
    EXEC (@sql);

    ----------------------------------------------------------------------
    -- 10. CampaignResponses
    ----------------------------------------------------------------------
    SET @sql = N'BULK INSERT dbo.CampaignResponse FROM ''' + @DatasetPath + N'/CampaignResponses.csv''
        WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', TABLOCK);';
    EXEC (@sql);

    ----------------------------------------------------------------------
    -- 10b. Data-quality fix: the source SalesTransactions.csv has
    -- TransactionTotal = 0 on every row (confirmed - not a sampling
    -- artifact, see Documentation/DataQualityReport.md). Recompute it from
    -- the loaded line items so every downstream feature/view/report that
    -- relies on TransactionTotal (CLV, average purchase value, sales
    -- performance...) reflects real spend instead of zeros.
    ----------------------------------------------------------------------
    UPDATE st
    SET st.TransactionTotal = ISNULL(agg.LineSum, 0)
    FROM dbo.SalesTransaction st
    CROSS APPLY (
        SELECT SUM(LineTotal) AS LineSum FROM dbo.SalesTransactionItem sti WHERE sti.TransactionID = st.TransactionID
    ) agg;

    ----------------------------------------------------------------------
    -- Row-count summary
    ----------------------------------------------------------------------
    SELECT 'Store' AS TableName, COUNT(*) AS RecordCount FROM dbo.Store
    UNION ALL SELECT 'ProductCategory', COUNT(*) FROM dbo.ProductCategory
    UNION ALL SELECT 'Product', COUNT(*) FROM dbo.Product
    UNION ALL SELECT 'Customer', COUNT(*) FROM dbo.Customer
    UNION ALL SELECT 'LoyaltyMembership', COUNT(*) FROM dbo.LoyaltyMembership
    UNION ALL SELECT 'Employee', COUNT(*) FROM dbo.Employee
    UNION ALL SELECT 'MarketingCampaign', COUNT(*) FROM dbo.MarketingCampaign
    UNION ALL SELECT 'SalesTransaction', COUNT(*) FROM dbo.SalesTransaction
    UNION ALL SELECT 'SalesTransactionItem', COUNT(*) FROM dbo.SalesTransactionItem
    UNION ALL SELECT 'CampaignResponse', COUNT(*) FROM dbo.CampaignResponse;
END
GO

EXEC dbo.uspLoadDataset;
GO

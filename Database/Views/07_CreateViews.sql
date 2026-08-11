USE CustomerCampaignAnalytics;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.vwCustomerAnalytics', 'V') IS NOT NULL DROP VIEW dbo.vwCustomerAnalytics;
GO
CREATE VIEW dbo.vwCustomerAnalytics AS
WITH LastResponse AS (
    SELECT CustomerID, PurchaseCompleted,
           ROW_NUMBER() OVER (PARTITION BY CustomerID ORDER BY ResponseDate DESC) AS rn
    FROM dbo.CampaignResponse
),
TxnAgg AS (
    SELECT CustomerID,
           COUNT(*)              AS NumTransactions,
           SUM(TransactionTotal) AS TotalAmountSpent,
           MAX(TransactionDate)  AS LastPurchaseDate
    FROM dbo.SalesTransaction
    GROUP BY CustomerID
),
ProductAgg AS (
    SELECT st.CustomerID, COUNT(DISTINCT sti.ProductID) AS NumDistinctProducts, AVG(sti.Discount) AS AvgDiscountReceived
    FROM dbo.SalesTransaction st
    JOIN dbo.SalesTransactionItem sti ON sti.TransactionID = st.TransactionID
    GROUP BY st.CustomerID
),
CampaignAgg AS (
    SELECT CustomerID,
           COUNT(*) AS NumCampaignsReceived,
           SUM(CASE WHEN PurchaseCompleted = 1 THEN 1 ELSE 0 END) AS NumCompleted
    FROM dbo.CampaignResponse
    GROUP BY CustomerID
)
SELECT
    c.CustomerID,
    DATEDIFF(YEAR, c.DateOfBirth, GETDATE())
        - CASE WHEN (MONTH(c.DateOfBirth) > MONTH(GETDATE()))
                 OR (MONTH(c.DateOfBirth) = MONTH(GETDATE()) AND DAY(c.DateOfBirth) > DAY(GETDATE()))
               THEN 1 ELSE 0 END                      AS Age,
    c.Province,
    ll.LevelName                                      AS LoyaltyLevel,
    ISNULL(ta.NumTransactions, 0)                     AS NumTransactions,
    ISNULL(ta.TotalAmountSpent, 0)                     AS TotalAmountSpent,
    CASE WHEN ISNULL(ta.NumTransactions, 0) = 0 THEN 0
         ELSE ta.TotalAmountSpent / ta.NumTransactions END AS AveragePurchaseValue,
    DATEDIFF(DAY, ta.LastPurchaseDate, GETDATE())      AS DaysSinceLastPurchase,
    ISNULL(ca.NumCampaignsReceived, 0)                 AS NumCampaignsReceived,
    CASE WHEN ISNULL(ca.NumCampaignsReceived, 0) = 0 THEN 0
         ELSE CAST(ca.NumCompleted AS DECIMAL(10,4)) / ca.NumCampaignsReceived * 100 END AS CampaignResponseRate,
    ISNULL(pa.NumDistinctProducts, 0)                  AS NumDistinctProductsPurchased,
    ISNULL(pa.AvgDiscountReceived, 0)                  AS AverageDiscountReceived,
    lr.PurchaseCompleted                               AS PurchaseCompleted
FROM dbo.Customer c
LEFT JOIN dbo.LoyaltyMembership lm ON lm.CustomerID = c.CustomerID
LEFT JOIN dbo.LoyaltyLevel ll ON ll.LoyaltyLevelID = lm.LoyaltyLevelID
LEFT JOIN TxnAgg ta ON ta.CustomerID = c.CustomerID
LEFT JOIN ProductAgg pa ON pa.CustomerID = c.CustomerID
LEFT JOIN CampaignAgg ca ON ca.CustomerID = c.CustomerID
LEFT JOIN LastResponse lr ON lr.CustomerID = c.CustomerID AND lr.rn = 1;
GO

-- vwCampaignPerformance: one row per campaign
IF OBJECT_ID('dbo.vwCampaignPerformance', 'V') IS NOT NULL DROP VIEW dbo.vwCampaignPerformance;
GO
CREATE VIEW dbo.vwCampaignPerformance AS
SELECT
    mc.CampaignID,
    mc.CampaignName,
    ch.ChannelName,
    mc.DiscountPercent,
    COUNT(cr.ResponseID)                                                   AS CustomersContacted,
    CAST(SUM(CASE WHEN cr.EmailOpened = 1 THEN 1 ELSE 0 END) AS DECIMAL(10,4))
        / NULLIF(COUNT(cr.ResponseID), 0) * 100                            AS OpenRate,
    CAST(SUM(CASE WHEN cr.PurchaseCompleted = 1 THEN 1 ELSE 0 END) AS DECIMAL(10,4))
        / NULLIF(COUNT(cr.ResponseID), 0) * 100                            AS PurchaseCompletionRate,
    ISNULL(SUM(cr.PurchaseAmount), 0)                                      AS TotalRevenueGenerated,
    ISNULL(AVG(NULLIF(cr.PurchaseAmount, 0)), 0)                           AS AveragePurchaseAmount
FROM dbo.MarketingCampaign mc
JOIN dbo.MarketingChannel ch ON ch.MarketingChannelID = mc.MarketingChannelID
LEFT JOIN dbo.CampaignResponse cr ON cr.CampaignID = mc.CampaignID
GROUP BY mc.CampaignID, mc.CampaignName, ch.ChannelName, mc.DiscountPercent;
GO

-- vwSalesPerformance: grain = year/month x store x category, so Power BI
-- can slice by any one dimension or roll several together.
IF OBJECT_ID('dbo.vwSalesPerformance', 'V') IS NOT NULL DROP VIEW dbo.vwSalesPerformance;
GO
CREATE VIEW dbo.vwSalesPerformance AS
SELECT
    YEAR(st.TransactionDate)  AS SalesYear,
    MONTH(st.TransactionDate) AS SalesMonth,
    s.StoreID,
    s.StoreName,
    s.Province,
    pc.CategoryID,
    pc.CategoryName,
    SUM(sti.LineTotal) AS Revenue,
    SUM(sti.Quantity)  AS UnitsSold,
    COUNT(DISTINCT st.TransactionID) AS TransactionCount
FROM dbo.SalesTransaction st
JOIN dbo.Store s ON s.StoreID = st.StoreID
JOIN dbo.SalesTransactionItem sti ON sti.TransactionID = st.TransactionID
JOIN dbo.Product p ON p.ProductID = sti.ProductID
JOIN dbo.ProductCategory pc ON pc.CategoryID = p.CategoryID
GROUP BY YEAR(st.TransactionDate), MONTH(st.TransactionDate), s.StoreID, s.StoreName, s.Province, pc.CategoryID, pc.CategoryName;
GO

-- vwCustomerLifetimeValue
IF OBJECT_ID('dbo.vwCustomerLifetimeValue', 'V') IS NOT NULL DROP VIEW dbo.vwCustomerLifetimeValue;
GO
CREATE VIEW dbo.vwCustomerLifetimeValue AS
SELECT
    c.CustomerID,
    c.FirstName,
    c.LastName,
    dbo.ufnCustomerLifetimeValue(c.CustomerID) AS TotalHistoricalSpend,
    ISNULL(ta.NumTransactions, 0)              AS NumTransactions,
    DATEDIFF(DAY, c.RegistrationDate, GETDATE()) AS TenureDays,
    -- CLV formula: total spend to date (a simple, defensible choice for a
    -- prototype - no future-value projection). Documented for the report.
    dbo.ufnCustomerLifetimeValue(c.CustomerID) AS CustomerLifetimeValue
FROM dbo.Customer c
LEFT JOIN (
    SELECT CustomerID, COUNT(*) AS NumTransactions
    FROM dbo.SalesTransaction
    GROUP BY CustomerID
) ta ON ta.CustomerID = c.CustomerID;
GO

-- vwPredictionResults: actual vs predicted, side by side, for Power BI's ML dashboard.
IF OBJECT_ID('dbo.vwPredictionResults', 'V') IS NOT NULL DROP VIEW dbo.vwPredictionResults;
GO
CREATE VIEW dbo.vwPredictionResults AS
WITH LastPrediction AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY CustomerID ORDER BY PredictionDate DESC) AS rn
    FROM dbo.CustomerPrediction
),
LastResponse AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY CustomerID ORDER BY ResponseDate DESC) AS rn
    FROM dbo.CampaignResponse
)
SELECT
    c.CustomerID,
    c.FirstName,
    c.LastName,
    lp.PredictionDate,
    lp.PredictionProbability,
    lp.PredictionResult,
    lp.MLModel,
    lp.ModelVersion,
    lr.PurchaseCompleted AS ActualPurchaseCompleted,
    CASE
        WHEN lr.PurchaseCompleted IS NULL OR lp.PredictionResult IS NULL THEN NULL
        WHEN (lp.PredictionResult = 'Yes' AND lr.PurchaseCompleted = 1)
          OR (lp.PredictionResult = 'No'  AND lr.PurchaseCompleted = 0) THEN CAST(1 AS BIT)
        ELSE CAST(0 AS BIT)
    END AS PredictionCorrect
FROM dbo.Customer c
LEFT JOIN LastPrediction lp ON lp.CustomerID = c.CustomerID AND lp.rn = 1
LEFT JOIN LastResponse lr ON lr.CustomerID = c.CustomerID AND lr.rn = 1;
GO

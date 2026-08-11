-- 08_CreateFunctions.sql
-- 5 mandatory scalar functions. Must run before 07_CreateViews.sql, since
-- vwCustomerAnalytics calls these.

USE CustomerCampaignAnalytics;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.ufnCustomerAge', 'FN') IS NOT NULL DROP FUNCTION dbo.ufnCustomerAge;
GO
CREATE FUNCTION dbo.ufnCustomerAge (@CustomerID INT)
RETURNS INT
AS
BEGIN
    DECLARE @DOB DATE, @Age INT;
    SELECT @DOB = DateOfBirth FROM dbo.Customer WHERE CustomerID = @CustomerID;
    IF @DOB IS NULL RETURN NULL;

    SET @Age = DATEDIFF(YEAR, @DOB, GETDATE());
    -- DATEDIFF(YEAR,...) counts calendar-year boundaries crossed, not full
    -- years elapsed - subtract 1 if this year's birthday hasn't happened yet.
    IF (MONTH(@DOB) > MONTH(GETDATE())) OR (MONTH(@DOB) = MONTH(GETDATE()) AND DAY(@DOB) > DAY(GETDATE()))
        SET @Age = @Age - 1;

    RETURN @Age;
END
GO

IF OBJECT_ID('dbo.ufnCustomerLifetimeValue', 'FN') IS NOT NULL DROP FUNCTION dbo.ufnCustomerLifetimeValue;
GO
CREATE FUNCTION dbo.ufnCustomerLifetimeValue (@CustomerID INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @CLV DECIMAL(12,2);
    SELECT @CLV = SUM(TransactionTotal) FROM dbo.SalesTransaction WHERE CustomerID = @CustomerID;
    RETURN ISNULL(@CLV, 0);
END
GO

IF OBJECT_ID('dbo.ufnAveragePurchase', 'FN') IS NOT NULL DROP FUNCTION dbo.ufnAveragePurchase;
GO
CREATE FUNCTION dbo.ufnAveragePurchase (@CustomerID INT)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @Avg DECIMAL(10,2);
    SELECT @Avg = AVG(TransactionTotal) FROM dbo.SalesTransaction WHERE CustomerID = @CustomerID;
    RETURN ISNULL(@Avg, 0);
END
GO

IF OBJECT_ID('dbo.ufnCampaignResponseRate', 'FN') IS NOT NULL DROP FUNCTION dbo.ufnCampaignResponseRate;
GO
CREATE FUNCTION dbo.ufnCampaignResponseRate (@CustomerID INT)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @Total INT, @Completed INT;
    SELECT @Total = COUNT(*), @Completed = SUM(CASE WHEN PurchaseCompleted = 1 THEN 1 ELSE 0 END)
    FROM dbo.CampaignResponse
    WHERE CustomerID = @CustomerID;

    IF @Total IS NULL OR @Total = 0 RETURN 0;
    RETURN CAST(@Completed AS DECIMAL(10,4)) / @Total * 100;
END
GO

IF OBJECT_ID('dbo.ufnDaysSinceLastPurchase', 'FN') IS NOT NULL DROP FUNCTION dbo.ufnDaysSinceLastPurchase;
GO
CREATE FUNCTION dbo.ufnDaysSinceLastPurchase (@CustomerID INT)
RETURNS INT
AS
BEGIN
    DECLARE @LastPurchase DATETIME2;
    SELECT @LastPurchase = MAX(TransactionDate) FROM dbo.SalesTransaction WHERE CustomerID = @CustomerID;
    -- NULL means the customer has never purchased - callers should treat
    -- this as "no purchase history", not "0 days ago".
    IF @LastPurchase IS NULL RETURN NULL;
    RETURN DATEDIFF(DAY, @LastPurchase, GETDATE());
END
GO

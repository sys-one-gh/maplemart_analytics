-- BusinessQueries.sql
-- Standalone analytical queries (not views) answering the 7 required
-- business questions, using CTEs and window functions. Run each block
-- independently in SSMS. For at least 2 of these, capture the estimated
-- execution plan and note it in PerformanceNotes.md.

USE CustomerCampaignAnalytics;
GO

-- 1) Top 20 customers by total revenue
SELECT TOP 20
    c.CustomerID, c.FirstName, c.LastName,
    SUM(st.TransactionTotal) AS TotalRevenue,
    RANK() OVER (ORDER BY SUM(st.TransactionTotal) DESC) AS RevenueRank
FROM dbo.Customer c
JOIN dbo.SalesTransaction st ON st.CustomerID = c.CustomerID
GROUP BY c.CustomerID, c.FirstName, c.LastName
ORDER BY TotalRevenue DESC;
GO

-- 2) Which campaign generated the highest response rate
SELECT TOP 1
    mc.CampaignID, mc.CampaignName,
    CAST(SUM(CASE WHEN cr.PurchaseCompleted = 1 THEN 1 ELSE 0 END) AS DECIMAL(10,4))
        / NULLIF(COUNT(*), 0) * 100 AS ResponseRatePct
FROM dbo.MarketingCampaign mc
JOIN dbo.CampaignResponse cr ON cr.CampaignID = mc.CampaignID
GROUP BY mc.CampaignID, mc.CampaignName
ORDER BY ResponseRatePct DESC;
GO

-- 3) Which products generate the highest profit (UnitPrice - UnitCost) x units sold
SELECT TOP 20
    p.ProductID, p.ProductName,
    SUM(sti.Quantity) AS UnitsSold,
    SUM(sti.Quantity * (p.UnitPrice - p.UnitCost)) AS TotalProfit,
    RANK() OVER (ORDER BY SUM(sti.Quantity * (p.UnitPrice - p.UnitCost)) DESC) AS ProfitRank
FROM dbo.Product p
JOIN dbo.SalesTransactionItem sti ON sti.ProductID = p.ProductID
GROUP BY p.ProductID, p.ProductName
ORDER BY TotalProfit DESC;
GO

-- 4) Which store has the highest monthly revenue (best single store-month)
WITH StoreMonth AS (
    SELECT s.StoreID, s.StoreName, YEAR(st.TransactionDate) AS Yr, MONTH(st.TransactionDate) AS Mo,
           SUM(st.TransactionTotal) AS MonthlyRevenue
    FROM dbo.SalesTransaction st
    JOIN dbo.Store s ON s.StoreID = st.StoreID
    GROUP BY s.StoreID, s.StoreName, YEAR(st.TransactionDate), MONTH(st.TransactionDate)
)
SELECT TOP 10 StoreID, StoreName, Yr, Mo, MonthlyRevenue,
       RANK() OVER (ORDER BY MonthlyRevenue DESC) AS RevenueRank
FROM StoreMonth
ORDER BY MonthlyRevenue DESC;
GO

-- 5) Which loyalty level spends the most on average
SELECT
    ll.LevelName,
    AVG(ta.TotalSpend) AS AvgSpendPerCustomer,
    COUNT(*) AS CustomerCount
FROM dbo.LoyaltyMembership lm
JOIN dbo.LoyaltyLevel ll ON ll.LoyaltyLevelID = lm.LoyaltyLevelID
CROSS APPLY (
    SELECT ISNULL(SUM(TransactionTotal), 0) AS TotalSpend
    FROM dbo.SalesTransaction st
    WHERE st.CustomerID = lm.CustomerID
) ta
GROUP BY ll.LevelName
ORDER BY AvgSpendPerCustomer DESC;
GO

-- 6) Customers who have not purchased within the last 6 months
WITH LastPurchase AS (
    SELECT CustomerID, MAX(TransactionDate) AS LastTxnDate
    FROM dbo.SalesTransaction
    GROUP BY CustomerID
)
SELECT c.CustomerID, c.FirstName, c.LastName, lp.LastTxnDate,
       DATEDIFF(DAY, lp.LastTxnDate, GETDATE()) AS DaysSinceLastPurchase
FROM dbo.Customer c
LEFT JOIN LastPurchase lp ON lp.CustomerID = c.CustomerID
WHERE lp.LastTxnDate IS NULL OR lp.LastTxnDate < DATEADD(MONTH, -6, GETDATE())
ORDER BY lp.LastTxnDate ASC;
GO

-- 7) Which campaigns produced the highest ROI (revenue generated vs. discount cost)
-- Discount cost approximated as: revenue-from-purchasers x campaign DiscountPercent.
WITH CampaignRevenue AS (
    SELECT mc.CampaignID, mc.CampaignName, mc.DiscountPercent,
           SUM(cr.PurchaseAmount) AS Revenue
    FROM dbo.MarketingCampaign mc
    JOIN dbo.CampaignResponse cr ON cr.CampaignID = mc.CampaignID AND cr.PurchaseCompleted = 1
    GROUP BY mc.CampaignID, mc.CampaignName, mc.DiscountPercent
)
SELECT CampaignID, CampaignName, Revenue,
       Revenue * (DiscountPercent / 100.0) AS EstimatedDiscountCost,
       (Revenue - Revenue * (DiscountPercent / 100.0))
           / NULLIF(Revenue * (DiscountPercent / 100.0), 0) AS ROI
FROM CampaignRevenue
ORDER BY ROI DESC;
GO

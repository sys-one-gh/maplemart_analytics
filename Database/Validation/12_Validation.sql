-- 12_Validation.sql
-- Post-load sanity checks. Run after 10_LoadDataset.sql (and again after
-- Dhruv's end-to-end integration test). Every SELECT below should return
-- zero rows except the "table existence" and "row counts" ones.

USE CustomerCampaignAnalytics;
GO

PRINT '--- 1. Table existence (expect 13 tables) ---';
SELECT t.name AS TableName
FROM sys.tables t
WHERE t.name IN ('Store','ProductCategory','LoyaltyLevel','PaymentMethod','CampaignType','MarketingChannel',
                  'Customer','LoyaltyMembership','Employee','Product','SalesTransaction','SalesTransactionItem',
                  'MarketingCampaign','CampaignResponse','CustomerPrediction','AIReport','ModelExecution')
ORDER BY t.name;
GO

PRINT '--- 2. Row counts ---';
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
GO

PRINT '--- 3a. Orphan FKs: SalesTransaction.CustomerID not in Customer (expect 0) ---';
SELECT COUNT(*) AS OrphanCount FROM dbo.SalesTransaction st
LEFT JOIN dbo.Customer c ON c.CustomerID = st.CustomerID WHERE c.CustomerID IS NULL;

PRINT '--- 3b. Orphan FKs: SalesTransactionItem.ProductID not in Product (expect 0) ---';
SELECT COUNT(*) AS OrphanCount FROM dbo.SalesTransactionItem sti
LEFT JOIN dbo.Product p ON p.ProductID = sti.ProductID WHERE p.ProductID IS NULL;

PRINT '--- 3c. Orphan FKs: SalesTransactionItem.TransactionID not in SalesTransaction (expect 0) ---';
SELECT COUNT(*) AS OrphanCount FROM dbo.SalesTransactionItem sti
LEFT JOIN dbo.SalesTransaction st ON st.TransactionID = sti.TransactionID WHERE st.TransactionID IS NULL;

PRINT '--- 3d. Orphan FKs: CampaignResponse.CampaignID/CustomerID (expect 0 each) ---';
SELECT COUNT(*) AS OrphanCampaignID FROM dbo.CampaignResponse cr
LEFT JOIN dbo.MarketingCampaign mc ON mc.CampaignID = cr.CampaignID WHERE mc.CampaignID IS NULL;
SELECT COUNT(*) AS OrphanCustomerID FROM dbo.CampaignResponse cr
LEFT JOIN dbo.Customer c ON c.CustomerID = cr.CustomerID WHERE c.CustomerID IS NULL;
GO

PRINT '--- 4. Duplicate primary keys (expect 0 rows each) ---';
SELECT CustomerID, COUNT(*) FROM dbo.Customer GROUP BY CustomerID HAVING COUNT(*) > 1;
SELECT TransactionID, COUNT(*) FROM dbo.SalesTransaction GROUP BY TransactionID HAVING COUNT(*) > 1;
SELECT TransactionItemID, COUNT(*) FROM dbo.SalesTransactionItem GROUP BY TransactionItemID HAVING COUNT(*) > 1;
GO

PRINT '--- 5. Constraint spot-checks (expect 0 rows each) ---';
SELECT * FROM dbo.CampaignResponse WHERE PurchaseAmount < 0;
SELECT * FROM dbo.MarketingCampaign WHERE DiscountPercent NOT BETWEEN 0 AND 100;
SELECT * FROM dbo.Customer WHERE Age NOT BETWEEN 18 AND 120;
SELECT * FROM dbo.SalesTransaction WHERE TransactionTotal < 0;
GO

PRINT '--- 6. Every Customer has exactly one LoyaltyMembership (expect 0 rows) ---';
SELECT c.CustomerID FROM dbo.Customer c
LEFT JOIN dbo.LoyaltyMembership lm ON lm.CustomerID = c.CustomerID
WHERE lm.CustomerID IS NULL;
GO

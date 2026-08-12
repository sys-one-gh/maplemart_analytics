-- 06_CreateIndexes.sql
-- Indexes on FK columns and the columns views/business queries filter or
-- join on most. UQ_Customer_Email (05) and all PKs already have an index.

USE CustomerCampaignAnalytics;
GO

CREATE INDEX IX_SalesTransaction_CustomerID    ON dbo.SalesTransaction (CustomerID);
CREATE INDEX IX_SalesTransaction_StoreID       ON dbo.SalesTransaction (StoreID);
CREATE INDEX IX_SalesTransaction_PaymentMethodID ON dbo.SalesTransaction (PaymentMethodID);
CREATE INDEX IX_SalesTransaction_TransactionDate ON dbo.SalesTransaction (TransactionDate);

CREATE INDEX IX_SalesTransactionItem_TransactionID ON dbo.SalesTransactionItem (TransactionID);
CREATE INDEX IX_SalesTransactionItem_ProductID      ON dbo.SalesTransactionItem (ProductID);

CREATE INDEX IX_CampaignResponse_CampaignID  ON dbo.CampaignResponse (CampaignID);
CREATE INDEX IX_CampaignResponse_CustomerID  ON dbo.CampaignResponse (CustomerID);
CREATE INDEX IX_CampaignResponse_ResponseDate ON dbo.CampaignResponse (ResponseDate);

CREATE INDEX IX_MarketingCampaign_ChannelID ON dbo.MarketingCampaign (MarketingChannelID);

CREATE INDEX IX_Product_CategoryID ON dbo.Product (CategoryID);

CREATE INDEX IX_Employee_StoreID ON dbo.Employee (StoreID);

CREATE INDEX IX_LoyaltyMembership_LoyaltyLevelID ON dbo.LoyaltyMembership (LoyaltyLevelID);

CREATE INDEX IX_CustomerPrediction_CustomerID ON dbo.CustomerPrediction (CustomerID);
CREATE INDEX IX_CustomerPrediction_PredictionDate ON dbo.CustomerPrediction (PredictionDate);

CREATE INDEX IX_AIReport_CampaignID   ON dbo.AIReport (CampaignID);
CREATE INDEX IX_AIReport_ReportType   ON dbo.AIReport (ReportType);
GO

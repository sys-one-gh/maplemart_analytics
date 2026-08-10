-- 05_CreateConstraints.sql
-- Foreign keys and CHECK constraints. Run after all tables (02-04) exist.

USE CustomerCampaignAnalytics;
GO

-- Required by the filtered UNIQUE INDEX below (sqlcmd's default session
-- setting is OFF, but filtered indexes require it ON).
SET QUOTED_IDENTIFIER ON;
GO

-- Operational table foreign keys -------------------------------------------
ALTER TABLE dbo.LoyaltyMembership  ADD CONSTRAINT FK_Customer_LoyaltyMembership FOREIGN KEY (CustomerID) REFERENCES dbo.Customer (CustomerID);
ALTER TABLE dbo.LoyaltyMembership  ADD CONSTRAINT FK_LoyaltyLevel_LoyaltyMembership FOREIGN KEY (LoyaltyLevelID) REFERENCES dbo.LoyaltyLevel (LoyaltyLevelID);

ALTER TABLE dbo.Employee ADD CONSTRAINT FK_Store_Employee FOREIGN KEY (StoreID) REFERENCES dbo.Store (StoreID);

ALTER TABLE dbo.Product ADD CONSTRAINT FK_ProductCategory_Product FOREIGN KEY (CategoryID) REFERENCES dbo.ProductCategory (CategoryID);

ALTER TABLE dbo.MarketingCampaign ADD CONSTRAINT FK_MarketingChannel_Campaign FOREIGN KEY (MarketingChannelID) REFERENCES dbo.MarketingChannel (MarketingChannelID);
ALTER TABLE dbo.MarketingCampaign ADD CONSTRAINT FK_CampaignType_Campaign FOREIGN KEY (CampaignTypeID) REFERENCES dbo.CampaignType (CampaignTypeID);

ALTER TABLE dbo.SalesTransaction ADD CONSTRAINT FK_Customer_SalesTransaction FOREIGN KEY (CustomerID) REFERENCES dbo.Customer (CustomerID);
ALTER TABLE dbo.SalesTransaction ADD CONSTRAINT FK_Store_SalesTransaction FOREIGN KEY (StoreID) REFERENCES dbo.Store (StoreID);
ALTER TABLE dbo.SalesTransaction ADD CONSTRAINT FK_PaymentMethod_SalesTransaction FOREIGN KEY (PaymentMethodID) REFERENCES dbo.PaymentMethod (PaymentMethodID);

ALTER TABLE dbo.SalesTransactionItem ADD CONSTRAINT FK_SalesTransaction_Item FOREIGN KEY (TransactionID) REFERENCES dbo.SalesTransaction (TransactionID);
ALTER TABLE dbo.SalesTransactionItem ADD CONSTRAINT FK_Product_SalesTransactionItem FOREIGN KEY (ProductID) REFERENCES dbo.Product (ProductID);

ALTER TABLE dbo.CampaignResponse ADD CONSTRAINT FK_MarketingCampaign_Response FOREIGN KEY (CampaignID) REFERENCES dbo.MarketingCampaign (CampaignID);
ALTER TABLE dbo.CampaignResponse ADD CONSTRAINT FK_Customer_CampaignResponse FOREIGN KEY (CustomerID) REFERENCES dbo.Customer (CustomerID);

-- Analytical table foreign keys ---------------------------------------------
ALTER TABLE dbo.CustomerPrediction ADD CONSTRAINT FK_Customer_CustomerPrediction FOREIGN KEY (CustomerID) REFERENCES dbo.Customer (CustomerID);
ALTER TABLE dbo.AIReport ADD CONSTRAINT FK_MarketingCampaign_AIReport FOREIGN KEY (CampaignID) REFERENCES dbo.MarketingCampaign (CampaignID);
GO

-- CHECK constraints -----------------------------------------------------
ALTER TABLE dbo.Customer ADD CONSTRAINT CK_Customer_Age CHECK (Age >= 18 AND Age <= 120);
ALTER TABLE dbo.Customer ADD CONSTRAINT CK_Customer_Status CHECK (CustomerStatus IN ('Active', 'Inactive', 'Suspended'));

ALTER TABLE dbo.Product ADD CONSTRAINT CK_Product_UnitPrice CHECK (UnitPrice >= 0);
ALTER TABLE dbo.Product ADD CONSTRAINT CK_Product_UnitCost CHECK (UnitCost >= 0);

ALTER TABLE dbo.MarketingCampaign ADD CONSTRAINT CK_Campaign_DiscountPercent CHECK (DiscountPercent BETWEEN 0 AND 100);
ALTER TABLE dbo.MarketingCampaign ADD CONSTRAINT CK_Campaign_Dates CHECK (EndDate >= StartDate);

ALTER TABLE dbo.SalesTransaction ADD CONSTRAINT CK_SalesTransaction_Total CHECK (TransactionTotal >= 0);

ALTER TABLE dbo.SalesTransactionItem ADD CONSTRAINT CK_TxnItem_Quantity CHECK (Quantity > 0);
ALTER TABLE dbo.SalesTransactionItem ADD CONSTRAINT CK_TxnItem_UnitPrice CHECK (UnitPrice >= 0);
-- Discount is a flat dollar amount deducted from the line (Quantity*UnitPrice - Discount = LineTotal),
-- confirmed against the source data - NOT a percentage, despite the similarly-named DiscountPercent on campaigns.
ALTER TABLE dbo.SalesTransactionItem ADD CONSTRAINT CK_TxnItem_Discount CHECK (Discount >= 0);
ALTER TABLE dbo.SalesTransactionItem ADD CONSTRAINT CK_TxnItem_LineTotal CHECK (LineTotal >= 0);

ALTER TABLE dbo.CampaignResponse ADD CONSTRAINT CK_Response_PurchaseAmount CHECK (PurchaseAmount >= 0);

ALTER TABLE dbo.LoyaltyMembership ADD CONSTRAINT CK_Loyalty_Points CHECK (CurrentPoints >= 0 AND LifetimePointsEarned >= 0 AND LifetimePointsRedeemed >= 0);

ALTER TABLE dbo.CustomerPrediction ADD CONSTRAINT CK_Prediction_Probability CHECK (PredictionProbability BETWEEN 0 AND 1);
ALTER TABLE dbo.CustomerPrediction ADD CONSTRAINT CK_Prediction_Result CHECK (PredictionResult IN ('Yes', 'No'));

ALTER TABLE dbo.ModelExecution ADD CONSTRAINT CK_Execution_Metrics CHECK (
    Accuracy BETWEEN 0 AND 1 AND Precision_ BETWEEN 0 AND 1 AND Recall BETWEEN 0 AND 1 AND F1Score BETWEEN 0 AND 1
);
GO

-- NOT unique: the real source data has ~41 customers sharing an email
-- (household/family accounts, or a source-data collision - see
-- Documentation/DataQualityReport.md). Enforcing UNIQUE here would mean
-- BULK INSERT silently fails/drops real customer rows, which violates
-- "historical data is never deleted". Indexed (not unique) for lookup speed.
CREATE INDEX IX_Customer_Email ON dbo.Customer (Email) WHERE Email IS NOT NULL;
GO

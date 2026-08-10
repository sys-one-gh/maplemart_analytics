-- 02_CreateReferenceTables.sql
-- Reference/lookup tables. Store and ProductCategory are populated
-- straight from their own CSVs (Stores.csv, ProductCategories.csv) so they
-- use the source file's ID as a natural primary key, not an identity.
--
-- LoyaltyLevel, PaymentMethod, MarketingChannel and CampaignType do NOT
-- have their own CSV - their values live as plain text columns inside
-- LoyaltyMemberships.csv, SalesTransactions.csv and MarketingCampaigns.csv.
-- We seed the known distinct values here; 10_LoadDataset.sql also inserts
-- any additional distinct value it finds in the source data that isn't
-- already seeded, so loading never fails because of an unseen value.

USE CustomerCampaignAnalytics;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.Store', 'U') IS NOT NULL DROP TABLE dbo.Store;
CREATE TABLE dbo.Store (
    StoreID     INT             NOT NULL,
    StoreName   NVARCHAR(100)   NOT NULL,
    City        NVARCHAR(100)   NOT NULL,
    Province    NVARCHAR(50)    NOT NULL,
    CONSTRAINT PK_Store PRIMARY KEY (StoreID)
);
GO

IF OBJECT_ID('dbo.ProductCategory', 'U') IS NOT NULL DROP TABLE dbo.ProductCategory;
CREATE TABLE dbo.ProductCategory (
    CategoryID      INT             NOT NULL,
    CategoryName    NVARCHAR(100)   NOT NULL,
    CONSTRAINT PK_ProductCategory PRIMARY KEY (CategoryID)
);
GO

IF OBJECT_ID('dbo.LoyaltyLevel', 'U') IS NOT NULL DROP TABLE dbo.LoyaltyLevel;
CREATE TABLE dbo.LoyaltyLevel (
    LoyaltyLevelID  INT IDENTITY(1,1)   NOT NULL,
    LevelName       NVARCHAR(50)        NOT NULL,
    CONSTRAINT PK_LoyaltyLevel PRIMARY KEY (LoyaltyLevelID),
    CONSTRAINT UQ_LoyaltyLevel_LevelName UNIQUE (LevelName)
);
GO
INSERT INTO dbo.LoyaltyLevel (LevelName) VALUES ('Bronze'), ('Silver'), ('Gold'), ('Platinum');
GO

IF OBJECT_ID('dbo.PaymentMethod', 'U') IS NOT NULL DROP TABLE dbo.PaymentMethod;
CREATE TABLE dbo.PaymentMethod (
    PaymentMethodID INT IDENTITY(1,1)  NOT NULL,
    MethodName      NVARCHAR(50)       NOT NULL,
    CONSTRAINT PK_PaymentMethod PRIMARY KEY (PaymentMethodID),
    CONSTRAINT UQ_PaymentMethod_MethodName UNIQUE (MethodName)
);
GO
INSERT INTO dbo.PaymentMethod (MethodName) VALUES ('Cash'), ('Credit'), ('Debit'), ('Mobile Payment');
GO

IF OBJECT_ID('dbo.MarketingChannel', 'U') IS NOT NULL DROP TABLE dbo.MarketingChannel;
CREATE TABLE dbo.MarketingChannel (
    MarketingChannelID INT IDENTITY(1,1)   NOT NULL,
    ChannelName         NVARCHAR(50)        NOT NULL,
    CONSTRAINT PK_MarketingChannel PRIMARY KEY (MarketingChannelID),
    CONSTRAINT UQ_MarketingChannel_ChannelName UNIQUE (ChannelName)
);
GO
INSERT INTO dbo.MarketingChannel (ChannelName) VALUES ('Email'), ('SMS'), ('Mobile App'), ('Social Media'), ('Direct Mail');
GO

IF OBJECT_ID('dbo.CampaignType', 'U') IS NOT NULL DROP TABLE dbo.CampaignType;
CREATE TABLE dbo.CampaignType (
    CampaignTypeID  INT IDENTITY(1,1)  NOT NULL,
    TypeName        NVARCHAR(50)       NOT NULL,
    CONSTRAINT PK_CampaignType PRIMARY KEY (CampaignTypeID),
    CONSTRAINT UQ_CampaignType_TypeName UNIQUE (TypeName)
);
GO
-- MarketingCampaigns.csv has no explicit "type" column; MarketingCampaign.CampaignTypeID
-- is derived from DiscountPercent by 10_LoadDataset.sql (documented there).
INSERT INTO dbo.CampaignType (TypeName) VALUES ('Deep Discount'), ('Standard Discount'), ('Loyalty/Retention'), ('Awareness');
GO

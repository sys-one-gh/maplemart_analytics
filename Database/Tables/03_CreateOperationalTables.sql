-- 03_CreateOperationalTables.sql
-- Core business tables. PKs for CSV-sourced entities are the source file's
-- own ID column (INT, not identity) so BULK INSERT can load them directly
-- without IDENTITY_INSERT juggling.

USE CustomerCampaignAnalytics;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.Customer', 'U') IS NOT NULL DROP TABLE dbo.Customer;
CREATE TABLE dbo.Customer (
    CustomerID       INT           NOT NULL,
    FirstName        NVARCHAR(50)  NOT NULL,
    LastName         NVARCHAR(50)  NOT NULL,
    Gender           NVARCHAR(20)  NULL,
    DateOfBirth      DATE          NOT NULL,
    Age              INT           NOT NULL,
    Email            NVARCHAR(255) NULL,
    Phone            NVARCHAR(20)  NULL,
    Address          NVARCHAR(200) NULL,
    City             NVARCHAR(100) NULL,
    Province         NVARCHAR(50)  NULL,
    PostalCode       CHAR(7)       NULL,
    RegistrationDate DATE          NOT NULL,
    CustomerStatus   NVARCHAR(20)  NOT NULL CONSTRAINT DF_Customer_Status DEFAULT ('Active'),
    CONSTRAINT PK_Customer PRIMARY KEY (CustomerID)
);
GO

IF OBJECT_ID('dbo.LoyaltyMembership', 'U') IS NOT NULL DROP TABLE dbo.LoyaltyMembership;
CREATE TABLE dbo.LoyaltyMembership (
    CustomerID            INT          NOT NULL,   -- 1:1 with Customer: this is both PK and FK
    LoyaltyNumber         NVARCHAR(20) NOT NULL,
    LoyaltyLevelID        INT          NOT NULL,
    JoinDate              DATE         NOT NULL,
    CurrentPoints         INT          NOT NULL CONSTRAINT DF_Loyalty_CurrentPoints DEFAULT (0),
    LifetimePointsEarned  INT          NOT NULL CONSTRAINT DF_Loyalty_Earned DEFAULT (0),
    LifetimePointsRedeemed INT         NOT NULL CONSTRAINT DF_Loyalty_Redeemed DEFAULT (0),
    CONSTRAINT PK_LoyaltyMembership PRIMARY KEY (CustomerID),
    CONSTRAINT UQ_LoyaltyMembership_Number UNIQUE (LoyaltyNumber)
);
GO

IF OBJECT_ID('dbo.Employee', 'U') IS NOT NULL DROP TABLE dbo.Employee;
CREATE TABLE dbo.Employee (
    EmployeeID INT          NOT NULL,
    FirstName  NVARCHAR(50) NOT NULL,
    LastName   NVARCHAR(50) NOT NULL,
    Role       NVARCHAR(50) NOT NULL,
    StoreID    INT          NOT NULL,
    CONSTRAINT PK_Employee PRIMARY KEY (EmployeeID)
);
GO

IF OBJECT_ID('dbo.Product', 'U') IS NOT NULL DROP TABLE dbo.Product;
CREATE TABLE dbo.Product (
    ProductID   INT           NOT NULL,
    ProductName NVARCHAR(150) NOT NULL,
    CategoryID  INT           NOT NULL,
    Brand       NVARCHAR(100) NULL,
    UnitPrice   DECIMAL(10,2) NOT NULL,
    UnitCost    DECIMAL(10,2) NOT NULL,
    CONSTRAINT PK_Product PRIMARY KEY (ProductID)
);
GO

IF OBJECT_ID('dbo.MarketingCampaign', 'U') IS NOT NULL DROP TABLE dbo.MarketingCampaign;
CREATE TABLE dbo.MarketingCampaign (
    CampaignID          INT           NOT NULL,
    CampaignName        NVARCHAR(150) NOT NULL,
    MarketingChannelID  INT           NOT NULL,
    CampaignTypeID      INT           NULL,   -- derived heuristically at load time, see 10_LoadDataset.sql
    StartDate           DATE          NOT NULL,
    EndDate             DATE          NOT NULL,
    DiscountPercent     DECIMAL(5,2)  NOT NULL,
    CONSTRAINT PK_MarketingCampaign PRIMARY KEY (CampaignID)
);
GO

IF OBJECT_ID('dbo.SalesTransaction', 'U') IS NOT NULL DROP TABLE dbo.SalesTransaction;
CREATE TABLE dbo.SalesTransaction (
    TransactionID     INT           NOT NULL,
    CustomerID        INT           NOT NULL,
    StoreID           INT           NOT NULL,
    TransactionDate   DATETIME2     NOT NULL,
    PaymentMethodID   INT           NOT NULL,
    TransactionTotal  DECIMAL(10,2) NOT NULL,
    CONSTRAINT PK_SalesTransaction PRIMARY KEY (TransactionID)
);
GO

IF OBJECT_ID('dbo.SalesTransactionItem', 'U') IS NOT NULL DROP TABLE dbo.SalesTransactionItem;
CREATE TABLE dbo.SalesTransactionItem (
    TransactionItemID INT           NOT NULL,
    TransactionID     INT           NOT NULL,
    ProductID         INT           NOT NULL,
    Quantity          INT           NOT NULL,
    UnitPrice         DECIMAL(10,2) NOT NULL,
    Discount          DECIMAL(10,2) NOT NULL CONSTRAINT DF_TxnItem_Discount DEFAULT (0), -- dollar amount, not a percent - see CK_TxnItem_Discount
    LineTotal         DECIMAL(10,2) NOT NULL,
    CONSTRAINT PK_SalesTransactionItem PRIMARY KEY (TransactionItemID)
);
GO

IF OBJECT_ID('dbo.CampaignResponse', 'U') IS NOT NULL DROP TABLE dbo.CampaignResponse;
CREATE TABLE dbo.CampaignResponse (
    ResponseID         INT           NOT NULL,
    CampaignID         INT           NOT NULL,
    CustomerID         INT           NOT NULL,
    EmailOpened        BIT           NOT NULL CONSTRAINT DF_Response_EmailOpened DEFAULT (0),
    CouponUsed         BIT           NOT NULL CONSTRAINT DF_Response_CouponUsed DEFAULT (0),
    PurchaseCompleted  BIT           NOT NULL CONSTRAINT DF_Response_PurchaseCompleted DEFAULT (0),
    PurchaseAmount     DECIMAL(10,2) NOT NULL CONSTRAINT DF_Response_PurchaseAmount DEFAULT (0),
    ResponseDate       DATETIME2     NOT NULL,
    CONSTRAINT PK_CampaignResponse PRIMARY KEY (ResponseID)
);
GO

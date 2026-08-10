-- 11_CreateSecurity.sql
-- Read-only login for Power BI. Password comes from the POWERBI_READER_PASSWORD
-- env var (see .env) - never hardcode it here. sqlcmd is invoked with
-- -v PowerBiPassword="..." by scripts/setup.sh; SSMS users should run this
-- with :setvar PowerBiPassword '...' set first, or just replace $(PowerBiPassword)
-- by hand before running interactively.

USE master;
GO

IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name = 'powerbi_reader')
BEGIN
    DECLARE @sql NVARCHAR(MAX) = N'CREATE LOGIN powerbi_reader WITH PASSWORD = ''' + '$(PowerBiPassword)' + N''', CHECK_POLICY = ON;';
    EXEC (@sql);
END
GO

USE CustomerCampaignAnalytics;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'powerbi_reader')
BEGIN
    CREATE USER powerbi_reader FOR LOGIN powerbi_reader;
END
GO

-- SELECT only, on the 5 mandatory views and the tables Power BI reads directly.
-- Never GRANT INSERT/UPDATE/DELETE to this user.
GRANT SELECT ON dbo.vwCustomerAnalytics      TO powerbi_reader;
GRANT SELECT ON dbo.vwCampaignPerformance    TO powerbi_reader;
GRANT SELECT ON dbo.vwSalesPerformance       TO powerbi_reader;
GRANT SELECT ON dbo.vwCustomerLifetimeValue  TO powerbi_reader;
GRANT SELECT ON dbo.vwPredictionResults      TO powerbi_reader;

GRANT SELECT ON dbo.Customer              TO powerbi_reader;
GRANT SELECT ON dbo.Product                TO powerbi_reader;
GRANT SELECT ON dbo.ProductCategory        TO powerbi_reader;
GRANT SELECT ON dbo.Store                  TO powerbi_reader;
GRANT SELECT ON dbo.SalesTransaction       TO powerbi_reader;
GRANT SELECT ON dbo.SalesTransactionItem   TO powerbi_reader;
GRANT SELECT ON dbo.MarketingCampaign      TO powerbi_reader;
GRANT SELECT ON dbo.CampaignResponse       TO powerbi_reader;
GRANT SELECT ON dbo.CustomerPrediction     TO powerbi_reader;
GRANT SELECT ON dbo.AIReport               TO powerbi_reader;
GRANT SELECT ON dbo.ModelExecution         TO powerbi_reader;
GO

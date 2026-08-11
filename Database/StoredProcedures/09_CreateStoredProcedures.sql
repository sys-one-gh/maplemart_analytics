-- 09_CreateStoredProcedures.sql
-- 7 mandatory procedures + uspLogModelExecution.
-- uspLoadDataset itself is defined in Database/DatabaseCreation/10_LoadDataset.sql
-- (it needs BULK INSERT logic that belongs next to the CSV loading order).

USE CustomerCampaignAnalytics;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.uspGenerateCustomerMetrics', 'P') IS NOT NULL DROP PROCEDURE dbo.uspGenerateCustomerMetrics;
GO
CREATE PROCEDURE dbo.uspGenerateCustomerMetrics
    @CustomerID INT = NULL   -- NULL = all customers
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.vwCustomerAnalytics
    WHERE @CustomerID IS NULL OR CustomerID = @CustomerID;
END
GO

IF OBJECT_ID('dbo.uspRefreshAnalytics', 'P') IS NOT NULL DROP PROCEDURE dbo.uspRefreshAnalytics;
GO
CREATE PROCEDURE dbo.uspRefreshAnalytics
AS
BEGIN
    SET NOCOUNT ON;
    -- Views are computed live on every query - nothing is cached, so
    -- "refresh" means keeping the query optimizer's statistics current
    -- after a bulk load, not rebuilding any data.
    UPDATE STATISTICS dbo.Customer;
    UPDATE STATISTICS dbo.SalesTransaction;
    UPDATE STATISTICS dbo.SalesTransactionItem;
    UPDATE STATISTICS dbo.CampaignResponse;
    UPDATE STATISTICS dbo.CustomerPrediction;
    SELECT 'Statistics refreshed' AS Status;
END
GO

IF OBJECT_ID('dbo.uspGeneratePredictionDataset', 'P') IS NOT NULL DROP PROCEDURE dbo.uspGeneratePredictionDataset;
GO
CREATE PROCEDURE dbo.uspGeneratePredictionDataset
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.vwCustomerAnalytics;
END
GO

IF OBJECT_ID('dbo.uspStorePredictionResults', 'P') IS NOT NULL DROP PROCEDURE dbo.uspStorePredictionResults;
GO
CREATE PROCEDURE dbo.uspStorePredictionResults
    @CustomerID             INT,
    @PredictionDate         DATETIME2,
    @PredictionProbability  DECIMAL(5,4),
    @PredictionResult       NVARCHAR(10),
    @MLModel                NVARCHAR(50),
    @ModelVersion           NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.CustomerPrediction
        (CustomerID, PredictionDate, PredictionProbability, PredictionResult, MLModel, ModelVersion)
    VALUES
        (@CustomerID, @PredictionDate, @PredictionProbability, @PredictionResult, @MLModel, @ModelVersion);

    SELECT SCOPE_IDENTITY() AS PredictionID;
END
GO

IF OBJECT_ID('dbo.uspStoreAIReport', 'P') IS NOT NULL DROP PROCEDURE dbo.uspStoreAIReport;
GO
CREATE PROCEDURE dbo.uspStoreAIReport
    @ReportType     NVARCHAR(50),
    @CampaignID     INT = NULL,
    @ModelName      NVARCHAR(50),
    @PromptVersion  NVARCHAR(20),
    @ReportText     NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.AIReport (ReportType, CampaignID, GeneratedDate, ModelName, PromptVersion, ReportText, Approved)
    VALUES (@ReportType, @CampaignID, SYSDATETIME(), @ModelName, @PromptVersion, @ReportText, 0);

    SELECT SCOPE_IDENTITY() AS AIReportID;
END
GO

IF OBJECT_ID('dbo.uspCampaignSummary', 'P') IS NOT NULL DROP PROCEDURE dbo.uspCampaignSummary;
GO
CREATE PROCEDURE dbo.uspCampaignSummary
    @CampaignID INT = NULL   -- NULL = all campaigns
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.vwCampaignPerformance
    WHERE @CampaignID IS NULL OR CampaignID = @CampaignID
    ORDER BY TotalRevenueGenerated DESC;
END
GO

IF OBJECT_ID('dbo.uspLogModelExecution', 'P') IS NOT NULL DROP PROCEDURE dbo.uspLogModelExecution;
GO
CREATE PROCEDURE dbo.uspLogModelExecution
    @Algorithm         NVARCHAR(50),
    @Accuracy          DECIMAL(5,4),
    @Precision         DECIMAL(5,4),
    @Recall            DECIMAL(5,4),
    @F1Score           DECIMAL(5,4),
    @DurationSeconds   DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.ModelExecution (ExecutionDate, Algorithm, Accuracy, Precision_, Recall, F1Score, ExecutionDurationSeconds)
    VALUES (SYSDATETIME(), @Algorithm, @Accuracy, @Precision, @Recall, @F1Score, @DurationSeconds);

    SELECT SCOPE_IDENTITY() AS ExecutionID;
END
GO

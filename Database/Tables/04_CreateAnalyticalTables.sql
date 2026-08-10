-- 04_CreateAnalyticalTables.sql
-- Tables written by the Python/Ollama pipeline, not loaded from CSV -
-- these use identity PKs since rows are generated at runtime.

USE CustomerCampaignAnalytics;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.CustomerPrediction', 'U') IS NOT NULL DROP TABLE dbo.CustomerPrediction;
CREATE TABLE dbo.CustomerPrediction (
    PredictionID         INT IDENTITY(1,1) NOT NULL,
    CustomerID           INT                NOT NULL,
    PredictionDate       DATETIME2          NOT NULL CONSTRAINT DF_Prediction_Date DEFAULT (SYSDATETIME()),
    PredictionProbability DECIMAL(5,4)      NOT NULL,
    PredictionResult     NVARCHAR(10)       NOT NULL,  -- 'Yes' / 'No'
    MLModel               NVARCHAR(50)       NOT NULL,  -- e.g. 'RandomForest'
    ModelVersion          NVARCHAR(20)       NOT NULL,  -- e.g. 'v1.0'
    CONSTRAINT PK_CustomerPrediction PRIMARY KEY (PredictionID)
);
GO

IF OBJECT_ID('dbo.AIReport', 'U') IS NOT NULL DROP TABLE dbo.AIReport;
CREATE TABLE dbo.AIReport (
    AIReportID     INT IDENTITY(1,1) NOT NULL,
    ReportType     NVARCHAR(50)      NOT NULL,  -- Executive Summary / Campaign Analysis / ...
    CampaignID     INT               NULL,      -- nullable: not every report is campaign-specific
    GeneratedDate  DATETIME2         NOT NULL CONSTRAINT DF_AIReport_Date DEFAULT (SYSDATETIME()),
    ModelName      NVARCHAR(50)      NOT NULL,  -- 'mistral'
    PromptVersion  NVARCHAR(20)      NOT NULL,
    ReportText     NVARCHAR(MAX)     NOT NULL,
    Approved       BIT               NOT NULL CONSTRAINT DF_AIReport_Approved DEFAULT (0),
    CONSTRAINT PK_AIReport PRIMARY KEY (AIReportID)
);
GO

IF OBJECT_ID('dbo.ModelExecution', 'U') IS NOT NULL DROP TABLE dbo.ModelExecution;
CREATE TABLE dbo.ModelExecution (
    ExecutionID             INT IDENTITY(1,1) NOT NULL,
    ExecutionDate           DATETIME2          NOT NULL CONSTRAINT DF_Execution_Date DEFAULT (SYSDATETIME()),
    Algorithm               NVARCHAR(50)       NOT NULL,
    Accuracy                DECIMAL(5,4)       NOT NULL,
    Precision_              DECIMAL(5,4)       NOT NULL,  -- PRECISION is a reserved word in T-SQL
    Recall                  DECIMAL(5,4)       NOT NULL,
    F1Score                 DECIMAL(5,4)       NOT NULL,
    ExecutionDurationSeconds DECIMAL(10,2)     NOT NULL,
    CONSTRAINT PK_ModelExecution PRIMARY KEY (ExecutionID)
);
GO

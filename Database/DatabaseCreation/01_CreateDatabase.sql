-- 01_CreateDatabase.sql
-- Creates the single project database. Safe to re-run: drops and recreates
-- it from scratch every time, so scripts 02-12 never have to reason about
-- leftover objects/FKs from a previous run (e.g. dropping a reference
-- table that an earlier run's operational tables still reference).

IF DB_ID(N'CustomerCampaignAnalytics') IS NOT NULL
BEGIN
    ALTER DATABASE CustomerCampaignAnalytics SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CustomerCampaignAnalytics;
END
GO

CREATE DATABASE CustomerCampaignAnalytics;
GO

ALTER DATABASE CustomerCampaignAnalytics SET RECOVERY SIMPLE;
GO

USE CustomerCampaignAnalytics;
GO

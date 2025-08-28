CREATE TABLE [History].[HHSurvey__Vehicle]
(
[hhid] [int] NOT NULL,
[vehnum] [int] NOT NULL,
[vehid] [bigint] NOT NULL,
[make] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[model] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[model_other] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[year] [smallint] NOT NULL,
[fuel] [int] NOT NULL,
[toll_transponder] [int] NOT NULL,
[survey_year] [smallint] NOT NULL,
[valid_from] [datetime2] NOT NULL,
[valid_to] [datetime2] NOT NULL
) ON [PRIMARY]
GO
CREATE CLUSTERED INDEX [ix_HHSurvey__Vehicle] ON [History].[HHSurvey__Vehicle] ([valid_to], [valid_from]) ON [PRIMARY]
GO
CREATE TABLE [HHSurvey].[Vehicle]
(
[hhid] [int] NOT NULL,
[vehnum] [int] NOT NULL,
[vehid] [bigint] NOT NULL,
[make] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[model] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[model_other] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[year] [smallint] NOT NULL,
[fuel] [int] NOT NULL,
[toll_transponder] [int] NOT NULL,
[survey_year] [smallint] NOT NULL,
[valid_from] [datetime2] GENERATED ALWAYS AS ROW START NOT NULL CONSTRAINT [HHSurvey_Vehicle_valid_from_default] DEFAULT (sysutcdatetime()),
[valid_to] [datetime2] GENERATED ALWAYS AS ROW END NOT NULL CONSTRAINT [HHSurvey_Vehicle_valid_to_default] DEFAULT ('9999-12-31 23:59:59.9999999'),
PERIOD FOR SYSTEM_TIME (valid_from, valid_to),
CONSTRAINT [HHSurvey_Vehicle_PK] PRIMARY KEY CLUSTERED ([vehid]) ON [PRIMARY]
) ON [PRIMARY]
WITH
(
SYSTEM_VERSIONING = ON (HISTORY_TABLE = [History].[HHSurvey__Vehicle])
)
GO

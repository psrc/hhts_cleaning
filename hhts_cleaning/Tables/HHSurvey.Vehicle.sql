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
[survey_year] [smallint] NOT NULL
) ON [PRIMARY]
GO

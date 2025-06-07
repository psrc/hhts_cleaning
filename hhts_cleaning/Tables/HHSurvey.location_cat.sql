CREATE TABLE [HHSurvey].[location_cat]
(
[tripid] [decimal] (19, 0) NOT NULL,
[dest_purpose] [int] NULL,
[trace_quality_flag] [smallint] NULL,
[api_result] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[location_type_id] [smallint] NULL,
[match_bing] [tinyint] NULL
) ON [PRIMARY]
GO
ALTER TABLE [HHSurvey].[location_cat] ADD CONSTRAINT [PK__location__303DBBBDD58C0D24] PRIMARY KEY CLUSTERED ([tripid]) ON [PRIMARY]
GO

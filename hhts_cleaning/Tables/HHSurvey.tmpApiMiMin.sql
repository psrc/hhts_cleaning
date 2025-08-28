CREATE TABLE [HHSurvey].[tmpApiMiMin]
(
[tripid] [decimal] (19, 0) NOT NULL,
[origin_geog] [sys].[geography] NULL,
[dest_geog] [sys].[geography] NULL,
[distance_miles] [float] NULL,
[revision_code] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[prev_arrival] [datetime2] NULL,
[depart] [datetime2] NULL,
[arrival] [datetime2] NULL,
[next_depart] [datetime2] NULL,
[query_mode] [varchar] (7) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[api_result] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[tmiles] [float] NULL,
[tminutes] [float] NULL,
[adj] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [HHSurvey].[tmpApiMiMin] ADD CONSTRAINT [PK__tmpApiMi__303DBBBD36F07731] PRIMARY KEY CLUSTERED ([tripid]) ON [PRIMARY]
GO

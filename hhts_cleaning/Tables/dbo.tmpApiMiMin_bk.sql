CREATE TABLE [dbo].[tmpApiMiMin_bk]
(
[recid] [int] NOT NULL,
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
[tmiles] [float] NOT NULL,
[tminutes] [float] NOT NULL,
[adj] [int] NOT NULL
) ON [PRIMARY]
GO

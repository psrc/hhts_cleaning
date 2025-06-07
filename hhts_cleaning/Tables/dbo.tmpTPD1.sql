CREATE TABLE [dbo].[tmpTPD1]
(
[recid] [int] NOT NULL,
[origin_lat] [float] NULL,
[origin_lng] [float] NULL,
[dest_lat] [float] NULL,
[dest_lng] [float] NULL,
[mode_1] [smallint] NOT NULL,
[mi_min_result] [varchar] (39) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO

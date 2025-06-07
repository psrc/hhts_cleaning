CREATE TABLE [dbo].[bing_response]
(
[tripid] [decimal] (19, 0) NULL,
[mode_1] [smallint] NULL,
[api_mode] [nvarchar] (15) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[mi_min_result] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[route_distance] [float] NULL,
[route_minutes] [float] NULL
) ON [PRIMARY]
GO

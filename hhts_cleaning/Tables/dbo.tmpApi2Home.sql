CREATE TABLE [dbo].[tmpApi2Home]
(
[rownum] [int] NOT NULL IDENTITY(1, 1),
[init_recid] [int] NULL,
[new_recid] [int] NULL,
[hhid] [int] NULL,
[person_id] [decimal] (19, 0) NULL,
[pernum] [int] NULL,
[api_response] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[depart_time_timestamp] [datetime2] NULL,
[api_minutes] [float] NULL,
[origin_geog] [sys].[geography] NULL,
[home_geog] [sys].[geography] NULL,
[mode_1] [int] NULL,
[travelers_hh] [int] NULL,
[travelers_nonhh] [int] NULL,
[travelers_total] [int] NULL,
[api_miles] [float] NULL
) ON [PRIMARY]
GO

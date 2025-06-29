CREATE TABLE [dbo].[trip_bk]
(
[recid] [int] NOT NULL IDENTITY(1, 1),
[hhid] [decimal] (19, 0) NOT NULL,
[person_id] [decimal] (19, 0) NOT NULL,
[pernum] [int] NULL,
[tripid] [decimal] (19, 0) NULL,
[tripnum] [int] NOT NULL,
[traveldate] [datetime2] NULL,
[daynum] [int] NULL,
[copied_trip] [int] NULL,
[svy_complete] [int] NULL,
[depart_time_timestamp] [datetime2] NULL,
[arrival_time_timestamp] [datetime2] NULL,
[origin_label] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[origin_lat] [float] NULL,
[origin_lng] [float] NULL,
[orgin_label] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[dest_lat] [float] NULL,
[dest_lng] [float] NULL,
[dest_label] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[distance_miles] [float] NULL,
[travel_time] [float] NULL,
[hhmember1] [decimal] (19, 0) NULL,
[hhmember2] [decimal] (19, 0) NULL,
[hhmember3] [decimal] (19, 0) NULL,
[hhmember4] [decimal] (19, 0) NULL,
[hhmember5] [decimal] (19, 0) NULL,
[hhmember6] [decimal] (19, 0) NULL,
[hhmember7] [decimal] (19, 0) NULL,
[hhmember8] [decimal] (19, 0) NULL,
[hhmember9] [decimal] (19, 0) NULL,
[travelers_hh] [int] NOT NULL,
[travelers_nonhh] [int] NOT NULL,
[travelers_total] [int] NOT NULL,
[origin_purpose] [int] NULL,
[origin_purpose_cat] [int] NULL,
[dest_purpose] [int] NULL,
[dest_purpose_other] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[dest_purpose_cat] [int] NULL,
[mode_1] [smallint] NOT NULL,
[mode_2] [smallint] NULL,
[mode_3] [smallint] NULL,
[mode_4] [smallint] NULL,
[mode_type] [int] NULL,
[driver] [smallint] NULL,
[change_vehicles] [smallint] NULL,
[is_access] [smallint] NULL,
[is_egress] [smallint] NULL,
[mode_acc] [smallint] NULL,
[mode_egr] [smallint] NULL,
[speed_mph] [float] NULL,
[trace_quality_flag] [smallint] NULL,
[user_added] [smallint] NULL,
[user_merged] [smallint] NULL,
[user_split] [smallint] NULL,
[analyst_merged] [smallint] NULL,
[analyst_split] [smallint] NULL,
[analyst_split_loop] [smallint] NULL,
[psrc_comment] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[psrc_resolved] [smallint] NULL,
[origin_geog] [sys].[geography] NULL,
[dest_geog] [sys].[geography] NULL,
[dest_county] [varchar] (3) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[dest_city] [varchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[dest_zip] [varchar] (5) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[dest_is_home] [bit] NULL,
[dest_is_work] [bit] NULL,
[modes] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[psrc_inserted] [bit] NULL,
[revision_code] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[time_adj] [smallint] NULL
) ON [PRIMARY]
GO

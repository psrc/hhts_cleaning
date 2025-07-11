CREATE TABLE [dbo].[trip_bk_20231213]
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
[origin_lat] [float] NULL,
[origin_lng] [float] NULL,
[origin_label] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
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
[has_access] [smallint] NULL,
[has_egress] [smallint] NULL,
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
[day_id] [bigint] NOT NULL,
[travel_day] [int] NOT NULL,
[travel_date] [date] NOT NULL,
[travel_dow] [int] NOT NULL,
[day_iscomplete] [smallint] NULL,
[depart_date] [date] NOT NULL,
[depart_dow] [int] NOT NULL,
[depart_time_hour] [int] NOT NULL,
[depart_time_minute] [int] NOT NULL,
[depart_time_second] [int] NOT NULL,
[arrive_date] [date] NOT NULL,
[arrive_dow] [int] NOT NULL,
[arrival_time_hour] [int] NOT NULL,
[arrival_time_minute] [int] NOT NULL,
[arrival_time_second] [int] NOT NULL,
[o_in_region] [int] NOT NULL,
[o_puma10] [int] NULL,
[o_bg] [bigint] NULL,
[d_in_region] [int] NOT NULL,
[d_puma10] [int] NULL,
[d_bg] [bigint] NULL,
[distance_meters] [float] NULL,
[duration_minutes] [int] NOT NULL,
[duration_seconds] [int] NOT NULL,
[speed_flag] [int] NOT NULL,
[dwell_mins] [float] NOT NULL,
[days_first_trip] [int] NOT NULL,
[days_last_trip] [int] NOT NULL,
[mode_other_specify] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[is_transit] [int] NOT NULL,
[hhmember10] [int] NOT NULL,
[hhmember11] [int] NOT NULL,
[hhmember12] [int] NOT NULL,
[taxi_cost_known] [int] NOT NULL,
[taxi_cost_int] [int] NULL,
[flag_teleport] [int] NOT NULL,
[pt_density] [float] NULL,
[point_dist_index] [float] NULL,
[trip_weight] [int] NOT NULL,
[survey_year] [int] NOT NULL,
[day_is_complete_a] [smallint] NULL,
[day_is_complete_b] [smallint] NULL,
[hh_day_iscomplete] [smallint] NULL,
[hh_day_iscomplete_a] [smallint] NULL,
[hh_day_iscomplete_b] [smallint] NULL,
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
[revision_code] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO

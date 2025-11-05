CREATE TABLE [HHSurvey].[TripHistory]
(
[recid] [decimal] (19, 0) NOT NULL,
[hhid] [decimal] (19, 0) NOT NULL,
[person_id] [decimal] (19, 0) NOT NULL,
[pernum] [int] NULL,
[tripid] [decimal] (19, 0) NULL,
[tripnum] [int] NOT NULL,
[traveldate] [datetime2] NULL,
[daynum] [int] NULL,
[depart_time_timestamp] [datetime2] NULL,
[arrival_time_timestamp] [datetime2] NULL,
[origin_lat] [float] NULL,
[origin_lng] [float] NULL,
[dest_lat] [float] NULL,
[dest_lng] [float] NULL,
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
[hhmember10] [decimal] (19, 0) NULL,
[hhmember11] [decimal] (19, 0) NULL,
[hhmember12] [decimal] (19, 0) NULL,
[hhmember13] [decimal] (19, 0) NULL,
[travelers_hh] [int] NOT NULL,
[travelers_nonhh] [int] NOT NULL,
[travelers_total] [int] NOT NULL,
[origin_purpose] [int] NULL,
[dest_purpose] [int] NULL,
[dest_purpose_other] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[mode_1] [int] NOT NULL,
[mode_2] [int] NULL,
[mode_3] [int] NULL,
[mode_4] [int] NULL,
[driver] [int] NULL,
[mode_acc] [int] NULL,
[mode_egr] [int] NULL,
[speed_mph] [float] NULL,
[mode_other_specify] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[origin_geog] [sys].[geography] NULL,
[dest_geog] [sys].[geography] NULL,
[dest_is_home] [bit] NULL,
[dest_is_work] [bit] NULL,
[modes] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[psrc_inserted] [bit] NULL,
[revision_code] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[psrc_resolved] [int] NULL,
[psrc_comment] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ValidFrom] [datetime2] NOT NULL,
[ValidTo] [datetime2] NOT NULL
) ON [PRIMARY]
GO
CREATE CLUSTERED INDEX [ix_TripHistory] ON [HHSurvey].[TripHistory] ([ValidTo], [ValidFrom]) ON [PRIMARY]
GO
CREATE TABLE [HHSurvey].[Trip]
(
[recid] [decimal] (19, 0) NOT NULL IDENTITY(1, 1),
[hhid] [decimal] (19, 0) NOT NULL,
[person_id] [decimal] (19, 0) NOT NULL,
[pernum] [int] NULL,
[tripid] [decimal] (19, 0) NULL,
[tripnum] [int] NOT NULL CONSTRAINT [DF__Trip__tripnum__3DF4B35D] DEFAULT ((0)),
[traveldate] [datetime2] NULL,
[daynum] [int] NULL,
[depart_time_timestamp] [datetime2] NULL,
[arrival_time_timestamp] [datetime2] NULL,
[origin_lat] [float] NULL,
[origin_lng] [float] NULL,
[dest_lat] [float] NULL,
[dest_lng] [float] NULL,
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
[hhmember10] [decimal] (19, 0) NULL,
[hhmember11] [decimal] (19, 0) NULL,
[hhmember12] [decimal] (19, 0) NULL,
[hhmember13] [decimal] (19, 0) NULL,
[travelers_hh] [int] NOT NULL,
[travelers_nonhh] [int] NOT NULL,
[travelers_total] [int] NOT NULL,
[origin_purpose] [int] NULL,
[dest_purpose] [int] NULL,
[dest_purpose_other] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[mode_1] [int] NOT NULL,
[mode_2] [int] NULL,
[mode_3] [int] NULL,
[mode_4] [int] NULL,
[driver] [int] NULL,
[mode_acc] [int] NULL,
[mode_egr] [int] NULL,
[speed_mph] [float] NULL,
[mode_other_specify] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[origin_geog] [sys].[geography] NULL,
[dest_geog] [sys].[geography] NULL,
[dest_is_home] [bit] NULL,
[dest_is_work] [bit] NULL,
[modes] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[psrc_inserted] [bit] NULL,
[revision_code] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[psrc_resolved] [int] NULL,
[psrc_comment] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ValidFrom] [datetime2] GENERATED ALWAYS AS ROW START HIDDEN NOT NULL CONSTRAINT [DF__Trip__ValidFrom__43AD8CB3] DEFAULT (sysutcdatetime()),
[ValidTo] [datetime2] GENERATED ALWAYS AS ROW END HIDDEN NOT NULL CONSTRAINT [DF__Trip__ValidTo__44A1B0EC] DEFAULT (CONVERT([datetime2],'9999-12-31 23:59:59.9999999')),
PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo),
CONSTRAINT [PK_trip_recid] PRIMARY KEY CLUSTERED ([recid]) WITH (FILLFACTOR=80) ON [PRIMARY]
) ON [PRIMARY]
WITH
(
SYSTEM_VERSIONING = ON (HISTORY_TABLE = [HHSurvey].[TripHistory])
)
GO
CREATE NONCLUSTERED INDEX [dest_purpose_idx] ON [HHSurvey].[Trip] ([dest_purpose]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [person_idx] ON [HHSurvey].[Trip] ([person_id]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [person_timestamps] ON [HHSurvey].[Trip] ([person_id], [depart_time_timestamp], [arrival_time_timestamp]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [person_tripnum_idx] ON [HHSurvey].[Trip] ([person_id], [tripnum]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [travelers_total_idx] ON [HHSurvey].[Trip] ([travelers_total]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [tripnum_idx] ON [HHSurvey].[Trip] ([tripnum]) ON [PRIMARY]
GO
CREATE SPATIAL INDEX [dest_geog_idx] ON [HHSurvey].[Trip] ([dest_geog]) WITH (CELLS_PER_OBJECT = 12) ON [PRIMARY]
GO
CREATE SPATIAL INDEX [origin_geog_idx] ON [HHSurvey].[Trip] ([origin_geog]) WITH (CELLS_PER_OBJECT = 12) ON [PRIMARY]
GO

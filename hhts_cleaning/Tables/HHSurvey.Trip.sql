CREATE TABLE [History].[HHSurvey__Trip]
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
[mode_1] [int] NULL,
[mode_2] [int] NULL,
[mode_3] [int] NULL,
[mode_4] [int] NULL,
[driver] [smallint] NULL,
[mode_acc] [smallint] NULL,
[mode_egr] [smallint] NULL,
[speed_mph] [float] NULL,
[mode_other_specify] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[origin_geog] [sys].[geography] NULL,
[dest_geog] [sys].[geography] NULL,
[dest_is_home] [bit] NULL,
[dest_is_work] [bit] NULL,
[modes] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[psrc_inserted] [bit] NULL,
[revision_code] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[psrc_resolved] [smallint] NULL,
[psrc_comment] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[valid_from] [datetime2] NOT NULL,
[valid_to] [datetime2] NOT NULL
) ON [PRIMARY]
GO
CREATE CLUSTERED INDEX [ix_HHSurvey__Trip] ON [History].[HHSurvey__Trip] ([valid_to], [valid_from]) ON [PRIMARY]
GO
CREATE TABLE [HHSurvey].[Trip]
(
[recid] [decimal] (19, 0) NOT NULL IDENTITY(1, 1),
[hhid] [decimal] (19, 0) NOT NULL,
[person_id] [decimal] (19, 0) NOT NULL,
[pernum] [int] NULL,
[tripid] [decimal] (19, 0) NULL,
[tripnum] [int] NOT NULL CONSTRAINT [DF__Trip__tripnum__31C3E6A2] DEFAULT ((0)),
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
[mode_1] [int] NULL,
[mode_2] [int] NULL,
[mode_3] [int] NULL,
[mode_4] [int] NULL,
[driver] [smallint] NULL,
[mode_acc] [smallint] NULL,
[mode_egr] [smallint] NULL,
[speed_mph] [float] NULL,
[mode_other_specify] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[origin_geog] [sys].[geography] NULL,
[dest_geog] [sys].[geography] NULL,
[dest_is_home] [bit] NULL,
[dest_is_work] [bit] NULL,
[modes] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[psrc_inserted] [bit] NULL,
[revision_code] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[psrc_resolved] [smallint] NULL,
[psrc_comment] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[valid_from] [datetime2] GENERATED ALWAYS AS ROW START NOT NULL CONSTRAINT [HHSurvey_Trip_valid_from_default] DEFAULT (sysutcdatetime()),
[valid_to] [datetime2] GENERATED ALWAYS AS ROW END NOT NULL CONSTRAINT [HHSurvey_Trip_valid_to_default] DEFAULT ('9999-12-31 23:59:59.9999999'),
PERIOD FOR SYSTEM_TIME (valid_from, valid_to),
CONSTRAINT [PK_recid] PRIMARY KEY CLUSTERED ([recid]) WITH (FILLFACTOR=80) ON [PRIMARY]
) ON [PRIMARY]
WITH
(
SYSTEM_VERSIONING = ON (HISTORY_TABLE = [History].[HHSurvey__Trip])
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
CREATE NONCLUSTERED INDEX [IX_Trip_recid_person] ON [HHSurvey].[Trip] ([recid], [person_id]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [travelers_total_idx] ON [HHSurvey].[Trip] ([travelers_total]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [tripnum_idx] ON [HHSurvey].[Trip] ([tripnum]) ON [PRIMARY]
GO
CREATE SPATIAL INDEX [dest_geog_idx] ON [HHSurvey].[Trip] ([dest_geog]) WITH (CELLS_PER_OBJECT = 12) ON [PRIMARY]
GO
CREATE SPATIAL INDEX [origin_geog_idx] ON [HHSurvey].[Trip] ([origin_geog]) WITH (CELLS_PER_OBJECT = 12) ON [PRIMARY]
GO

CREATE TABLE [HHSurvey].[Trip_gapfill_backup]
(
[backup_id] [int] NOT NULL IDENTITY(1, 1),
[reason] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[person_id] [bigint] NULL,
[prior_recid] [int] NULL,
[next_recid] [int] NULL,
[block_id] [bigint] NULL,
[block_first_depart] [datetime2] NULL,
[block_last_arrive] [datetime2] NULL,
[original_revision_code] [nvarchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[trip_recid] [int] NULL,
[depart_time_timestamp] [datetime2] NULL,
[arrival_time_timestamp] [datetime2] NULL,
[origin_geog] [sys].[geography] NULL,
[dest_geog] [sys].[geography] NULL,
[dest_purpose] [int] NULL,
[mode_1] [int] NULL,
[distance_miles] [float] NULL,
[created_at] [datetime2] NULL CONSTRAINT [DF__Trip_gapf__creat__19B752E7] DEFAULT (sysutcdatetime())
) ON [PRIMARY]
GO
ALTER TABLE [HHSurvey].[Trip_gapfill_backup] ADD CONSTRAINT [PK__Trip_gap__AE70C880C06438CF] PRIMARY KEY CLUSTERED ([backup_id]) ON [PRIMARY]
GO

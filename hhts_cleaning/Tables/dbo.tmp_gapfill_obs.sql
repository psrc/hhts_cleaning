CREATE TABLE [dbo].[tmp_gapfill_obs]
(
[deleted_id] [int] NOT NULL IDENTITY(1, 1),
[removed_at_utc] [datetime2] NOT NULL CONSTRAINT [DF__tmp_gapfi__remov__2BD60322] DEFAULT (sysutcdatetime()),
[removal_rev_type] [nvarchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[removal_reason] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[recid] [decimal] (19, 0) NULL,
[hhid] [decimal] (19, 0) NULL,
[person_id] [decimal] (19, 0) NULL,
[pernum] [int] NULL,
[tripnum] [int] NULL,
[depart_time_timestamp] [datetime2] NULL,
[arrival_time_timestamp] [datetime2] NULL,
[origin_lat] [float] NULL,
[origin_lng] [float] NULL,
[dest_lat] [float] NULL,
[dest_lng] [float] NULL,
[distance_miles] [float] NULL,
[travel_time] [float] NULL,
[dest_purpose] [int] NULL,
[mode_1] [int] NULL,
[modes] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[psrc_inserted] [bit] NULL,
[revision_code] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[psrc_comment] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[travelers_hh] [int] NULL,
[travelers_nonhh] [int] NULL,
[travelers_total] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[tmp_gapfill_obs] ADD CONSTRAINT [PK__tmp_gapf__4672768027E95CEB] PRIMARY KEY CLUSTERED ([deleted_id]) ON [PRIMARY]
GO

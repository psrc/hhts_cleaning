CREATE TABLE [HHSurvey].[mode_imputation_log]
(
[log_id] [bigint] NOT NULL IDENTITY(1, 1),
[recid] [decimal] (19, 0) NOT NULL,
[person_id] [decimal] (19, 0) NULL,
[tripnum] [int] NULL,
[traveldate] [date] NULL,
[method] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[confidence] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[chosen_family] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[chosen_mode_id] [int] NULL,
[prev_mode_id] [int] NULL,
[distance_miles] [float] NULL,
[duration_minutes] [float] NULL,
[avg_speed_mph] [float] NULL,
[tour_id] [int] NULL,
[donor_recid] [decimal] (19, 0) NULL,
[donor_person_id] [decimal] (19, 0) NULL,
[donor_tripnum] [int] NULL,
[api_driving_min] [float] NULL,
[api_transit_min] [float] NULL,
[api_bicycling_min] [float] NULL,
[api_walking_min] [float] NULL,
[api_best_mode] [nvarchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[api_diff_minutes] [float] NULL,
[api_calls_used] [int] NULL,
[notes] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[created_at] [datetime2] NOT NULL CONSTRAINT [DF__mode_impu__creat__794A8355] DEFAULT (sysutcdatetime())
) ON [PRIMARY]
GO
ALTER TABLE [HHSurvey].[mode_imputation_log] ADD CONSTRAINT [PK__mode_imp__9E2397E0C33C1CBD] PRIMARY KEY CLUSTERED ([log_id]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_mode_imputation_log_person] ON [HHSurvey].[mode_imputation_log] ([person_id], [traveldate]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_mode_imputation_log_recid] ON [HHSurvey].[mode_imputation_log] ([recid]) ON [PRIMARY]
GO

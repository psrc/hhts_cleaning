CREATE TABLE [History].[HHSurvey__trip_error_flags]
(
[recid] [decimal] (19, 0) NOT NULL,
[person_id] [decimal] (19, 0) NOT NULL,
[tripnum] [int] NOT NULL,
[error_flag] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[valid_from] [datetime2] NOT NULL,
[valid_to] [datetime2] NOT NULL
) ON [PRIMARY]
GO
CREATE CLUSTERED INDEX [ix_HHSurvey__trip_error_flags] ON [History].[HHSurvey__trip_error_flags] ([valid_to], [valid_from]) ON [PRIMARY]
GO
CREATE TABLE [HHSurvey].[trip_error_flags]
(
[recid] [decimal] (19, 0) NOT NULL,
[person_id] [decimal] (19, 0) NOT NULL,
[tripnum] [int] NOT NULL,
[error_flag] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[valid_from] [datetime2] GENERATED ALWAYS AS ROW START HIDDEN NOT NULL CONSTRAINT [HHSurvey_trip_error_flags_valid_from_default] DEFAULT (sysutcdatetime()),
[valid_to] [datetime2] GENERATED ALWAYS AS ROW END HIDDEN NOT NULL CONSTRAINT [HHSurvey_trip_error_flags_valid_to_default] DEFAULT ('9999-12-31 23:59:59.9999999'),
PERIOD FOR SYSTEM_TIME (valid_from, valid_to),
CONSTRAINT [PK__trip_err__A85F028DD88F9687] PRIMARY KEY CLUSTERED ([person_id], [recid], [error_flag]) ON [PRIMARY]
) ON [PRIMARY]
WITH
(
SYSTEM_VERSIONING = ON (HISTORY_TABLE = [History].[HHSurvey__trip_error_flags])
)
GO

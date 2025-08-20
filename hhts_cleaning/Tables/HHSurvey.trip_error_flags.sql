CREATE TABLE [HHSurvey].[trip_error_flags]
(
[recid] [decimal] (19, 0) NOT NULL,
[person_id] [decimal] (19, 0) NOT NULL,
[tripnum] [int] NOT NULL,
[error_flag] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [HHSurvey].[trip_error_flags] ADD CONSTRAINT [PK__trip_err__A85F028D92832636] PRIMARY KEY CLUSTERED ([person_id], [recid], [error_flag]) ON [PRIMARY]
GO

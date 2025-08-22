CREATE TABLE [HHSurvey].[trip_purpose]
(
[purpose_id] [int] NOT NULL,
[purpose] [nvarchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [HHSurvey].[trip_purpose] ADD CONSTRAINT [PK_trip_purpose] PRIMARY KEY CLUSTERED ([purpose_id]) ON [PRIMARY]
GO

CREATE TABLE [HHSurvey].[trip_mode]
(
[mode_id] [smallint] NOT NULL,
[mode_desc] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [HHSurvey].[trip_mode] ADD CONSTRAINT [PK_trip_mode] PRIMARY KEY CLUSTERED ([mode_id]) ON [PRIMARY]
GO

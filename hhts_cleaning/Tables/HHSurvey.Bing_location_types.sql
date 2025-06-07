CREATE TABLE [HHSurvey].[Bing_location_types]
(
[location_type_id] [int] NOT NULL IDENTITY(1, 1),
[location_type] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[dest_purpose] [smallint] NULL
) ON [PRIMARY]
GO
ALTER TABLE [HHSurvey].[Bing_location_types] ADD CONSTRAINT [PK__Bing_loc__535FD89A34538F29] PRIMARY KEY CLUSTERED ([location_type_id]) ON [PRIMARY]
GO

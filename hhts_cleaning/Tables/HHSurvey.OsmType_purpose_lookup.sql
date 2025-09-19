CREATE TABLE [HHSurvey].[OsmType_purpose_lookup]
(
[OsmType_id] [int] NOT NULL IDENTITY(1, 1),
[OsmType] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[dest_purpose] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [HHSurvey].[OsmType_purpose_lookup] ADD CONSTRAINT [PK__OsmType___3F19910D41ACB6E6] PRIMARY KEY CLUSTERED ([OsmType_id]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_OsmType_lookup_dest_purpose] ON [HHSurvey].[OsmType_purpose_lookup] ([dest_purpose]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_OsmType_lookup_OsmType] ON [HHSurvey].[OsmType_purpose_lookup] ([OsmType]) ON [PRIMARY]
GO

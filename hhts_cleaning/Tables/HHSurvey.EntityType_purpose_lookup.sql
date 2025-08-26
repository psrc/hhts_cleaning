CREATE TABLE [HHSurvey].[EntityType_purpose_lookup]
(
[EntityType_id] [int] NOT NULL IDENTITY(1, 1),
[category] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[EntityType] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[dest_purpose] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [HHSurvey].[EntityType_purpose_lookup] ADD CONSTRAINT [PK__EntityTy__70D5571C9888858E] PRIMARY KEY CLUSTERED ([EntityType_id]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_google_entitytype_lookup_category] ON [HHSurvey].[EntityType_purpose_lookup] ([category]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_google_entitytype_lookup_dest_purpose] ON [HHSurvey].[EntityType_purpose_lookup] ([dest_purpose]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_google_entitytype_lookup_entitytype] ON [HHSurvey].[EntityType_purpose_lookup] ([EntityType]) ON [PRIMARY]
GO

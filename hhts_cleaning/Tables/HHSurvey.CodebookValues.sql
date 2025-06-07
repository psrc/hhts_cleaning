CREATE TABLE [HHSurvey].[CodebookValues]
(
[variable] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[value] [int] NOT NULL,
[label] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[recid] [int] NOT NULL IDENTITY(1, 1)
) ON [PRIMARY]
GO
CREATE UNIQUE CLUSTERED INDEX [idx_CodebookValues_recid] ON [HHSurvey].[CodebookValues] ([recid]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [idx_CodebookValues_variable] ON [HHSurvey].[CodebookValues] ([variable]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [idx_CodebookValues_variable_value] ON [HHSurvey].[CodebookValues] ([variable], [value]) ON [PRIMARY]
GO

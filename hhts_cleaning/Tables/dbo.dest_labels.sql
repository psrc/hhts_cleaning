CREATE TABLE [dbo].[dest_labels]
(
[tripid] [bigint] NOT NULL,
[origin_label] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[dest_label] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO

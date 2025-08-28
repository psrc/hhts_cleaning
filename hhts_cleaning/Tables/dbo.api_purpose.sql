CREATE TABLE [dbo].[api_purpose]
(
[recid] [decimal] (19, 0) NOT NULL,
[dest_lat] [float] NULL,
[dest_lng] [float] NULL,
[dwell] [int] NULL,
[loc_result] [nvarchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[new_dest_purpose] [int] NOT NULL
) ON [PRIMARY]
GO

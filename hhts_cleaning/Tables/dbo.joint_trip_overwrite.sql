CREATE TABLE [dbo].[joint_trip_overwrite]
(
[flagged_trip] [bigint] NOT NULL,
[unflagged_cotraveler_trip] [bigint] NULL
) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ft_idx] ON [dbo].[joint_trip_overwrite] ([flagged_trip]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [uct_idx] ON [dbo].[joint_trip_overwrite] ([unflagged_cotraveler_trip]) ON [PRIMARY]
GO

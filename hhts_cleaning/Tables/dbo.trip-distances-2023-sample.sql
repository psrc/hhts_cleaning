CREATE TABLE [dbo].[trip-distances-2023-sample]
(
[column1] [tinyint] NULL,
[destinationIndex] [tinyint] NULL,
[originIndex] [tinyint] NULL,
[totalWalkDuration] [tinyint] NULL,
[travelDistance] [float] NULL,
[travelDuration] [float] NULL,
[TRIPID] [bigint] NOT NULL,
[ORIGIN_LAT] [float] NOT NULL,
[ORIGIN_LNG] [float] NOT NULL,
[DEST_LAT] [float] NOT NULL,
[DEST_LNG] [float] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[trip-distances-2023-sample] ADD CONSTRAINT [PK_trip-distances-2023-sample] PRIMARY KEY CLUSTERED ([TRIPID]) ON [PRIMARY]
GO

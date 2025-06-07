SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
	CREATE VIEW [HHSurvey].[pass2trip] WITH SCHEMABINDING
	AS
	SELECT t.[recid]
		   ,h.[hhid]
		   ,t.[person_id] AS personid
		   ,t.[pernum]
		   ,t.[tripid]
		   ,t.[tripnum]
		   ,t.[traveldate]
		   ,t.[daynum]
		   ,CASE WHEN h.hhgroup=11 THEN 'rMove' ELSE 'rSurvey' END AS hhgroup
		   ,t.[copied_trip]
		   ,t.[svy_complete]
		   ,t.[depart_time_timestamp]
		   ,t.[arrival_time_timestamp]
		   ,'' AS origin_name
		   ,t.[origin_lat]
		   ,t.[origin_lng]
		   ,'' AS dest_name
		   ,t.[dest_lat]
		   ,t.[dest_lng]
		   ,t.distance_miles AS trip_path_distance
		   ,t.[travel_time]
		   ,t.[hhmember1]
		   ,t.[hhmember2]
		   ,t.[hhmember3]
		   ,t.[hhmember4]
		   ,t.[hhmember5]
		   ,t.[hhmember6]
		   ,t.[hhmember7]
		   ,t.[hhmember8]
		   ,t.[hhmember9]
		   ,t.[travelers_hh]
		   ,t.[travelers_nonhh]
		   ,t.[travelers_total]
		   ,t.[origin_purpose]
		   ,t.[dest_purpose]
		   ,t.[mode_1]
		   ,t.[mode_2]
		   ,t.[mode_3]
		   ,t.[mode_4]
		   ,t.[driver]
		   ,t.[mode_acc]
		   ,t.[mode_egr]
		   ,t.[speed_mph]
		   ,t.[psrc_comment]
		   ,t.[psrc_resolved]
	FROM HHSurvey.Trip AS t JOIN HHSurvey.Household AS h on h.hhid=t.hhid;
GO
CREATE UNIQUE CLUSTERED INDEX [PK_pass2trip] ON [HHSurvey].[pass2trip] ([recid]) ON [PRIMARY]
GO

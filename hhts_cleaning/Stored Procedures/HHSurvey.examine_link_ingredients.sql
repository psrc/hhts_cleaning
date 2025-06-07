SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
		CREATE PROCEDURE [HHSurvey].[examine_link_ingredients]
			@target_recid numeric NULL --provide recid of reference member
		
		AS BEGIN
		SET NOCOUNT OFF;
		WITH cte AS
		(SELECT tid0.person_id, tid0.trip_link FROM HHSurvey.trip_ingredients_done AS tid0 WHERE tid0.recid = @target_recid)
		SELECT tid.recid, tid.person_id, tid.hhid, tid.tripnum, tid.daynum, tid.mode_1,
			FORMAT(tid.depart_time_timestamp,N'hh\:mm tt','en-US') AS depart_dhm,
			FORMAT(tid.arrival_time_timestamp,N'hh\:mm tt','en-US') AS arrive_dhm,
			ROUND(tid.distance_miles,1) AS miles,
			ROUND(tid.speed_mph,1) AS mph, 
			CONCAT(tid.origin_purpose, '-',tpo.purpose) AS origin_purpose, tid.dest_label, CONCAT(tid.dest_purpose, '-',tpd.purpose) AS dest_purpose, 
				CONCAT(CONVERT(varchar(30), (DATEDIFF(mi, tid.arrival_time_timestamp, t2.depart_time_timestamp) / 60)),'h',RIGHT('00'+CONVERT(varchar(30), (DATEDIFF(mi, tid.arrival_time_timestamp, CASE WHEN t2.recid IS NULL 
										THEN DATETIME2FROMPARTS(DATEPART(year,tid.arrival_time_timestamp),DATEPART(month,tid.arrival_time_timestamp),DATEPART(day,tid.arrival_time_timestamp),3,0,0,0,0) 
										ELSE t2.depart_time_timestamp END) % 60)),2),'m') AS duration_at_dest,
				CONCAT(CAST(tid.origin_lat AS VARCHAR(20)),', ',CAST(tid.origin_lng AS VARCHAR(20))) AS origin_coord,						 
				CONCAT(CAST(tid.dest_lat AS VARCHAR(20)),', ',CAST(tid.dest_lng AS VARCHAR(20))) AS dest_coord,
				tid.revision_code AS rc, tid.psrc_comment AS elevate_issue
			FROM HHSurvey.trip_ingredients_done AS tid 
				JOIN cte ON tid.trip_link = cte.trip_link AND tid.person_id = cte.person_id
				LEFT JOIN HHSurvey.trip_ingredients_done as t2 ON tid.person_id = t2.person_id AND (tid.tripnum+1) = t2.tripnum
				LEFT JOIN HHSurvey.trip_purpose AS tpo ON tid.origin_purpose=tpo.purpose_id
				LEFT JOIN HHSurvey.trip_purpose AS tpd ON tid.dest_purpose=tpd.purpose_id
		ORDER BY tid.tripnum ASC;
		END
GO

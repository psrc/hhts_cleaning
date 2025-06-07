SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
	CREATE VIEW [HHSurvey].[data2fixie] WITH SCHEMABINDING  
	AS
	SELECT t1.recid, t1.person_id AS personid, t1.hhid, t1.pernum, CASE WHEN h.hhgroup=11 THEN 'rMove' ELSE 'rSurvey' END AS hhgroup, 
	       CASE WHEN EXISTS (SELECT 1 FROM HHSurvey.Trip WHERE Trip.psrc_comment IS NOT NULL AND t1.person_id = Trip.person_id) THEN 1 ELSE 0 END AS Elevated, 0 AS Seattle,
			t1.tripnum, 
			STUFF(	COALESCE(',' + CAST(ma.mode_desc AS nvarchar), '') + 
					COALESCE(',' + CAST(m1.mode_desc AS nvarchar), '') + 
					COALESCE(',' + CAST(m2.mode_desc AS nvarchar), '') + 
					COALESCE(',' + CAST(m3.mode_desc AS nvarchar), '') + 
					COALESCE(',' + CAST(m4.mode_desc AS nvarchar), '') +
					COALESCE(',' + CAST(me.mode_desc AS nvarchar), ''), 1, 1, '') AS modes_desc,
			t1.daynum,	 
			FORMAT(t1.depart_time_timestamp,N'hh\:mm tt','en-US') AS depart_dhm,
			FORMAT(t1.arrival_time_timestamp,N'hh\:mm tt','en-US') AS arrive_dhm,
			ROUND(t1.distance_miles,1) AS miles,
			ROUND(t1.speed_mph,1) AS mph, 
			ROUND(t1.dest_geog.STDistance(t1.origin_geog) / 1609.344, 1) AS linear_miles,
			CASE WHEN DATEDIFF(minute, t1.depart_time_timestamp, t1.arrival_time_timestamp) > 0 
					THEN ROUND((t1.dest_geog.STDistance(t1.origin_geog) / 1609.344) / (CAST(DATEDIFF(second, t1.depart_time_timestamp, t1.arrival_time_timestamp) AS decimal) / 3600),1) 
					ELSE -9999 END AS linear_mph,
			STUFF(
					(SELECT ',' + tef.error_flag
						FROM HHSurvey.trip_error_flags AS tef
						WHERE tef.recid = t1.recid
						ORDER BY tef.error_flag DESC
						FOR XML PATH('')), 1, 1, NULL) AS Error,
			CASE WHEN t1.travelers_total = 1 THEN '' ELSE CONCAT(CAST(t1.travelers_total - 1 AS nvarchar),' - ', 
					STUFF(	
						COALESCE(',' + CASE WHEN t1.hhmember1 <> t1.pernum AND NOT EXISTS (SELECT flag_value from HHSurvey.NullFlags WHERE flag_value = t1.hhmember1) THEN RIGHT(CAST(t1.hhmember1 AS nvarchar),2) ELSE NULL END, '') +
						COALESCE(',' + CASE WHEN t1.hhmember2 <> t1.pernum AND NOT EXISTS (SELECT flag_value from HHSurvey.NullFlags WHERE flag_value = t1.hhmember2) THEN RIGHT(CAST(t1.hhmember2 AS nvarchar),2) ELSE NULL END, '') + 
						COALESCE(',' + CASE WHEN t1.hhmember3 <> t1.pernum AND NOT EXISTS (SELECT flag_value from HHSurvey.NullFlags WHERE flag_value = t1.hhmember3) THEN RIGHT(CAST(t1.hhmember3 AS nvarchar),2) ELSE NULL END, '') + 
						COALESCE(',' + CASE WHEN t1.hhmember4 <> t1.pernum AND NOT EXISTS (SELECT flag_value from HHSurvey.NullFlags WHERE flag_value = t1.hhmember4) THEN RIGHT(CAST(t1.hhmember4 AS nvarchar),2) ELSE NULL END, '') + 
						COALESCE(',' + CASE WHEN t1.hhmember5 <> t1.pernum AND NOT EXISTS (SELECT flag_value from HHSurvey.NullFlags WHERE flag_value = t1.hhmember5) THEN RIGHT(CAST(t1.hhmember5 AS nvarchar),2) ELSE NULL END, '') + 
						COALESCE(',' + CASE WHEN t1.hhmember6 <> t1.pernum AND NOT EXISTS (SELECT flag_value from HHSurvey.NullFlags WHERE flag_value = t1.hhmember6) THEN RIGHT(CAST(t1.hhmember6 AS nvarchar),2) ELSE NULL END, '') + 
						COALESCE(',' + CASE WHEN t1.hhmember7 <> t1.pernum AND NOT EXISTS (SELECT flag_value from HHSurvey.NullFlags WHERE flag_value = t1.hhmember7) THEN RIGHT(CAST(t1.hhmember7 AS nvarchar),2) ELSE NULL END, '') + 
						COALESCE(',' + CASE WHEN t1.hhmember8 <> t1.pernum AND NOT EXISTS (SELECT flag_value from HHSurvey.NullFlags WHERE flag_value = t1.hhmember8) THEN RIGHT(CAST(t1.hhmember8 AS nvarchar),2) ELSE NULL END, '') + 
						COALESCE(',' + CASE WHEN t1.hhmember9 <> t1.pernum AND NOT EXISTS (SELECT flag_value from HHSurvey.NullFlags WHERE flag_value = t1.hhmember9) THEN RIGHT(CAST(t1.hhmember9 AS nvarchar),2) ELSE NULL END, ''), 
							1, 1, '')) END AS cotravelers,
				CONCAT(t1.origin_purpose, '-',tpo.purpose) AS origin_purpose, '' AS dest_name, CONCAT(t1.dest_purpose, '-',tpd.purpose) AS dest_purpose, 
				CONCAT(CONVERT(varchar(30), (DATEDIFF(mi, t1.arrival_time_timestamp, t2.depart_time_timestamp) / 60)),'h',RIGHT('00'+CONVERT(varchar(30), (DATEDIFF(mi, t1.arrival_time_timestamp, CASE WHEN t2.recid IS NULL 
										THEN DATETIME2FROMPARTS(DATEPART(year,t1.arrival_time_timestamp),DATEPART(month,t1.arrival_time_timestamp),DATEPART(day,t1.arrival_time_timestamp),3,0,0,0,0) 
										ELSE t2.depart_time_timestamp END) % 60)),2),'m') AS duration_at_dest,
				CONCAT(CAST(t1.origin_lat AS VARCHAR(20)),', ',CAST(t1.origin_lng AS VARCHAR(20))) AS origin_coord,						 
				CONCAT(CAST(t1.dest_lat AS VARCHAR(20)),', ',CAST(t1.dest_lng AS VARCHAR(20))) AS dest_coord,
				t1.revision_code AS rc, t1.psrc_comment AS elevate_issue
		FROM HHSurvey.trip AS t1 LEFT JOIN HHSurvey.trip as t2 ON t1.person_id = t2.person_id AND (t1.tripnum+1) = t2.tripnum JOIN HHSurvey.Household AS h on h.hhid=t1.hhid
			LEFT JOIN HHSurvey.trip_mode AS ma ON t1.mode_acc=ma.mode_id AND ma.mode_id NOT IN(SELECT flag_value FROM HHSurvey.NullFlags)
			LEFT JOIN HHSurvey.trip_mode AS m1 ON t1.mode_1=m1.mode_id AND m1.mode_id NOT IN(SELECT flag_value FROM HHSurvey.NullFlags)
			LEFT JOIN HHSurvey.trip_mode AS m2 ON t1.mode_2=m2.mode_id AND m2.mode_id NOT IN(SELECT flag_value FROM HHSurvey.NullFlags)
			LEFT JOIN HHSurvey.trip_mode AS m3 ON t1.mode_3=m3.mode_id AND m3.mode_id NOT IN(SELECT flag_value FROM HHSurvey.NullFlags)
			LEFT JOIN HHSurvey.trip_mode AS m4 ON t1.mode_4=m4.mode_id AND m4.mode_id NOT IN(SELECT flag_value FROM HHSurvey.NullFlags)
			LEFT JOIN HHSurvey.trip_mode AS me ON t1.mode_egr=me.mode_id AND me.mode_id NOT IN(SELECT flag_value FROM HHSurvey.NullFlags)
			LEFT JOIN HHSurvey.trip_purpose AS tpo ON t1.origin_purpose=tpo.purpose_id
			LEFT JOIN HHSurvey.trip_purpose AS tpd ON t1.dest_purpose=tpd.purpose_id;
GO

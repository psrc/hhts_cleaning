SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [HHSurvey].[data2fixie] WITH SCHEMABINDING  
	AS
	SELECT 
        t1.recid, 
        t1.person_id,
        t1.daynum,	
        t1.tripnum, 
        STUFF((SELECT ',' + tef.error_flag
                FROM HHSurvey.trip_error_flags AS tef
                WHERE tef.recid = t1.recid
                ORDER BY tef.error_flag DESC
                FOR XML PATH('')), 1, 1, NULL) AS Error,
        STUFF((SELECT DISTINCT ',' + mode_desc
                FROM (
                    SELECT ma.mode_desc UNION ALL
                    SELECT m1.mode_desc UNION ALL  
                    SELECT m2.mode_desc UNION ALL
                    SELECT m3.mode_desc UNION ALL
                    SELECT m4.mode_desc UNION ALL
                    SELECT me.mode_desc
                ) AS all_modes
                WHERE mode_desc IS NOT NULL
                FOR XML PATH('')
            ), 1, 1, '') AS Modes, 
        FORMAT(t1.depart_time_timestamp,N'hh\:mm tt','en-US') AS DepartTime,
        FORMAT(t1.arrival_time_timestamp,N'hh\:mm tt','en-US') AS ArriveTime,
        ROUND(t1.distance_miles,1) AS Miles,
        ROUND(t1.speed_mph,1) AS MPH, 
        t1.travelers_total AS TotalTravelers,
        CONCAT(t1.origin_purpose, ': ',tpo.purpose) AS OriginPurpose, 
        CONCAT(t1.dest_purpose, ': ',tpd.purpose) AS DestPurpose,
        t1.dest_purpose_other AS OtherPurpose,
        CONCAT(CONVERT(varchar(30), (DATEDIFF(mi, t1.arrival_time_timestamp, t2.depart_time_timestamp) / 60)),'h',RIGHT('00'+CONVERT(varchar(30), (DATEDIFF(mi, t1.arrival_time_timestamp, CASE WHEN t2.recid IS NULL 
                                THEN DATETIME2FROMPARTS(DATEPART(year,t1.arrival_time_timestamp),DATEPART(month,t1.arrival_time_timestamp),DATEPART(day,t1.arrival_time_timestamp),3,0,0,0,0) 
                                ELSE t2.depart_time_timestamp END) % 60)),2),'m') AS DurationAtDest,
        t1.revision_code--, 
        -- t1.psrc_comment AS ElevateIssue,
        -- CASE WHEN EXISTS (SELECT 1 FROM HHSurvey.Trip WHERE Trip.psrc_comment IS NOT NULL AND t1.person_id = Trip.person_id) THEN 1 ELSE 0 END AS Elevated
        
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

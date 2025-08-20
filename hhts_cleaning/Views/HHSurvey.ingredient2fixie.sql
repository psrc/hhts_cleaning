SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

	CREATE VIEW [HHSurvey].[ingredient2fixie] WITH SCHEMABINDING  
        AS
        SELECT
        t1.recid,
        t1.person_id,
        t1.daynum,
        t1.tripid,
        t1.tripnum,
        t1.depart_time_timestamp,
        t1.arrival_time_timestamp,
        FORMAT(t1.depart_time_timestamp,N'hh\:mm tt','en-US') AS DepartTime,
        FORMAT(t1.arrival_time_timestamp,N'hh\:mm tt','en-US') AS ArriveTime,
        CONCAT(t1.origin_purpose, ': ',tpo.purpose) AS OriginPurpose, 
        CONCAT(t1.dest_purpose, ': ',tpd.purpose) AS DestPurpose,
        m1.mode_desc AS mode_1,
        t1.trip_link
    FROM HHSurvey.trip_ingredients_done AS t1
    LEFT JOIN HHSurvey.trip_purpose AS tpo ON t1.origin_purpose=tpo.purpose_id
    LEFT JOIN HHSurvey.trip_purpose AS tpd ON t1.dest_purpose=tpd.purpose_id
    LEFT JOIN HHSurvey.trip_mode AS m1 ON t1.mode_1=m1.mode_id AND m1.mode_id NOT IN(SELECT flag_value FROM HHSurvey.NullFlags);
    -- WHERE t1.person_id = 2322121601 and t1.trip_link IN (SELECT trip_link FROM HHSurvey.trip_ingredients_done WHERE recid = 12)
    -- ORDER BY t1.person_id,t1.daynum,t1.depart_time_timestamp, arrival_time_timestamp
GO

SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [HHSurvey].[revise_excessive_speed_trips] @BingKey nvarchar
AS BEGIN

    BEGIN TRANSACTION;
    DROP TABLE IF EXISTS dbo.tmpApiMiMin;
    COMMIT TRANSACTION;

    BEGIN TRANSACTION;
    CREATE TABLE [dbo].[tmpApiMiMin](
        tripid decimal(19,0) PRIMARY KEY NOT NULL,
        origin_geog geography NULL,
        dest_geog geography NULL,
        distance_miles float NULL,
        revision_code nvarchar(50) NOT NULL,
        prev_arrival datetime2(7) NULL,
        depart datetime2(7) NULL,
        arrival datetime2(7) NULL,
        next_depart datetime2(7) NULL,
        query_mode varchar(7) NOT NULL,
        api_result nvarchar(max) NULL,
        tmiles float NULL,
        tminutes float NULL,
        adj int NULL
    )
    COMMIT TRANSACTION;

    BEGIN TRANSACTION;
    WITH cte AS (SELECT t.tripid, t.origin_geog, t.dest_geog, t.distance_miles, CONCAT(t.revision_code, '12,') AS revision_code,
        prev_t.arrival_time_timestamp AS prev_arrival, t.depart_time_timestamp AS depart, t.arrival_time_timestamp AS arrival, next_t.depart_time_timestamp AS next_depart, 
        CASE WHEN EXISTS (SELECT 1 FROM HHSurvey.walkmodes WHERE walkmodes.mode_id = t.mode_1) THEN 'walking' 
                --WHEN EXISTS (SELECT 1 FROM HHSurvey.transitmodes WHERE transitmodes.mode_id = t.mode_1) THEN 'transit' 
                ELSE 'driving' END as query_mode
    FROM HHSurvey.Trip AS t
            LEFT JOIN HHSurvey.Trip AS prev_t ON t.person_id = prev_t.person_id AND t.tripnum -1 = prev_t.tripnum
            LEFT JOIN HHSurvey.Trip AS next_t ON t.person_id = next_t.person_id AND t.tripnum +1 = next_t.tripnum
            JOIN dbo.bing_response AS br ON t.tripid=br.tripid 
        WHERE (EXISTS (SELECT 1 FROM HHSurvey.walkmodes WHERE walkmodes.mode_id = t.mode_1) AND t.speed_mph > 20)
            OR (EXISTS (SELECT 1 FROM HHSurvey.automodes WHERE automodes.mode_id = t.mode_1) AND t.speed_mph > 85)	
            OR (EXISTS (SELECT 1 FROM HHSurvey.transitmodes WHERE transitmodes.mode_id = t.mode_1) AND t.mode_1 <> 31 AND t.speed_mph > 60)	
            OR (t.speed_mph > 600 AND (t.origin_lng between -140 AND -116.95) AND (t.dest_lng between -140 AND -116.95))    -- qualifies for 'excessive speed' flag
            OR t.depart_time_timestamp=t.arrival_time_timestamp                                                             -- instantaneous
            OR DATEDIFF(Minute,  t.depart_time_timestamp,  t.arrival_time_timestamp) > 180 AND  t.speed_mph < 20	        -- qualifies for 'too slow' flag
            )
    INSERT INTO dbo.tmpApiMiMin(tripid, origin_geog, dest_geog, distance_miles, revision_code, prev_arrival, depart, arrival, next_depart, query_mode)
    SELECT cte.*
    FROM cte
    WHERE cte.origin_geog.Lat BETWEEN 45 AND 50
        AND cte.origin_geog.Long BETWEEN -126 AND -117 
        AND cte.dest_geog.Lat BETWEEN 45 AND 50
        AND cte.dest_geog.Long BETWEEN -126 AND -117 
        AND NOT EXISTS (SELECT 1 FROM dbo.tmpApiMiMin AS tam WHERE tam.tripid=cte.tripid);
    COMMIT TRANSACTION;

--Add a for loop here to keep API call batches small
    DECLARE @i int
    SET @i = (SELECT count(*) FROM dbo.tmpApiMiMin WHERE api_result ='')
    WHILE @i > 0
    BEGIN 
        BEGIN TRANSACTION;
        UPDATE TOP (5) [m]
        SET m.api_result=Elmer.dbo.route_mi_min(m.origin_geog.Long, m.origin_geog.Lat, m.dest_geog.Long, m.dest_geog.Lat, m.query_mode, @BingKey)
        FROM dbo.tmpApiMiMin AS m
        WHERE m.api_result IS NULL AND m.origin_geog IS NOT NULL AND m.dest_geog IS NOT NULL AND m.query_mode IS NOT NULL;

        SET @i = (SELECT count(*) FROM dbo.tmpApiMiMin WHERE api_result ='')
        COMMIT TRANSACTION;
    END

    UPDATE dbo.tmpApiMiMin SET tmiles = CAST(Elmer.dbo.rgx_replace(api_result,'^(.*),.*','$1',1) AS float), 
                            tminutes = CAST(Elmer.dbo.rgx_replace(api_result,'.*,(.*)$','$1',1) AS float)
    WHERE api_result IS NOT NULL;

    UPDATE dbo.tmpApiMiMin
        SET distance_miles = tmiles, adj = 1,
        depart  = DATEADD(Second, round(-60 * tminutes, 0), arrival)
        WHERE (DATEDIFF(Second, prev_arrival, arrival)/60.0 -1 > tminutes OR prev_arrival IS NULL) AND adj IS NULL		  --fits the window to adjust departure only	
            AND (query_mode <> 'walking' 
            OR DATEDIFF(Day, DATEADD(Hour, 3, DATEADD(Second, round(-60 * tminutes, 0), arrival)), arrival) = 0); 		  --walk doesn't cross 3am boundary	

    UPDATE dbo.tmpApiMiMin
        SET distance_miles = tmiles, adj = 1,
        arrival  = DATEADD(Second, round(60 * tminutes, 0), depart)
        WHERE (DATEDIFF(Second, next_depart, depart)/60.0 -1 > tminutes OR next_depart IS NULL) AND adj IS NULL		  --fits the window to adjust arrival only	
            AND (query_mode <> 'walking' 
            OR DATEDIFF(Day, DATEADD(Hour, 3, DATEADD(Second, round(60 * tminutes, 0), depart)), depart) = 0); 		  --walk doesn't cross 3am boundary	

    UPDATE dbo.tmpApiMiMin
        SET distance_miles = tmiles, adj = 2,
        depart  = DATEADD(Second, (DATEDIFF(Second, prev_arrival, next_depart)/2 - tminutes * 30), prev_arrival), 
        arrival =  DATEADD(Second, (DATEDIFF(Second, prev_arrival, next_depart)/2 + tminutes * 30), prev_arrival) 
        WHERE (DATEDIFF(Second, prev_arrival, next_depart)/60.0 -2) > tminutes AND adj IS NULL		                	  --fits the maximum travel window
            AND (query_mode <> 'walking' 
            OR DATEDIFF(Day, DATEADD(Hour, 3, 
                DATEADD(Second, (DATEDIFF(Second, prev_arrival, next_depart)/2 - tminutes * 30), prev_arrival)), 
                DATEADD(Second, (DATEDIFF(Second, prev_arrival, next_depart)/2 + tminutes * 30), prev_arrival)) = 0);     --walk doesn't cross 3am boundary	
    
    UPDATE dbo.tmpApiMiMin
        SET adj = -1, revision_code = CONCAT(revision_code, '13,'), 											          --where walk doesn't fit, try driving
        tminutes = CAST(Elmer.dbo.rgx_replace(Elmer.dbo.route_mi_min(origin_geog.Long, origin_geog.Lat, dest_geog.Long, dest_geog.Lat,'driving', @BingKey),'.*,(.*)$','$1',1) AS float)
        WHERE query_mode = 'walking' AND adj IS NULL AND DATEDIFF(Minute, depart, arrival)/60 < 7;

    UPDATE dbo.tmpApiMiMin
        SET adj = 3
        WHERE adj = -1 																		   	                	 	   --only potential mode recodes
            AND ABS(DATEDIFF(Second, depart, arrival)/60 - tminutes) < 5; 												   --drive matches reported time 

    UPDATE t																											   --carry out the update for relevant records
        SET t.distance_miles = amm.distance_miles, 
            t.revision_code = amm.revision_code, 
            t.depart_time_timestamp = amm.depart, 
            t.arrival_time_timestamp = amm.arrival,
            t.mode_1 = CASE WHEN amm.adj = 3 THEN 16 ELSE t.mode_1 END
        FROM HHSurvey.Trip AS t JOIN dbo.tmpApiMiMin AS amm ON t.tripid = amm.tripid
        WHERE amm.adj > 0;

    DROP TABLE HHSurvey.tmpApiMiMin;																					  --clean up

END 
GO

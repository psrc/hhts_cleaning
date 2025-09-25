SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [HHSurvey].[link_trips_systemically]
AS BEGIN

    DECLARE @trip_ingredients_input HHSurvey.TripIngredientType;

    -- Populate consolidated modes field, used later
    BEGIN TRANSACTION;
    UPDATE HHSurvey.Trip
        SET modes = CONCAT_WS(',', mode_1, mode_2, mode_3, mode_4)
    COMMIT TRANSACTION;

    BEGIN TRANSACTION;
    -- impute mode for vehicular tour components
    WITH cte AS (SELECT t.recid, next_t.modes AS simple_tour_mode
                    FROM HHSurvey.Trip AS t JOIN HHSurvey.Trip AS prev_t ON t.person_id=prev_t.person_id AND t.tripnum -1 = prev_t.tripnum 
                                            JOIN HHSurvey.Trip AS next_t ON t.person_id=next_t.person_id AND t.tripnum +1 = next_t.tripnum 	
                    WHERE t.modes IS NULL AND t.dest_purpose<>51                                              -- exclude exercise (potential loop?)
                    AND next_t.modes IN(SELECT mode_id FROM HHSurvey.automodes) AND prev_t.modes=next_t.modes -- missing mode trip surrounded by trip using same vehicle
                    AND Elmer.dbo.rgx_find(next_t.modes,',',1)=0)                                             --only single-mode tripes for simplicity
    UPDATE t2
    SET t2.modes = cte.simple_tour_mode, t2.mode_1= cte.simple_tour_mode
    FROM HHSurvey.Trip AS t2 JOIN cte ON t2.recid=cte.recid WHERE t2.modes IS NULL;		

    -- impute mode for a two-trip tour when one half is missing
    WITH cte AS (SELECT CASE WHEN t.modes IS NULL THEN t.recid WHEN next_t.modes IS NULL THEN next_t.recid END AS recid, 
                        COALESCE(t.modes, next_t.modes) AS mirror_mode
                    FROM HHSurvey.Trip AS t JOIN HHSurvey.Trip AS prev_t ON t.person_id=prev_t.person_id AND t.tripnum -1 = prev_t.tripnum 
                                            JOIN HHSurvey.Trip AS next_t ON t.person_id=next_t.person_id AND t.tripnum +1 = next_t.tripnum 	
                    WHERE prev_t.dest_geog.STDistance(next_t.dest_geog) < 30 AND t.distance_miles * 1609 > 120
                    AND (t.modes IS NULL OR next_t.modes IS NULL) AND COALESCE(t.modes, next_t.modes) IS NOT NULL)
    UPDATE t2
    SET t2.modes = cte.mirror_mode
    FROM HHSurvey.Trip AS t2 JOIN cte ON t2.recid=cte.recid WHERE t2.modes IS NULL;	

    -- impute mode for cases on the spectrum ends of speed + distance: 
        -- slow, short trips are walk; long, fast trips are airplane.  Other modes can't be easily assumed.
    UPDATE t 
    SET t.modes = 31, t.revision_code = CONCAT(t.revision_code,'7,')	
    FROM HHSurvey.Trip AS t 
    WHERE t.modes IS NULL AND t.distance_miles > 200 AND t.speed_mph between 200 and 600;

    UPDATE t 
    SET t.modes = 1,  t.mode_1=1, t.revision_code = CONCAT(t.revision_code,'7,') 	
    FROM HHSurvey.Trip AS t 
    WHERE t.modes IS NULL AND t.distance_miles < 0.6 AND t.speed_mph < 5;

-- Drop trips that go nowhere and replicate prior purpose
    
    DELETE t 
    FROM HHSurvey.Trip AS t 
    LEFT JOIN HHSurvey.Trip AS prev_t ON t.person_id=prev_t.person_id AND t.tripnum - 1 = prev_t.tripnum
    LEFT JOIN HHSurvey.Trip AS next_t ON t.person_id=next_t.person_id AND t.tripnum + 1 = next_t.tripnum
    WHERE t.depart_time_timestamp=t.arrival_time_timestamp
        AND ((t.origin_geog.STEquals(prev_t.origin_geog)=1 AND t.dest_geog.STEquals(prev_t.dest_geog)=1)
        OR (t.origin_geog.STEquals(t.dest_geog)=1)) AND t.dest_purpose=prev_t.dest_purpose;

    -- Ensure the component archive table exists; preserve existing records across reruns
    -- The criteria below determine which get considered components.
    COMMIT TRANSACTION

    BEGIN TRANSACTION;
    IF OBJECT_ID(N'HHSurvey.trip_ingredients_done', N'U') IS NULL
    BEGIN
        SELECT TOP 0 HHSurvey.Trip.*, CAST(0 AS int) AS trip_link 
            INTO HHSurvey.trip_ingredients_done 
            FROM HHSurvey.Trip
        UNION ALL -- Prevent recid from becoming IDENTITY by forcing UNION ALL side effect
        SELECT TOP 0 HHSurvey.Trip.*, CAST(0 AS int) AS trip_link 
            FROM HHSurvey.Trip
    END
    COMMIT TRANSACTION;

    --select the trip ingredients that will be linked; this selects all but the first component 
    BEGIN TRANSACTION;
    INSERT INTO @trip_ingredients_input
    SELECT [next_trip].[recid]
      ,[next_trip].[hhid]
      ,[next_trip].[person_id]
      ,[next_trip].[pernum]
      ,[next_trip].[tripid]
      ,[next_trip].[tripnum]
      ,[next_trip].[traveldate]
      ,[next_trip].[daynum]
      ,[next_trip].[depart_time_timestamp]
      ,[next_trip].[arrival_time_timestamp]
      ,[next_trip].[origin_lat]
      ,[next_trip].[origin_lng]
      ,[next_trip].[dest_lat]
      ,[next_trip].[dest_lng]
      ,[next_trip].[distance_miles]
      ,[next_trip].[travel_time]
      ,[next_trip].[hhmember1]
      ,[next_trip].[hhmember2]
      ,[next_trip].[hhmember3]
      ,[next_trip].[hhmember4]
      ,[next_trip].[hhmember5]
      ,[next_trip].[hhmember6]
      ,[next_trip].[hhmember7]
      ,[next_trip].[hhmember8]
      ,[next_trip].[hhmember9]
      ,[next_trip].[hhmember10]
      ,[next_trip].[hhmember11]
      ,[next_trip].[hhmember12]
      ,[next_trip].[hhmember13]
      ,[next_trip].[travelers_hh]
      ,[next_trip].[travelers_nonhh]
      ,[next_trip].[travelers_total]
      ,[next_trip].[origin_purpose]
      ,[next_trip].[dest_purpose]
      ,[next_trip].[dest_purpose_other]
      ,[next_trip].[mode_1]
      ,[next_trip].[mode_2]
      ,[next_trip].[mode_3]
      ,[next_trip].[mode_4]
      ,[next_trip].[driver]
      ,[next_trip].[mode_acc]
      ,[next_trip].[mode_egr]
      ,[next_trip].[speed_mph]
      ,[next_trip].[mode_other_specify]
      ,[next_trip].[origin_geog]
      ,[next_trip].[dest_geog]
      ,[next_trip].[dest_is_home]
      ,[next_trip].[dest_is_work]
      ,[next_trip].[modes]
      ,[next_trip].[psrc_inserted]
      ,[next_trip].[revision_code]
      ,[next_trip].[psrc_resolved]
      ,[next_trip].[psrc_comment]
      , CAST(0 AS int) AS trip_link
    FROM HHSurvey.Trip as trip 
        JOIN HHSurvey.Trip AS next_trip ON trip.person_id=next_trip.person_id AND trip.tripnum + 1 = next_trip.tripnum
    WHERE trip.dest_is_home IS NULL AND trip.dest_is_work IS NULL AND (											  -- destination of preceding leg isn't home or work
            (trip.origin_geog.STEquals(next_trip.origin_geog)=1 AND trip.dest_geog.STEquals(next_trip.dest_geog)=1) OR-- coordinates identical to prior (denotes RSG-split trip components)	
        (trip.dest_purpose = 60 AND DATEDIFF(Minute, trip.arrival_time_timestamp, next_trip.depart_time_timestamp) < 45)) -- change mode purpose, max 45min dwell (relaxed from 2021)
        OR (trip.travelers_total = next_trip.travelers_total	 												      -- traveler # the same
    AND trip.dest_purpose = next_trip.dest_purpose 
    AND trip.dest_purpose NOT IN(SELECT purpose_id FROM HHSurvey.PUDO_purposes) -- purpose allows for linking (excludes PUDO purposes)
    AND trip.dest_purpose <> 51 -- prevent linking purely recreational/exercise segments when purposes match
        AND (trip.mode_1<>next_trip.mode_1 OR trip.mode_1 IN(SELECT flag_value FROM HHSurvey.NullFlags) OR trip.mode_1 IN(SELECT mode_id FROM HHSurvey.transitmodes)) --either change modes or switch transit lines                     
        AND DATEDIFF(Minute, trip.arrival_time_timestamp, next_trip.depart_time_timestamp) < 15);                 -- under 15min dwell
    COMMIT TRANSACTION;
    BEGIN TRANSACTION;
    -- set the trip_link value of the 2nd component to the tripnum of the 1st component.
    UPDATE ti  
        SET ti.trip_link = (ti.tripnum - 1)
        FROM @trip_ingredients_input AS ti 
            LEFT JOIN @trip_ingredients_input AS previous_et ON ti.person_id = previous_et.person_id AND (ti.tripnum - 1) = previous_et.tripnum
        WHERE (CONCAT(ti.person_id, (ti.tripnum - 1)) <> CONCAT(previous_et.person_id, previous_et.tripnum));
    
    -- assign trip_link value to remaining records in the trip.
    WITH cte (recid, ref_link) AS 
    (SELECT ti1.recid, MAX(ti1.trip_link) OVER(PARTITION BY ti1.person_id ORDER BY ti1.tripnum ROWS UNBOUNDED PRECEDING) AS ref_link
        FROM @trip_ingredients_input AS ti1)
    UPDATE ti
        SET ti.trip_link = cte.ref_link
        FROM @trip_ingredients_input AS ti JOIN cte ON ti.recid = cte.recid
        WHERE ti.trip_link = 0;	

    -- add the 1st component without deleting it from the trip table.
    INSERT INTO @trip_ingredients_input
        SELECT t.[recid]
      ,t.[hhid]
      ,t.[person_id]
      ,t.[pernum]
      ,t.[tripid]
      ,t.[tripnum]
      ,t.[traveldate]
      ,t.[daynum]
      ,t.[depart_time_timestamp]
      ,t.[arrival_time_timestamp]
      ,t.[origin_lat]
      ,t.[origin_lng]
      ,t.[dest_lat]
      ,t.[dest_lng]
      ,t.[distance_miles]
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
      ,t.[hhmember10]
      ,t.[hhmember11]
      ,t.[hhmember12]
      ,t.[hhmember13]
      ,t.[travelers_hh]
      ,t.[travelers_nonhh]
      ,t.[travelers_total]
      ,t.[origin_purpose]
      ,t.[dest_purpose]
      ,t.[dest_purpose_other]
      ,t.[mode_1]
      ,t.[mode_2]
      ,t.[mode_3]
      ,t.[mode_4]
      ,t.[driver]
      ,t.[mode_acc]
      ,t.[mode_egr]
      ,t.[speed_mph]
      ,t.[mode_other_specify]
      ,t.[origin_geog]
      ,t.[dest_geog]
      ,t.[dest_is_home]
      ,t.[dest_is_work]
      ,t.[modes]
      ,t.[psrc_inserted]
      ,t.[revision_code]
      ,t.[psrc_resolved]
      ,t.[psrc_comment]
      ,t.tripnum AS trip_link 
        FROM HHSurvey.Trip AS t 
            JOIN @trip_ingredients_input AS ti ON t.person_id = ti.person_id AND t.tripnum = ti.trip_link AND t.tripnum = ti.tripnum - 1;

    WITH cte_b AS 
        (SELECT DISTINCT ti_wndw2.person_id, ti_wndw2.trip_link, Elmer.dbo.TRIM(Elmer.dbo.rgx_replace(
            STUFF((SELECT ',' + ti2.modes				--non-adjacent repeated modes, i.e. suggests a loop trip
                FROM @trip_ingredients_input AS ti2
                WHERE ti2.person_id = ti_wndw2.person_id AND ti2.trip_link = ti_wndw2.trip_link 
                GROUP BY ti2.modes
                ORDER BY ti_wndw2.person_id DESC, ti_wndw2.tripnum DESC
                FOR XML PATH('')), 1, 1, NULL),'(\b\d+\b),(?=\1)','',1)) AS modes	
        FROM @trip_ingredients_input as ti_wndw2),
    cte2 AS 
        (SELECT ti3.person_id, ti3.trip_link 			--sets with more than 6 trip components
            FROM @trip_ingredients_input as ti3 GROUP BY ti3.person_id, ti3.trip_link
            HAVING count(*) > 6 
        /*UNION ALL SELECT ti4.person_id, ti4.trip_link --sets with two items that each denote a separate trip
            FROM @trip_ingredients_input as ti4 GROUP BY ti4.person_id, ti4.trip_link
            HAVING sum(CASE WHEN ti4.change_vehicles = 1 THEN 1 ELSE 0 END) > 1*/
        UNION ALL SELECT cte_b.person_id, cte_b.trip_link	--sets with a pair of modes repeating in reverse (i.e., return trip)
            FROM cte_b
            WHERE Elmer.dbo.rgx_find(Elmer.dbo.rgx_replace(cte_b.modes,',1,','',1),'\b(\d+),(\d+)\b,.+(?=\2,\1)',1)=1
            )
    UPDATE ti
        SET ti.trip_link = -1 * ti.trip_link
        FROM @trip_ingredients_input AS ti JOIN cte2 ON cte2.person_id = ti.person_id AND cte2.trip_link = ti.trip_link;

    UPDATE @trip_ingredients_input
    SET modes=Elmer.dbo.rgx_replace(modes,',1,','',1) WHERE Elmer.dbo.rgx_find(modes,',1,',1)=1; -- Not necessary to represent walk between other modes besides access/egress.
    COMMIT TRANSACTION;
    EXECUTE HHSurvey.link_trips @trip_ingredients_input;

END
GO

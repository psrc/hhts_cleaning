SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [HHSurvey].[link_trips_systemically]
AS BEGIN

    DECLARE @trip_ingredients_input HHSurvey.TripIngredientType;

    -- Ensure the component archive table exists; preserve existing records across reruns
    -- The criteria below determine which get considered components.

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
    SELECT next_trip.recid
      ,next_trip.hhid
      ,next_trip.person_id
      ,next_trip.pernum
      ,next_trip.tripid
      ,next_trip.tripnum
      ,next_trip.traveldate
      ,next_trip.daynum
      ,next_trip.depart_time_timestamp
      ,next_trip.arrival_time_timestamp
      ,next_trip.origin_lat
      ,next_trip.origin_lng
      ,next_trip.dest_lat
      ,next_trip.dest_lng
      ,next_trip.distance_miles
      ,next_trip.travel_time
      ,next_trip.hhmember1
      ,next_trip.hhmember2
      ,next_trip.hhmember3
      ,next_trip.hhmember4
      ,next_trip.hhmember5
      ,next_trip.hhmember6
      ,next_trip.hhmember7
      ,next_trip.hhmember8
      ,next_trip.hhmember9
      ,next_trip.hhmember10
      ,next_trip.hhmember11
      ,next_trip.hhmember12
      ,next_trip.hhmember13
      ,next_trip.travelers_hh
      ,next_trip.travelers_nonhh
      ,next_trip.travelers_total
      ,next_trip.origin_purpose
      ,next_trip.dest_purpose
      ,next_trip.dest_purpose_other
      ,next_trip.mode_1
      ,next_trip.mode_2
      ,next_trip.mode_3
      ,next_trip.mode_4
      ,next_trip.driver
      ,next_trip.mode_acc
      ,next_trip.mode_egr
      ,next_trip.speed_mph
      ,next_trip.mode_other_specify
      ,next_trip.origin_geog
      ,next_trip.dest_geog
      ,next_trip.dest_is_home
      ,next_trip.dest_is_work
      ,next_trip.modes
      ,next_trip.psrc_inserted
      ,next_trip.revision_code
      ,next_trip.psrc_resolved
      ,next_trip.psrc_comment
      , CAST(0 AS int) AS trip_link
    FROM HHSurvey.Trip as trip 
        JOIN HHSurvey.Trip AS next_trip ON trip.person_id=next_trip.person_id AND trip.tripnum + 1 = next_trip.tripnum
    WHERE trip.dest_is_home IS NULL AND trip.dest_is_work IS NULL AND (											      -- destination of preceding leg isn't home or work
    --first case: "change mode" purpose chosen (or RSG indicates split linked trip)
            ((trip.origin_geog.STEquals(next_trip.origin_geog)=1 AND trip.dest_geog.STEquals(next_trip.dest_geog)=1)  -- coordinates identical to prior (denotes RSG-split trip components)	
           OR(trip.dest_purpose = 60 AND DATEDIFF(Minute, trip.arrival_time_timestamp, next_trip.depart_time_timestamp) <= 60) -- change mode purpose, max 60min dwell
           OR(trip.dest_purpose = 60 AND next_trip.mode_1 IN(80,108) AND DATEDIFF(Minute, trip.arrival_time_timestamp, next_trip.depart_time_timestamp) <= 120)) --longer dwell allowed for ferry
    --second case: pattern suggests "change mode"; more conservative dwell critiera   
        OR (trip.travelers_total = next_trip.travelers_total AND trip.dest_purpose = next_trip.dest_purpose 	 												      -- traveler # the same
            AND trip.dest_purpose NOT IN(SELECT purpose_id FROM HHSurvey.PUDO_purposes UNION SELECT 51) -- purpose match excludes pick-up/drop-off, exercise/recreational
            AND (trip.mode_1<>next_trip.mode_1 OR trip.mode_1 IN(SELECT flag_value FROM HHSurvey.NullFlags UNION SELECT mode_id FROM HHSurvey.transitmodes)) --either change modes or switch transit lines                     
            AND DATEDIFF(Minute, trip.arrival_time_timestamp, next_trip.depart_time_timestamp) < 15))                 -- under 15min dwell
         -- Exclude any candidate pair where either side contains mode 31 (airplane) in the consolidated modes list; also breaks sequence past a 31 trip
         AND ((trip.modes IS NULL OR CHARINDEX(',31,', CONCAT(',', trip.modes, ',')) = 0)
                 AND (next_trip.modes IS NULL OR CHARINDEX(',31,', CONCAT(',', next_trip.modes, ',')) = 0) );
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
        SELECT t.recid
      ,t.hhid
      ,t.person_id
      ,t.pernum
      ,t.tripid
      ,t.tripnum
      ,t.traveldate
      ,t.daynum
      ,t.depart_time_timestamp
      ,t.arrival_time_timestamp
      ,t.origin_lat
      ,t.origin_lng
      ,t.dest_lat
      ,t.dest_lng
      ,t.distance_miles
      ,t.travel_time
      ,t.hhmember1
      ,t.hhmember2
      ,t.hhmember3
      ,t.hhmember4
      ,t.hhmember5
      ,t.hhmember6
      ,t.hhmember7
      ,t.hhmember8
      ,t.hhmember9
      ,t.hhmember10
      ,t.hhmember11
      ,t.hhmember12
      ,t.hhmember13
      ,t.travelers_hh
      ,t.travelers_nonhh
      ,t.travelers_total
      ,t.origin_purpose
      ,t.dest_purpose
      ,t.dest_purpose_other
      ,t.mode_1
      ,t.mode_2
      ,t.mode_3
      ,t.mode_4
      ,t.driver
      ,t.mode_acc
      ,t.mode_egr
      ,t.speed_mph
      ,t.mode_other_specify
      ,t.origin_geog
      ,t.dest_geog
      ,t.dest_is_home
      ,t.dest_is_work
      ,t.modes
      ,t.psrc_inserted
      ,t.revision_code
      ,t.psrc_resolved
      ,t.psrc_comment
      ,t.tripnum AS trip_link 
        FROM HHSurvey.Trip AS t 
            JOIN @trip_ingredients_input AS ti ON t.person_id = ti.person_id AND t.tripnum = ti.trip_link AND t.tripnum = ti.tripnum - 1;

    UPDATE @trip_ingredients_input
    SET modes = REPLACE(modes, ',1,', ',')
    WHERE modes LIKE '%,1,%'; -- Not necessary to represent walk between other modes besides access/egress.

    WITH cte_b AS (
        SELECT
            b.person_id,
            b.trip_link,
            -- remove internal walk and drop adjacent repeated codes
            Elmer.dbo.TRIM(
                Elmer.dbo.rgx_replace(
                    REPLACE(COALESCE(s.modes_concat, ''), ',1,', ','),   -- remove combined walk
                    '(-?\b\d+\b),(?=\b\1\b)', '', 1                      -- drop adjacent repeated codes
                )
            ) AS modes
        FROM (
            SELECT DISTINCT person_id, trip_link
            FROM @trip_ingredients_input
        ) AS b
        CROSS APPLY (
            SELECT STRING_AGG(d.modes, ',') WITHIN GROUP (ORDER BY d.min_tripnum) AS modes_concat
            FROM (
                SELECT ti2.modes, MIN(ti2.tripnum) AS min_tripnum
                FROM @trip_ingredients_input AS ti2
                WHERE ti2.person_id = b.person_id
                AND ti2.trip_link = b.trip_link
                GROUP BY ti2.modes
            ) AS d
        ) AS s
    ),
    big_sets AS (
        SELECT ti3.person_id, ti3.trip_link
        FROM @trip_ingredients_input AS ti3
        GROUP BY ti3.person_id, ti3.trip_link
        HAVING COUNT(*) > 6
        ),

    reverse_pairs AS (
        SELECT b.person_id, b.trip_link
        FROM cte_b AS b
        WHERE Elmer.dbo.rgx_find(
                COALESCE(b.modes, ''),
                '\b(\d+),(\d+)\b,.+(?=\2,\1)', 1) = 1
        ),
    cte2 AS ( 
        SELECT person_id, trip_link FROM big_sets
        UNION
        SELECT person_id, trip_link FROM reverse_pairs
    )
    UPDATE ti
    SET ti.trip_link = -1 * ti.trip_link
    FROM @trip_ingredients_input AS ti
    JOIN cte2 ON cte2.person_id = ti.person_id AND cte2.trip_link = ti.trip_link;

    EXECUTE HHSurvey.link_trips @trip_ingredients_input;
    COMMIT TRANSACTION;

END
GO

SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE    PROCEDURE [HHSurvey].[link_trips]
    @trip_ingredients HHSurvey.TripIngredientType READONLY
AS
BEGIN
    SELECT * INTO #trip_ingredient FROM @trip_ingredients;

    -- meld the trip ingredients to create the fields that will populate the linked trip, and saves those as a separate table, 'linked_trip'.
    BEGIN TRANSACTION;
    DROP TABLE IF EXISTS #linked_trips;	
    -- NOTE: Avoid global recomputation of modes here; we'll recompute only for affected trip(s) below.
        
    WITH cte_agg AS
    (SELECT ti_agg.person_id,
            ti_agg.trip_link,
            CAST(MAX(ti_agg.arrival_time_timestamp) AS [datetime2]) AS arrival_time_timestamp,	
            SUM((CASE WHEN ti_agg.travel_time 		IN (-9998,-9999,995) THEN 0 ELSE 1 END) * ti_agg.travel_time 		 ) AS travel_time, 
            SUM((CASE WHEN ti_agg.distance_miles 	IN (-9998,-9999,995) THEN 0 ELSE 1 END) * ti_agg.distance_miles) AS distance_miles, 	
            MAX((CASE WHEN ti_agg.hhmember1 			IN (995) THEN -1 ELSE 1 END) * ti_agg.hhmember1 			 ) AS hhmember1, 		
            MAX((CASE WHEN ti_agg.hhmember2 			IN (995) THEN -1 ELSE 1 END) * ti_agg.hhmember2 			 ) AS hhmember2,
            MAX((CASE WHEN ti_agg.hhmember3 			IN (995) THEN -1 ELSE 1 END) * ti_agg.hhmember3 			 ) AS hhmember3, 
            MAX((CASE WHEN ti_agg.hhmember4 			IN (995) THEN -1 ELSE 1 END) * ti_agg.hhmember4 			 ) AS hhmember4, 
            MAX((CASE WHEN ti_agg.hhmember5 			IN (995) THEN -1 ELSE 1 END) * ti_agg.hhmember5 			 ) AS hhmember5, 
            MAX((CASE WHEN ti_agg.hhmember6 			IN (995) THEN -1 ELSE 1 END) * ti_agg.hhmember6 			 ) AS hhmember6,
            MAX((CASE WHEN ti_agg.hhmember7 			IN (995) THEN -1 ELSE 1 END) * ti_agg.hhmember7 			 ) AS hhmember7, 
            MAX((CASE WHEN ti_agg.hhmember8 			IN (995) THEN -1 ELSE 1 END) * ti_agg.hhmember8 			 ) AS hhmember8, 
            MAX((CASE WHEN ti_agg.hhmember9 			IN (995) THEN -1 ELSE 1 END) * ti_agg.hhmember9 			 ) AS hhmember9, 
            MAX((CASE WHEN ti_agg.hhmember10 			IN (995) THEN -1 ELSE 1 END) * ti_agg.hhmember10 			 ) AS hhmember10, 
            MAX((CASE WHEN ti_agg.hhmember11			IN (995) THEN -1 ELSE 1 END) * ti_agg.hhmember11 			 ) AS hhmember11, 
            MAX((CASE WHEN ti_agg.hhmember12 			IN (995) THEN -1 ELSE 1 END) * ti_agg.hhmember12 			 ) AS hhmember12, 
            MAX((CASE WHEN ti_agg.hhmember13 			IN (995) THEN -1 ELSE 1 END) * ti_agg.hhmember13 			 ) AS hhmember13, 
            MAX((CASE WHEN ti_agg.travelers_hh 			IN (995) THEN -1 ELSE 1 END) * ti_agg.travelers_hh 			 ) AS travelers_hh, 				
            MAX((CASE WHEN ti_agg.travelers_nonhh 		IN (995) THEN -1 ELSE 1 END) * ti_agg.travelers_nonhh 		 ) AS travelers_nonhh,				
            MAX((CASE WHEN ti_agg.travelers_total 		IN (995) THEN -1 ELSE 1 END) * ti_agg.travelers_total 		 ) AS travelers_total								
        FROM #trip_ingredient as ti_agg WHERE ti_agg.trip_link > 0 GROUP BY ti_agg.person_id, ti_agg.trip_link),
    cte_wndw AS	
    (SELECT 
            ti_wndw.person_id AS person_id2,
            ti_wndw.trip_link AS trip_link2,
            FIRST_VALUE(ti_wndw.dest_purpose) 	OVER (PARTITION BY CONCAT(ti_wndw.person_id,ti_wndw.trip_link) ORDER BY ti_wndw.tripnum DESC) AS dest_purpose,
            FIRST_VALUE(ti_wndw.origin_purpose) OVER (PARTITION BY CONCAT(ti_wndw.person_id,ti_wndw.trip_link) ORDER BY ti_wndw.tripnum ASC) AS origin_purpose,
            FIRST_VALUE(ti_wndw.dest_is_home) 	OVER (PARTITION BY CONCAT(ti_wndw.person_id,ti_wndw.trip_link) ORDER BY ti_wndw.tripnum DESC) AS dest_is_home,
            FIRST_VALUE(ti_wndw.dest_is_work) 	OVER (PARTITION BY CONCAT(ti_wndw.person_id,ti_wndw.trip_link) ORDER BY ti_wndw.tripnum DESC) AS dest_is_work,
            FIRST_VALUE(ti_wndw.dest_lat) 		OVER (PARTITION BY CONCAT(ti_wndw.person_id,ti_wndw.trip_link) ORDER BY ti_wndw.tripnum DESC) AS dest_lat,
            FIRST_VALUE(ti_wndw.dest_lng) 		OVER (PARTITION BY CONCAT(ti_wndw.person_id,ti_wndw.trip_link) ORDER BY ti_wndw.tripnum DESC) AS dest_lng,
            FIRST_VALUE(ti_wndw.mode_acc) 		OVER (PARTITION BY CONCAT(ti_wndw.person_id,ti_wndw.trip_link) ORDER BY ti_wndw.tripnum ASC)  AS mode_acc,
            FIRST_VALUE(ti_wndw.mode_egr) 		OVER (PARTITION BY CONCAT(ti_wndw.person_id,ti_wndw.trip_link) ORDER BY ti_wndw.tripnum DESC) AS mode_egr,
            --STRING_AGG(ti_wnd.modes,',') 		OVER (PARTITION BY ti_wnd.trip_link ORDER BY ti_wndw.tripnum ASC) AS modes -- Thought this would work with MSSQL2017+ but not w/ windowing
            Elmer.dbo.TRIM(Elmer.dbo.rgx_replace(STUFF(
                (SELECT ',' + ti1.modes
                FROM #trip_ingredient AS ti1 
                WHERE ti1.person_id = ti_wndw.person_id AND ti1.trip_link = ti_wndw.trip_link
                GROUP BY ti1.modes
                ORDER BY ti_wndw.person_id DESC, ti_wndw.tripnum DESC
                FOR XML PATH('')), 1, 1, NULL),'(-?\b\d+\b),(?=\b\1\b)','',1)) AS modes
        FROM #trip_ingredient as ti_wndw WHERE ti_wndw.trip_link > 0 )
    SELECT DISTINCT cte_wndw.*, cte_agg.* INTO #linked_trips
        FROM cte_wndw JOIN cte_agg ON cte_wndw.person_id2 = cte_agg.person_id AND cte_wndw.trip_link2 = cte_agg.trip_link;

    UPDATE #linked_trips
    SET modes=Elmer.dbo.rgx_replace(modes,',1,',',',1) WHERE Elmer.dbo.rgx_find(modes,',1,',1)=1; -- Not necessary to represent walk between other modes besides access/egress.

    ALTER TABLE #linked_trips ADD dest_geog geography;		

    UPDATE #linked_trips
    SET dest_geog=geography::STGeomFromText('POINT(' + CAST(dest_lng AS VARCHAR(20)) + ' ' + CAST(dest_lat AS VARCHAR(20)) + ')', 4326);

    DELETE lt
    FROM #linked_trips AS lt JOIN HHSurvey.Trip AS t on t.person_id = lt.person_id AND t.tripnum = lt.trip_link
        WHERE t.origin_geog.STDistance(lt.dest_geog) < 50                                                                         -- discard potential linked trips that return to the same location
            OR (lt.origin_purpose=lt.dest_purpose AND lt.dest_purpose IN(1,10))                                                     -- or would result in a looped purpose
            OR DATEDIFF(Minute, t.depart_time_timestamp, lt.arrival_time_timestamp) / t.origin_geog.STDistance(lt.dest_geog) > 30; -- or speed suggests a stop
    COMMIT TRANSACTION;


    IF NOT EXISTS (SELECT 1 FROM #linked_trips)
    BEGIN
        PRINT 'HHSurvey.link_trips: No linkable trips found (all candidates were filtered out); no changes made.';
        RETURN; -- No-op when nothing to link
    END;

    -- Collect affected people for scoping downstream operations
    DROP TABLE IF EXISTS #affected_people;
    SELECT DISTINCT person_id INTO #affected_people FROM #linked_trips;


    -- delete the components that will get replaced with linked trips
    BEGIN TRANSACTION;
    DELETE t
    FROM HHSurvey.Trip AS t JOIN #trip_ingredient AS ti ON t.recid=ti.recid
        WHERE t.tripnum <> ti.trip_link AND EXISTS (SELECT 1 FROM #linked_trips AS lt WHERE ti.person_id = lt.person_id AND ti.trip_link = lt.trip_link);	


    /* Capture component trip mode values BEFORE deleting ingredients so we can rebuild mode_1..4 and access/egress
       without relying on the concatenated string field (previous regex-based approach). */
    DROP TABLE IF EXISTS #component_modes;
    SELECT 
        ti.person_id,
        ti.trip_link,
        ti.tripnum AS component_tripnum,
        ROW_NUMBER() OVER (PARTITION BY ti.person_id, ti.trip_link ORDER BY ti.tripnum) AS component_order,
        v.mode_code,
        v.pos AS position_in_component
    INTO #component_modes
    FROM #trip_ingredient ti
    CROSS APPLY (VALUES (ti.mode_1,1),(ti.mode_2,2),(ti.mode_3,3),(ti.mode_4,4)) v(mode_code,pos)
    WHERE ti.trip_link > 0
      AND v.mode_code IS NOT NULL
      AND v.mode_code NOT IN (995,-9998,-9999); -- exclude sentinels

    /* Capture driver values per component before deletion for later aggregation */
    DROP TABLE IF EXISTS #component_driver_values;
    SELECT ti.person_id, ti.trip_link, ti.tripnum AS component_tripnum,
           ROW_NUMBER() OVER (PARTITION BY ti.person_id, ti.trip_link ORDER BY ti.tripnum) AS component_order,
           ti.driver
    INTO #component_driver_values
    FROM #trip_ingredient ti
    WHERE ti.trip_link > 0;

    /* Capture edge component original access/egress modes and whether first/last components are transit. */
    DROP TABLE IF EXISTS #component_edge_modes;
    WITH comp AS (
        SELECT ti.person_id, ti.trip_link, ti.tripnum,
               ROW_NUMBER() OVER (PARTITION BY ti.person_id, ti.trip_link ORDER BY ti.tripnum) AS rn,
               COUNT(*) OVER (PARTITION BY ti.person_id, ti.trip_link) AS cnt,
               ti.mode_acc, ti.mode_egr
        FROM #trip_ingredient ti
        WHERE ti.trip_link > 0
    )
    SELECT c.person_id, c.trip_link,
           MAX(CASE WHEN c.rn = 1 THEN c.mode_acc END) AS first_component_mode_acc,
           MAX(CASE WHEN c.rn = c.cnt THEN c.mode_egr END) AS last_component_mode_egr,
           CAST(0 AS bit) AS first_component_has_transit,
           CAST(0 AS bit) AS last_component_has_transit
    INTO #component_edge_modes
    FROM comp c
    GROUP BY c.person_id, c.trip_link;

    -- Populate transit flags
    UPDATE ce
        SET first_component_has_transit = CASE WHEN EXISTS (
                SELECT 1 FROM #component_modes m
                WHERE m.person_id = ce.person_id AND m.trip_link = ce.trip_link
                  AND m.component_order = 1
                  AND m.mode_code IN (SELECT mode_id FROM HHSurvey.transitmodes)) THEN 1 ELSE 0 END,
            last_component_has_transit = CASE WHEN EXISTS (
                SELECT 1 FROM #component_modes m
                WHERE m.person_id = ce.person_id AND m.trip_link = ce.trip_link
                  AND m.component_order = (SELECT MAX(component_order) FROM #component_modes m2 WHERE m2.person_id = ce.person_id AND m2.trip_link = ce.trip_link)
                  AND m.mode_code IN (SELECT mode_id FROM HHSurvey.transitmodes)) THEN 1 ELSE 0 END
    FROM #component_edge_modes ce;
    -- this update achieves trip linking via revising elements of the 1st component (purposely left in the trip table).		
    UPDATE 	t
        SET t.dest_purpose 		= lt.dest_purpose * (CASE WHEN lt.dest_purpose IN(-97,-60) THEN -1 ELSE 1 END),	
            t.modes				= lt.modes,
            t.dest_is_home		= lt.dest_is_home,					
            t.dest_is_work		= lt.dest_is_work,
            t.dest_lat			= lt.dest_lat,
            t.dest_lng			= lt.dest_lng,
            t.dest_geog         = geography::STGeomFromText('POINT(' + CAST(lt.dest_lng 	  AS VARCHAR(20)) + ' ' + CAST(lt.dest_lat 	AS VARCHAR(20)) + ')', 4326),
            t.speed_mph			= CASE WHEN (lt.distance_miles > 0 AND (CAST(DATEDIFF_BIG (second, t.depart_time_timestamp, lt.arrival_time_timestamp) AS numeric) > 0)) 
                                    THEN  lt.distance_miles / (CAST(DATEDIFF_BIG (second, t.depart_time_timestamp, lt.arrival_time_timestamp) AS numeric)/3600) 
                                    ELSE 0 END,			   	
            t.arrival_time_timestamp = lt.arrival_time_timestamp,
            t.distance_miles  = lt.distance_miles,
            t.travelers_hh 	  = lt.travelers_hh,
            t.travelers_nonhh = lt.travelers_nonhh,
            t.travelers_total = lt.travelers_total,	
            t.hhmember1 	  = lt.hhmember1, 
            t.hhmember2 	  = lt.hhmember2, 
            t.hhmember3 	  = lt.hhmember3,                                                         
            t.hhmember4 	  = lt.hhmember4,                                                        
            t.hhmember5 	  = lt.hhmember5,                                                        
            t.hhmember6 	  = lt.hhmember6,			 
            t.hhmember7 	  = lt.hhmember7,  				 
            t.hhmember8 	  = lt.hhmember8, 			
            t.hhmember9 	  = lt.hhmember9,
            t.hhmember10 	  = lt.hhmember10,  				 
            t.hhmember11 	  = lt.hhmember11, 			
            t.hhmember12 	  = lt.hhmember12,			
            t.hhmember13 	  = lt.hhmember13,                                          				 	
            t.revision_code   = CONCAT(t.revision_code, '8,')
        FROM HHSurvey.Trip AS t JOIN #linked_trips AS lt ON t.person_id = lt.person_id AND t.tripnum = lt.trip_link;

    --move the ingredients to another named table so this procedure can be re-run as sproc during manual cleaning

    DELETE FROM #trip_ingredient
    OUTPUT 
		DELETED.recid, DELETED.hhid, DELETED.person_id, DELETED.pernum, DELETED.tripid, DELETED.tripnum,
		DELETED.traveldate, DELETED.daynum, DELETED.depart_time_timestamp, DELETED.arrival_time_timestamp, DELETED.origin_lat, 
		DELETED.origin_lng, DELETED.dest_lat, DELETED.dest_lng, DELETED.distance_miles, DELETED.travel_time, DELETED.hhmember1, 
		DELETED.hhmember2, DELETED.hhmember3, DELETED.hhmember4, DELETED.hhmember5, DELETED.hhmember6, 
		DELETED.hhmember7, DELETED.hhmember8, DELETED.hhmember9, DELETED.hhmember10, DELETED.hhmember11, DELETED.hhmember12, 
		DELETED.hhmember13, DELETED.travelers_hh, DELETED.travelers_nonhh, DELETED.travelers_total, DELETED.origin_purpose, 
		DELETED.dest_purpose, DELETED.dest_purpose_other, DELETED.mode_1, DELETED.mode_2, DELETED.mode_3, DELETED.mode_4, 
		DELETED.driver, DELETED.mode_acc, DELETED.mode_egr, DELETED.speed_mph, DELETED.mode_other_specify, 
		DELETED.origin_geog, DELETED.dest_geog, DELETED.dest_is_home, DELETED.dest_is_work,
		DELETED.modes, DELETED.psrc_inserted, DELETED.revision_code, DELETED.psrc_resolved, DELETED.psrc_comment, DELETED.trip_link
	INTO HHSurvey.trip_ingredients_done (
		recid, hhid, person_id, pernum, tripid, tripnum, traveldate, daynum, depart_time_timestamp, arrival_time_timestamp, origin_lat,
		origin_lng, dest_lat, dest_lng, distance_miles, travel_time, hhmember1, hhmember2, hhmember3, hhmember4, hhmember5, hhmember6,
		hhmember7, hhmember8, hhmember9, hhmember10, hhmember11, hhmember12, hhmember13, travelers_hh, travelers_nonhh, travelers_total, origin_purpose,
		dest_purpose, dest_purpose_other, mode_1, mode_2, mode_3, mode_4, driver, mode_acc, mode_egr, speed_mph, mode_other_specify,
		origin_geog, dest_geog, dest_is_home, dest_is_work, modes, psrc_inserted, revision_code, psrc_resolved, psrc_comment, trip_link
	)
    WHERE #trip_ingredient.trip_link > 0;

    /* STEP 6.  Mode standardization using component trip mode columns.
        Rules:
          * Gather all non-sentinel mode codes from component trips (mode_1..mode_4) preserving component order then position.
          * If ANY transit mode (HHSurvey.transitmodes) appears:
               - One pre-transit access mode is chosen (preference: automodes > bikemodes > walkmodes) from before the earliest transit component.
               - One post-transit egress mode chosen similarly from after the last transit component.
               - Pre-transit and post-transit access/egress candidate modes are NOT placed into mode_1..mode_4.
               - Internal segment (between first and last transit component inclusive) supplies up to 4 distinct modes (first occurrence order) for mode_1..4.
          * If NO transit mode: mode_acc/mode_egr set to 995 and first four distinct modes across all components fill mode_1..4.
          * Distinctness: keep first occurrence; later duplicates ignored.
    */

    -- Compute transit bounds per linked trip
    DROP TABLE IF EXISTS #transit_bounds;
SELECT cm.person_id, cm.trip_link,
       CASE WHEN COUNT(CASE WHEN tm.mode_id IS NOT NULL THEN 1 END) > 0 THEN 1 ELSE 0 END AS has_transit,
       MIN(CASE WHEN tm.mode_id IS NOT NULL THEN component_order END) AS first_transit_order,
       MAX(CASE WHEN tm.mode_id IS NOT NULL THEN component_order END) AS last_transit_order
INTO #transit_bounds
FROM #component_modes cm
LEFT JOIN HHSurvey.transitmodes tm ON tm.mode_id = cm.mode_code
GROUP BY cm.person_id, cm.trip_link;

     -- Access and egress mode selection (only when transit present)
     DROP TABLE IF EXISTS #ae_modes;
     SELECT tb.person_id, tb.trip_link,
              acc.access_mode_code,
              egr.egress_mode_code
     INTO #ae_modes
     FROM #transit_bounds tb
     OUTER APPLY (
          SELECT TOP 1 cm.mode_code AS access_mode_code
          FROM #component_modes cm
          WHERE cm.person_id = tb.person_id AND cm.trip_link = tb.trip_link
             AND tb.has_transit = 1
             AND cm.component_order < tb.first_transit_order
             AND (
                     cm.mode_code IN (SELECT mode_id FROM HHSurvey.automodes)
                 OR cm.mode_code IN (SELECT mode_id FROM HHSurvey.bikemodes)
                 OR cm.mode_code IN (SELECT mode_id FROM HHSurvey.walkmodes)
             )
          ORDER BY CASE 
                          WHEN cm.mode_code IN (SELECT mode_id FROM HHSurvey.automodes) THEN 1
                          WHEN cm.mode_code IN (SELECT mode_id FROM HHSurvey.bikemodes) THEN 2
                          WHEN cm.mode_code IN (SELECT mode_id FROM HHSurvey.walkmodes) THEN 3
                          ELSE 4 END,
                      cm.component_order,
                      cm.position_in_component
     ) acc
     OUTER APPLY (
          SELECT TOP 1 cm.mode_code AS egress_mode_code
          FROM #component_modes cm
          WHERE cm.person_id = tb.person_id AND cm.trip_link = tb.trip_link
             AND tb.has_transit = 1
             AND cm.component_order > tb.last_transit_order
             AND (
                     cm.mode_code IN (SELECT mode_id FROM HHSurvey.automodes)
                 OR cm.mode_code IN (SELECT mode_id FROM HHSurvey.bikemodes)
                 OR cm.mode_code IN (SELECT mode_id FROM HHSurvey.walkmodes)
             )
          ORDER BY CASE 
                          WHEN cm.mode_code IN (SELECT mode_id FROM HHSurvey.automodes) THEN 1
                          WHEN cm.mode_code IN (SELECT mode_id FROM HHSurvey.bikemodes) THEN 2
                          WHEN cm.mode_code IN (SELECT mode_id FROM HHSurvey.walkmodes) THEN 3
                          ELSE 4 END,
                      cm.component_order,
                      cm.position_in_component
     ) egr;

     -- Add mode_in to mode_out mapping table
     DECLARE @mode_in_out TABLE (mode_in INT, mode_out INT);
     INSERT INTO @mode_in_out (mode_in, mode_out) VALUES
          (1,1),
          (995,995),
          (100,13),
          (101,14),
          (103,2),
          (104,97),
          (106,12),
          (107,9);

    -- Internal (or all, if no transit) distinct modes in order
    DROP TABLE IF EXISTS #internal_modes;
    WITH internal_candidates AS (
        SELECT cm.person_id, cm.trip_link, cm.mode_code,
               MIN(cm.component_order * 10 + cm.position_in_component) AS order_key
        FROM #component_modes cm
        JOIN #transit_bounds tb ON tb.person_id = cm.person_id AND tb.trip_link = cm.trip_link
        LEFT JOIN #ae_modes ae ON ae.person_id = cm.person_id AND ae.trip_link = cm.trip_link
        WHERE (
                tb.has_transit = 0
             OR (cm.component_order BETWEEN tb.first_transit_order AND tb.last_transit_order)
              )
        GROUP BY cm.person_id, cm.trip_link, cm.mode_code
    )
    SELECT person_id, trip_link, mode_code,
           ROW_NUMBER() OVER (PARTITION BY person_id, trip_link ORDER BY order_key) AS seq
    INTO #internal_modes
    FROM internal_candidates;

    /* Build ordered full mode list including access and egress (if present and not sentinel) then internal modes, de-duplicated by first occurrence */
    DROP TABLE IF EXISTS #all_modes;
    WITH seeds AS (
     -- access (seq base 0)
     SELECT tb.person_id, tb.trip_link,
         CASE WHEN tb.has_transit = 1 THEN ae.access_mode_code END AS mode_code,
         0 AS rank_group,
         0 AS order_key
     FROM #transit_bounds tb
     LEFT JOIN #ae_modes ae ON ae.person_id = tb.person_id AND ae.trip_link = tb.trip_link
     UNION ALL
     -- internal modes (seq base 100)
     SELECT im.person_id, im.trip_link, im.mode_code, 1 AS rank_group, im.seq + 100 AS order_key
     FROM #internal_modes im
     UNION ALL
     -- egress (seq base 200)
     SELECT tb.person_id, tb.trip_link,
         CASE WHEN tb.has_transit = 1 THEN ae.egress_mode_code END AS mode_code,
         2 AS rank_group,
         200 AS order_key
     FROM #transit_bounds tb
     LEFT JOIN #ae_modes ae ON ae.person_id = tb.person_id AND ae.trip_link = tb.trip_link
    ), filtered AS (
     SELECT person_id, trip_link, mode_code, order_key
     FROM seeds
     WHERE mode_code IS NOT NULL AND mode_code NOT IN (995,-9998,-9999)
    ), distinct_first AS (
     SELECT f.person_id, f.trip_link, f.mode_code,
         ROW_NUMBER() OVER (PARTITION BY f.person_id, f.trip_link ORDER BY MIN(f.order_key)) AS new_seq,
         MIN(f.order_key) AS first_order_key
     FROM filtered f
     GROUP BY f.person_id, f.trip_link, f.mode_code
    )
    SELECT person_id, trip_link, mode_code, new_seq
    INTO #all_modes
    FROM distinct_first;

    /* Driver aggregation rules:
      * If any transit present in linked trip -> driver=2 (passenger) regardless of underlying mix (requirement as stated).
      * Otherwise: if all underlying driver values (excluding NULL) are 1 => 1; if all 2 => 2; if mix of 1 and 2 => 3.
        Keep 995 only if all are 995 or NULL (no qualifying 1/2). */
    DROP TABLE IF EXISTS #driver_resolved;
    WITH drv AS (
     SELECT d.person_id, d.trip_link,
         SUM(CASE WHEN d.driver = 1 THEN 1 ELSE 0 END) AS cnt1,
         SUM(CASE WHEN d.driver = 2 THEN 1 ELSE 0 END) AS cnt2,
         SUM(CASE WHEN d.driver = 995 THEN 1 ELSE 0 END) AS cnt995,
         SUM(CASE WHEN d.driver IS NULL THEN 1 ELSE 0 END) AS cntNULL,
         COUNT(*) AS total
     FROM #component_driver_values d
     GROUP BY d.person_id, d.trip_link
    )
    SELECT tb.person_id, tb.trip_link,
        CASE 
        WHEN tb.has_transit = 1 THEN 2
        WHEN drv.cnt1 > 0 AND drv.cnt2 = 0 THEN 1
        WHEN drv.cnt2 > 0 AND drv.cnt1 = 0 THEN 2
        WHEN drv.cnt1 > 0 AND drv.cnt2 > 0 THEN 3
        WHEN drv.cnt1 = 0 AND drv.cnt2 = 0 AND drv.cnt995 > 0 AND drv.cnt995 = drv.total THEN 995
        ELSE 995
        END AS final_driver
    INTO #driver_resolved
    FROM #transit_bounds tb
    LEFT JOIN drv ON drv.person_id = tb.person_id AND drv.trip_link = tb.trip_link;

    -- Update trips with new mode fields, mapping mode_acc and mode_egr through correspondence table
    UPDATE t
        SET t.mode_acc =
                CASE 
                    WHEN tb.has_transit = 1 AND cem.first_component_has_transit = 1 
                         AND cem.first_component_mode_acc NOT IN (NULL, 995, -9998, -9999)
                        THEN COALESCE((SELECT mode_out FROM @mode_in_out WHERE mode_in = cem.first_component_mode_acc), cem.first_component_mode_acc)
                    WHEN tb.has_transit = 1
                        THEN COALESCE((SELECT mode_out FROM @mode_in_out WHERE mode_in = ae.access_mode_code), ae.access_mode_code, 995)
                    ELSE 995
                END,
            t.mode_egr =
                CASE 
                    WHEN tb.has_transit = 1 AND cem.last_component_has_transit = 1 
                         AND cem.last_component_mode_egr NOT IN (NULL, 995, -9998, -9999)
                        THEN COALESCE((SELECT mode_out FROM @mode_in_out WHERE mode_in = cem.last_component_mode_egr), cem.last_component_mode_egr)
                    WHEN tb.has_transit = 1
                        THEN COALESCE((SELECT mode_out FROM @mode_in_out WHERE mode_in = ae.egress_mode_code), ae.egress_mode_code, 995)
                    ELSE 995
                END,
            t.mode_1 = COALESCE((SELECT im.mode_code FROM #internal_modes im WHERE im.person_id = t.person_id AND im.trip_link = t.tripnum AND im.seq = 1), 995),
            t.mode_2 = COALESCE((SELECT im.mode_code FROM #internal_modes im WHERE im.person_id = t.person_id AND im.trip_link = t.tripnum AND im.seq = 2), 995),
            t.mode_3 = COALESCE((SELECT im.mode_code FROM #internal_modes im WHERE im.person_id = t.person_id AND im.trip_link = t.tripnum AND im.seq = 3), 995),
            t.mode_4 = COALESCE((SELECT im.mode_code FROM #internal_modes im WHERE im.person_id = t.person_id AND im.trip_link = t.tripnum AND im.seq = 4), 995),
            t.modes = (SELECT STRING_AGG(CAST(am.mode_code AS varchar(10)), ',') 
                   FROM #all_modes am 
                   WHERE am.person_id = t.person_id AND am.trip_link = t.tripnum AND am.new_seq BETWEEN 1 AND 6),
            t.driver = COALESCE(dr.final_driver, t.driver)
    FROM HHSurvey.Trip t
    JOIN #linked_trips lt ON lt.person_id = t.person_id AND lt.trip_link = t.tripnum
    JOIN #transit_bounds tb ON tb.person_id = t.person_id AND tb.trip_link = t.tripnum
    LEFT JOIN #ae_modes ae ON ae.person_id = t.person_id AND ae.trip_link = t.tripnum
    LEFT JOIN #component_edge_modes cem ON cem.person_id = t.person_id AND cem.trip_link = t.tripnum
    LEFT JOIN #driver_resolved dr ON dr.person_id = t.person_id AND dr.trip_link = t.tripnum;

    -- Final safeguard: if any NULLs remain (unexpected), set to 995 for affected trips
    UPDATE t SET t.mode_acc = 995 FROM HHSurvey.Trip AS t JOIN #linked_trips AS lt ON t.person_id = lt.person_id AND t.tripnum = lt.trip_link WHERE t.mode_acc IS NULL;
    UPDATE t SET t.mode_egr = 995 FROM HHSurvey.Trip AS t JOIN #linked_trips AS lt ON t.person_id = lt.person_id AND t.tripnum = lt.trip_link WHERE t.mode_egr IS NULL;
    UPDATE t SET t.mode_1   = 995 FROM HHSurvey.Trip AS t JOIN #linked_trips AS lt ON t.person_id = lt.person_id AND t.tripnum = lt.trip_link WHERE t.mode_1   IS NULL;
    UPDATE t SET t.mode_2   = 995 FROM HHSurvey.Trip AS t JOIN #linked_trips AS lt ON t.person_id = lt.person_id AND t.tripnum = lt.trip_link WHERE t.mode_2   IS NULL;
    UPDATE t SET t.mode_3   = 995 FROM HHSurvey.Trip AS t JOIN #linked_trips AS lt ON t.person_id = lt.person_id AND t.tripnum = lt.trip_link WHERE t.mode_3   IS NULL;
    UPDATE t SET t.mode_4   = 995 FROM HHSurvey.Trip AS t JOIN #linked_trips AS lt ON t.person_id = lt.person_id AND t.tripnum = lt.trip_link WHERE t.mode_4   IS NULL;

    -- Clean temp tables
    DROP TABLE IF EXISTS #internal_modes; 
    DROP TABLE IF EXISTS #ae_modes; 
    DROP TABLE IF EXISTS #transit_bounds; 
    DROP TABLE IF EXISTS #component_edge_modes;
    DROP TABLE IF EXISTS #driver_resolved;
    DROP TABLE IF EXISTS #component_driver_values;
    DROP TABLE IF EXISTS #all_modes;
    DROP TABLE IF EXISTS #component_modes;
    COMMIT TRANSACTION;

    --temp tables should disappear when the spoc ends, but to be tidy we explicitly delete them.
    DROP TABLE IF EXISTS #linked_trips;
    
    -- Recalculate only for affected people (this includes per-person tripnum_update)
    DECLARE @pid_dec DECIMAL(19,0);
    DECLARE cur_recalc CURSOR LOCAL FAST_FORWARD FOR SELECT person_id FROM #affected_people;
    OPEN cur_recalc;
    FETCH NEXT FROM cur_recalc INTO @pid_dec;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC HHSurvey.recalculate_after_edit @target_person_id = @pid_dec;
        FETCH NEXT FROM cur_recalc INTO @pid_dec;
    END
    CLOSE cur_recalc; DEALLOCATE cur_recalc;
    DROP TABLE IF EXISTS #affected_people;

END
GO

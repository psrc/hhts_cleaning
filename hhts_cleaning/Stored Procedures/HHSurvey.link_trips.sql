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

    /* STEP 6.	Mode number standardization, including access and egress characterization */

    --eliminate repeated values for modes
    UPDATE t 
        SET t.modes				= Elmer.dbo.TRIM(Elmer.dbo.rgx_replace(t.modes,'(-?\b\d+\b),(?=\b\1\b)','',1))
        FROM HHSurvey.Trip AS t WHERE EXISTS (SELECT 1 FROM #linked_trips AS lt WHERE lt.person_id = t.person_id AND lt.trip_link = t.tripnum)
        ;
    -- Defer trip re-numbering to recalculate_after_edit (scoped per person)
            
    -- Populate separate mode fields
        WITH cte AS 
        (
            SELECT t.recid,
                   Elmer.dbo.rgx_replace(t.modes, '(?<=\b\1,.*)\b(\w+),?','',1) AS mode_reduced
            FROM HHSurvey.Trip AS t
            JOIN #linked_trips AS lt2 ON t.person_id = lt2.person_id AND t.tripnum = lt2.trip_link
        )
    UPDATE t
        SET mode_1 = COALESCE((SELECT match FROM Elmer.dbo.rgx_matches(cte.mode_reduced,'\b\d+\b',1) ORDER BY match_index OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY), 995),
            mode_2 = COALESCE((SELECT match FROM Elmer.dbo.rgx_matches(cte.mode_reduced,'\b\d+\b',1) ORDER BY match_index OFFSET 1 ROWS FETCH NEXT 1 ROWS ONLY), 995),
            mode_3 = COALESCE((SELECT match FROM Elmer.dbo.rgx_matches(cte.mode_reduced,'\b\d+\b',1) ORDER BY match_index OFFSET 2 ROWS FETCH NEXT 1 ROWS ONLY), 995),
            mode_4 = COALESCE((SELECT match FROM Elmer.dbo.rgx_matches(cte.mode_reduced,'\b\d+\b',1) ORDER BY match_index OFFSET 3 ROWS FETCH NEXT 1 ROWS ONLY), 995)
    FROM HHSurvey.Trip AS t JOIN cte ON t.recid = cte.recid
    ;
    -- Limit NULL-to-995 normalization to affected trips only
    UPDATE t SET t.mode_acc = 995 FROM HHSurvey.Trip AS t JOIN #linked_trips AS lt ON t.person_id = lt.person_id AND t.tripnum = lt.trip_link WHERE t.mode_acc IS NULL;
    UPDATE t SET t.mode_1   = 995 FROM HHSurvey.Trip AS t JOIN #linked_trips AS lt ON t.person_id = lt.person_id AND t.tripnum = lt.trip_link WHERE t.mode_1   IS NULL;
    UPDATE t SET t.mode_2   = 995 FROM HHSurvey.Trip AS t JOIN #linked_trips AS lt ON t.person_id = lt.person_id AND t.tripnum = lt.trip_link WHERE t.mode_2   IS NULL;
    UPDATE t SET t.mode_3   = 995 FROM HHSurvey.Trip AS t JOIN #linked_trips AS lt ON t.person_id = lt.person_id AND t.tripnum = lt.trip_link WHERE t.mode_3   IS NULL;
    UPDATE t SET t.mode_4   = 995 FROM HHSurvey.Trip AS t JOIN #linked_trips AS lt ON t.person_id = lt.person_id AND t.tripnum = lt.trip_link WHERE t.mode_4   IS NULL; 
    UPDATE t SET t.mode_egr = 995 FROM HHSurvey.Trip AS t JOIN #linked_trips AS lt ON t.person_id = lt.person_id AND t.tripnum = lt.trip_link WHERE t.mode_egr IS NULL;
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

SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [HHSurvey].[link_trips] AS
BEGIN

    -- meld the trip ingredients to create the fields that will populate the linked trip, and saves those as a separate table, 'linked_trip'.
    DROP TABLE IF EXISTS #linked_trips;	
        
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
        FROM HHSurvey.trip_ingredient as ti_agg WHERE ti_agg.trip_link > 0 GROUP BY ti_agg.person_id, ti_agg.trip_link),
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
            --STRING_AGG(ti_wnd.modes,',') 		OVER (PARTITION BY ti_wnd.trip_link ORDER BY ti_wndw.tripnum ASC) AS modes, -- This can be used once we upgrade from MSSQL16
            Elmer.dbo.TRIM(Elmer.dbo.rgx_replace(STUFF(
                (SELECT ',' + ti1.modes
                FROM HHSurvey.trip_ingredient AS ti1 
                WHERE ti1.person_id = ti_wndw.person_id AND ti1.trip_link = ti_wndw.trip_link
                GROUP BY ti1.modes
                ORDER BY ti_wndw.person_id DESC, ti_wndw.tripnum DESC
                FOR XML PATH('')), 1, 1, NULL),'(-?\b\d+\b),(?=\b\1\b)','',1)) AS modes
        FROM HHSurvey.trip_ingredient as ti_wndw WHERE ti_wndw.trip_link > 0 )
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

    IF NOT EXISTS (SELECT 1 FROM #linked_trips)
    BEGIN
        THROW 50001, 'All linked trips were filtered out because they would return to the same location, result in a looped purpose, or speed suggests a stop.', 1;
    END;


    -- delete the components that will get replaced with linked trips
    DELETE t
    FROM HHSurvey.Trip AS t JOIN HHSurvey.trip_ingredient AS ti ON t.recid=ti.recid
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

    DELETE FROM HHSurvey.trip_ingredient
    OUTPUT deleted.* INTO HHSurvey.trip_ingredients_done
    WHERE HHSurvey.trip_ingredient.trip_link > 0;

    /* STEP 6.	Mode number standardization, including access and egress characterization */

    --eliminate repeated values for modes
    UPDATE t 
        SET t.modes				= Elmer.dbo.TRIM(Elmer.dbo.rgx_replace(t.modes,'(-?\b\d+\b),(?=\b\1\b)','',1))
        FROM HHSurvey.Trip AS t WHERE EXISTS (SELECT 1 FROM #linked_trips AS lt WHERE lt.person_id =t.person_id AND lt.trip_link = t.tripnum)
        ;

    EXECUTE HHSurvey.tripnum_update; 
            
/*    UPDATE HHSurvey.Trip SET mode_acc = NULL, mode_egr = NULL   -- Clears what was stored as access or egress; those values are still part of the chain captured in the concatenated 'modes' field.
        WHERE EXISTS (SELECT 1 FROM #linked_trips AS lt WHERE lt.person_id =trip.person_id AND lt.trip_link = trip.tripnum)
        ;

    -- Characterize access and egress trips, separately for 1) transit trips and 2) auto trips.  (Bike/Ped trips have no access/egress)
    -- [Unions must be used here; otherwise the VALUE set from the dbo.Rgx table object gets reused across cte fields.]

    -- Create rgx expressions for access/egress modes
    	DECLARE @auto_access_egress_modes nvarchar;
		WITH cte AS (SELECT mode_id FROM HHSurvey.walkmodes
		   UNION ALL SELECT mode_id FROM HHSurvey.bikemodes)
		SELECT @auto_access_egress_modes =  STUFF(Elmer.dbo.TRIM('||' + CAST(mode_id AS nchar)), 1, 1, NULL) 
							   FROM cte FOR XML PATH('');

		DECLARE @transit_access_egress_modes nvarchar;
		WITH cte AS (SELECT mode_id FROM HHSurvey.walkmodes
		   UNION ALL SELECT mode_id FROM HHSurvey.bikemodes
		   UNION ALL SELECT mode_id FROM HHSurvey.automodes)
		SELECT @auto_access_egress_modes =  STUFF(Elmer.dbo.TRIM('||' + CAST(mode_id AS nchar)), 1, 1, NULL) 
							   FROM cte FOR XML PATH('');

    WITH cte_acc_egr1  AS 
    (	SELECT t1.person_id, t1.tripnum, 'A' AS label, 'transit' AS trip_type,
            (SELECT MAX(CAST(VALUE AS int)) FROM STRING_SPLIT(Elmer.dbo.rgx_extract(t1.modes,'^((?:' + @transit_access_egress_modes + '),)+',1),',')) AS link_value
        FROM HHSurvey.Trip AS t1 WHERE EXISTS (SELECT 1 FROM STRING_SPLIT(t1.modes,',') WHERE VALUE IN(SELECT mode_id FROM HHSurvey.transitmodes)) 
                            AND Elmer.dbo.rgx_extract(t1.modes,'^(\b(?:' + @transit_access_egress_modes + ')\b,?)+',1) IS NOT NULL
        UNION ALL 
        SELECT t2.person_id, t2.tripnum, 'E' AS label, 'transit' AS trip_type,	
            (SELECT MAX(CAST(VALUE AS int)) FROM STRING_SPLIT(Elmer.dbo.rgx_extract(t2.modes,'(,(?:' + @transit_access_egress_modes + '))+$',1),',')) AS link_value 
        FROM HHSurvey.Trip AS t2 WHERE EXISTS (SELECT 1 FROM STRING_SPLIT(t2.modes,',') WHERE VALUE IN(SELECT mode_id FROM HHSurvey.transitmodes))
                            AND Elmer.dbo.rgx_extract(t2.modes,'^(\b(?:' + @transit_access_egress_modes + ')\b,?)+',1) IS NOT NULL			
        UNION ALL 
        SELECT t3.person_id, t3.tripnum, 'A' AS label, 'auto' AS trip_type,
            (SELECT MAX(CAST(VALUE AS int)) FROM STRING_SPLIT(Elmer.dbo.rgx_extract(t3.modes,'^((?:' + @auto_access_egress_modes + ')\b,?)+',1),',')) AS link_value
        FROM HHSurvey.Trip AS t3 WHERE EXISTS (SELECT 1 FROM STRING_SPLIT(t3.modes,',') WHERE VALUE IN(SELECT mode_id FROM HHSurvey.automodes)) 
                                AND NOT EXISTS (SELECT 1 FROM STRING_SPLIT(t3.modes,',') WHERE VALUE IN(SELECT mode_id FROM HHSurvey.transitmodes))
                                AND Elmer.dbo.rgx_replace(t3.modes,'^(\b(?:' + @auto_access_egress_modes + ')\b,?)+','',1) IS NOT NULL
        UNION ALL 
        SELECT t4.person_id, t4.tripnum, 'E' AS label, 'auto' AS trip_type,
            (SELECT MAX(CAST(VALUE AS int)) FROM STRING_SPLIT(Elmer.dbo.rgx_extract(t4.modes,'(,(?:' + @auto_access_egress_modes + '))+$',1),',')) AS link_value
        FROM HHSurvey.Trip AS t4 WHERE EXISTS (SELECT 1 FROM STRING_SPLIT(t4.modes,',') WHERE VALUE IN(SELECT mode_id FROM HHSurvey.automodes)) 
                                AND NOT EXISTS (SELECT 1 FROM STRING_SPLIT(t4.modes,',') WHERE VALUE IN(SELECT mode_id FROM HHSurvey.transitmodes))
                                AND Elmer.dbo.rgx_replace(t4.modes,'^(\b(?:' + @auto_access_egress_modes + ')\b,?)+','',1) IS NOT NULL),
    cte_acc_egr2 AS (SELECT cte.person_id, cte.tripnum, cte.trip_type,
                            MAX(CASE WHEN cte.label = 'A' THEN cte.link_value ELSE NULL END) AS mode_acc,
                            MAX(CASE WHEN cte.label = 'E' THEN cte.link_value ELSE NULL END) AS mode_egr
        FROM cte_acc_egr1 AS cte GROUP BY cte.person_id, cte.tripnum, cte.trip_type)
    UPDATE t 
        SET t.mode_acc = cte_acc_egr2.mode_acc,
            t.mode_egr = cte_acc_egr2.mode_egr
        FROM HHSurvey.Trip AS t JOIN cte_acc_egr2 ON t.person_id = cte_acc_egr2.person_id AND t.tripnum = cte_acc_egr2.tripnum 
        WHERE EXISTS (SELECT 1 FROM #linked_trips AS lt WHERE lt.person_id =t.person_id AND lt.trip_link = t.tripnum)
        ;

    --handle the 'other' category left out of the operation above (it is the largest integer but secondary to listed modes)
    UPDATE HHSurvey.Trip SET trip.mode_acc = 97 WHERE trip.mode_acc IS NULL AND Elmer.dbo.rgx_find(trip.modes,'^97,\d+',1) = 1
        AND EXISTS (SELECT 1 FROM STRING_SPLIT(trip.modes,',') WHERE VALUE IN(SELECT mode_id FROM HHSurvey.automodes UNION select mode_id FROM HHSurvey.transitmodes)) 
        AND EXISTS (SELECT 1 FROM #linked_trips AS lt WHERE lt.person_id =trip.person_id AND lt.trip_link = trip.tripnum);
    UPDATE HHSurvey.Trip SET trip.mode_egr = 97 WHERE trip.mode_egr IS NULL AND Elmer.dbo.rgx_find(trip.modes,'\d+,97$',1) = 1
        AND EXISTS (SELECT 1 FROM STRING_SPLIT(trip.modes,',') WHERE VALUE IN(SELECT mode_id FROM HHSurvey.automodes UNION select mode_id FROM HHSurvey.transitmodes)) 
        AND EXISTS (SELECT 1 FROM #linked_trips AS lt WHERE lt.person_id =trip.person_id AND lt.trip_link = trip.tripnum)
        ;	
*/
    -- Populate separate mode fields [[No longer removing access/egress from the beginning and end of 1) transit and 2) auto trip strings]]
        WITH cte AS 
/*    (SELECT t1.recid, Elmer.dbo.rgx_replace(Elmer.dbo.rgx_replace(Elmer.dbo.rgx_replace(t1.modes,'\b(' + @auto_access_egress_modes + ')\b','',1),
        '(,(?:' + @transit_access_egress_modes + '))+$','',1),'^((?:' + @transit_access_egress_modes + '),)+','',1) AS mode_reduced
        FROM HHSurvey.Trip AS t1
        WHERE EXISTS (SELECT 1 FROM STRING_SPLIT(t1.modes,',') WHERE VALUE IN(SELECT mode_id FROM HHSurvey.transitmodes))
    UNION ALL 	
    SELECT t2.recid, Elmer.dbo.rgx_replace(t2.modes,'\b(' + @auto_access_egress_modes + ')\b','',1) AS mode_reduced
        FROM HHSurvey.Trip AS t2
        WHERE EXISTS (SELECT 1 FROM STRING_SPLIT(t2.modes,',') WHERE VALUE IN(SELECT mode_id FROM HHSurvey.automodes))
        AND NOT EXISTS (SELECT 1 FROM STRING_SPLIT(t2.modes,',') WHERE VALUE IN(SELECT mode_id FROM HHSurvey.transitmodes))),*/
        (SELECT t.recid, Elmer.dbo.rgx_replace(t.modes, '(?<=\b\1,.*)\b(\w+),?','',1) AS mode_reduced FROM HHSurvey.Trip AS t)
    UPDATE t
        SET mode_1 = COALESCE((SELECT match FROM Elmer.dbo.rgx_matches(cte.mode_reduced,'\b\d+\b',1) ORDER BY match_index OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY), 995),
            mode_2 = COALESCE((SELECT match FROM Elmer.dbo.rgx_matches(cte.mode_reduced,'\b\d+\b',1) ORDER BY match_index OFFSET 1 ROWS FETCH NEXT 1 ROWS ONLY), 995),
            mode_3 = COALESCE((SELECT match FROM Elmer.dbo.rgx_matches(cte.mode_reduced,'\b\d+\b',1) ORDER BY match_index OFFSET 2 ROWS FETCH NEXT 1 ROWS ONLY), 995),
            mode_4 = COALESCE((SELECT match FROM Elmer.dbo.rgx_matches(cte.mode_reduced,'\b\d+\b',1) ORDER BY match_index OFFSET 3 ROWS FETCH NEXT 1 ROWS ONLY), 995)
    FROM HHSurvey.Trip AS t JOIN cte ON t.recid = cte.recid AND EXISTS (SELECT 1 FROM #linked_trips AS lt WHERE lt.person_id =t.person_id AND lt.trip_link = t.tripnum)
    ;

    UPDATE HHSurvey.Trip SET mode_acc = 995 WHERE mode_acc IS NULL;
    UPDATE HHSurvey.Trip SET mode_1   = 995 WHERE mode_1   IS NULL;
    UPDATE HHSurvey.Trip SET mode_2   = 995 WHERE mode_2   IS NULL
    UPDATE HHSurvey.Trip SET mode_3   = 995 WHERE mode_3   IS NULL;
    UPDATE HHSurvey.Trip SET mode_4   = 995 WHERE mode_4   IS NULL; 
    UPDATE HHSurvey.Trip SET mode_egr = 995 WHERE mode_egr IS NULL;

    --temp tables should disappear when the spoc ends, but to be tidy we explicitly delete them.
    DROP TABLE IF EXISTS HHSurvey.trip_ingredient
    DROP TABLE IF EXISTS #linked_trips
    EXEC HHSurvey.recalculate_after_edit;

END
GO

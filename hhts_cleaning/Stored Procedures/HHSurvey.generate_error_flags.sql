SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [HHSurvey].[generate_error_flags] 
    @target_person_id decimal = NULL --If missing, generated for all records
AS BEGIN
    SET NOCOUNT ON

    EXECUTE HHSurvey.tripnum_update @target_person_id;
    DELETE tef 
        FROM HHSurvey.trip_error_flags AS tef 
        WHERE tef.person_id = (CASE WHEN @target_person_id IS NULL THEN tef.person_id ELSE @target_person_id END);

        -- 																									  LOGICAL ERROR LABEL 		
    DROP TABLE IF EXISTS #dayends;
    SELECT t.person_id, ROUND(t.dest_lat,2) AS loc_lat, ROUND(t.dest_lng,2) as loc_lng, count(*) AS n 
        INTO #dayends
        FROM HHSurvey.Trip AS t LEFT JOIN HHSurvey.Trip AS next_t ON t.person_id = next_t.person_id AND t.tripnum + 1 = next_t.tripnum
                WHERE (next_t.recid IS NULL											 -- either there is no 'next trip'
                        OR (DATEDIFF(Day, t.arrival_time_timestamp, next_t.depart_time_timestamp) = 1 
                            AND DATEPART(Hour, next_t.depart_time_timestamp) > 2 ))   -- or the next trip starts the next day after 3am)
                GROUP BY t.person_id, ROUND(t.dest_lat,2), ROUND(t.dest_lng,2)
                HAVING count(*) > 1;

    ALTER TABLE #dayends ADD loc_geog GEOGRAPHY NULL;

    UPDATE #dayends 
        SET loc_geog = geography::STGeomFromText('POINT(' + CAST(loc_lng AS VARCHAR(20)) + ' ' + CAST(loc_lat AS VARCHAR(20)) + ')', 4326);
    
    WITH trip_ref AS (SELECT * FROM HHSurvey.Trip AS t0
                        WHERE (t0.dest_lat BETWEEN 46.725491 AND 48.392602) AND (t0.dest_lng BETWEEN -123.199429 AND -121.243746) 
                        AND  t0.person_id = (CASE WHEN @target_person_id IS NULL THEN t0.person_id ELSE @target_person_id END)),
    /*	cte_dwell AS 
            (SELECT c.tripid, c.collect_time, cnxt.collect_time AS nxt_collected FROM HHSurvey.Trace AS c 
            JOIN HHSurvey.Trace AS cnxt ON c.traceid + 1 = cnxt.traceid AND c.tripid = cnxt.tripid
            WHERE DATEDIFF(Minute, c.collect_time, cnxt.collect_time) > 14),

        cte_tracecount AS (SELECT ctc.tripid, count(*) AS tracecount FROM HHSurvey.Trace AS ctc GROUP BY ctc.tripid HAVING count(*) > 2),
    */
        error_flag_compilation(recid, person_id, tripnum, error_flag) AS
        (SELECT t1.recid, t1.person_id, t1.tripnum,	           				   			                  'ends day, not home' AS error_flag
        FROM trip_ref AS t1 JOIN hhts_cleaning.HHSurvey.Household AS h ON t1.hhid = h.hhid
        LEFT JOIN trip_ref AS t_next ON t1.person_id = t_next.person_id AND t1.tripnum + 1 = t_next.tripnum
            JOIN HHSurvey.Person AS p1 ON t1.person_id=p1.person_id AND p1.age_detailed > 17
            WHERE DATEDIFF(Day, (CASE WHEN DATEPART(Hour, t1.arrival_time_timestamp) < 3 
                                      THEN DATEADD(Hour, -3, t1.arrival_time_timestamp) 
                                      ELSE t1.arrival_time_timestamp END),
                                (CASE WHEN DATEPART(Hour, t_next.arrival_time_timestamp) < 3 
                                      THEN DATEADD(Hour, -3, t_next.depart_time_timestamp) 
                                      ELSE t_next.depart_time_timestamp END)) = 1  -- or the next trip starts the next day after 3am)
            AND t1.dest_is_home IS NULL 
            AND (t1.dest_purpose NOT IN(SELECT purpose_id FROM HHSurvey.sleepstay_purposes) OR 
                (t1.dest_purpose IN(SELECT purpose_id FROM HHSurvey.work_purposes UNION ALL SELECT purpose_id FROM HHSurvey.social_purposes) 
                AND t_next.dest_purpose NOT IN(SELECT purpose_id FROM HHSurvey.sleepstay_purposes))) --allow for graveyard shift work, activities that cross 3am boundary
            --AND Elmer.dbo.rgx_find(t1.psrc_comment,'ADD RETURN HOME \d?\d:\d\d',1) = 0
            AND t1.dest_geog.STDistance(h.home_geog) > 300
            AND NOT EXISTS (SELECT 1 FROM #dayends AS de WHERE t1.person_id = de.person_id AND t1.dest_geog.STDistance(de.loc_geog) < 300)
            AND Elmer.dbo.rgx_find(t1.modes,'31',1) = 0		

        UNION ALL SELECT t_next.recid, t_next.person_id, t_next.tripnum,	           		   		   'starts, not from home' AS error_flag
        FROM trip_ref AS t2 JOIN trip_ref AS t_next ON t2.person_id = t_next.person_id AND t2.tripnum + 1 = t_next.tripnum
            WHERE DATEDIFF(Day, t2.arrival_time_timestamp, t_next.depart_time_timestamp) = 1 -- t_next is first trip of the day
                AND t2.dest_is_home IS NULL AND t2.origin_purpose NOT IN(SELECT purpose_id FROM HHSurvey.sleepstay_purposes)
                AND DATEPART(Hour, t_next.depart_time_timestamp) > 1  -- Night owls typically home before 2am

            UNION ALL SELECT t3.recid, t3.person_id, t3.tripnum, 									       		 'purpose missing' AS error_flag
            FROM trip_ref AS t3
                LEFT JOIN trip_ref AS t_next ON t3.person_id = t_next.person_id AND t3.tripnum + 1 = t_next.tripnum
            WHERE (t3.dest_purpose in(SELECT flag_value FROM HHSurvey.NullFlags) OR t3.dest_purpose IS NULL)

        UNION ALL SELECT t4.recid, t4.person_id, t4.tripnum,  								   'initial trip purpose missing' AS error_flag
            FROM trip_ref AS t4 
            WHERE t4.dest_purpose in(SELECT flag_value FROM HHSurvey.NullFlags) AND t4.tripnum = 1

        UNION ALL SELECT  t5.recid,  t5.person_id,  t5.tripnum, 											 'mode_1 missing' AS error_flag
            FROM trip_ref AS t5
                LEFT JOIN trip_ref AS t_prev ON t5.person_id = t_prev.person_id AND t5.tripnum - 1 = t_prev.tripnum
                LEFT JOIN trip_ref AS t_next ON t5.person_id = t_next.person_id AND t5.tripnum + 1 = t_next.tripnum
            WHERE t5.mode_1 in(SELECT flag_value FROM HHSurvey.NullFlags)
                AND t_prev.mode_1 NOT in(SELECT flag_value FROM HHSurvey.NullFlags)  -- we don't5 want to focus on instances with large blocks of trips missing info
                AND t_next.mode_1 NOT in(SELECT flag_value FROM HHSurvey.NullFlags)

        UNION ALL SELECT t6.recid, t6.person_id, t6.tripnum, 					     'o purpose not equal to prior d purpose' AS error_flag
            FROM trip_ref AS t6
                JOIN trip_ref AS t_prev ON t6.person_id = t_prev.person_id AND t6.tripnum - 1 = t_prev.tripnum
                WHERE t6.origin_purpose <> t_prev.dest_purpose AND DATEDIFF(Day, t_prev.arrival_time_timestamp, t6.depart_time_timestamp) =0

        UNION ALL SELECT max(t7.recid), t7.person_id, max(t7.tripnum) AS tripnum, 							  'lone trip' AS error_flag
            FROM HHSurvey.Trip AS t7
            GROUP BY  t7.person_id 
            HAVING count(*)=1

        UNION ALL SELECT  t8.recid,  t8.person_id,  t8.tripnum,									        	'underage driver' AS error_flag
            FROM hhts_cleaning.HHSurvey.Person AS p
            JOIN trip_ref AS t8 ON p.person_id = t8.person_id
            WHERE t8.driver = 1 AND (p.age_detailed BETWEEN 0 AND 15)

        UNION ALL SELECT  t10.recid,  t10.person_id,  t10.tripnum, 									  'driver, no-drive mode' AS error_flag
            FROM trip_ref as t10
            WHERE NOT EXISTS (SELECT value FROM STRING_SPLIT(t10.modes, ',') WHERE value NOT IN (SELECT mode_id FROM HHSurvey.transitmodes UNION SELECT 1)) AND  t10.driver = 1
            AND EXISTS (SELECT value FROM STRING_SPLIT(t10.modes, ',') WHERE value IN (SELECT mode_id FROM HHSurvey.automodes))

        UNION ALL SELECT  t11.recid,  t11.person_id,  t11.tripnum, 							 		 'non-worker + work trip' AS error_flag
            FROM trip_ref AS t11 JOIN hhts_cleaning.HHSurvey.Person AS p ON p.person_id= t11.person_id
            WHERE p.employment IN(5,6,7) AND  t11.dest_purpose in(SELECT purpose_id FROM HHSurvey.work_purposes)

        UNION ALL SELECT t12.recid, t12.person_id, t12.tripnum, 												'instantaneous' AS error_flag
            FROM trip_ref AS t12	
            WHERE t12.depart_time_timestamp = t12.arrival_time_timestamp

        UNION ALL SELECT t13.recid, t13.person_id, t13.tripnum, 												'excessive speed' AS error_flag
            FROM trip_ref AS t13									
            WHERE 	((EXISTS (SELECT 1 FROM HHSurvey.walkmodes WHERE walkmodes.mode_id = t13.mode_1) AND t13.speed_mph > 20)
                OR 	(EXISTS (SELECT 1 FROM HHSurvey.bikemodes WHERE bikemodes.mode_id = t13.mode_1) AND t13.speed_mph > 40)
                OR	(EXISTS (SELECT 1 FROM HHSurvey.automodes WHERE automodes.mode_id = t13.mode_1) AND t13.speed_mph > 85)	
                OR	(EXISTS (SELECT 1 FROM HHSurvey.transitmodes WHERE transitmodes.mode_id = t13.mode_1) AND t13.mode_1 <> 31 AND t13.speed_mph > 60)	
                OR 	(t13.speed_mph > 600 AND (t13.origin_lng between -140 AND -116.95) AND (t13.dest_lng between -140 AND -116.95)))	-- approximates Pacific Time Zone until vendor delivers UST offset

        UNION ALL SELECT  t14.recid,  t14.person_id,  t14.tripnum,					  					   				'too slow' AS error_flag
            FROM trip_ref AS t14
            WHERE DATEDIFF(Minute,  t14.depart_time_timestamp,  t14.arrival_time_timestamp) > 180 AND  t14.speed_mph < 20		

    /*	UNION ALL SELECT  t15.recid,  t15.person_id,  t15.tripnum,					  					   				'long dwell' AS error_flag
            FROM trip_ref AS t15 JOIN cte_tracecount ON t15.tripid = cte_tracecount.tripid
            WHERE EXISTS (SELECT 1 FROM cte_dwell WHERE cte_dwell.tripid = t15.tripid AND cte_dwell.collect_time > t15.depart_time_timestamp AND cte_dwell.nxt_collected < t15.arrival_time_timestamp)
                AND Elmer.dbo.rgx_find(t15.revision_code,'8,',1) = 0
    */
        UNION ALL SELECT  t16.recid,  t16.person_id,  t16.tripnum,				   					  		'no activity time after' AS error_flag
            FROM trip_ref as t16 JOIN HHSurvey.Trip AS t_next ON t16.person_id=t_next.person_id AND t16.tripnum + 1 = t_next.tripnum
            WHERE DATEDIFF(Second,  t16.depart_time_timestamp, t_next.depart_time_timestamp) < 60 
                AND  t16.dest_purpose NOT IN(SELECT purpose_id FROM HHSurvey.brief_purposes) AND t16.dest_purpose NOT in(SELECT flag_value FROM HHSurvey.NullFlags)

        UNION ALL SELECT t_next.recid, t_next.person_id, t_next.tripnum,	       				            'same dest as prior' AS error_flag
            FROM trip_ref as t17 JOIN HHSurvey.Trip AS t_next ON  t17.person_id=t_next.person_id AND t17.tripnum + 1 =t_next.tripnum 
                AND t17.dest_geog.STDistance(t_next.dest_geog) < 10

        UNION ALL (SELECT t18.recid, t18.person_id, t18.tripnum,					         				     	  'time overlap' AS error_flag
            FROM trip_ref AS t18 JOIN HHSurvey.Trip AS compare_t ON  t18.person_id=compare_t.person_id AND  t18.recid <> compare_t.recid
            WHERE 	(compare_t.depart_time_timestamp  BETWEEN DATEADD(Minute, 2, t18.depart_time_timestamp) AND DATEADD(Minute, -2, t18.arrival_time_timestamp))
                OR	(compare_t.arrival_time_timestamp BETWEEN DATEADD(Minute, 2,  t18.depart_time_timestamp) AND DATEADD(Minute, -2,  t18.arrival_time_timestamp))
                OR	(t18.depart_time_timestamp  BETWEEN DATEADD(Minute, 2, compare_t.depart_time_timestamp) AND DATEADD(Minute, -2, compare_t.arrival_time_timestamp))
                OR	(t18.arrival_time_timestamp BETWEEN DATEADD(Minute, 2, compare_t.depart_time_timestamp) AND DATEADD(Minute, -2, compare_t.arrival_time_timestamp)))

        UNION ALL SELECT t19.recid, t19.person_id, t19.tripnum,	  		   			 		   	       'purpose at odds w/ dest' AS error_flag
            FROM trip_ref AS t19 JOIN hhts_cleaning.HHSurvey.Household AS h ON t19.hhid = h.hhid JOIN hhts_cleaning.HHSurvey.Person AS p ON t19.person_id = p.person_id
            WHERE (t19.dest_purpose NOT IN(SELECT 1 UNION ALL SELECT purpose_id FROM HHSurvey.PUDO_purposes) and t19.dest_is_home = 1) OR 
                  (t19.dest_purpose NOT IN(SELECT purpose_id FROM HHSurvey.work_purposes) and t19.dest_is_work = 1)
                AND h.home_geog.STDistance(p.work_geog) > 500

        UNION ALL SELECT t20.recid, t20.person_id, t20.tripnum,					                        'missing next trip link' AS error_flag
        FROM trip_ref AS t20 JOIN HHSurvey.Trip AS t_next ON  t20.person_id = t_next.person_id AND t20.tripnum + 1 = t_next.tripnum
                                JOIN HHSurvey.Person AS p ON t20.person_id=p.person_id AND p.age_detailed > 17
            WHERE ABS(t20.dest_geog.STDistance(t_next.origin_geog)) > 500  --500m difference or more

        /*UNION ALL SELECT t_next.recid, t_next.person_id, t_next.tripnum,	              	           'missing prior trip link' AS error_flag
        FROM trip_ref AS t21 JOIN HHSurvey.Trip AS t_next ON t21.person_id = t_next.person_id AND  t21.tripnum + 1 = t_next.tripnum
                                JOIN HHSurvey.Person AS p ON t21.person_id=p.person_id AND p.age_detailed > 17
            WHERE ABS(t21.dest_geog.STDistance(t_next.origin_geog)) > 500	--500m difference or more*/			

        UNION ALL SELECT t22.recid, t22.person_id, t22.tripnum,	              	 			 			 '"change mode" purpose' AS error_flag	
            FROM trip_ref AS t22 JOIN HHSurvey.Trip AS t_next ON t22.person_id = t_next.person_id AND  t22.tripnum + 1 = t_next.tripnum
                WHERE t22.dest_purpose = 60 AND Elmer.dbo.rgx_find(t_next.modes,'(31|32)',1) = 0 AND Elmer.dbo.rgx_find(t22.modes,'(31|32)',1) = 0
                AND t22.travelers_total = t_next.travelers_total

/*        UNION ALL SELECT t23.recid, t23.person_id, t23.tripnum,					          		  		'PUDO, no +/- travelers' AS error_flag
            FROM HHSurvey.Trip AS t23 LEFT JOIN HHSurvey.Trip AS t_next ON  t23.person_id = t_next.person_id	AND  t23.tripnum + 1 = t_next.tripnum						
            WHERE  t23.dest_purpose IN(SELECT purpose_id FROM HHSurvey.PUDO_purposes) AND (t23.travelers_total = t_next.travelers_total)
                AND NOT (CASE WHEN t23.hhmember1 <> t_next.hhmember1 THEN 1 ELSE 0 END +
                            CASE WHEN t23.hhmember2 <> t_next.hhmember2 THEN 1 ELSE 0 END +
                            CASE WHEN t23.hhmember3 <> t_next.hhmember3 THEN 1 ELSE 0 END +
                            CASE WHEN t23.hhmember4 <> t_next.hhmember4 THEN 1 ELSE 0 END +
                            CASE WHEN t23.hhmember5 <> t_next.hhmember5 THEN 1 ELSE 0 END +
                            CASE WHEN t23.hhmember6 <> t_next.hhmember6 THEN 1 ELSE 0 END +
                            CASE WHEN t23.hhmember7 <> t_next.hhmember7 THEN 1 ELSE 0 END +
                            CASE WHEN t23.hhmember8 <> t_next.hhmember8 THEN 1 ELSE 0 END) > 1 
*/
        UNION ALL SELECT t24.recid, t24.person_id, t24.tripnum,					  				 	    	   'too long at dest?' AS error_flag
            FROM trip_ref AS t24 JOIN HHSurvey.Trip AS t_next ON t24.person_id = t_next.person_id AND t24.tripnum + 1 = t_next.tripnum
                WHERE   (t24.dest_purpose IN(SELECT purpose_id FROM HHSurvey.work_purposes UNION ALL SELECT purpose_id FROM HHSurvey.ed_purposes)    		
                    AND DATEDIFF(Minute, t24.arrival_time_timestamp, 
                            CASE WHEN t_next.recid IS NULL 
                                    THEN DATETIME2FROMPARTS(DATEPART(year, t24.arrival_time_timestamp),DATEPART(month, t24.arrival_time_timestamp),DATEPART(day, t24.arrival_time_timestamp),3,0,0,0,0) 
                                    ELSE t_next.depart_time_timestamp END) > 840)
                    OR  (t24.dest_purpose IN(30)      			
                    AND DATEDIFF(Minute, t24.arrival_time_timestamp, 
                            CASE WHEN t_next.recid IS NULL 
                                    THEN DATETIME2FROMPARTS(DATEPART(year, t24.arrival_time_timestamp),DATEPART(month, t24.arrival_time_timestamp),DATEPART(day, t24.arrival_time_timestamp),3,0,0,0,0) 
                                    ELSE t_next.depart_time_timestamp END) > 240)
                    OR  (t24.dest_purpose IN(SELECT purpose_id FROM HHSurvey.under4hr_purposes) 	
                    AND DATEDIFF(Minute, t24.arrival_time_timestamp, 
                            CASE WHEN t_next.recid IS NULL 
                                    THEN DATETIME2FROMPARTS(DATEPART(year, t24.arrival_time_timestamp),DATEPART(month, t24.arrival_time_timestamp),DATEPART(day, t24.arrival_time_timestamp),3,0,0,0,0) 
                                    ELSE t_next.depart_time_timestamp END) > 480)
                    OR  (t24.dest_purpose IN (SELECT purpose_id FROM HHSurvey.PUDO_purposes) 	
                    AND DATEDIFF(Minute, t24.arrival_time_timestamp, 
                            CASE WHEN t_next.recid IS NULL 
                                    THEN DATETIME2FROMPARTS(DATEPART(year, t24.arrival_time_timestamp),DATEPART(month, t24.arrival_time_timestamp),DATEPART(day, t24.arrival_time_timestamp),3,0,0,0,0) 
                                    ELSE t_next.depart_time_timestamp END) > 35)    

        UNION ALL SELECT t25.recid, t25.person_id, t25.tripnum, 		  				   		          'non-student + school trip' AS error_flag
            FROM trip_ref AS t25 JOIN HHSurvey.Trip as t_next ON t25.person_id = t_next.person_id AND t25.tripnum + 1 = t_next.tripnum JOIN hhts_cleaning.HHSurvey.Person ON t25.person_id=person.person_id 					
            WHERE t25.dest_purpose IN(SELECT purpose_id FROM HHSurvey.ed_purposes)		
                AND (person.student=1) AND person.age_detailed > 17					
            )

    INSERT INTO HHSurvey.trip_error_flags (recid, person_id, tripnum, error_flag)
        SELECT efc.recid, efc.person_id, efc.tripnum, efc.error_flag 
        FROM error_flag_compilation AS efc
        WHERE NOT EXISTS (SELECT 1 FROM trip_ref AS t_active WHERE efc.recid = t_active.recid AND t_active.psrc_resolved = 1)
        AND efc.person_id = (CASE WHEN @target_person_id IS NULL THEN efc.person_id ELSE @target_person_id END)
        GROUP BY efc.recid, efc.person_id, efc.tripnum, efc.error_flag;

    DROP TABLE IF EXISTS #dayends;
END
GO

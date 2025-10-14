SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
  CREATE   PROCEDURE [HHSurvey].[dest_purpose_updates] AS 
    BEGIN

        UPDATE t--Classify home destinations
            SET t.dest_is_home = 1
            FROM HHSurvey.Trip AS t JOIN HHSurvey.household AS h ON t.hhid = h.hhid
            WHERE t.dest_geog.STDistance(h.home_geog) < 150;

        UPDATE t --Classify home purposes where destination code is absent; 150m proximity to home location on file
            SET t.dest_purpose = 1, 
                t.revision_code = CONCAT(t.revision_code,'5,') 
            FROM HHSurvey.Trip AS t JOIN HHSurvey.household AS h ON t.hhid = h.hhid
            WHERE t.dest_is_home = 1 AND t.dest_purpose NOT IN(SELECT purpose_id FROM HHSurvey.PUDO_purposes UNION ALL SELECT 1);

        UPDATE t --Classify primary work destinations
            SET t.dest_is_work = 1
            FROM HHSurvey.Trip AS t JOIN HHSurvey.person AS p ON t.person_id = p.person_id AND p.employment > 1
            WHERE t.dest_geog.STDistance(p.work_geog) < 150;

        UPDATE t --Classify work destinations where destination code is absent; 150m proximity to work location on file
            SET t.dest_purpose = 10, t.revision_code = CONCAT(t.revision_code,'5,')
            FROM HHSurvey.Trip AS t JOIN HHSurvey.person AS p ON t.person_id  = p.person_id AND p.employment > 1
            WHERE t.dest_is_work = 1 AND t.dest_purpose <> 10
                AND t.dest_purpose in(SELECT flag_value FROM HHSurvey.NullFlags UNION SELECT 60 UNION SELECT 97);

        UPDATE t --Classify school destinations where destination code is absent; 150m proximity to school location on file
            SET t.dest_purpose = CASE WHEN p.age_detailed < 5 THEN 26 WHEN p.age_detailed < 19 THEN 21 ELSE 22 END, t.revision_code = CONCAT(t.revision_code,'5,')
            FROM HHSurvey.Trip AS t JOIN HHSurvey.person AS p ON t.person_id  = p.person_id AND (p.age_detailed BETWEEN 5 and 18 OR p.student IN(4,5,6,7))
            WHERE t.dest_purpose in(SELECT flag_value FROM HHSurvey.NullFlags UNION SELECT 60 UNION SELECT 97)
                AND t.dest_geog.STDistance(p.school_geog) < 150;		

        UPDATE t --revises purpose field for home return portion of a single stop loop trip 
            SET t.dest_purpose = 1, t.revision_code = CONCAT(t.revision_code,'1,')
            FROM HHSurvey.Trip AS t
            WHERE t.dest_purpose NOT IN(SELECT purpose_id FROM HHSurvey.PUDO_purposes UNION ALL SELECT 1)
                AND t.dest_is_home = 1;					

        UPDATE t --Change code to pickup when passenger number increases and duration is under 30 minutes
                SET t.dest_purpose = 45, t.revision_code = CONCAT(t.revision_code,'2,')
            FROM HHSurvey.Trip AS t
                JOIN HHSurvey.person AS p ON t.person_id=p.person_id 
                JOIN HHSurvey.Trip AS next_t ON t.person_id=next_t.person_id	AND t.tripnum + 1 = next_t.tripnum						
            WHERE p.age_detailed > 18 
                AND p.student = 1 
                and (t.dest_purpose IN(SELECT purpose_id FROM HHSurvey.ed_purposes) 
                    or t.dest_purpose in(SELECT flag_value FROM HHSurvey.NullFlags)
                    or t.dest_purpose=97
                    )
                AND t.travelers_total < next_t.travelers_total
                AND DATEDIFF(minute, t.arrival_time_timestamp, next_t.depart_time_timestamp) < 30;

            UPDATE t --Change code to dropoff when passenger number decreases and duration is under 30 minutes
                SET t.dest_purpose = 46, t.revision_code = CONCAT(t.revision_code,'2,')
            FROM HHSurvey.Trip AS t
                JOIN HHSurvey.person AS p ON t.person_id=p.person_id 
                JOIN HHSurvey.Trip AS next_t ON t.person_id=next_t.person_id	AND t.tripnum + 1 = next_t.tripnum						
            WHERE p.age_detailed > 18 
                AND p.student = 1
                and (t.dest_purpose IN(SELECT purpose_id FROM HHSurvey.ed_purposes)
                    or t.dest_purpose in(SELECT flag_value FROM HHSurvey.NullFlags)
                    or t.dest_purpose=97
                    )
                AND t.travelers_total > next_t.travelers_total
                AND DATEDIFF(minute, t.arrival_time_timestamp, next_t.depart_time_timestamp) < 30;

        UPDATE t --Change code to pickup when passenger number increases and duration is under 30 minutes
            SET t.dest_purpose = 45, t.revision_code = CONCAT(t.revision_code,'2,')
            FROM HHSurvey.Trip AS t
                JOIN HHSurvey.person AS p ON t.person_id=p.person_id 
                JOIN HHSurvey.Trip AS next_t ON t.person_id=next_t.person_id	AND t.tripnum + 1 = next_t.tripnum						
            WHERE (p.age_detailed < 4 OR p.employment = 0) 
                and t.dest_purpose IN(SELECT flag_value FROM HHSurvey.NullFlags)
                AND t.travelers_total < next_t.travelers_total
                AND DATEDIFF(minute, t.arrival_time_timestamp, next_t.depart_time_timestamp) < 30;					

        UPDATE t --Change code to dropoff when passenger number decreases and duration is under 30 minutes
            SET t.dest_purpose = 46, t.revision_code = CONCAT(t.revision_code,'2,')
            FROM HHSurvey.Trip AS t
                JOIN HHSurvey.person AS p ON t.person_id=p.person_id 
                JOIN HHSurvey.Trip AS next_t ON t.person_id=next_t.person_id	AND t.tripnum + 1 = next_t.tripnum						
            WHERE (p.age_detailed < 4 OR p.employment = 0) 
                and t.dest_purpose IN(SELECT flag_value FROM HHSurvey.NullFlags)
                AND t.travelers_total > next_t.travelers_total
                AND DATEDIFF(minute, t.arrival_time_timestamp, next_t.depart_time_timestamp) < 30;	
        
/*        UPDATE t --changes code to 'family activity' when adult is present, multiple people involved and duration is from 30mins to 4hrs
            SET t.dest_purpose = 56, t.revision_code = CONCAT(t.revision_code,'3,')
            FROM HHSurvey.Trip AS t
                JOIN HHSurvey.person AS p ON t.person_id=p.person_id 
                LEFT JOIN HHSurvey.Trip as next_t ON t.person_id=next_t.person_id AND t.tripnum + 1 = next_t.tripnum
            WHERE p.age_detailed > 18
                AND p.student = 1
                AND (t.travelers_total > 1 OR next_t.travelers_total > 1)
                AND (t.dest_purpose IN(SELECT purpose_id FROM HHSurvey.ed_purposes)
                    --OR Elmer.dbo.rgx_find(t.dest_label,'(school|care)',1) = 1
                )
                AND DATEDIFF(Minute, t.arrival_time_timestamp, next_t.depart_time_timestamp) Between 30 and 240;
*/ -- No "family activity" code anymore                

    --if traveling with another hhmember, take missing purpose from the most adult member with whom they traveled
    WITH cte AS
        (SELECT myself.recid AS self_recid, family.person_id AS referent, family.recid AS referent_recid
            FROM HHSurvey.Trip AS myself 
                JOIN HHSurvey.Trip AS family ON myself.hhid=family.hhid AND myself.pernum <> family.pernum 
            WHERE EXISTS (
                SELECT 1 
                FROM (VALUES (family.hhmember1),(family.hhmember2),(family.hhmember3),
                        (family.hhmember4),(family.hhmember5),(family.hhmember6),
                        (family.hhmember7),(family.hhmember8),(family.hhmember9)
                    ) AS hhmem(member) 
                WHERE myself.person_id IN (member)
            )
        AND (myself.depart_time_timestamp BETWEEN DATEADD(Minute, -5, family.depart_time_timestamp) AND DATEADD(Minute, 5, family.arrival_time_timestamp))
        AND (myself.arrival_time_timestamp BETWEEN DATEADD(Minute, -5, family.depart_time_timestamp) AND DATEADD(Minute, 5, family.arrival_time_timestamp))
        AND myself.dest_purpose IN(SELECT flag_value FROM HHSurvey.NullFlags)
        AND myself.mode_1 IN(SELECT flag_value FROM HHSurvey.NullFlags)
        AND family.dest_purpose NOT IN(SELECT flag_value FROM HHSurvey.NullFlags)
        AND family.mode_1 NOT IN(SELECT flag_value FROM HHSurvey.NullFlags)
        )
    UPDATE t
        SET t.dest_purpose = ref_t.dest_purpose, 
            t.mode_1 	   = ref_t.mode_1,
            t.revision_code = CONCAT(t.revision_code,'6,')		
        FROM HHSurvey.Trip AS t 
            JOIN cte ON t.recid = cte.self_recid 
            JOIN HHSurvey.Trip AS ref_t ON cte.referent_recid = ref_t.recid AND cte.referent = ref_t.person_id
        WHERE t.dest_purpose IN(SELECT flag_value FROM HHSurvey.NullFlags);

    --if the same person has been to the purpose-missing location at other times and provided a consistent purpose for those trips, use it again
    WITH cte AS (SELECT t1.person_id, t1.recid, t2.dest_purpose 
                    FROM HHSurvey.Trip AS t1
                    JOIN HHSurvey.Trip AS t2 ON t1.person_id = t2.person_id
                    WHERE t1.dest_geog.STDistance(t2.dest_geog) < 100 AND (t1.dest_purpose in(SELECT flag_value FROM HHSurvey.NullFlags) OR t1.dest_purpose=97) AND t2.dest_purpose NOT in(SELECT flag_value FROM HHSurvey.NullFlags) AND t2.dest_purpose<>97
                    GROUP BY t1.person_id, t1.recid, t2.dest_purpose),
        cte_filter AS (SELECT cte.person_id, cte.recid, count(*) AS instances FROM cte GROUP BY cte.person_id, cte.recid HAVING count(*) = 1)
    UPDATE t 
        SET t.dest_purpose = cte.dest_purpose,
            t.revision_code = CONCAT(t.revision_code,'5b,') 
        FROM HHSurvey.Trip AS t JOIN cte ON t.recid = cte.recid JOIN cte_filter ON t.recid = cte_filter.recid;

    --if anyone has been to the purpose-missing location at other times and all visitors provided a consistent purpose for those trips, use it again
    WITH cte AS (SELECT t1.recid, t2.dest_purpose 
                    FROM HHSurvey.Trip AS t1
                    JOIN HHSurvey.Trip AS t2 ON t1.dest_geog.STDistance(t2.dest_geog) < 100 
                    WHERE t2.dest_purpose NOT IN (1,10) AND (t1.dest_purpose in(SELECT flag_value FROM HHSurvey.NullFlags) OR t1.dest_purpose=97) AND t2.dest_purpose NOT in(SELECT flag_value FROM HHSurvey.NullFlags) AND t2.dest_purpose<>97
                    GROUP BY t1.recid, t2.dest_purpose),
        cte_filter AS (SELECT cte.recid, count(*) AS instances FROM cte GROUP BY cte.recid HAVING count(*) = 1)
    UPDATE t 
        SET t.dest_purpose = cte.dest_purpose,
            t.revision_code = CONCAT(t.revision_code,'5c,') 
        FROM HHSurvey.Trip AS t JOIN cte ON t.recid = cte.recid JOIN cte_filter ON t.recid = cte_filter.recid
        WHERE cte.dest_purpose IN(30,32,33,34,50,51,52,53,54,61,62);

    UPDATE t
        SET t.origin_purpose = t_prev.dest_purpose
        FROM HHSurvey.Trip AS t 
            JOIN HHSurvey.Trip AS t_prev ON t.person_id = t_prev.person_id AND t.tripnum -1 = t_prev.tripnum 
        WHERE t.origin_purpose <> t_prev.dest_purpose 
            AND t.tripnum > 1
            AND t_prev.dest_purpose > 0;

    END
GO

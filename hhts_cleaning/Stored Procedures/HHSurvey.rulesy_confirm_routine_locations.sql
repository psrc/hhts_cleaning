SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [HHSurvey].[rulesy_confirm_routine_locations]
AS BEGIN

    BEGIN TRANSACTION;
    DROP TABLE IF EXISTS #central_home_tripend, #central_work_tripend, #central_school_tripend;
    COMMIT TRANSACTION;

    BEGIN TRANSACTION;
    
    --determine central home-purpose trip end, i.e. the home-purpose destination w/ shortest cumulative distance to all other household home-purpose destinations.
    WITH cte AS 		
    (SELECT t1.hhid,
            t1.recid, 
            ROW_NUMBER() OVER (PARTITION BY t1.hhid ORDER BY sum(t1.dest_geog.STDistance(t2.dest_geog)) ASC) AS ranker
        FROM HHSurvey.Trip AS t1 JOIN HHSurvey.Trip AS t2 ON t1.hhid = t2.hhid AND t1.dest_purpose = 1 AND t2.dest_purpose = 1 
        WHERE  EXISTS (SELECT 1 FROM HHSurvey.Household AS h WHERE h.hhid = t1.hhid AND h.home_geog IS NULL)
        AND EXISTS (SELECT 1 FROM HHSurvey.Household AS h WHERE h.hhid = t2.hhid AND h.home_geog IS NULL)
        GROUP BY t1.hhid, t1.recid
    )
    SELECT cte.hhid, cte.recid INTO #central_home_tripend
        FROM cte 			
        WHERE cte.ranker = 1;
    
    UPDATE h					-- Default is reported home location; invalidate when not within 300m of most central home-purpose trip
        SET h.home_geog = NULL
        FROM HHSurvey.Household AS h JOIN #central_home_tripend AS te ON h.hhid = te.hhid JOIN HHSurvey.Trip AS t ON te.recid = t.recid
        WHERE t.dest_geog.STDistance(h.home_geog) > 300;	

    UPDATE h					-- When Reported home location is invalidated, fill with sample home location when within 300m of of most central home-purpose trip
        SET h.home_geog = h.sample_geog
        FROM HHSurvey.Household AS h JOIN #central_home_tripend AS te ON h.hhid = te.hhid JOIN HHSurvey.Trip AS t ON te.recid = t.recid
        WHERE h.home_geog IS NULL 
            AND t.dest_geog.STDistance(h.sample_geog) < 300;				

    UPDATE h					-- When neither Reported or Sampled home location is valid, take the most central home-purpose trip destination
        SET h.home_geog = t.dest_geog, 
            h.home_lat = t.dest_lat, 
            h.home_lng = t.dest_lng 
        FROM HHSurvey.Household AS h JOIN #central_home_tripend AS te ON h.hhid = te.hhid JOIN HHSurvey.Trip AS t ON t.recid = te.recid
        WHERE h.home_geog IS NULL;

    UPDATE h 
        SET h.home_lat = h.home_geog.Lat, 
            h.home_lng = h.home_geog.Long
        FROM HHSurvey.Household AS h 
        WHERE h.home_lat IS NULL;

    DROP TABLE IF EXISTS #central_home_tripend;
    COMMIT TRANSACTION;

    --similarly determine central primary work-purpose trip end, on a person- rather than household-basis
    BEGIN TRANSACTION;
    WITH cte AS 		
    (SELECT t1.person_id,
            t1.recid, 
            ROW_NUMBER() OVER (PARTITION BY t1.person_id ORDER BY sum(t1.dest_geog.STDistance(t2.dest_geog)) ASC) AS ranker
        FROM HHSurvey.Trip AS t1 JOIN HHSurvey.Trip AS t2 ON t1.person_id = t2.person_id AND t1.dest_purpose = 10 AND t2.dest_purpose = 10 
        WHERE  EXISTS (SELECT 1 FROM HHSurvey.Person AS p WHERE p.person_id = t1.person_id AND p.work_geog IS NULL)
        AND EXISTS (SELECT 1 FROM HHSurvey.Person AS p WHERE p.person_id = t2.person_id AND p.work_geog IS NULL)
        GROUP BY t1.person_id, t1.recid
    )
    SELECT cte.person_id, cte.recid INTO #central_work_tripend
        FROM cte 			
        WHERE cte.ranker = 1;

    UPDATE p					-- When neither Reported or Sampled work location is valid, take the most central work-purpose trip destination
        SET p.work_geog = t.dest_geog,
            p.work_lat = t.dest_lat,
            p.work_lng = t.dest_lng 
        FROM HHSurvey.Person AS p JOIN #central_work_tripend AS te ON p.person_id = te.person_id JOIN HHSurvey.Trip AS t ON t.recid = te.recid 
        WHERE p.work_geog IS NULL AND (p.employment < 7 OR t.dest_purpose IN(SELECT flag_value FROM HHSurvey.NullFlags));

    UPDATE p
        SET p.work_lat = p.work_geog.Lat, 
            p.work_lng = p.work_geog.Long
        FROM HHSurvey.Person AS p 
        WHERE p.work_lat IS NULL;

    DROP TABLE IF EXISTS #central_work_tripend;
    COMMIT TRANSACTION;

    --similarly determine central school-purpose trip end, on a person- rather than household-basis
    BEGIN TRANSACTION;
    WITH cte AS 		
    (SELECT t1.person_id,
            t1.recid, 
            ROW_NUMBER() OVER (PARTITION BY t1.person_id ORDER BY sum(t1.dest_geog.STDistance(t2.dest_geog)) ASC) AS ranker
        FROM HHSurvey.Trip AS t1 JOIN HHSurvey.Trip AS t2 ON t1.person_id = t2.person_id AND t1.dest_purpose BETWEEN 21 AND 26 AND t2.dest_purpose BETWEEN 21 AND 26
        WHERE  EXISTS (SELECT 1 FROM HHSurvey.Person AS p WHERE p.person_id = t1.person_id AND p.school_geog IS NULL)
        AND EXISTS (SELECT 1 FROM HHSurvey.Person AS p WHERE p.person_id = t2.person_id AND p.school_geog IS NULL)
        GROUP BY t1.person_id, t1.recid
    )
    SELECT cte.person_id, cte.recid INTO #central_school_tripend
        FROM cte 			
        WHERE cte.ranker = 1;	

    UPDATE p					-- When reported school location is not valid, take the most central school-purpose trip destination
        SET p.school_geog = t.dest_geog,
            p.school_loc_lat = t.dest_lat,
            p.school_loc_lng = t.dest_lng 
        FROM HHSurvey.Person AS p JOIN #central_school_tripend AS te ON p.person_id = te.person_id JOIN HHSurvey.Trip AS t ON t.recid = te.recid
        WHERE p.school_geog IS NULL AND (p.student IN(2,3) OR t.dest_purpose IN(SELECT flag_value FROM HHSurvey.NullFlags));

    UPDATE p
        SET p.school_loc_lat = p.school_geog.Lat, 
            p.school_loc_lng = p.school_geog.Long
        FROM HHSurvey.Person AS p 
        WHERE p.school_loc_lat IS NULL;

    DROP TABLE IF EXISTS #central_school_tripend;
    COMMIT TRANSACTION;
END
GO


/* Add Trip table fields initially left out for efficiency */

    ALTER TABLE HHSurvey.Trip ADD 
        [analyst_merged] int NULL,
        [analyst_split] int NULL,
        [analyst_split_loop] int NULL,
        [arrival_time_hour] int NULL,
        [arrival_time_minute] int NULL,
        [arrival_time_second] int NULL,
        [arrive_date] VARCHAR(255) NULL,
        [arrive_dow] int NULL,
        [copied_trip] int NULL,
        [d_bg] VARCHAR(255) NULL,
        [d_in_region] int NULL,
        [d_puma10] VARCHAR(255) NULL,
        [day_id] VARCHAR(255) NULL,
        [day_iscomplete] int NULL,
        [depart_date] VARCHAR(255) NULL,
        [depart_dow] int NULL,
        [depart_time_hour] int NULL,
        [depart_time_minute] int NULL,
        [depart_time_second] int NULL,
        [dest_purpose_cat] int NULL,
        [duration_minutes] float NULL,
        [dwell_mins] float NULL,
        [flag_teleport] int NULL,
        [has_access] int NULL,
        [has_egress] int NULL,
        [has_synthetic_access] int NULL,
        [has_synthetic_egress] int NULL,
        [hh_day_iscomplete] int NULL,
        [is_access] int NULL,
        [is_egress] int NULL,
        [is_transit] int NULL,
        [mode_type] int NULL,
        [o_bg] VARCHAR(255) NULL,
        [o_in_region] int NULL,
        [o_puma10] VARCHAR(255) NULL,
        [origin_purpose_cat] int NULL,
        [speed_flag] float NULL,
        [survey_year] VARCHAR(255) NULL,
        [svy_complete] int NULL,
        [transit_quality_flag] VARCHAR(255) NULL,
        [travel_date] VARCHAR(255) NULL,
        [travel_dow] int NULL,
        [traveldate_end] VARCHAR(255) NULL,
        [traveldate_start] VARCHAR(255) NULL,
        [user_added] float NULL,
        [user_merged] int NULL,
        [user_split] int NULL,
        [linked_trip_id] VARCHAR(255) NULL,
        [linked_trip_num] VARCHAR(255) NULL,
        [n_legs] VARCHAR(255) NULL,
        [imputed_joint_trip] int NULL,
        [imputed_record_type] int NULL,
        [distance_meters] float NULL,
        [distance_beeline_meters] float NULL,
        [duration_seconds] float NULL;
        
    UPDATE t 
    SET t.analyst_merged = r.analyst_merged,
        t.analyst_split = r.analyst_split,
        t.analyst_split_loop = r.analyst_split_loop,
        t.copied_trip = r.copied_trip,
        t.flag_teleport = r.flag_teleport,
        t.has_access = r.has_access,
        t.has_egress = r.has_egress,
        t.has_synthetic_access = r.has_synthetic_access,
        t.has_synthetic_egress = r.has_synthetic_egress,
        t.is_access = r.is_access,
        t.is_egress = r.is_egress,
        t.svy_complete = r.svy_complete,
        t.transit_quality_flag = r.transit_quality_flag,
        t.traveldate_end = r.traveldate_end,
        t.traveldate_start = r.traveldate_start,
        t.user_added = r.user_added,
        t.speed_flag = r.speed_flag,
        t.user_merged = r.user_merged,
        t.user_split = r.user_split,
        t.linked_trip_id = r.linked_trip_id,
        t.linked_trip_num = r.linked_trip_num,
        t.imputed_joint_trip = r.imputed_joint_trip,
        t.imputed_record_type = r.imputed_record_type
    FROM HHSurvey.Trip t JOIN HouseholdTravelSurvey2025.delivered_20251021.ex_trip_unlinked r ON t.tripid=r.tripid;

/* Update geographically calculated variables and geoassignments */

    --Update distance_miles calculation where absent
    DECLARE @GoogleRoutesAPI nvarchar(25) = '<key>';
    WITH cte AS (SELECT t.recid, Elmer.dbo.route_mi_min(t.origin_lng, t.origin_lat, t.dest_lng, t.dest_lat, 
          CASE WHEN (t.mode_1 IN (SELECT mode_id FROM HHSurvey.automodes) OR  
                      t.mode_2 IN (SELECT mode_id FROM HHSurvey.automodes) OR
                  t.mode_3 IN (SELECT mode_id FROM HHSurvey.automodes) OR
                  t.mode_4 IN (SELECT mode_id FROM HHSurvey.automodes)) THEN 'driving'
              WHEN (t.mode_1 IN (SELECT mode_id FROM HHSurvey.transitmodes) OR  
                      t.mode_2 IN (SELECT mode_id FROM HHSurvey.transitmodes) OR
                  t.mode_3 IN (SELECT mode_id FROM HHSurvey.transitmodes) OR
                  t.mode_4 IN (SELECT mode_id FROM HHSurvey.transitmodes)) THEN 'transit'
              WHEN (t.mode_1 IN (SELECT mode_id FROM HHSurvey.bikemodes) OR  
                      t.mode_2 IN (SELECT mode_id FROM HHSurvey.bikemodes) OR
                  t.mode_3 IN (SELECT mode_id FROM HHSurvey.bikemodes) OR
                  t.mode_4 IN (SELECT mode_id FROM HHSurvey.bikemodes)) THEN 'cycling'
              WHEN 	(t.mode_1 =1) THEN 'walking' ELSE 'driving' END,			
          @GoogleRoutesAPI, t.depart_time_timestamp) AS mi_min_result
    FROM HHSurvey.Trip AS t
    WHERE (t.distance_miles IS NULL OR t.distance_miles=0) AND t.origin_lng BETWEEN -125 AND -116 AND t.dest_lng BETWEEN -125 AND -115 
    AND t.origin_lat BETWEEN 44 and 50 AND t.dest_lat BETWEEN 44 AND 50)
    UPDATE tu 
      SET tu.distance_miles = CAST(LEFT(cte.mi_min_result, CHARINDEX(',', cte.mi_min_result)-1) AS float),
          tu.distance_beeline_meters = tu.origin_geog.STDistance(tu.dest_geog)
      FROM HHSurvey.Trip AS tu JOIN cte ON tu.recid=cte.recid WHERE cte.mi_min_result<>'0,0' AND tu.distance_miles IS NULL;

    ALTER TABLE HHSurvey.Trip ADD dest_geom GEOMETRY NULL;
    ALTER TABLE HHSurvey.Trip ADD origin_geom GEOMETRY NULL;
    ALTER TABLE HHSurvey.Trip ADD dest_city nvarchar(25);
    ALTER TABLE HHSurvey.Trip ADD dest_zip nchar(5);
    ALTER TABLE HHSurvey.Trip ADD dest_county nchar(3);
    GO
    UPDATE t SET t.dest_geom=Elmer.dbo.ToXY(t.dest_lng, t.dest_lat) FROM HHSurvey.Trip AS t;

    UPDATE t SET t.origin_geom=Elmer.dbo.ToXY(t.origin_lng, t.origin_lat) FROM HHSurvey.Trip AS t;
    GO
    CREATE SPATIAL INDEX dest_geom_idx ON HHSurvey.Trip(dest_geom) USING GEOMETRY_AUTO_GRID
      WITH (BOUNDING_BOX = (xmin = 1095800, ymin = -97600, xmax = 1622700, ymax = 477600));

      CREATE SPATIAL INDEX origin_geom_idx ON HHSurvey.Trip(origin_geom) USING GEOMETRY_AUTO_GRID
      WITH (BOUNDING_BOX = (xmin = 1095800, ymin = -97600, xmax = 1622700, ymax = 477600));
    GO

    UPDATE t
    SET t.d_in_region = CASE WHEN r.Shape IS NOT NULL THEN 1 ELSE 0 END
    FROM HHSurvey.Trip AS t
    LEFT JOIN ElmerGeo.dbo.PSRC_REGIONAL_OUTLINE AS r
      ON r.Shape.STIntersects(t.dest_geom) = 1;
    GO
    UPDATE t
    SET t.o_in_region = CASE WHEN r.Shape IS NOT NULL THEN 1 ELSE 0 END
    FROM HHSurvey.Trip AS t
    LEFT JOIN ElmerGeo.dbo.PSRC_REGIONAL_OUTLINE AS r
      ON r.Shape.STIntersects(t.origin_geom) = 1;
    GO

    UPDATE t SET t.dest_city=r.city_name 
    FROM HHSurvey.Trip AS t JOIN ElmerGeo.dbo.PSRC_REGION AS r ON r.Shape.STContains(t.dest_geom)=1
    WHERE r.feat_type='city';
    GO
    UPDATE t SET t.dest_zip=r.zipcode 
    FROM HHSurvey.Trip AS t JOIN ElmerGeo.dbo.ZIP_CODES AS r ON r.Shape.STContains(t.dest_geom)=1;
    GO 
    /*--not used?
    UPDATE t SET t.o_puma10=r.pumace10
    FROM HHSurvey.Trip AS t JOIN ElmerGeo.dbo.REG10PUMA AS r ON r.Shape.STContains(t.dest_geom)=1;
    GO */

  -- For county, first use rectangular approximation first for performance
    UPDATE t
    SET t.dest_county=CASE WHEN (t.dest_lat BETWEEN 47.32417899933368 AND 47.77557543545566) AND (t.dest_lng BETWEEN -122.40491513697908 AND -121.47382388080176) THEN '033'
                WHEN (t.dest_lat BETWEEN 46.987025526142794 AND 47.25521385921765) AND (t.dest_lng BETWEEN -122.61999268125203 AND -122.14483401659517) THEN '053'
                WHEN (t.dest_lat BETWEEN 47.785624118154686 AND 48.29247321335945) AND (t.dest_lng BETWEEN -122.34422210698376 AND -121.18653784598449) THEN '061'
                WHEN (t.dest_lat BETWEEN 47.5126145395748 AND 47.7726115311967) AND (t.dest_lng BETWEEN -122.73894212405432 AND -122.50273608266419) THEN '035'
                ELSE NULL END
    FROM HHSurvey.Trip AS t WHERE t.dest_county IS NULL;
    GO
    UPDATE t
    SET t.dest_county = r.county_fip
    FROM HHSurvey.Trip AS t JOIN ElmerGeo.dbo.COUNTY_LINES AS r ON t.dest_geom.STContains(r.Shape)=1
    WHERE r.psrc=1 AND t.dest_county IS NULL;
    GO
    UPDATE t
    SET t.o_bg=bg.geoid20
    FROM HHSurvey.Trip AS t JOIN ElmerGeo.dbo.BLOCKGRP2020 AS bg ON bg.Shape.STContains(t.origin_geom)=1
    GO
    UPDATE t
    SET t.d_bg=bg.geoid20
    FROM HHSurvey.Trip AS t JOIN ElmerGeo.dbo.BLOCKGRP2020 AS bg ON bg.Shape.STContains(t.dest_geom)=1
    GO
    UPDATE t
    SET t.o_puma10=CONCAT('53', p.pumace10)
    FROM HHSurvey.Trip AS t JOIN ElmerGeo.dbo.REG10PUMA AS p ON p.Shape.STContains(t.origin_geom)=1
    GO
    UPDATE t
    SET t.d_puma10=CONCAT('53', p.pumace10)
    FROM HHSurvey.Trip AS t JOIN ElmerGeo.dbo.REG10PUMA AS p ON p.Shape.STContains(t.dest_geom)=1
    GO
    ALTER TABLE HHSurvey.household ADD home_geom GEOMETRY;
    GO
    UPDATE h 
    SET h.home_lat=h.home_geog.Lat,
        h.home_lng=h.home_geog.Long
    FROM HHSurvey.Household AS h;
    GO
    UPDATE h SET h.home_geom=Elmer.dbo.ToXY(h.home_lng, h.home_lat) FROM HHSurvey.Household AS h;
    GO
    CREATE SPATIAL INDEX home_geom_idx ON HHSurvey.Household(home_geom) USING GEOMETRY_AUTO_GRID
      WITH (BOUNDING_BOX = (xmin = 1095800, ymin = -97600, xmax = 1622700, ymax = 477600));
    GO

    UPDATE h
    SET h.home_bg_2010=b.geoid10
    FROM HHSurvey.Household AS h JOIN ElmerGeo.dbo.BLOCKGRP2010 AS b ON b.Shape.STContains(h.home_geom)=1;

    UPDATE h
    SET h.home_bg_2020=b.geoid20
    FROM HHSurvey.Household AS h JOIN ElmerGeo.dbo.BLOCKGRP2020 AS b ON b.Shape.STContains(h.home_geom)=1;

    UPDATE h
    SET h.home_puma_2012=CONCAT('53',p.pumace10)
    FROM HHSurvey.Household AS h JOIN ElmerGeo.dbo.BLOCKGRP2010 AS b ON h.home_bg_2010=b.geoid10 JOIN ElmerGeo.dbo.REG10PUMA AS p ON b.Shape.STContains(p.Shape)=1;

    UPDATE h
    SET h.home_puma_2022=CONCAT('53',p.pumace20)
    FROM HHSurvey.Household AS h JOIN ElmerGeo.dbo.BLOCKGRP2020 AS b ON h.home_bg_2020=b.geoid20 JOIN ElmerGeo.dbo.REG20PUMA AS p ON b.Shape.STContains(p.Shape)=1;
    GO

    UPDATE h
    SET h.home_in_region = CASE WHEN r.Shape IS NOT NULL THEN 1 ELSE 0 END
    FROM HHSurvey.Household AS h
    LEFT JOIN ElmerGeo.dbo.PSRC_REGIONAL_OUTLINE AS r
      ON r.Shape.STIntersects(h.home_geom) = 1;
    GO

    /*--Not used?
    WITH cte AS (SELECT h.hhid, r.city_name FROM HHSurvey.Household AS h JOIN ElmerGeo.dbo.PSRC_REGION AS r ON r.Shape.STContains(h.home_geom)=1)
    UPDATE h2 
    SET h2.cityofseattle= CASE WHEN cte.city_name='Seattle' THEN 1 ELSE 0 END,
        h2.cityofbellevue= CASE WHEN cte.city_name='Bellevue' THEN 1 ELSE 0 END
    FROM HHSurvey.Household AS h2 JOIN cte ON h2.hhid=cte.hhid;
    GO 
    */

    ALTER TABLE HHSurvey.Person ADD work_geom GEOMETRY, school_geom GEOMETRY, work_in_region smallint, school_in_region smallint;
    GO
    UPDATE p 
    SET p.work_lat=p.work_geog.Lat,
        p.work_lng=p.work_geog.Long,
      p.school_loc_lat=p.school_geog.Lat,
      p.school_loc_lng=p.school_geog.Long
    FROM HHSurvey.Person AS p;
    GO
    UPDATE HHSurvey.Person SET work_geom=Elmer.dbo.ToXY(work_lng, work_lat) WHERE work_lng IS NOT NULL AND work_lat IS NOT NULL;
    GO
    UPDATE HHSurvey.Person SET school_geom=Elmer.dbo.ToXY(school_loc_lng, school_loc_lat) WHERE school_loc_lng IS NOT NULL AND school_loc_lat IS NOT NULL;
    GO
    CREATE SPATIAL INDEX work_geom_idx ON HHSurvey.Person(work_geom) USING GEOMETRY_AUTO_GRID
      WITH (BOUNDING_BOX = (xmin = 1095800, ymin = -97600, xmax = 1622700, ymax = 477600));
    GO
    CREATE SPATIAL INDEX school_geom_idx ON HHSurvey.Person(school_geom) USING GEOMETRY_AUTO_GRID
      WITH (BOUNDING_BOX = (xmin = 1095800, ymin = -97600, xmax = 1622700, ymax = 477600));
    GO
    UPDATE p
    SET p.work_in_region = CASE WHEN r.Shape IS NOT NULL THEN 1 ELSE 0 END
    FROM HHSurvey.Person AS p
    LEFT JOIN ElmerGeo.dbo.PSRC_REGIONAL_OUTLINE AS r
      ON r.Shape.STIntersects(p.work_geom) = 1; 
    GO
    UPDATE p
    SET p.school_in_region = CASE WHEN r.Shape IS NOT NULL THEN 1 ELSE 0 END
    FROM HHSurvey.Person AS p
    LEFT JOIN ElmerGeo.dbo.PSRC_REGIONAL_OUTLINE AS r
      ON r.Shape.STIntersects(p.school_geom) = 1; 
    GO

    UPDATE p
    SET p.school_bg=bg.geoid20
    FROM HHSurvey.Person AS p JOIN ElmerGeo.dbo.BLOCKGRP2020 AS bg ON bg.Shape.STContains(p.school_geom)=1
    GO

    UPDATE p
    SET p.school_puma10=CONCAT('53', rp.pumace10)
    FROM HHSurvey.Person AS p JOIN ElmerGeo.dbo.REG10PUMA AS rp ON rp.Shape.STContains(p.school_geom)=1
    GO

/* Remove invalid records from primary tables */
    SELECT * INTO HHSurvey.day_invalid_hh 
    FROM HHSurvey.Day AS d
    WHERE EXISTS (SELECT 1 FROM HHSurvey.trip_invalid AS ti WHERE d.hhid=ti.hhid);
    GO
    DELETE d FROM HHSurvey.Day AS d
    WHERE EXISTS (SELECT 1 FROM HHSurvey.trip_invalid AS ti WHERE d.hhid=ti.hhid);
    GO
    SELECT * INTO HHSurvey.trip_invalid_hh 
    FROM HHSurvey.Trip AS t
    WHERE EXISTS (SELECT 1 FROM HHSurvey.trip_invalid AS ti WHERE t.hhid=ti.hhid)
    GO
    DELETE t FROM HHSurvey.Trip AS t
    WHERE EXISTS (SELECT 1 FROM HHSurvey.trip_invalid AS ti WHERE t.hhid=ti.hhid);
    GO
    SELECT * INTO HHSurvey.person_invalid 
    FROM HHSurvey.Person AS p
    WHERE EXISTS (SELECT 1 FROM HHSurvey.trip_invalid AS ti WHERE p.person_id=ti.person_id)
    GO
    DELETE p FROM HHSurvey.Person AS p
    WHERE EXISTS (SELECT 1 FROM HHSurvey.trip_invalid AS ti WHERE p.person_id=ti.person_id);
    GO
    SELECT * INTO HHSurvey.person_invalid_hh 
    FROM HHSurvey.Person AS p
    WHERE EXISTS (SELECT 1 FROM HHSurvey.trip_invalid AS ti WHERE p.hhid=ti.hhid)
    GO
    DELETE p FROM HHSurvey.Person AS p
    WHERE EXISTS (SELECT 1 FROM HHSurvey.trip_invalid AS ti WHERE p.hhid=ti.hhid);
    GO
    SELECT * INTO HHSurvey.household_invalid 
    FROM HHSurvey.Household AS h
    WHERE EXISTS (SELECT 1 FROM HHSurvey.trip_invalid AS ti WHERE h.hhid=ti.hhid);
    GO
    DELETE h FROM HHSurvey.Household AS h
    WHERE EXISTS (SELECT 1 FROM HHSurvey.trip_invalid AS ti WHERE h.hhid=ti.hhid);
    GO

    DELETE p FROM HHSurvey.Person AS p WHERE NOT EXISTS (SELECT 1 FROM HHSurvey.Household AS h WHERE h.hhid=p.hhid);
    DELETE d FROM HHSurvey.Day AS d WHERE NOT EXISTS (SELECT 1 FROM HHSurvey.Household AS h WHERE h.hhid=d.hhid);
    DELETE t FROM HHSurvey.Trip AS t WHERE NOT EXISTS (SELECT 1 FROM HHSurvey.Household AS h WHERE h.hhid=t.hhid);
    DELETE v FROM HHSurvey.Vehicle AS v WHERE NOT EXISTS (SELECT 1 FROM HHSurvey.Household AS h WHERE h.hhid=v.hhid);
    GO

/* Update fields calculated from timestamps */

    UPDATE HHSurvey.Trip 
    SET survey_year=2025 WHERE survey_year IS NULL;
    GO
    SET DATEFIRST 7;
    UPDATE t 
    SET t.depart_date=CONVERT(NVARCHAR, t.depart_time_timestamp, 23),
      t.depart_dow=CASE WHEN DATEPART(DW, t.depart_time_timestamp)=1 THEN 7 ELSE DATEPART(DW, t.depart_time_timestamp) -1 END,
      t.depart_time_hour=DATEPART(HOUR, t.depart_time_timestamp),
      t.depart_time_minute=DATEPART(MINUTE, t.depart_time_timestamp),
      t.depart_time_second=DATEPART(SECOND, t.depart_time_timestamp),
      t.arrival_time_hour=DATEPART(HOUR, t.arrival_time_timestamp),
      t.arrival_time_minute=DATEPART(MINUTE, t.arrival_time_timestamp),
      t.arrival_time_second=DATEPART(SECOND, t.arrival_time_timestamp),
      t.arrive_date=CONVERT(NVARCHAR, t.arrival_time_timestamp, 23),
      t.arrive_dow=CASE WHEN DATEPART(DW, t.arrival_time_timestamp)=1 THEN 7 ELSE DATEPART(DW, t.arrival_time_timestamp) -1 END,
      t.distance_meters=t.distance_miles * 1609.344
    FROM HHSurvey.Trip AS t;
    GO

    WITH cte AS (SELECT person_id, travel_date, day_id FROM HHSurvey.Day)
    UPDATE t 
    SET t.day_id=cte.day_id,
      t.travel_date=CONVERT(NVARCHAR, DATEADD(HOUR, -3, t.depart_time_timestamp), 23),
      t.travel_dow=CASE WHEN DATEPART(DW, DATEADD(HOUR, -3, t.depart_time_timestamp))=1 THEN 7 ELSE DATEPART(DW, DATEADD(HOUR, -3, t.depart_time_timestamp)) -1 END
      FROM HHSurvey.Trip AS t JOIN cte ON cte.person_id=t.person_id AND cte.travel_date=CONVERT(NVARCHAR, DATEADD(HOUR, -3, t.depart_time_timestamp), 23);
    GO

    UPDATE t 
    SET t.duration_minutes=DATEDIFF(MINUTE, t.depart_time_timestamp, t.arrival_time_timestamp),
        t.duration_seconds=DATEDIFF(SECOND, t.depart_time_timestamp, t.arrival_time_timestamp)
    FROM HHSurvey.Trip AS t;

    UPDATE t 
    SET t.dwell_mins=DATEDIFF(MINUTE, t.arrival_time_timestamp,t_next.depart_time_timestamp)
    FROM HHSurvey.Trip AS t JOIN HHSurvey.Trip AS t_next ON t.person_id=t_next.person_id AND t.tripnum + 1 = t_next.tripnum;
    GO

/* Update RSG metacategories using the raw data as lookup */
    WITH cte AS (SELECT dest_purpose, dest_purpose_cat FROM HouseholdTravelSurvey2025.delivered_20251021.ex_trip_unlinked GROUP BY dest_purpose, dest_purpose_cat)
    UPDATE t 
    SET t.d_purpose_category=cte.dest_purpose_cat
    FROM HHSurvey.Trip AS t JOIN cte ON t.dest_purpose=cte.dest_purpose WHERE t.d_purpose_category<>cte.dest_purpose_cat;

    WITH cte AS (SELECT origin_purpose, origin_purpose_cat FROM HouseholdTravelSurvey2025.delivered_20251021.ex_trip_unlinked GROUP BY origin_purpose, origin_purpose_cat)
    UPDATE t 
    SET t.o_purpose_category=cte.origin_purpose_cat
    FROM HHSurvey.Trip AS t JOIN cte ON t.origin_purpose=cte.origin_purpose WHERE t.o_purpose_category<>cte.origin_purpose_cat;

/* Individual field revisions under specific circumstances */

    UPDATE t 
    SET t.is_transit=COALESCE(CASE WHEN (t.mode_1 IN(SELECT mode_id FROM HHSurvey.transitmodes) OR 
                              t.mode_2 IN(SELECT mode_id FROM HHSurvey.transitmodes) OR
                  t.mode_3 IN(SELECT mode_id FROM HHSurvey.transitmodes) OR
                  t.mode_4 IN(SELECT mode_id FROM HHSurvey.transitmodes)) THEN 1
                WHEN t.is_transit=1 THEN 0 ELSE t.is_transit END, 0)
    FROM HHSurvey.Trip AS t;

    UPDATE t 
    SET t.driver= CASE WHEN EXISTS (SELECT 1 FROM (VALUES (mode_acc),(mode_1),(mode_2),(mode_3),(mode_4),(mode_egr)) v(m) 
                                    WHERE v.m IN (SELECT mode_id FROM HHSurvey.automodes)) THEN t.driver ELSE 0 END
    FROM HHSurvey.Trip AS t;

    --update hhmember field

    UPDATE HHSurvey.Trip
    SET hhmember1 =CASE WHEN hhmember1 IS NULL AND pernum =1 THEN person_id ELSE hhmember1 END,
        hhmember2 =CASE WHEN hhmember2 IS NULL AND pernum =2 THEN person_id ELSE hhmember2 END,
        hhmember3 =CASE WHEN hhmember3 IS NULL AND pernum =3 THEN person_id ELSE hhmember3 END,
        hhmember4 =CASE WHEN hhmember4 IS NULL AND pernum =4 THEN person_id ELSE hhmember4 END,
        hhmember5 =CASE WHEN hhmember5 IS NULL AND pernum =5 THEN person_id ELSE hhmember5 END,
        hhmember6 =CASE WHEN hhmember6 IS NULL AND pernum =6 THEN person_id ELSE hhmember6 END,
        hhmember7 =CASE WHEN hhmember7 IS NULL AND pernum =7 THEN person_id ELSE hhmember7 END,
        hhmember8 =CASE WHEN hhmember8 IS NULL AND pernum =8 THEN person_id ELSE hhmember8 END,
        hhmember9 =CASE WHEN hhmember9 IS NULL AND pernum =9 THEN person_id ELSE hhmember9 END,
        hhmember10 =CASE WHEN hhmember10 IS NULL AND pernum =10 THEN person_id ELSE hhmember10 END,
        hhmember11 =CASE WHEN hhmember11 IS NULL AND pernum =11 THEN person_id ELSE hhmember11 END,
        hhmember12 =CASE WHEN hhmember12 IS NULL AND pernum =12 THEN person_id ELSE hhmember12 END,
        hhmember13 =CASE WHEN hhmember13 IS NULL AND pernum =13 THEN person_id ELSE hhmember13 END;

    UPDATE HHSurvey.Trip SET travelers_total=5 WHERE travelers_total>5;
    UPDATE HHSurvey.Trip SET travelers_nonhh=995 WHERE travelers_nonhh=-995;

/* Update Person and Household tripcounts */

    WITH cte AS (SELECT t.person_id, count(*) AS tripcount FROM HHSurvey.Trip AS t GROUP BY t.person_id)
    UPDATE p 
    SET p.num_trips = cte.tripcount
    FROM HHSurvey.Person AS p JOIN cte ON cte.person_id=p.person_id 
    WHERE ISNULL(cte.tripcount, -1) <> ISNULL(p.num_trips, -1);
    GO

    WITH cte AS (SELECT t.hhid, count(*) AS tripcount FROM HHSurvey.Trip AS t GROUP BY t.hhid)
    UPDATE h 
    SET h.num_trips=cte.tripcount
    FROM HHSurvey.Household AS h JOIN cte ON cte.hhid=h.hhid WHERE cte.tripcount<>h.num_trips;

/* Update Day variables derived from trip attributes */
    -- Moved below #trip_bounds creation to reuse precomputed aggregates

    -- Precompute first/last trip numbers for each person/day (with tripcount) for downstream adjustments
    IF OBJECT_ID('tempdb..#trip_bounds') IS NOT NULL DROP TABLE #trip_bounds;
    SELECT person_id, day_id,
          MIN(tripnum) AS first_tripnum,
          MAX(tripnum) AS last_tripnum,
          COUNT(*)     AS tripcount
    INTO #trip_bounds
    FROM HHSurvey.Trip
    GROUP BY person_id, day_id;
    -- Supporting index to accelerate joins
    CREATE NONCLUSTERED INDEX IX_trip_bounds_person_day ON #trip_bounds(person_id, day_id)
    INCLUDE (first_tripnum, last_tripnum, tripcount);

  -- Day-level derivations using #trip_bounds for efficiency and consistency
  UPDATE d
  SET d.num_trips = COALESCE(tb.tripcount,0),
    d.loc_start = CASE WHEN (tf.origin_purpose IS NULL OR tf.origin_purpose IN (SELECT flag_value FROM HHSurvey.NullFlags)) THEN 995
               WHEN tf.origin_purpose = 1 THEN 1
               WHEN tf.origin_purpose = 152 THEN 7
               WHEN tf.origin_purpose IN (10,11,14) THEN 10
               WHEN tf.origin_purpose IN (52,150) THEN 4
               ELSE 3 END,
    d.loc_end = CASE WHEN (tl.dest_purpose IS NULL OR tl.dest_purpose IN (SELECT flag_value FROM HHSurvey.NullFlags)) THEN 995
             WHEN tl.dest_purpose = 1 THEN 1
             WHEN tl.dest_purpose = 152 THEN 7
             WHEN tl.dest_purpose IN (10,11,14) THEN 10
             WHEN tl.dest_purpose IN (52,150) THEN 6
             ELSE 3 END,
    d.no_travel = CASE WHEN tb.tripcount > 0 THEN 1 ELSE d.no_travel END
  FROM HHSurvey.Day AS d
  LEFT JOIN #trip_bounds AS tb ON tb.person_id = d.person_id AND tb.day_id = d.day_id
  LEFT JOIN HHSurvey.Trip AS tf ON tf.person_id = d.person_id AND tf.day_id = d.day_id AND tf.tripnum = tb.first_tripnum
  LEFT JOIN HHSurvey.Trip AS tl ON tl.person_id = d.person_id AND tl.day_id = d.day_id AND tl.tripnum = tb.last_tripnum;
  GO

    -- Start-of-day not-home adjustment (uses first_tripnum)
    UPDATE d 
    SET d.loc_start = 4
    FROM HHSurvey.Day AS d
    JOIN #trip_bounds tb ON tb.person_id = d.person_id AND tb.day_id = d.day_id
    JOIN HHSurvey.Trip AS t ON t.person_id = d.person_id AND t.day_id = d.day_id AND t.tripnum = tb.first_tripnum
    WHERE NOT EXISTS (
      SELECT 1 FROM HHSurvey.Household AS h
      WHERE h.hhid = d.hhid AND t.origin_geog.STDistance(h.home_geog) < 800
    ) AND d.loc_start = 1;

    -- End-of-day not-home adjustment (uses last_tripnum)
    UPDATE d
    SET d.loc_end = 4
    FROM HHSurvey.Day AS d
    JOIN #trip_bounds tb ON tb.person_id = d.person_id AND tb.day_id = d.day_id
    JOIN HHSurvey.Trip AS t ON t.person_id = d.person_id AND t.day_id = d.day_id AND t.tripnum = tb.last_tripnum
    WHERE NOT EXISTS (
      SELECT 1 FROM HHSurvey.Household AS h
      WHERE h.hhid = d.hhid AND t.dest_geog.STDistance(h.home_geog) < 800
    ) AND d.loc_end = 1;

    WITH cte AS (
      SELECT t.person_id, t.day_id, t_next.day_id AS nxt_day_id
      FROM HHSurvey.Trip AS t
      JOIN #trip_bounds tb ON tb.person_id = t.person_id AND tb.day_id = t.day_id AND t.tripnum = tb.last_tripnum
      JOIN HHSurvey.Trip AS t_next ON t.person_id = t_next.person_id AND t.tripnum + 1 = t_next.tripnum
      -- Cross-midnight (relative to 3am day boundary) detection:
      -- Shift both timestamps back 3 hours so that activity between midnight and 2:59:59 becomes part of the prior survey day.
      -- If the shifted arrival date is later than the shifted departure date, the trip spans the boundary.
      WHERE DATEDIFF(DAY, DATEADD(HOUR, -3, t.depart_time_timestamp), DATEADD(HOUR, -3, t.arrival_time_timestamp)) > 0
    )
    UPDATE d 
    SET d.loc_end = 5
    FROM HHSurvey.Day AS d JOIN cte ON cte.person_id = d.person_id AND cte.day_id = d.day_id;

    WITH cte AS (
      SELECT t.person_id, t.day_id, t_next.day_id AS nxt_day_id
      FROM HHSurvey.Trip AS t
      JOIN #trip_bounds tb ON tb.person_id = t.person_id AND tb.day_id = t.day_id AND t.tripnum = tb.last_tripnum
      JOIN HHSurvey.Trip AS t_next ON t.person_id = t_next.person_id AND t.tripnum + 1 = t_next.tripnum
      -- Cross-midnight (relative to 3am day boundary) detection for start of following day
      WHERE DATEDIFF(DAY, DATEADD(HOUR, -3, t.depart_time_timestamp), DATEADD(HOUR, -3, t.arrival_time_timestamp)) > 0
    )
    UPDATE d 
    SET d.loc_start = 5
    FROM HHSurvey.Day AS d JOIN cte ON cte.person_id = d.person_id AND cte.nxt_day_id = d.day_id;
    DROP TABLE #trip_bounds;
    GO

/* Update completion variables */ 

    UPDATE t 
    SET t.svy_complete = 1 
    FROM HHSurvey.Trip AS t
    WHERE t.dest_purpose NOT IN (SELECT flag_value FROM HHSurvey.NullFlags)
      AND t.mode_1 NOT IN (SELECT flag_value FROM HHSurvey.NullFlags);

    ;WITH cte AS (
      SELECT t.person_id,
             t.day_id,
             SUM(COALESCE(t.svy_complete,0)) AS num_complete_trip_surveys,
             COUNT(*)            AS num_trips
      FROM HHSurvey.Trip AS t
      GROUP BY t.person_id, t.day_id
    )
    UPDATE HHSurvey.Day
    SET num_complete_trip_surveys = cte.num_complete_trip_surveys,
      num_trips = cte.num_trips
    FROM HHSurvey.Day
    JOIN cte
      ON cte.person_id = HHSurvey.Day.person_id
     AND cte.day_id = HHSurvey.Day.day_id;

    UPDATE HHSurvey.Day
    SET is_complete = CASE
      WHEN (num_complete_trip_surveys > 0 OR no_travel = 0)
       --AND loc_start NOT IN (SELECT flag_value FROM HHSurvey.NullFlags)
       --AND loc_end   NOT IN (SELECT flag_value FROM HHSurvey.NullFlags)
      THEN 1 ELSE 0 END;

    IF OBJECT_ID('tempdb..#hh_complete_days') IS NOT NULL DROP TABLE #hh_complete_days;

    SELECT s.hhid, s.travel_date, s.travel_dow
    INTO #hh_complete_days
    FROM (
      SELECT d.hhid,
             d.travel_date,
             MIN(d.travel_dow) AS travel_dow,
             COUNT(*)          AS complete_participant_count
      FROM HHSurvey.Day AS d
      WHERE d.is_complete = 1
      GROUP BY d.hhid, d.travel_date
    ) AS s
    JOIN HHSurvey.Household AS h
      ON h.hhid = s.hhid
    WHERE s.complete_participant_count >= h.num_participants;

    CREATE CLUSTERED INDEX IX_hh_complete_days_hhid_date
      ON #hh_complete_days(hhid, travel_date);
    CREATE NONCLUSTERED INDEX IX_hh_complete_days_hhid_dow
      ON #hh_complete_days(hhid, travel_dow)
      INCLUDE (travel_date);

    UPDATE d 
    SET d.hh_day_complete = 0
    FROM HHSurvey.Day AS d; 

    UPDATE d 
    SET d.hh_day_complete = 1
    FROM HHSurvey.Day AS d
    JOIN #hh_complete_days AS hcd 
      ON d.hhid = hcd.hhid AND d.travel_date = hcd.travel_date;

    UPDATE t 
    SET t.hh_day_iscomplete = 0
    FROM HHSurvey.Trip AS t;

    UPDATE t 
    SET t.hh_day_iscomplete = d.hh_day_complete
    FROM HHSurvey.Trip AS t 
    JOIN HHSurvey.Day AS d 
      ON t.day_id = d.day_id;    

    ;WITH cte AS (
      SELECT hhid, COUNT(*) AS n_complete_days
      FROM #hh_complete_days
      GROUP BY hhid
    )
    UPDATE hh
    SET hh.numdayscomplete = COALESCE(cte.n_complete_days, 0)
    FROM HHSurvey.Household AS hh
    LEFT JOIN cte
      ON cte.hhid = hh.hhid;
    GO

    ;WITH cte AS (
      SELECT hhid,
             SUM(CASE WHEN travel_dow = 1 THEN 1 ELSE 0 END) AS num_complete_mon,
             SUM(CASE WHEN travel_dow = 2 THEN 1 ELSE 0 END) AS num_complete_tue,
             SUM(CASE WHEN travel_dow = 3 THEN 1 ELSE 0 END) AS num_complete_wed,
             SUM(CASE WHEN travel_dow = 4 THEN 1 ELSE 0 END) AS num_complete_thu,
             SUM(CASE WHEN travel_dow = 5 THEN 1 ELSE 0 END) AS num_complete_fri,
             SUM(CASE WHEN travel_dow = 6 THEN 1 ELSE 0 END) AS num_complete_sat,
             SUM(CASE WHEN travel_dow = 7 THEN 1 ELSE 0 END) AS num_complete_sun,
             SUM(CASE WHEN travel_dow BETWEEN 1 AND 5 THEN 1 ELSE 0 END) AS num_days_complete_weekday,
             SUM(CASE WHEN travel_dow IN (6,7) THEN 1 ELSE 0 END) AS num_days_complete_weekend
      FROM #hh_complete_days
      GROUP BY hhid
    )
    UPDATE h
    SET h.num_complete_mon = COALESCE(cte.num_complete_mon, 0),
        h.num_complete_tue = COALESCE(cte.num_complete_tue, 0),
        h.num_complete_wed = COALESCE(cte.num_complete_wed, 0),
        h.num_complete_thu = COALESCE(cte.num_complete_thu, 0),
        h.num_complete_fri = COALESCE(cte.num_complete_fri, 0),
        h.num_complete_sat = COALESCE(cte.num_complete_sat, 0),
        h.num_complete_sun = COALESCE(cte.num_complete_sun, 0),
        h.num_days_complete_weekday = COALESCE(cte.num_days_complete_weekday, 0),
        h.num_days_complete_weekend = COALESCE(cte.num_days_complete_weekend, 0)
    FROM HHSurvey.Household AS h
    LEFT JOIN cte
      ON cte.hhid = h.hhid;

    DROP TABLE #hh_complete_days;

SELECT TOP (0) p.* INTO HHSurvey.no_complete_hh_days_person FROM HHSurvey.Person p;
SELECT TOP (0) h.* INTO HHSurvey.no_complete_hh_days_household FROM HHSurvey.Household h;
SELECT TOP (0) d.* INTO HHSurvey.no_complete_hh_days_day FROM HHSurvey.Day d;
SELECT TOP (0) t.* INTO HHSurvey.no_complete_hh_days_trip FROM HHSurvey.Trip t JOIN HHSurvey.Day d ON t.day_id=d.day_id;
SELECT TOP (0) v.* INTO HHSurvey.no_complete_hh_days_vehicle FROM HHSurvey.Vehicle v;

-- Remove persons without any complete days
DELETE p
OUTPUT deleted.* INTO HHSurvey.no_complete_hh_days_person
FROM HHSurvey.Person AS p
WHERE NOT EXISTS (
  SELECT 1 FROM HHSurvey.Day AS d WHERE d.person_id = p.person_id
     AND d.is_complete = 1);

DELETE p
OUTPUT deleted.* INTO HHSurvey.no_complete_hh_days_person
FROM HHSurvey.Person AS p
WHERE EXISTS (
  SELECT 1 FROM HHSurvey.no_complete_hh_days_person pno WHERE pno.hhid = p.hhid);

-- Remove households, days, trips, vehicles from households without any shared complete days
DELETE h
OUTPUT deleted.* INTO HHSurvey.no_complete_hh_days_household
FROM HHSurvey.Household AS h
WHERE EXISTS (
  SELECT 1 FROM HHSurvey.no_complete_hh_days_person p WHERE h.hhid = p.hhid);

DELETE d
OUTPUT deleted.* INTO HHSurvey.no_complete_hh_days_day
FROM HHSurvey.Day AS d
WHERE EXISTS (
  SELECT 1 FROM HHSurvey.no_complete_hh_days_person p WHERE d.hhid = p.hhid);

DELETE t
OUTPUT deleted.* INTO HHSurvey.no_complete_hh_days_trip
FROM HHSurvey.Trip AS t
WHERE EXISTS (
  SELECT 1 FROM HHSurvey.no_complete_hh_days_person p WHERE t.hhid = p.hhid);

DELETE v
OUTPUT deleted.* INTO HHSurvey.no_complete_hh_days_vehicle
FROM HHSurvey.Vehicle AS v
WHERE EXISTS (
  SELECT 1 FROM HHSurvey.no_complete_hh_days_person p WHERE v.hhid = p.hhid);
 


/* Shift unique key to separate field and update tripid to reflect current tripnum */    

    ALTER TABLE HHSurvey.Trip ADD initial_tripid decimal(19,0) NULL;
    GO
    UPDATE HHSurvey.Trip SET initial_tripid=tripid;
    GO
    UPDATE HHSurvey.Trip SET tripid=person_id * 1000 + tripnum
      WHERE tripid <> person_id * 1000 + tripnum;

/* Add binned age variable */

UPDATE p 
SET p.age = CASE WHEN p.age_detailed < 5               THEN 1
                 WHEN p.age_detailed BETWEEN 5 AND 15  THEN 2
                 WHEN p.age_detailed BETWEEN 16 AND 17 THEN 3
                 WHEN p.age_detailed BETWEEN 18 AND 24 THEN 4
                 WHEN p.age_detailed BETWEEN 25 AND 34 THEN 5
                 WHEN p.age_detailed BETWEEN 35 AND 44 THEN 6
                 WHEN p.age_detailed BETWEEN 45 AND 54 THEN 7
                 WHEN p.age_detailed BETWEEN 55 AND 64 THEN 8
                 WHEN p.age_detailed BETWEEN 65 AND 74 THEN 9
                 WHEN p.age_detailed BETWEEN 75 AND 84 THEN 10
                 WHEN p.age_detailed > 84 THEN 11 END 
FROM HHSurvey.Person p;
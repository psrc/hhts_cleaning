
DROP TABLE IF EXISTS dbo.tmpTPD1
GO

--Update distance_miles calculation for edited records where the coords were edited but distance wasn't

SELECT t.recid, t.origin_lat, t.origin_lng, t.dest_lat, t.dest_lng, t.mode_1, '                                       ' AS mi_min_result
	INTO dbo.tmpTPD1
	FROM HHSurvey.Trip AS t JOIN HouseholdTravelSurvey2023.combined_data.v_trip AS t0 ON t.tripid=t0.tripid
	WHERE t.distance_miles > 0 --AND NOT EXISTS (SELECT 1 FROM dbo.tmpTPD AS tz WHERE tz.recid=t.recid) 
		AND ABS(geography::STGeomFromText('POINT(' + CAST(t0.origin_lng AS VARCHAR(20)) + ' ' + CAST(t0.origin_lat AS VARCHAR(20)) + ')', 4326).STDistance(t.origin_geog) +
		        geography::STGeomFromText('POINT(' + CAST(t0.dest_lng   AS VARCHAR(20)) + ' ' + CAST(t0.dest_lat   AS VARCHAR(20)) + ')', 4326).STDistance(t.dest_geog)) > 150 
		AND ABS(t.distance_miles-t0.distance_miles) < 0.01
		AND t.origin_lng BETWEEN -125 AND -116 AND t.dest_lng BETWEEN -125 AND -115 
		AND t.origin_lat BETWEEN 44 and 50 AND t.dest_lat BETWEEN 44 AND 50;

UPDATE TOP (5) dbo.tmpTPD1
SET mi_min_result=Elmer.dbo.route_mi_min(origin_lng, origin_lat, dest_lng, dest_lat, CASE WHEN mode_1=1 THEN 'walking' ELSE 'driving' END,'AmXTWUc52YYqvdSlHNGUEAe3RH1TvtcECyH6RGZm7q2vhzv9JzOm1GaY9TKW47lF')
WHERE mi_min_result='';

UPDATE tu 
	SET tu.distance_miles = CAST(LEFT(tm.mi_min_result, CHARINDEX(',',tm.mi_min_result)-1) AS float)
	FROM HHSurvey.Trip AS tu JOIN dbo.tmpTPD1 tm ON tu.recid=tm.recid WHERE tm.mi_min_result<>'0,0';

--Update distance_miles calculation where absent
WITH cte AS (SELECT t.recid, Elmer.dbo.route_mi_min(t.origin_lng, t.origin_lat, t.dest_lng, t.dest_lat, CASE WHEN t.mode_1=1 THEN 'walking' ELSE 'driving' END,'AmXTWUc52YYqvdSlHNGUEAe3RH1TvtcECyH6RGZm7q2vhzv9JzOm1GaY9TKW47lF') AS mi_min_result
FROM HHSurvey.Trip AS t
WHERE (t.distance_miles IS NULL OR t.distance_miles=0) AND t.origin_lng BETWEEN -125 AND -116 AND t.dest_lng BETWEEN -125 AND -115 
AND t.origin_lat BETWEEN 44 and 50 AND t.dest_lat BETWEEN 44 AND 50 AND recid BETWEEN 8001 AND 20000)
UPDATE tu 
	SET tu.distance_miles = CAST(LEFT(cte.mi_min_result, CHARINDEX(',', cte.mi_min_result)-1) AS float)
	FROM HHSurvey.Trip AS tu JOIN cte ON tu.recid=cte.recid WHERE cte.mi_min_result<>'0,0';

--Update geoassignments; for county first use rectangular approximation to save computation

ALTER TABLE HHSurvey.Trip ADD dest_geom GEOMETRY NULL;

ALTER TABLE HHSurvey.Trip ADD origin_geom GEOMETRY NULL;
GO
UPDATE t SET t.dest_geom=Elmer.dbo.ToXY(t.dest_lng, t.dest_lat) FROM HHSurvey.Trip AS t;

UPDATE t SET t.origin_geom=Elmer.dbo.ToXY(t.origin_lng, t.origin_lat) FROM HHSurvey.Trip AS t;
GO
CREATE SPATIAL INDEX dest_geom_idx ON HHSurvey.Trip(dest_geom) USING GEOMETRY_AUTO_GRID
  WITH (BOUNDING_BOX = (xmin = 1095800, ymin = -97600, xmax = 1622700, ymax = 477600));

  CREATE SPATIAL INDEX origin_geom_idx ON HHSurvey.Trip(origin_geom) USING GEOMETRY_AUTO_GRID
  WITH (BOUNDING_BOX = (xmin = 1095800, ymin = -97600, xmax = 1622700, ymax = 477600));
GO
UPDATE t SET t.d_in_region=CASE WHEN r.Shape.STIntersects(t.dest_geom)=1 THEN 1 ELSE 0 END
FROM HHSurvey.Trip AS t JOIN ElmerGeo.dbo.PSRC_REGIONAL_OUTLINE AS r ON 1=1;
GO
UPDATE t SET  t.o_in_region=CASE WHEN r.Shape.STIntersects(t.dest_geom)=1 THEN 1 ELSE 0 END
FROM HHSurvey.Trip AS t JOIN ElmerGeo.dbo.PSRC_REGIONAL_OUTLINE AS r ON 1=1;
GO
UPDATE t SET t.dest_city=r.city_name 
FROM HHSurvey.Trip AS t JOIN ElmerGeo.dbo.PSRC_REGION AS r ON r.Shape.STIntersects(t.dest_geom)=1
WHERE r.feat_type='city';
GO
UPDATE t SET t.dest_zip=r.zipcode 
FROM HHSurvey.Trip AS t JOIN ElmerGeo.dbo.ZIP_CODES AS r ON r.Shape.STIntersects(t.dest_geom)=1;
GO 
UPDATE t SET t.o_puma10=r.pumace10
FROM HHSurvey.Trip AS t JOIN ElmerGeo.dbo.REG10PUMA AS r ON r.Shape.STIntersects(t.dest_geom)=1;
GO 



--SELECT t.region_tripends, count(*) FROM HHSurvey.Trip AS t GROUP BY t.region_tripends;

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
FROM HHSurvey.Trip AS t JOIN ElmerGeo.dbo.COUNTY_LINES AS r ON t.dest_geom.STIntersects(r.Shape)=1
WHERE r.psrc=1 AND t.dest_county IS NULL;
GO
UPDATE t
SET t.o_bg=bg.geoid20
FROM HHSurvey.Trip AS t JOIN ElmerGeo.dbo.BLOCKGRP2020 AS bg ON bg.Shape.STIntersects(t.origin_geom)=1
GO
UPDATE t
SET t.d_bg=bg.geoid20
FROM HHSurvey.Trip AS t JOIN ElmerGeo.dbo.BLOCKGRP2020 AS bg ON bg.Shape.STIntersects(t.dest_geom)=1
GO
UPDATE t
SET t.o_puma10=CONCAT('53', p.pumace10)
FROM HHSurvey.Trip AS t JOIN ElmerGeo.dbo.REG10PUMA AS p ON p.Shape.STIntersects(t.origin_geom)=1
GO
UPDATE t
SET t.d_puma10=CONCAT('53', p.pumace10)
FROM HHSurvey.Trip AS t JOIN ElmerGeo.dbo.REG10PUMA AS p ON p.Shape.STIntersects(t.dest_geom)=1
GO
ALTER TABLE HHSurvey.household ADD home_geom GEOMETRY;
GO
UPDATE h 
SET h.home_lat=h.home_geog.Lat,
    h.home_lng=h.home_geog.Long
FROM HHSurvey.Household AS h WHERE h.home_geog.Lat<>h.home_lat OR h.home_geog.Long<>h.home_lng;
GO
UPDATE h SET h.home_geom=Elmer.dbo.ToXY(h.home_lng, h.home_lat) FROM HHSurvey.Household AS h;
GO
CREATE SPATIAL INDEX home_geom_idx ON HHSurvey.Household(home_geom) USING GEOMETRY_AUTO_GRID
  WITH (BOUNDING_BOX = (xmin = 1095800, ymin = -97600, xmax = 1622700, ymax = 477600));
GO
WITH cte AS (SELECT h.hhid, r.city_name FROM HHSurvey.Household AS h JOIN ElmerGeo.dbo.PSRC_REGION AS r ON r.Shape.STIntersects(h.home_geom)=1)
UPDATE h2 
SET h2.cityofseattle= CASE WHEN cte.city_name='Seattle' THEN 1 ELSE 0 END,
    h2.cityofbellevue= CASE WHEN cte.city_name='Bellevue' THEN 1 ELSE 0 END
FROM HHSurvey.Household AS h2 JOIN cte ON h2.hhid=cte.hhid;
GO 
UPDATE h SET h.psrc=CASE WHEN r.Shape.STIntersects(h.home_geom)=1 THEN 1 ELSE 0 END
FROM HHSurvey.Household AS h JOIN ElmerGeo.dbo.PSRC_REGIONAL_OUTLINE AS r ON 1=1;
GO
ALTER TABLE HHSurvey.Person ADD work_geom GEOMETRY, school_geom GEOMETRY;
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
UPDATE p SET p.work_in_region=CASE WHEN r.Shape.STIntersects(p.work_geom)=1 THEN 1 ELSE 0 END
FROM HHSurvey.Person AS p JOIN ElmerGeo.dbo.PSRC_REGIONAL_OUTLINE AS r ON 1=1; 
GO
UPDATE p SET p.school_in_region=CASE WHEN r.Shape.STIntersects(p.school_geom)=1 THEN 1 ELSE 0 END
FROM HHSurvey.Person AS p JOIN ElmerGeo.dbo.PSRC_REGIONAL_OUTLINE AS r ON 1=1; 
GO
UPDATE p
SET p.school_bg=bg.geoid20
FROM HHSurvey.Person AS p JOIN ElmerGeo.dbo.BLOCKGRP2020 AS bg ON bg.Shape.STIntersects(p.school_geom)=1
GO
UPDATE p
SET p.school_puma10=CONCAT('53', rp.pumace10)
FROM HHSurvey.Person AS p JOIN ElmerGeo.dbo.REG10PUMA AS rp ON rp.Shape.STIntersects(p.school_geom)=1
GO


/*
UPDATE h
SET h.home_puma10=CONCAT('53',p.pumace10)
FROM HHSurvey.Household AS h JOIN ElmerGeo.dbo.BLOCK2010 AS b ON h.home_block=b.geoid10 JOIN ElmerGeo.dbo.REG10PUMA AS p ON b.Shape.STIntersects(p.Shape)=1
WHERE len(h.home_puma10)=5 */

--update hhmember field

UPDATE HHSurvey.Trip 
SET hhmember_none=CASE WHEN travelers_hh>1 THEN 0 WHEN travelers_hh=1 THEN 1 ELSE NULL END
WHERE hhmember_none IS NULL;

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
 hhmember12 =CASE WHEN hhmember12 IS NULL AND pernum =12 THEN person_id ELSE hhmember12 END;

 --Remove invalid records from primary tables
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
WHERE EXISTS (SELECT 1 FROM HHSurvey.trip_invalid AS ti WHERE p.personid=ti.personid)
GO
DELETE p FROM HHSurvey.Person AS p
WHERE EXISTS (SELECT 1 FROM HHSurvey.trip_invalid AS ti WHERE p.personid=ti.personid);
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

UPDATE HHSurvey.Trip 
SET survey_year=2023 WHERE survey_year IS NULL;
GO
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

WITH cte AS (SELECT person_id, travel_date, travel_day, day_id FROM HHSurvey.Day)
UPDATE t 
SET t.day_id=cte.day_id,
    t.travel_day=cte.travel_day,
	t.travel_date=CONVERT(NVARCHAR, DATEADD(HOUR, -3, t.depart_time_timestamp), 23),
	t.travel_dow=CASE WHEN DATEPART(DW, DATEADD(HOUR, -3, t.depart_time_timestamp))=1 THEN 7 ELSE DATEPART(DW, DATEADD(HOUR, -3, t.depart_time_timestamp)) -1 END,
    t.day_iscomplete=t.day_iscomplete
	FROM HHSurvey.Trip AS t JOIN cte ON cte.person_id=t.person_id AND cte.travel_date=CONVERT(NVARCHAR, DATEADD(HOUR, -3, t.depart_time_timestamp), 23);
GO

UPDATE t 
SET t.travel_day=d.travel_day
FROM HHSurvey.Trip AS t JOIN HHSurvey.Day AS d ON t.day_id=t.day_id
GO



UPDATE t 
SET t.dwell_mins=DATEDIFF(MINUTE, t.arrival_time_timestamp,t_next.depart_time_timestamp)
FROM HHSurvey.Trip AS t JOIN HHSurvey.Trip AS t_next ON t.person_id=t_next.person_id AND t.tripnum + 1 = t_next.tripnum;
GO

WITH cte AS (SELECT t.person_id, count(*) AS tripcount FROM HHSurvey.Trip AS t GROUP BY t.person_id)
UPDATE p 
SET p.num_trips=cte.tripcount
FROM HHSurvey.Person AS p JOIN cte ON cte.person_id=p.person_id WHERE cte.tripcount<>p.num_trips;
GO

WITH cte AS (SELECT t.hhid, count(*) AS tripcount FROM HHSurvey.Trip AS t GROUP BY t.hhid)
UPDATE h 
SET h.num_trips=cte.tripcount
FROM HHSurvey.Household AS h JOIN cte ON cte.hhid=h.hhid WHERE cte.tripcount<>h.num_trips;
GO

WITH cte AS (SELECT dest_purpose, dest_purpose_cat FROM HouseholdTravelSurvey2023.combined_data.v_trip GROUP BY dest_purpose, dest_purpose_cat)
UPDATE t 
SET t.dest_purpose_cat=cte.dest_purpose_cat
FROM HHSurvey.Trip AS t JOIN cte ON t.dest_purpose=cte.dest_purpose WHERE t.dest_purpose_cat<>cte.dest_purpose_cat;

WITH cte AS (SELECT origin_purpose, origin_purpose_cat FROM HouseholdTravelSurvey2023.combined_data.v_trip GROUP BY origin_purpose, origin_purpose_cat)
UPDATE t 
SET t.origin_purpose_cat=cte.origin_purpose_cat
FROM HHSurvey.Trip AS t JOIN cte ON t.origin_purpose=cte.origin_purpose WHERE t.origin_purpose_cat<>cte.origin_purpose_cat;

UPDATE t 
SET t.duration_minutes=DATEDIFF(MINUTE, t.depart_time_timestamp, t.arrival_time_timestamp),
    t.duration_seconds=DATEDIFF(SECOND, t.depart_time_timestamp, t.arrival_time_timestamp)
FROM HHSurvey.Trip AS t;

UPDATE t 
SET t.is_transit=CASE WHEN (t.mode_1 IN(SELECT mode_id FROM HHSurvey.transitmodes) OR 
                           t.mode_2 IN(SELECT mode_id FROM HHSurvey.transitmodes) OR
						   t.mode_3 IN(SELECT mode_id FROM HHSurvey.transitmodes) OR
						   t.mode_4 IN(SELECT mode_id FROM HHSurvey.transitmodes)) THEN 1
					  WHEN t.is_transit=1 THEN 0 ELSE t.is_transit END
FROM HHSurvey.Trip AS t;

UPDATE t 
SET t.driver= CASE WHEN (t.mode_acc NOT IN(SELECT mode_id FROM HHSurvey.automodes) AND
							t.mode_1 NOT IN(SELECT mode_id FROM HHSurvey.automodes) AND 
                           t.mode_2 NOT IN(SELECT mode_id FROM HHSurvey.automodes) AND
						   t.mode_3 NOT IN(SELECT mode_id FROM HHSurvey.automodes) AND
						   t.mode_4 NOT IN(SELECT mode_id FROM HHSurvey.automodes) AND 
						   t.mode_egr NOT IN(SELECT mode_id FROM HHSurvey.automodes)) THEN 0 ELSE t.driver END
FROM HHSurvey.Trip AS t;

SELECT is_transit FROM HHSurvey.Trip GROUP BY is_transit

ALTER TABLE HHSurvey.Trip ADD initial_tripid decimal(19,0) NULL;
GO
UPDATE HHSurvey.Trip SET initial_tripid=tripid;
GO
UPDATE HHSurvey.Trip SET tripid=CONCAT(person_id, FORMAT(tripnum, '000'));

WITH cte AS (SELECT t.person_id, t.day_id, min(t.tripnum) AS firsttrip, max(t.tripnum) AS lasttrip, count(*) AS tripcount FROM HHSurvey.Trip AS t GROUP BY t.person_id, t.day_id),
	startloco AS (SELECT t2.person_id, t2.day_id, t2.origin_purpose FROM HHSurvey.Trip AS t2 JOIN cte ON cte.person_id=t2.person_id AND cte.day_id=t2.day_id AND t2.tripnum=cte.firsttrip),
	endloco AS (SELECT t3.person_id, t3.day_id, t3.dest_purpose FROM HHSurvey.Trip AS t3 JOIN cte ON cte.person_id=t3.person_id AND cte.day_id=t3.day_id AND t3.tripnum=cte.lasttrip)
UPDATE d 
SET d.num_trips=COALESCE(cte.tripcount,0),
    d.loc_start=COALESCE(sl.origin_purpose, 995),
	d.loc_end=COALESCE(el.dest_purpose, 995),
	d.trips_yesno=CASE WHEN cte.tripcount > 0 THEN 1 ELSE 0 END
FROM HHSurvey.Day AS d LEFT JOIN cte ON cte.person_id=d.person_id AND cte.day_id=d.day_id
 LEFT JOIN startloco AS sl ON sl.person_id=d.person_id AND sl.day_id=d.day_id
 LEFT JOIN endloco AS el ON el.person_id=d.person_id AND el.day_id=d.day_id;

UPDATE d 
SET d.notravel_madetrips=0 
FROM HHSurvey.Day AS d WHERE d.trips_yesno=0 AND d.notravel_madetrips=1 AND d.day_iscomplete=1;

UPDATE d 
SET d.loc_start=CASE d.loc_start WHEN 1 THEN 1 WHEN 2 THEN 2 WHEN 10 THEN 2 WHEN 11 THEN 2 WHEN 14 THEN 2 WHEN 52 THEN 6 WHEN 150 THEN 6 WHEN 152 THEN 7 ELSE 3 END,
	d.loc_end=CASE d.loc_end WHEN 1 THEN 1 WHEN 2 THEN 2 WHEN 10 THEN 2 WHEN 11 THEN 2 WHEN 14 THEN 2 WHEN 52 THEN 6 WHEN 150 THEN 6 WHEN 152 THEN 7 ELSE 3 END
FROM HHSurvey.Day AS d WHERE d.loc_start<>995 AND d.loc_end<>995;

UPDATE d 
SET  d.loc_start=4
FROM HHSurvey.Day AS d JOIN HHSurvey.Trip AS t ON d.person_id=t.person_id AND d.day_id=t.day_id AND t.days_first_trip=1
WHERE NOT EXISTS (SELECT 1 FROM HHSurvey.Household AS h WHERE h.hhid=d.hhid AND t.origin_geog.STDistance(h.home_geog) <800) AND d.loc_start=1;

UPDATE d 
SET  d.loc_end=4
FROM HHSurvey.Day AS d JOIN HHSurvey.Trip AS t ON d.person_id=t.person_id AND d.day_id=t.day_id AND t.days_last_trip=1
WHERE NOT EXISTS (SELECT 1 FROM HHSurvey.Household AS h WHERE h.hhid=d.hhid AND t.dest_geog.STDistance(h.home_geog) <800) AND d.loc_end=1;

WITH cte AS (SELECT t.person_id, t.day_id, t_next.day_id AS nxt_day_id
			FROM HHSurvey.Trip AS t JOIN HHSurvey.Trip AS t_next ON t.person_id=t_next.person_id AND t.tripnum+1=t_next.tripnum
			WHERE DATEPART(DAY, DATEDIFF(HOUR, -3, t.depart_time_timestamp)) > DATEPART(DAY, DATEDIFF(HOUR, -3, t.arrival_time_timestamp))
			AND t.days_last_trip=1)
UPDATE d 
SET d.loc_end=5 
FROM HHSurvey.Day AS d JOIN cte ON cte.person_id=d.person_id AND cte.day_id=d.day_id;

WITH cte AS (SELECT t.person_id, t.day_id, t_next.day_id AS nxt_day_id
			FROM HHSurvey.Trip AS t JOIN HHSurvey.Trip AS t_next ON t.person_id=t_next.person_id AND t.tripnum+1=t_next.tripnum
			WHERE DATEPART(DAY, DATEDIFF(HOUR, -3, t.depart_time_timestamp)) > DATEPART(DAY, DATEDIFF(HOUR, -3, t.arrival_time_timestamp))
			AND t.days_last_trip=1)
UPDATE d 
SET d.loc_start=5 
FROM HHSurvey.Day AS d JOIN cte ON cte.person_id=d.person_id AND cte.nxt_day_id=d.day_id;


WITH cte AS (SELECT t.person_id, t.day_id, min(t.tripnum) AS firsttrip, max(t.tripnum) AS lasttrip, count(*) AS tripcount FROM HHSurvey.Trip AS t GROUP BY t.person_id, t.day_id),
	startloco AS (SELECT t2.person_id, t2.day_id, t2.recid FROM HHSurvey.Trip AS t2 JOIN cte ON cte.person_id=t2.person_id AND cte.day_id=t2.day_id AND t2.tripnum=cte.firsttrip),
	endloco AS (SELECT t3.person_id, t3.day_id, t3.recid FROM HHSurvey.Trip AS t3 JOIN cte ON cte.person_id=t3.person_id AND cte.day_id=t3.day_id AND t3.tripnum=cte.lasttrip)
UPDATE x 
SET x.days_first_trip=CASE WHEN sl.recid=x.recid THEN 1 ELSE 0 END, 
    x.days_last_trip=CASE WHEN el.recid=x.recid THEN 1 ELSE 0 END
FROM HHSurvey.Trip AS x
 LEFT JOIN startloco AS sl ON sl.person_id=x.person_id AND sl.day_id=x.day_id
 LEFT JOIN endloco AS el ON el.person_id=x.person_id AND el.day_id=x.day_id;





WITH cte AS (SELECT person_id, day_id FROM HouseholdTravelSurvey2023.combined_data.v_day WHERE loc_start=5)
SELECT t.person_id, t.day_id, t.depart_date, t.depart_time_hour, t.depart_time_minute, t.arrive_date, t.arrival_time_hour, t.arrival_time_minute, 
		nt.depart_date, nt.depart_time_hour, nt.depart_time_minute, nt.arrive_date, nt.arrival_time_hour, nt.arrival_time_minute
FROM HHSurvey.Trip AS t JOIN cte ON t.day_id=cte.day_id AND t.person_id=cte.person_id 
 JOIN HHSurvey.Trip AS nt ON t.person_id=nt.person_id AND t.tripnum-1=nt.tripnum
WHERE t.days_first_trip=1
ORDER BY t.person_id, t.day_id, t.tripnum;

WITH cte AS (SELECT person_id, day_id FROM HouseholdTravelSurvey2023.combined_data.v_day WHERE loc_end=5)
SELECT t.person_id, t.day_id, t.depart_date, t.depart_time_hour, t.depart_time_minute, t.arrive_date, t.arrival_time_hour, t.arrival_time_minute, 
		nt.depart_date, nt.depart_time_hour, nt.depart_time_minute, nt.arrive_date, nt.arrival_time_hour, nt.arrival_time_minute
FROM HHSurvey.Trip AS t JOIN cte ON t.day_id=cte.day_id AND t.person_id=cte.person_id 
 JOIN HHSurvey.Trip AS nt ON t.person_id=nt.person_id AND t.tripnum+1=nt.tripnum
WHERE t.days_last_trip=1
ORDER BY t.person_id, t.day_id, t.tripnum;

SELECT loc_start, count(*) FROM HouseholdTravelSurvey2023.combined_data.v_day GROUP BY loc_start ORDER BY loc_start
SELECT loc_end, count(*) FROM HouseholdTravelSurvey2023.combined_data.v_day GROUP BY loc_end ORDER BY loc_end

SELECT t.driver, count(*) FROM HHSurvey.Trip AS t 
WHERE t.travelers_total=1 AND t.travelers_hh=1 AND t.travelers_nonhh IN(0,995) AND t.is_transit = 0 AND t.driver=995 AND (t.mode_acc IN(SELECT mode_id FROM HHSurvey.automodes) OR
							t.mode_1 IN(SELECT mode_id FROM HHSurvey.automodes) OR 
                           t.mode_2 IN(SELECT mode_id FROM HHSurvey.automodes) OR
						   t.mode_3 IN(SELECT mode_id FROM HHSurvey.automodes) OR
						   t.mode_4 IN(SELECT mode_id FROM HHSurvey.automodes) OR 
						   t.mode_egr IN(SELECT mode_id FROM HHSurvey.automodes))
GROUP BY t.driver;

WITH cte AS (SELECT hhid, count(*) AS completedaycount FROM HHSurvey.Day WHERE pernum=1 AND day_iscomplete=1 GROUP BY hhid)
UPDATE h
SET h.numdayscomplete=cte.completedaycount
FROM HHSurvey.Household AS h JOIN cte ON h.hhid=cte.hhid;
GO

WITH cte AS (SELECT hhid, [1],[2],[3],[4],[5],[6],[7] FROM 
			(SELECT hhid, travel_dow, COALESCE(count(*),0) AS completedaycount FROM HHSurvey.Day WHERE pernum=1 AND day_iscomplete=1 GROUP BY hhid, travel_dow) AS s1
			PIVOT (max(s1.completedaycount) FOR travel_dow IN([1],[2],[3],[4],[5],[6],[7])) AS p1)
UPDATE h
SET	h.num_complete_mon = COALESCE(cte.[1],0),
	h.num_complete_tue = COALESCE(cte.[2],0),
	h.num_complete_wed = COALESCE(cte.[3],0),
	h.num_complete_thu = COALESCE(cte.[4],0),
	h.num_complete_fri = COALESCE(cte.[5],0),
	h.num_complete_sat = COALESCE(cte.[6],0),
	h.num_complete_sun = COALESCE(cte.[7],0)
FROM HHSurvey.Household AS h JOIN cte ON h.hhid=cte.hhid;

UPDATE HHSurvey.Trip SET travelers_total=5 WHERE travelers_total>5;
UPDATE HHSurvey.Trip SET travelers_nonhh=995 WHERE travelers_nonhh=-995;
/*
DELETE h FROM HHSurvey.Household AS h WHERE h.hh_iscomplete_b=0;
GO
DELETE p FROM HHSurvey.Person AS p WHERE NOT EXISTS (SELECT 1 FROM HHSurvey.Household AS h WHERE h.hhid=p.hhid);
GO
DELETE d FROM HHSurvey.Day AS d WHERE NOT EXISTS (SELECT 1 FROM HHSurvey.Household AS h WHERE h.hhid=d.hhid);
GO
DELETE t FROM HHSurvey.Trip AS t WHERE NOT EXISTS (SELECT 1 FROM HHSurvey.Household AS h WHERE h.hhid=t.hhid);
GO
DELETE v FROM HHSurvey.Vehicle AS v WHERE NOT EXISTS (SELECT 1 FROM HHSurvey.Household AS h WHERE h.hhid=v.hhid);
GO*/

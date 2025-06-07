SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
	CREATE PROCEDURE [HHSurvey].[silent_passenger_trips_inserted] @respondent int=0  
	AS BEGIN
	WITH cte AS 
		(SELECT -- select fields necessary for new trip records	
			t.hhid, spt.passengerid AS person_id, CAST(RIGHT(spt.passengerid,2) AS int) AS pernum,
			t.depart_time_timestamp, t.arrival_time_timestamp,
			t.dest_label, t.dest_lat, t.dest_lng,
			t.distance_miles, t.travel_time,
			t.hhmember1, t.hhmember2, t.hhmember3, t.hhmember4, t.hhmember5, t.hhmember6, t.hhmember7, t.hhmember8, t.hhmember9, t.travelers_hh, t.travelers_nonhh, t.travelers_total,
			t.mode_acc, t.mode_egr, t.mode_1,
			t.origin_geog, t.origin_lat, t.origin_lng, t.dest_geog, t.dest_county, t.dest_city, t.dest_zip, t.dest_is_home, t.dest_is_work, 1 AS psrc_inserted, CONCAT(t.revision_code, '9,') AS revision_code
		FROM HHSurvey.silent_passenger_trip AS spt -- insert only when the CTE trip doesn't overlap any trip by the same person; doesn't matter if an intersecting trip reports the other hhmembers or not.
			JOIN HHSurvey.Trip as t ON spt.recid = t.recid
		WHERE spt.respondent = @respondent
		)
   INSERT INTO HHSurvey.Trip
		(hhid, person_id, pernum, 
		depart_time_timestamp, arrival_time_timestamp,
		dest_label, dest_lat, dest_lng,
		distance_miles, travel_time,
		hhmember1, hhmember2, hhmember3, hhmember4, hhmember5, hhmember6, hhmember7, hhmember8, hhmember9, travelers_hh, travelers_nonhh, travelers_total,
		mode_acc, mode_egr, mode_1,
		origin_geog, origin_lat, origin_lng, dest_geog, dest_county, dest_city, dest_zip, dest_is_home, dest_is_work, psrc_inserted, revision_code)
	SELECT * FROM cte 
	WHERE NOT EXISTS (SELECT 1 FROM HHSurvey.Trip AS t WHERE cte.person_id = t.person_id
			                AND ((cte.depart_time_timestamp BETWEEN t.depart_time_timestamp AND t.arrival_time_timestamp)
				            OR (cte.arrival_time_timestamp BETWEEN t.depart_time_timestamp AND t.arrival_time_timestamp)));	
	END
GO

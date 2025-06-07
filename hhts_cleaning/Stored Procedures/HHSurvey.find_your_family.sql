SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
		CREATE PROCEDURE [HHSurvey].[find_your_family] 
			@target_recid numeric NULL --provide recid of reference member

		AS BEGIN
		SET NOCOUNT OFF;
		WITH cte_ref AS
				(SELECT t0.hhid, t0.depart_time_timestamp, t0.arrival_time_timestamp, t0.pernum, t0.driver
					FROM HHSurvey.Trip AS t0 
					WHERE t0.recid = @target_recid),
			cte_mobile AS(
				SELECT 	t3.hhid, t3.pernum, ac1.agedesc,
						'enroute' AS member_status, 
						CONCAT(CAST(t3.origin_lat AS NVARCHAR(20)),', ',CAST(t3.origin_lng AS NVARCHAR(20))) AS prior_location,
						CONCAT(CAST(t3.dest_lat AS NVARCHAR(20)),', ',CAST(t3.dest_lng AS NVARCHAR(20))) AS next_destination, 
						CONCAT((CASE WHEN t3.pernum = cte_ref.pernum THEN 'reference person - ' ELSE '' END),
							CASE WHEN t3.driver = 1 THEN 'driver' 	
								WHEN EXISTS (SELECT 1 FROM HHSurvey.AutoModes AS am WHERE t3.mode_1 = am.mode_id) THEN 'passenger' 
								WHEN EXISTS (SELECT 1 FROM HHSurvey.TransitModes AS tm WHERE t3.mode_1 = tm.mode_id) THEN 'transit rider'
								WHEN t3.mode_1 = 1 THEN 'pedestrian'
								ELSE 'other' END) AS rider_status
					FROM HHSurvey.Trip AS t3
					JOIN cte_ref ON t3.hhid = cte_ref.hhid
					JOIN HHSurvey.Person AS p1 ON t3.person_id = p1.person_id LEFT JOIN HHSurvey.AgeCategories AS ac1 ON ac1.AgeCode = p1.age
					WHERE ((cte_ref.depart_time_timestamp BETWEEN t3.depart_time_timestamp AND t3.arrival_time_timestamp) 
							OR (cte_ref.arrival_time_timestamp BETWEEN t3.depart_time_timestamp AND t3.arrival_time_timestamp))),
			cte_static AS
				(SELECT t1.hhid, t1.pernum, ac2.agedesc,
						'at rest' AS member_status, 
						CONCAT(CAST(t1.dest_lat AS NVARCHAR(20)),', ',CAST(t1.dest_lng AS NVARCHAR(20))) AS prior_location,
						CONCAT(CAST(t2.dest_lat AS NVARCHAR(20)),', ',CAST(t2.dest_lng AS NVARCHAR(20))) AS next_destination,
						'n/a' AS rider_status
					FROM HHSurvey.Trip AS t1
					LEFT JOIN HHsurvey.Trip AS t2 ON t1.person_id = t2.person_id AND t1.tripnum + 1 = t2.tripnum
					JOIN cte_ref ON t1.hhid = cte_ref.hhid AND NOT EXISTS (SELECT 1 FROM cte_mobile WHERE cte_mobile.pernum = t1.pernum)
					JOIN HHSurvey.Person AS p2 ON t2.person_id = p2.person_id LEFT JOIN HHSurvey.AgeCategories AS ac2 ON ac2.AgeCode = p2.age
					WHERE (cte_ref.depart_time_timestamp > t1.arrival_time_timestamp AND cte_ref.arrival_time_timestamp < t2.depart_time_timestamp)
						OR (cte_ref.depart_time_timestamp > t1.arrival_time_timestamp AND t2.depart_time_timestamp IS NULL)
			)
		SELECT * FROM cte_mobile UNION SELECT * FROM cte_static
		ORDER BY pernum;
		END
GO

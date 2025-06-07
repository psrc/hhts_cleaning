SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
			CREATE PROCEDURE [HHSurvey].[split_trip_from_traces]
				@target_recid int = NULL
			AS BEGIN
			SET NOCOUNT ON; 
			DROP TABLE IF EXISTS #tmpSplit;

			WITH cte AS
			(SELECT t.recid, t.tripid, t.personid, t.origin_geog, t.dest_geog, t.depart_time_timestamp, t.arrival_time_timestamp, t.trip_path_distance
				FROM HHSurvey.Trip AS t WHERE t.recid = @target_recid AND t.hhgroup = 1)
			SELECT TOP 1 cte.*, c.lat, c.lng, c.point_geog, c.traceid, c.collected_at AS midpoint_arrival_timestamp, cnxt.collected_at AS midpoint_depart_timestamp,
				c.point_geog.STDistance(cte.origin_geog)/1609.344 AS cfmiles2start, c.point_geog.STDistance(cte.dest_geog)/1609.344 AS cfmiles2end,
				cte.trip_path_distance * (c.point_geog.STDistance(cte.origin_geog) / (c.point_geog.STDistance(cte.origin_geog) + c.point_geog.STDistance(cte.dest_geog))) AS to_midpoint_distance_approx,
				cte.trip_path_distance * (1- c.point_geog.STDistance(cte.origin_geog) / (c.point_geog.STDistance(cte.origin_geog) + c.point_geog.STDistance(cte.dest_geog))) AS from_midpoint_distance_approx
			INTO #tmpSplit
			FROM HHSurvey.Trace AS c 
				JOIN cte ON c.tripid = cte.tripid 
				JOIN HHSurvey.Trace AS cnxt ON c.traceid + 1 = cnxt.traceid AND c.tripid = cnxt.tripid
				WHERE DATEDIFF(Minute, c.collected_at, cnxt.collected_at) > 14 AND c.collected_at > cte.depart_time_timestamp AND c.collected_at < cte.arrival_time_timestamp AND cte.dest_geog.STDistance(cte.origin_geog) > 0
				ORDER BY DATEDIFF(Second, c.collected_at, cnxt.collected_at) DESC;

			IF (SELECT cfmiles2start FROM #tmpSplit) < 0.1
				BEGIN
				UPDATE t 
				SET t.depart_time_timestamp = DATEADD(Minute, -3, x.midpoint_depart_timestamp),  --(3 min adjustment to counteract the standard trace lag)
					t.revision_code = CONCAT(t.revision_code, '14,'),
					t.psrc_comment = NULL
				FROM HHSurvey.Trip AS t JOIN #tmpSplit AS x ON t.recid = x.recid;
				END

			ELSE IF (SELECT cfmiles2end FROM #tmpSplit) < 0.1
				BEGIN
				UPDATE t 
				SET t.arrival_time_timestamp = x.midpoint_arrival_timestamp,
					t.revision_code = CONCAT(t.revision_code, '14,'),
					t.psrc_comment = NULL
				FROM HHSurvey.Trip AS t JOIN #tmpSplit AS x ON t.recid = x.recid;
				END

			ELSE IF ((SELECT cfmiles2start FROM #tmpSplit) > 0.1 AND (SELECT cfmiles2end FROM #tmpSplit) > 0.1)
				BEGIN
				INSERT INTO HHSurvey.Trip (hhid, personid, pernum, hhgroup, travelers_hh, travelers_nonhh, travelers_total, modes, mode_1, 
					hhmember1, hhmember2, hhmember3, hhmember4, hhmember5, hhmember6, hhmember7, hhmember8, hhmember9, 
					dest_purpose,depart_time_timestamp, 
					arrival_time_timestamp, 
					trip_path_distance,
					origin_lat, origin_lng, origin_geog, 
					dest_lat, dest_lng, dest_geog, dest_is_home, dest_is_work,
					revision_code, psrc_inserted)			
				SELECT  t.hhid, t.personid, t.pernum, t.hhgroup, t.travelers_hh, t.travelers_nonhh, t.travelers_total, t.modes, t.mode_1,
						t.hhmember1, t.hhmember2, t.hhmember3, t.hhmember4, t.hhmember5, t.hhmember6, t.hhmember7, t.hhmember8, t.hhmember9, 
					t.dest_purpose, DATEADD(Minute, -3, x.midpoint_depart_timestamp) AS depart_time_timestamp, 
					t.arrival_time_timestamp, 
					x.from_midpoint_distance_approx AS trip_path_distance,
					x.lat AS origin_lat, x.lng AS origin_lng, x.point_geog AS origin_geog, 
					t.dest_lat, t.dest_lng, t.dest_geog, t.dest_is_home, t.dest_is_work,
					14 AS revision_code, 1 AS psrc_inserted
					FROM HHSurvey.Trip AS t JOIN #tmpSplit AS x ON t.recid = x.recid
				
				UPDATE t 
				SET t.arrival_time_timestamp = x.midpoint_arrival_timestamp,
					t.dest_lat = x.lat,
					t.dest_lng = x.lng,
					t.dest_geog = x.point_geog,
					t.trip_path_distance = x.to_midpoint_distance_approx,
					t.dest_purpose = 97,
					t.revision_code = CONCAT(t.revision_code, '15,'),
					t.psrc_comment = NULL,
					t.dest_is_home = NULL,
					t.dest_is_work = NULL
				FROM HHSurvey.Trip AS t JOIN #tmpSplit AS x ON t.recid = x.recid;
				END

			DECLARE @split_personid decimal (19,0) = (SELECT x.personid FROM #tmpSplit AS x)
			DROP TABLE #tmpSplit;
			EXECUTE HHSurvey.recalculate_after_edit @split_personid;
			EXECUTE HHSurvey.generate_error_flags @split_personid;

			END
	
	--ADD TRIP, details optional
		/*	Generates a blank trip, or populates a trip with the information from another trip */

		DROP PROCEDURE IF EXISTS HHSurvey.insert_new_trip;
GO

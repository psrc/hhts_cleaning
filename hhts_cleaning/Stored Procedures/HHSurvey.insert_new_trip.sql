SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
		CREATE PROCEDURE [HHSurvey].[insert_new_trip]
			@target_person_id decimal = NULL, @target_recid int = NULL
		AS BEGIN
		IF @target_recid IS NOT NULL 
			BEGIN
			INSERT INTO HHSurvey.Trip (hhid, person_id, pernum, psrc_inserted, tripnum,
				dest_lat, dest_lng, dest_label, origin_lat, origin_lng, depart_time_timestamp, arrival_time_timestamp, /*travel_time,*/ distance_miles,
				dest_purpose, dest_purpose_cat, modes, mode_acc, mode_1, /*mode_2, mode_3, mode_4, */mode_egr, travelers_hh, travelers_nonhh, travelers_total)
			SELECT p.hhid, p.person_id, p.pernum, 1, 0,
				t.dest_lat, t.dest_lng, t.dest_label, t.origin_lat, t.origin_lng, t.depart_time_timestamp, t.arrival_time_timestamp, /*t.travel_time,*/ t.distance_miles,
				t.dest_purpose, t.dest_purpose_cat, t.modes, t.mode_acc, t.mode_1, /*mode_2, mode_3, mode_4, */t.mode_egr, t.travelers_hh, t.travelers_nonhh, t.travelers_total
			FROM HHSurvey.Person AS p CROSS JOIN HHSurvey.Trip AS t WHERE p.person_id = @target_person_id AND t.recid = @target_recid;
			END
		ELSE
			BEGIN
			INSERT INTO HHSurvey.Trip (hhid, person_id, pernum, psrc_inserted)
			SELECT p.hhid, p.person_id, p.pernum, 1
			FROM HHSurvey.Person AS p WHERE p.person_id = @target_person_id;
			END

		EXECUTE HHSurvey.recalculate_after_edit @target_person_id;
		EXECUTE HHSurvey.generate_error_flags @target_person_id;
		END

	--ADD REVERSE TRIP

		DROP PROCEDURE IF EXISTS HHSurvey.insert_reverse_trip;
GO

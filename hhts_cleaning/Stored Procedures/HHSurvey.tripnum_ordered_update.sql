SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
		CREATE PROCEDURE [HHSurvey].[tripnum_ordered_update] 
			@target_person_id decimal = NULL --optional parameter
		AS
		BEGIN
		WITH tripnum_ordered_rev(recid, person_id, tripnum_ordered) AS
			(SELECT t0.recid, t0.person_id, ROW_NUMBER() OVER(PARTITION BY t0.person_id ORDER BY t0.arrival_time_timestamp ASC, t0.depart_time_timestamp ASC) AS tripnum_ordered 
			 	FROM HHSurvey.Trip AS t0 
				WHERE t0.person_id = CASE WHEN @target_person_id IS NULL THEN t0.person_id ELSE @target_person_id END)
		UPDATE t
			SET t.tripnum_ordered = tripnum_ordered_rev.tripnum_ordered
			FROM HHSurvey.Trip AS t JOIN tripnum_ordered_rev ON t.recid=tripnum_ordered_rev.recid AND t.person_id = tripnum_ordered_rev.person_id
			WHERE t.tripnum_ordered <> tripnum_ordered_rev.tripnum_ordered OR t.tripnum_ordered IS NULL;
		END
GO

SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
    CREATE PROCEDURE [HHSurvey].[tripnum_update] @target_person_id decimal = NULL --optional parameter
    AS BEGIN
    WITH tripnum_rev(recid, person_id, tripnum) AS
        (SELECT t0.recid, t0.person_id, ROW_NUMBER() OVER(PARTITION BY t0.person_id ORDER BY t0.depart_time_timestamp ASC, 
        t0.arrival_time_timestamp ASC) AS tripnum 
            FROM HHSurvey.Trip AS t0 
            WHERE t0.person_id = CASE WHEN @target_person_id IS NULL THEN t0.person_id ELSE @target_person_id END)
    UPDATE t
        SET t.tripnum = tripnum_rev.tripnum
        FROM HHSurvey.Trip AS t JOIN tripnum_rev ON t.recid=tripnum_rev.recid AND t.person_id = tripnum_rev.person_id
        WHERE t.tripnum <> tripnum_rev.tripnum OR t.tripnum IS NULL;
    END
GO

SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [HHSurvey].[trip_removals]
AS BEGIN

--This creates a table with the same structure as the Trip table
    BEGIN TRANSACTION;
	DROP TABLE IF EXISTS HHSurvey.removed_trip;
	COMMIT TRANSACTION;

    BEGIN TRANSACTION;
	SELECT TOP 0 t1.* INTO HHSurvey.removed_trip
	FROM HHSurvey.Trip AS t1
  	UNION ALL 
  	SELECT top 0 t2.* 
  	FROM HHSurvey.Trip AS t2
	COMMIT TRANSACTION;
	TRUNCATE TABLE HHSurvey.removed_trip;

	BEGIN TRANSACTION;
	WITH cte AS (
		SELECT t.recid 
		FROM HHSurvey.Trip AS t 
		JOIN 		HHSurvey.Trip AS prior_t ON t.person_id = prior_t.person_id AND t.tripnum - 1 = prior_t.tripnum AND t.daynum = prior_t.daynum
		LEFT JOIN 	HHSurvey.Trip AS next_t  ON t.person_id = next_t.person_id  AND t.tripnum + 1 = next_t.tripnum  AND t.daynum = next_t.daynum
		WHERE t.origin_purpose = 1 AND t.dest_purpose = 1 AND next_t.recid IS NULL AND ABS(t.dest_geog.STDistance(t.origin_geog)) < 100 ) -- points within 100m of one another
	DELETE FROM HHSurvey.Trip OUTPUT deleted.* INTO HHSurvey.removed_trip
		WHERE EXISTS (SELECT 1 FROM cte WHERE Trip.recid = cte.recid);
	COMMIT TRANSACTION;

END
GO

SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [HHSurvey].[trip_removals]
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
		WHERE t.distance_miles = 0 AND (t.revision_code IS NULL OR t.revision_code NOT LIKE '%8,%'))
	DELETE FROM HHSurvey.Trip OUTPUT deleted.* INTO HHSurvey.removed_trip
		WHERE EXISTS (SELECT 1 FROM cte WHERE Trip.recid = cte.recid);
	COMMIT TRANSACTION;

END
GO

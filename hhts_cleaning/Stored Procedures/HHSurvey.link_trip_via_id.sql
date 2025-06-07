SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
			CREATE PROCEDURE [HHSurvey].[link_trip_via_id]
				@recid_list nvarchar(255) NULL --Parameter necessary to have passed: comma-separated recids to be linked (not limited to two)
			AS BEGIN
			SET NOCOUNT ON; 
			SELECT CAST(Elmer.dbo.TRIM(value) AS int) AS recid INTO #recid_list 
				FROM STRING_SPLIT(@recid_list, ',')
				WHERE RTRIM(value) <> '';
			
			WITH cte AS (SELECT TOP 1 tripnum AS trip_link FROM HHSurvey.trip AS t JOIN #recid_list AS rid ON rid.recid = t.recid ORDER BY t.depart_time_timestamp)
			SELECT t.*, cte.trip_link INTO HHSurvey.trip_ingredient
				FROM HHSurvey.trip AS t JOIN cte ON 1 = 1
				WHERE EXISTS (SELECT 1 FROM #recid_list AS rid WHERE rid.recid = t.recid);
			
			DECLARE @person_id decimal(19,0) = NULL
			SET @person_id = (SELECT person_id FROM HHSurvey.trip_ingredient GROUP BY person_id);

			EXECUTE HHSurvey.link_trips;
			EXECUTE HHSurvey.tripnum_update @person_id;
			EXECUTE HHSurvey.generate_error_flags @person_id;
			DROP TABLE IF EXISTS #recid_list;
			DROP TABLE IF EXISTS HHSurvey.trip_ingredient;
			SET @person_id = NULL
			SET @recid_list = NULL
			END
GO

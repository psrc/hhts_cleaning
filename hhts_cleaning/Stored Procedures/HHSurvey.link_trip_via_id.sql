SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [HHSurvey].[link_trip_via_id]
	@recid_list nvarchar(255) NULL --Parameter necessary to have passed: comma-separated recids to be linked (not limited to two)
AS BEGIN
	SET NOCOUNT ON; 
	
	DECLARE @started_transaction BIT = 0;
	IF @@TRANCOUNT = 0
	BEGIN
		BEGIN TRANSACTION;
		SET @started_transaction = 1;
	END
	
	BEGIN TRY
		-- Declare TVP variable for trip ingredients
		DECLARE @trip_ingredients_param HHSurvey.TripIngredientType;

		-- insert recid's into #recid_list
		SELECT CAST(Elmer.dbo.TRIM(value) AS int) AS recid INTO #recid_list 
			FROM STRING_SPLIT(@recid_list, ',')
			WHERE RTRIM(value) <> '';
		
		-- find the earliest trip segment and insert it into TVP parameter
		WITH cte AS (SELECT TOP 1 tripnum AS trip_link FROM HHSurvey.trip AS t JOIN #recid_list AS rid ON rid.recid = t.recid ORDER BY t.depart_time_timestamp)
		INSERT INTO @trip_ingredients_param
			SELECT t.*, cte.trip_link
			FROM HHSurvey.trip AS t JOIN cte ON 1 = 1
			WHERE EXISTS (SELECT 1 FROM #recid_list AS rid WHERE rid.recid = t.recid);
		
		-- Set @person_id to the person in trip_ingredient with validation
		DECLARE @person_id decimal(19,0) = NULL;
		DECLARE @person_count int;
		SELECT @person_count = COUNT(DISTINCT person_id) FROM @trip_ingredients_param;
		
		IF @person_count > 1
			THROW 50002, 'Trip ingredients span multiple people. All recids must belong to the same person.', 1;
		IF @person_count = 0
			THROW 50003, 'No valid trip ingredients found for provided recids.', 1;
			
		SET @person_id = (SELECT TOP 1 person_id FROM @trip_ingredients_param);

		EXECUTE HHSurvey.link_trips @trip_ingredients = @trip_ingredients_param;
		EXECUTE HHSurvey.tripnum_update @person_id;
		EXECUTE HHSurvey.generate_error_flags @person_id;
		DROP TABLE IF EXISTS #recid_list;
		SET @person_id = NULL
		SET @recid_list = NULL
		
		IF @started_transaction = 1
			COMMIT;
			
	END TRY
	BEGIN CATCH
		-- Cleanup on error
		DROP TABLE IF EXISTS #recid_list;
		
		-- Transaction rollback
		IF @started_transaction = 1 AND @@TRANCOUNT > 0 AND XACT_STATE() <> 0
			ROLLBACK;
			
		THROW;
	END CATCH
END
GO

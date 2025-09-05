SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [HHSurvey].[link_trip_via_id]
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
		INSERT INTO @trip_ingredients_param (
			recid, hhid, person_id, pernum, tripid, tripnum, traveldate, daynum, 
			depart_time_timestamp, arrival_time_timestamp, origin_lat, origin_lng, 
			dest_lat, dest_lng, distance_miles, travel_time, hhmember1, hhmember2, 
			hhmember3, hhmember4, hhmember5, hhmember6, hhmember7, hhmember8, 
			hhmember9, hhmember10, hhmember11, hhmember12, hhmember13, travelers_hh, 
			travelers_nonhh, travelers_total, origin_purpose, dest_purpose, 
			dest_purpose_other, mode_1, mode_2, mode_3, mode_4, driver, mode_acc, 
			mode_egr, speed_mph, mode_other_specify, origin_geog, dest_geog, 
			dest_is_home, dest_is_work, modes, psrc_inserted, revision_code, 
			psrc_resolved, psrc_comment, trip_link
		)
		SELECT t.recid, t.hhid, t.person_id, t.pernum, t.tripid, t.tripnum, t.traveldate, t.daynum, 
			t.depart_time_timestamp, t.arrival_time_timestamp, t.origin_lat, t.origin_lng, 
			t.dest_lat, t.dest_lng, t.distance_miles, t.travel_time, t.hhmember1, t.hhmember2, 
			t.hhmember3, t.hhmember4, t.hhmember5, t.hhmember6, t.hhmember7, t.hhmember8, 
			t.hhmember9, t.hhmember10, t.hhmember11, t.hhmember12, t.hhmember13, t.travelers_hh, 
			t.travelers_nonhh, t.travelers_total, t.origin_purpose, t.dest_purpose, 
			t.dest_purpose_other, t.mode_1, t.mode_2, t.mode_3, t.mode_4, t.driver, t.mode_acc, 
			t.mode_egr, t.speed_mph, t.mode_other_specify, t.origin_geog, t.dest_geog, 
			t.dest_is_home, t.dest_is_work, t.modes, t.psrc_inserted, t.revision_code, 
			t.psrc_resolved, t.psrc_comment, cte.trip_link
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

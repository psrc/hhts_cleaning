SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
			CREATE PROCEDURE [HHSurvey].[unlink_via_id]
				@ref_recid int = NULL
			AS BEGIN

				BEGIN TRANSACTION;
				BEGIN TRY

					DECLARE @ref_person_id decimal(19,0) = NULL,
							@ref_starttime DATETIME2 = NULL,
							@ref_endtime DATETIME2 = NULL,
							@ref_triplink int = NULL
					SET NOCOUNT OFF;

					SET @ref_person_id = (SELECT t.person_id FROM HHSurvey.Trip AS t WHERE t.recid = @ref_recid);
					SET @ref_starttime = (SELECT t.depart_time_timestamp FROM HHSurvey.Trip AS t WHERE t.recid = @ref_recid);
					SET @ref_endtime = (SELECT t.arrival_time_timestamp FROM HHSurvey.Trip AS t WHERE t.recid = @ref_recid);

					WITH cte AS (SELECT tid.person_id, tid.trip_link, min(tid.depart_time_timestamp) AS start_time, max(tid.arrival_time_timestamp) AS end_time 
								FROM HHSurvey.trip_ingredients_done AS tid WHERE tid.person_id = @ref_person_id  GROUP BY tid.person_id, tid.trip_link)
					SELECT cte.trip_link INTO #FoundTripLink
						FROM cte JOIN HHSurvey.Trip AS t ON cte.start_time = t.depart_time_timestamp 
							AND cte.end_time = t.arrival_time_timestamp 
							AND cte.person_id = t.person_id 
							AND t.recid = @ref_recid
						GROUP BY cte.trip_link;

					SET @ref_triplink = (SELECT trip_link FROM #FoundTripLink)

					IF (@ref_triplink > 0 )
						BEGIN

						DELETE FROM HHSurvey.Trip WHERE recid = @ref_recid;
						-- ALTER TABLE HHSurvey.trip DISABLE TRIGGER tr_trip;

						SET IDENTITY_INSERT HHSurvey.Trip ON;
						INSERT INTO HHSurvey.Trip (
							[recid]
							,[hhid]
							,[person_id]
							,[pernum]
							,[tripid]
							,[tripnum]
							,[traveldate]
							,[daynum]
							--,[copied_trip]
							-- ,[svy_complete]
							,[depart_time_timestamp]
							,[arrival_time_timestamp]
							,[origin_lat]
							,[origin_lng]
							-- ,[origin_label]
							,[dest_lat]
							,[dest_lng]
							-- ,[dest_label]
							,[distance_miles]
							,[travel_time]
							,[hhmember1]
							,[hhmember2]
							,[hhmember3]
							,[hhmember4]
							,[hhmember5]
							,[hhmember6]
							,[hhmember7]
							,[hhmember8]
							,[hhmember9]
							,[travelers_hh]
							,[travelers_nonhh]
							,[travelers_total]
							,[origin_purpose]
							-- ,origin_purpose_cat
							,[dest_purpose]
							,[dest_purpose_other]
							-- ,dest_purpose_cat			
							,[mode_1]
							,[mode_2]
							,[mode_3]
							,[mode_4]
							-- ,mode_type			
							,[driver]
							-- ,[change_vehicles]
							-- ,[is_access]
							-- ,[is_egress]
							-- ,[has_access]
							-- ,[has_egress]			
							,[mode_acc]
							,[mode_egr]			
							,[speed_mph]
							-- ,[trace_quality_flag]
							-- ,[user_added]
							-- ,[user_merged]
							-- ,[user_split]
							-- ,[analyst_merged]
							-- ,[analyst_split]
							-- ,[analyst_split_loop]
							,[day_id]
							-- ,[travel_day]
							-- ,[travel_date] 
							-- ,[travel_dow] 
							-- ,[day_iscomplete]
							-- ,[depart_date] 
							-- ,[depart_dow]
							-- ,[depart_time_hour]
							-- ,[depart_time_minute]
							-- ,[depart_time_second]
							-- ,[arrive_date]
							-- ,[arrive_dow]
							-- ,[arrival_time_hour]
							-- ,[arrival_time_minute]
							-- ,[arrival_time_second]
							-- ,[o_in_region]
							-- ,[o_puma10]
							-- ,[o_bg]
							-- ,[d_in_region]
							-- ,[d_puma10]
							-- ,[d_bg]
							-- ,[distance_meters]
							-- ,[duration_minutes]
							-- ,[duration_seconds]
							-- ,[speed_flag]
							-- ,[dwell_mins]
							-- ,[days_first_trip] 
							-- ,[days_last_trip]
							,[mode_other_specify]
							-- ,[is_transit]
							,[hhmember10]
							,[hhmember11]
							,[hhmember12]
							,[hhmember13]
							-- ,[taxi_cost_known]
							-- ,[taxi_cost_int]
							-- ,[flag_teleport]
							-- ,[pt_density]
							-- ,[point_dist_index]
							-- ,[trip_weight]
							-- ,[survey_year] 
							-- ,[day_is_complete_a]
							-- ,[day_is_complete_b]
							-- ,[hh_day_iscomplete]
							-- ,[hh_day_iscomplete_a]
							-- ,[hh_day_iscomplete_b]
							,dest_is_home
							,dest_is_work
							,modes
							,psrc_inserted
							,revision_code)
						SELECT recid
							,[hhid]
							,[person_id]
							,[pernum]
							,[tripid]
							,[tripnum]
							,[traveldate]
							,[daynum]
							-- ,[copied_trip]
							-- ,[svy_complete]
							,[depart_time_timestamp]
							,[arrival_time_timestamp]
							,[origin_lat]
							,[origin_lng]
							-- ,[origin_label]
							,[dest_lat]
							,[dest_lng]
							-- ,[dest_label]
							,[distance_miles]
							,[travel_time]
							,[hhmember1]
							,[hhmember2]
							,[hhmember3]
							,[hhmember4]
							,[hhmember5]
							,[hhmember6]
							,[hhmember7]
							,[hhmember8]
							,[hhmember9]
							,[travelers_hh]
							,[travelers_nonhh]
							,[travelers_total]
							,[origin_purpose]
							-- ,origin_purpose_cat
							,[dest_purpose]
							,[dest_purpose_other]
							-- ,dest_purpose_cat			
							,[mode_1]
							,[mode_2]
							,[mode_3]
							,[mode_4]
							-- ,mode_type			
							,[driver]
							-- ,[change_vehicles]
							-- ,[is_access]
							-- ,[is_egress]
							-- ,[has_access]
							-- ,[has_egress]			
							,[mode_acc]
							,[mode_egr]			
							,[speed_mph]
							-- ,[trace_quality_flag]
							-- ,[user_added]
							-- ,[user_merged]
							-- ,[user_split]
							-- ,[analyst_merged]
							-- ,[analyst_split]
							-- ,[analyst_split_loop]
							,[day_id]
							-- ,[travel_day]
							-- ,[travel_date] 
							-- ,[travel_dow] 
							-- ,[day_iscomplete]
							-- ,[depart_date] 
							-- ,[depart_dow]
							-- ,[depart_time_hour]
							-- ,[depart_time_minute]
							-- ,[depart_time_second]
							-- ,[arrive_date]
							-- ,[arrive_dow]
							-- ,[arrival_time_hour]
							-- ,[arrival_time_minute]
							-- ,[arrival_time_second]
							-- ,[o_in_region]
							-- ,[o_puma10]
							-- ,[o_bg]
							-- ,[d_in_region]
							-- ,[d_puma10]
							-- ,[d_bg]
							-- ,[distance_meters]
							-- ,[duration_minutes]
							-- ,[duration_seconds]
							-- ,[speed_flag]
							-- ,[dwell_mins]
							-- ,[days_first_trip] 
							-- ,[days_last_trip]
							,[mode_other_specify]
							-- ,[is_transit]
							,[hhmember10]
							,[hhmember11]
							,[hhmember12]
							,[hhmember13]
							-- ,[taxi_cost_known]
							-- ,[taxi_cost_int]
							-- ,[flag_teleport]
							-- ,[pt_density]
							-- ,[point_dist_index]
							-- ,[trip_weight]
							-- ,[survey_year] 
							-- ,[day_is_complete_a]
							-- ,[day_is_complete_b]
							-- ,[hh_day_iscomplete]
							-- ,[hh_day_iscomplete_a]
							-- ,[hh_day_iscomplete_b]
							,dest_is_home
							,dest_is_work
							,modes
							,psrc_inserted
							,revision_code
							FROM HHSurvey.trip_ingredients_done AS tid 
							WHERE tid.person_id = @ref_person_id AND tid.trip_link = @ref_triplink;

						DELETE tid
						FROM HHSurvey.trip_ingredients_done AS tid 
						WHERE tid.person_id = @ref_person_id AND tid.trip_link = @ref_triplink;

						EXECUTE HHSurvey.recalculate_after_edit @ref_person_id;
						EXECUTE HHSurvey.generate_error_flags @ref_person_id;
					END
						
					DROP TABLE IF EXISTS #FoundTripLink;

					-- ALTER TABLE HHSurvey.trip ENABLE TRIGGER [tr_trip];
					SET IDENTITY_INSERT HHSurvey.Trip OFF;

					COMMIT TRANSACTION
				END TRY

				BEGIN CATCH
					DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
					DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
					DECLARE @ErrorState INT = ERROR_STATE();
					DECLARE @ErrorNumber INT = ERROR_NUMBER();
					
					-- Always ensure cleanup happens
					BEGIN TRY
						IF OBJECT_ID('tempdb..#FoundTripLink') IS NOT NULL
							DROP TABLE #FoundTripLink;
					END TRY
					BEGIN CATCH
						-- Ignore cleanup errors
					END CATCH
					
					-- Always turn off IDENTITY_INSERT and re-enable trigger
					BEGIN TRY
						SET IDENTITY_INSERT HHSurvey.Trip OFF;
					END TRY
					BEGIN CATCH
						-- Ignore if already off
					END CATCH
					
					-- Handle transaction rollback safely
					IF @@TRANCOUNT > 0
					BEGIN
						IF XACT_STATE() = -1  -- Uncommittable transaction
							ROLLBACK TRANSACTION;
						ELSE IF XACT_STATE() = 1  -- Committable transaction
							ROLLBACK TRANSACTION;
						-- If XACT_STATE() = 0, no active transaction
					END
					
					-- Re-throw with original error info
					RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
				END CATCH   
			
			END 
GO

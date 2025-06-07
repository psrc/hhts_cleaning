SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
	CREATE PROCEDURE [HHSurvey].[insert_reverse_trip]
			@target_recid int, @starttime nvarchar(5)
		AS BEGIN
		IF @target_recid IS NOT NULL 
			BEGIN

			DECLARE @target_person_id decimal(19,0) = NULL;
			SET @target_person_id = (SELECT x.person_id FROM HHSurvey.Trip AS x WHERE x.recid=@target_recid);

			WITH cte AS (SELECT DATETIME2FROMPARTS(YEAR(t0.arrival_time_timestamp), 
			   					  MONTH(t0.arrival_time_timestamp), 
								  DAY(t0.arrival_time_timestamp), 
								  CAST(Elmer.dbo.rgx_replace(@starttime,'(\d?\d):\d\d',LTRIM('$1'),1) AS int), 
								  CAST(RIGHT(Elmer.dbo.rgx_replace(@starttime,':(\d\d)$',LTRIM('$1'),1),2) AS int), 0 ,0 ,0) AS depart_time_timestamp,
								DATEDIFF(minute, t0.depart_time_timestamp, t0.arrival_time_timestamp) AS travel_time_elapsed,
								t0.person_id, t0.recid 
							FROM HHSurvey.Trip AS t0 WHERE t0.recid=@target_recid)
			INSERT INTO HHSurvey.Trip (hhid, person_id, pernum, psrc_inserted, tripnum,
				dest_lat, dest_lng, dest_label, origin_lat, origin_lng, origin_label, depart_time_timestamp, arrival_time_timestamp, /*travel_time,*/ distance_miles,
				dest_purpose, dest_purpose_cat, origin_purpose, origin_purpose_cat, modes, mode_acc, mode_1, /*mode_2, mode_3, mode_4, */mode_egr, travelers_hh, travelers_nonhh, travelers_total)
			SELECT t.hhid, t.person_id, t.pernum, 1, 0,
				t.origin_lat, t.origin_lng, t.origin_label, t.dest_lat, t.dest_lng, t.dest_label,
				cte.depart_time_timestamp, DATEADD(minute, cte.travel_time_elapsed, cte.depart_time_timestamp) AS arrival_time_timestamp,
				 /*t.travel_time,*/ t.distance_miles,
				t.origin_purpose, t.origin_purpose_cat, t.dest_purpose, t.dest_purpose_cat, t.modes, t.mode_acc, t.mode_1, /*mode_2, mode_3, mode_4, */t.mode_egr, t.travelers_hh, t.travelers_nonhh, t.travelers_total
			FROM HHSurvey.Trip AS t JOIN cte ON t.recid=cte.recid;

			EXECUTE HHSurvey.recalculate_after_edit @target_person_id;
			EXECUTE HHSurvey.generate_error_flags @target_person_id;
			END
		END
GO

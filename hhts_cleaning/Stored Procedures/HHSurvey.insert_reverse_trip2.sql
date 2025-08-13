SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
	CREATE PROCEDURE [HHSurvey].[insert_reverse_trip2]
			@target_recid int, 
            @startdatetime nvarchar(19)

		AS BEGIN
		IF @target_recid IS NOT NULL 
			BEGIN

			DECLARE @target_person_id decimal(19,0) = NULL;
			SET @target_person_id = (SELECT x.person_id FROM HHSurvey.Trip AS x WHERE x.recid=@target_recid);

			WITH cte AS (SELECT @startdatetime AS depart_time_timestamp,
								DATEDIFF(minute, t0.depart_time_timestamp, t0.arrival_time_timestamp) AS travel_time_elapsed,
								t0.person_id, t0.recid 
                        FROM HHSurvey.Trip AS t0 
                        WHERE t0.recid=@target_recid)

			INSERT INTO HHSurvey.Trip (hhid, 
                                       person_id, 
                                       pernum, 
                                       day_id,
                                       psrc_inserted, 
                                       tripnum,
                                       origin_lat, 
                                       origin_lng, 
                                       dest_lat, 
                                       dest_lng, 
                                       depart_time_timestamp, 
                                       arrival_time_timestamp,
                                       distance_miles,
                                       origin_purpose, 
                                       dest_purpose, 
                                       modes, 
                                       mode_acc, 
                                       mode_1, mode_2, mode_3, mode_4,
                                       mode_egr, 
                                       travelers_hh, 
                                       travelers_nonhh, 
                                       travelers_total,
                                       driver,
                                       hhmember1,
                                       hhmember2,
                                       hhmember3,
                                       hhmember4,
                                       hhmember5,
                                       hhmember6,
                                       hhmember7,
                                       hhmember8,
                                       hhmember9,
                                       hhmember10,
                                       hhmember11,
                                       hhmember12,
                                       hhmember13)
			SELECT t.hhid, 
                   t.person_id, 
                   t.pernum, 
                   t.day_id,
                   1 AS psrc_inserted, 
                   0 AS tripnum,
                   t.dest_lat AS origin_lat, -- dest of previous trip as origin of reverse trip
                   t.dest_lng AS origin_lng, 
                   t.origin_lat AS dest_lat,  -- origin of previous trip as dest of reverse trip
                   t.origin_lng AS dest_lng, 
                   cte.depart_time_timestamp, 
                   DATEADD(minute, cte.travel_time_elapsed, cte.depart_time_timestamp) AS arrival_time_timestamp,
                   t.distance_miles,
                   t.dest_purpose AS origin_purpose,   -- dest purpose of previous trip as origin purpose of reverse trip
                   t.origin_purpose AS dest_purpose,  -- origin purpose of previous trip as dest purpose of reverse trip
                   t.modes, 
                   t.mode_acc, 
                   t.mode_1,mode_2, mode_3, mode_4,
                   t.mode_egr, 
                   t.travelers_hh, 
                   t.travelers_nonhh, 
                   t.travelers_total,
                   -992 AS driver,
                   -992 AS hhmember1,
                   -992 AS hhmember2,
                   -992 AS hhmember3,
                   -992 AS hhmember4,
                   -992 AS hhmember5,
                   -992 AS hhmember6,
                   -992 AS hhmember7,
                   -992 AS hhmember8,
                   -992 AS hhmember9,
                   -992 AS hhmember10,
                   -992 AS hhmember11,
                   -992 AS hhmember12,
                   -992 AS hhmember13
			FROM HHSurvey.Trip AS t 
            JOIN cte ON t.recid=cte.recid;

			EXECUTE HHSurvey.recalculate_after_edit @target_person_id;
			EXECUTE HHSurvey.generate_error_flags @target_person_id;
			END
		END
GO

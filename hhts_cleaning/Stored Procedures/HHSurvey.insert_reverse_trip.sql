SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
	CREATE   PROCEDURE [HHSurvey].[insert_reverse_trip]
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
                                       tripnum,
                                       traveldate,
                                       daynum,
                                       depart_time_timestamp, 
                                       arrival_time_timestamp,
                                       origin_lat, 
                                       origin_lng, 
                                       dest_lat, 
                                       dest_lng, 
                                       distance_miles,
                                       travel_time,
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
                                       hhmember13,
                                       travelers_hh, 
                                       travelers_nonhh, 
                                       travelers_total,
                                       origin_purpose, 
                                       dest_purpose, 
                                       mode_1, 
                                       mode_2, 
                                       mode_3, 
                                       mode_4,
                                       driver,
                                       mode_acc, 
                                       mode_egr,
                                       modes,
                                       psrc_inserted)
			SELECT t.hhid, 
                   t.person_id, 
                   t.pernum, 
                   0 AS tripnum,
                   t.traveldate,
                   t.daynum,
                   cte.depart_time_timestamp, 
                   DATEADD(minute, cte.travel_time_elapsed, cte.depart_time_timestamp) AS arrival_time_timestamp,
                   t.dest_lat AS origin_lat, -- dest of previous trip as origin of reverse trip
                   t.dest_lng AS origin_lng, 
                   t.origin_lat AS dest_lat,  -- origin of previous trip as dest of reverse trip
                   t.origin_lng AS dest_lng, 
                   t.distance_miles,
                   cte.travel_time_elapsed AS travel_time,
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
                   -992 AS hhmember13,
                   t.travelers_hh, 
                   t.travelers_nonhh, 
                   t.travelers_total,
                   t.dest_purpose AS origin_purpose,   -- dest purpose of previous trip as origin purpose of reverse trip
                   t.origin_purpose AS dest_purpose,  -- origin purpose of previous trip as dest purpose of reverse trip
                   t.mode_1, 
                   t.mode_2, 
                   t.mode_3, 
                   t.mode_4,
                   -992 AS driver,
                   t.mode_acc, 
                   t.mode_egr,
                   t.modes,
                   1 AS psrc_inserted
			FROM HHSurvey.Trip AS t 
            JOIN cte ON t.recid=cte.recid;
			END
		END
GO

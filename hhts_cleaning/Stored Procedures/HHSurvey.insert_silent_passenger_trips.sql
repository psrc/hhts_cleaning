SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

    CREATE PROCEDURE [HHSurvey].[insert_silent_passenger_trips]
    AS BEGIN

        BEGIN TRANSACTION;   
        DROP TABLE IF EXISTS HHSurvey.silent_passenger_trip;
        COMMIT TRANSACTION;
        
        BEGIN TRANSACTION;
        WITH cte AS --create CTE set of passenger trips
                (         SELECT recid, pernum AS respondent, hhmember1  as passengerid FROM HHSurvey.Trip WHERE hhmember1  IS NOT NULL AND hhmember1  not in (SELECT flag_value FROM HHSurvey.NullFlags) AND hhmember1  <> pernum
                UNION ALL SELECT recid, pernum AS respondent, hhmember2  as passengerid FROM HHSurvey.Trip WHERE hhmember2  IS NOT NULL AND hhmember2  not in (SELECT flag_value FROM HHSurvey.NullFlags) AND hhmember2  <> pernum
                UNION ALL SELECT recid, pernum AS respondent, hhmember3  as passengerid FROM HHSurvey.Trip WHERE hhmember3  IS NOT NULL AND hhmember3  not in (SELECT flag_value FROM HHSurvey.NullFlags) AND hhmember3  <> pernum
                UNION ALL SELECT recid, pernum AS respondent, hhmember4  as passengerid FROM HHSurvey.Trip WHERE hhmember4  IS NOT NULL AND hhmember4  not in (SELECT flag_value FROM HHSurvey.NullFlags) AND hhmember4  <> pernum
                UNION ALL SELECT recid, pernum AS respondent, hhmember5  as passengerid FROM HHSurvey.Trip WHERE hhmember5  IS NOT NULL AND hhmember5  not in (SELECT flag_value FROM HHSurvey.NullFlags) AND hhmember5  <> pernum
                UNION ALL SELECT recid, pernum AS respondent, hhmember6  as passengerid FROM HHSurvey.Trip WHERE hhmember6  IS NOT NULL AND hhmember6  not in (SELECT flag_value FROM HHSurvey.NullFlags) AND hhmember6  <> pernum
                UNION ALL SELECT recid, pernum AS respondent, hhmember7  as passengerid FROM HHSurvey.Trip WHERE hhmember7  IS NOT NULL AND hhmember7  not in (SELECT flag_value FROM HHSurvey.NullFlags) AND hhmember7  <> pernum
                UNION ALL SELECT recid, pernum AS respondent, hhmember8  as passengerid FROM HHSurvey.Trip WHERE hhmember8  IS NOT NULL AND hhmember8  not in (SELECT flag_value FROM HHSurvey.NullFlags) AND hhmember8  <> pernum
                UNION ALL SELECT recid, pernum AS respondent, hhmember9  as passengerid FROM HHSurvey.Trip WHERE hhmember9  IS NOT NULL AND hhmember9  not in (SELECT flag_value FROM HHSurvey.NullFlags) AND hhmember9  <> pernum)
        SELECT recid, respondent, passengerid INTO HHSurvey.silent_passenger_trip FROM cte GROUP BY recid, respondent, passengerid;
        COMMIT TRANSACTION;

        /* 	Batching by respondent prevents duplication in the case silent passengers were reported by multiple household members on the same trip.
            While there were copied trips with silent passengers listed in both (as they should), the 2017 data had no silent passenger trips in which pernum 1 was not involved;
            that is not guaranteed, so I've left the 8 procedure calls in, although later ones can be expected not to have an effect
        */ 
        EXECUTE HHSurvey.pernum_silent_passenger_trips 1;
        EXECUTE HHSurvey.pernum_silent_passenger_trips 2;
        EXECUTE HHSurvey.pernum_silent_passenger_trips 3;
        EXECUTE HHSurvey.pernum_silent_passenger_trips 4;
        EXECUTE HHSurvey.pernum_silent_passenger_trips 5;
        EXECUTE HHSurvey.pernum_silent_passenger_trips 6;
        EXECUTE HHSurvey.pernum_silent_passenger_trips 7;
        EXECUTE HHSurvey.pernum_silent_passenger_trips 8;
        EXECUTE HHSurvey.pernum_silent_passenger_trips 9;
        DROP PROCEDURE HHSurvey.pernum_silent_passenger_trips;
        DROP TABLE HHSurvey.silent_passenger_trip;

        EXEC HHSurvey.recalculate_after_edit;

        EXECUTE HHSurvey.tripnum_update; --after adding records, we need to renumber them consecutively 
        EXECUTE HHSurvey.dest_purpose_updates;  --running these again to apply to linked trips, JIC
END
GO

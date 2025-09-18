use hhts_cleaning
go
-- Convert temporal tables (aka system versioned tables) back to traditional tables
-- Removing the history tables altogether

-- Household 
    ALTER TABLE HHSurvey.Household 
    set (system_versioning = OFF);

    ALTER TABLE HHSurvey.Household 
    DROP PERIOD FOR SYSTEM_TIME;

    DROP TABLE History.HHSurvey__Household;

-- Person 
    ALTER TABLE HHSurvey.Person 
    set (system_versioning = OFF);

    ALTER TABLE HHSurvey.Person 
    DROP PERIOD FOR SYSTEM_TIME;
    
    DROP TABLE History.HHSurvey__Person;

-- Trip 
    ALTER TABLE HHSurvey.Trip 
    set (system_versioning = OFF);

    ALTER TABLE HHSurvey.Trip 
    DROP PERIOD FOR SYSTEM_TIME;

    DROP TABLE History.HHSurvey__Trip;

-- Day 
    ALTER TABLE HHSurvey.Day 
    set (system_versioning = OFF);

    ALTER TABLE HHSurvey.Day 
    DROP PERIOD FOR SYSTEM_TIME;

    DROP TABLE History.HHSurvey__Day;

-- Vehicle 
    ALTER TABLE HHSurvey.Vehicle 
    set (system_versioning = OFF);

    ALTER TABLE HHSurvey.Vehicle 
    DROP PERIOD FOR SYSTEM_TIME;

    DROP TABLE History.HHSurvey__Vehicle;

-- trip_error_flags 
    ALTER TABLE HHSurvey.trip_error_flags 
    set (system_versioning = OFF);

    ALTER TABLE HHSurvey.trip_error_flags 
    DROP PERIOD FOR SYSTEM_TIME;

    DROP TABLE History.HHSurvey__trip_error_flags;

-- trip_ingredients_done 
    ALTER TABLE HHSurvey.trip_ingredients_done 
    set (system_versioning = OFF);

    ALTER TABLE HHSurvey.trip_ingredients_done 
    DROP PERIOD FOR SYSTEM_TIME;

    DROP TABLE History.HHSurvey__trip_ingredients_done;

    ALTER TABLE HHSurvey.trip_ingredients_done 
    drop constraint HHSurvey_trip_ingredients_done_valid_from_default
    
    ALTER TABLE HHSurvey.trip_ingredients_done 
    drop column valid_from

    ALTER TABLE HHSurvey.trip_ingredients_done 
    drop constraint HHSurvey_trip_ingredients_done_valid_to_default

    ALTER TABLE HHSurvey.trip_ingredients_done 
    drop column valid_to

    ALTER TABLE HHSurvey.trip_ingredients_done 
    drop constraint PK_trip_ingredients_done

    ALTER TABLE HHSurvey.trip_ingredients_done 
    drop  column ingredient_id
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
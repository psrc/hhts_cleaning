-- Convert temporal tables (aka system versioned tables) back to traditional tables
-- Removing the history tables altogether

-- Household 
    ALTER TABLE HHSurvey.Household 
    set (system_versioning = OFF (history_table = History.HHSurvey__Household, DATA_CONSISTENCY_CHECK = OFF));

    DROP TABLE History.HHSurvey__Household;

-- Person 
    ALTER TABLE HHSurvey.Person 
    set (system_versioning = OFF (history_table = History.HHSurvey__Person, DATA_CONSISTENCY_CHECK = OFF));

    DROP TABLE History.HHSurvey__Person;

-- Trip 
    ALTER TABLE HHSurvey.Trip 
    set (system_versioning = OFF (history_table = History.HHSurvey__Trip, DATA_CONSISTENCY_CHECK = OFF));

    DROP TABLE History.HHSurvey__Trip;

-- Day 
    ALTER TABLE HHSurvey.Day 
    set (system_versioning = OFF (history_table = History.HHSurvey__Day, DATA_CONSISTENCY_CHECK = OFF));

    DROP TABLE History.HHSurvey__Day;

-- Vehicle 
    ALTER TABLE HHSurvey.Vehicle 
    set (system_versioning = OFF (history_table = History.HHSurvey__Vehicle, DATA_CONSISTENCY_CHECK = OFF));

    DROP TABLE History.HHSurvey__Vehicle;
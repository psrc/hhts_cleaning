use hhts_cleaning
go
--use hhts_cleaning_temporal;
--go

create schema History;
go

-- Household
    alter table HHSurvey.Household add
        valid_from datetime2 generated always as row start HIDDEN 
        constraint HHSurvey_Household_valid_from_default default sysutcdatetime(),
        valid_to datetime2 generated always as row end HIDDEN
        constraint HHSurvey_Household_valid_to_default default '9999-12-31 23:59:59.9999999'
    go

    alter table HHSurvey.Household add
        period for SYSTEM_TIME (valid_from, valid_to)

    alter table HHSurvey.Household
        set (system_versioning = on (history_table = History.HHSurvey__Household));

-- Person
    alter table HHSurvey.Person add
        valid_from datetime2 generated always as row start HIDDEN 
        constraint HHSurvey_Person_valid_from_default default sysutcdatetime(),
        valid_to datetime2 generated always as row end HIDDEN
        constraint HHSurvey_Person_valid_to_default default '9999-12-31 23:59:59.9999999'
    go

    alter table HHSurvey.Person add
        period for SYSTEM_TIME (valid_from, valid_to)

    alter table HHSurvey.Person
        set (system_versioning = on (history_table = History.HHSurvey__Person));
    go

-- Trip 
    alter table HHSurvey.Trip add
        valid_from datetime2 generated always as row start HIDDEN 
        constraint HHSurvey_Trip_valid_from_default default sysutcdatetime(),
        valid_to datetime2 generated always as row end HIDDEN
        constraint HHSurvey_Trip_valid_to_default default '9999-12-31 23:59:59.9999999'
    go

    alter table HHSurvey.Trip add
        period for SYSTEM_TIME (valid_from, valid_to)

    alter table HHSurvey.Trip
        set (system_versioning = on (history_table = History.HHSurvey__Trip));
    go



-- Vehicle 
    alter table HHSurvey.Vehicle 
        add constraint HHSurvey_Vehicle_PK primary key (vehid)

    alter table HHSurvey.Vehicle add
        valid_from datetime2 generated always as row start HIDDEN 
        constraint HHSurvey_Vehicle_valid_from_default default sysutcdatetime(),
        valid_to datetime2 generated always as row end HIDDEN
        constraint HHSurvey_Vehicle_valid_to_default default '9999-12-31 23:59:59.9999999'
    go

    alter table HHSurvey.Vehicle add
        period for SYSTEM_TIME (valid_from, valid_to)

    alter table HHSurvey.Vehicle
        set (system_versioning = on (history_table = History.HHSurvey__Vehicle));
    go

-- Day 
    alter table HHSurvey.Day
    alter column day_id varchar(255) not null

    alter table HHSurvey.Day 
        add constraint HHSurvey_Day_PK primary key (day_id)

    alter table HHSurvey.Day add
        valid_from datetime2 generated always as row start HIDDEN 
        constraint HHSurvey_Day_valid_from_default default sysutcdatetime(),
        valid_to datetime2 generated always as row end HIDDEN
        constraint HHSurvey_Day_valid_to_default default '9999-12-31 23:59:59.9999999'
    go

    alter table HHSurvey.Day add
        period for SYSTEM_TIME (valid_from, valid_to)

    alter table HHSurvey.Day
        set (system_versioning = on (history_table = History.HHSurvey__Day));
    go

-- trip_error_flags
    alter table HHSurvey.trip_error_flags add
        valid_from datetime2 generated always as row start HIDDEN 
        constraint HHSurvey_trip_error_flags_valid_from_default default sysutcdatetime(),
        valid_to datetime2 generated always as row end HIDDEN
        constraint HHSurvey_trip_error_flags_valid_to_default default '9999-12-31 23:59:59.9999999'
    go

    alter table HHSurvey.trip_error_flags add
        period for SYSTEM_TIME (valid_from, valid_to)

    alter table HHSurvey.trip_error_flags
        set (system_versioning = on (history_table = History.HHSurvey__trip_error_flags));
    go

-- helper functions
    create FUNCTION dbo.LocalToUtc (@localTime DATETIME2)
    RETURNS DATETIME2
    AS
    BEGIN
        RETURN CAST(@localTime AT TIME ZONE 'Pacific Standard Time' AT TIME ZONE 'UTC' AS DATETIME2);
    END

    select dbo.LocalToUtc('2025-06-07 20:09:00.0000000') as utc_time;


-- testing the results:
select * from HHSurvey.Household
where hhid = 23221206

select * from History.Household

update HHSurvey.Household 
set num_complete_thu = 1
where hhid = 23221206;

select * from History.Household

select sysdatetime(), sysutcdatetime()

select * from HHSurvey.Household
where hhid = 23221206

select * from History.Household
where hhid = 23221206

declare @utctime Datetime2 = dbo.LocalToUtc('2025-06-09 08:09:00.0000000');

select * from HHSurvey.Household
for SYSTEM_TIME as of @utctime
where hhid = 23221206

select dbo.LocaltoUtc('2025-06-09 08:17:00.0000000') as utc_time;

select * from HHSurvey.Household
for SYSTEM_TIME as of '2025-06-09 15:17:00.0000000'
where hhid = 23221206

update HHSurvey.Household 
set num_complete_thu = 1
where hhid = 23221206;

select * from HHSurvey.Person
where person_id = 2322120601

update HHSurvey.Person
set numdayscomplete = 10
where person_id = 2322120601

select *
from History.Person
where person_id = 2322120601

select * from HHSurvey.Person
for system_time as of '2025-06-08 02:54:00.0000000'
where person_id = 2322120601


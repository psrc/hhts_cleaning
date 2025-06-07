SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [HHSurvey].[setup_error_flags]
AS BEGIN

    BEGIN TRANSACTION
    DROP TABLE IF EXISTS HHSurvey.error_types;
    CREATE TABLE HHSurvey.error_types	  (error_flag nvarchar(100) NULL, vital int NULL);
    COMMIT TRANSACTION

    BEGIN TRANSACTION
    INSERT INTO HHSurvey.error_types (error_flag, vital) VALUES
        ('unlicensed driver',0),
        ('underage driver',0),
        ('non-student + school trip',0),
        ('non-worker + work trip',0),
        ('no activity time after',0),			
        ('no activity time before',0),
        ('missing next trip link',0),
        ('missing prior trip link',1),
        ('same dest as next',0),
        ('same dest as prior',1),
        ('same transit line listed 2x+',0),
        ('starts, not from home',0),
        ('ends day, not home',0),
        ('too long at dest',1),
        ('excessive speed',1),
        ('too slow',1),
        ('purpose at odds w/ dest',1),
        ('PUDO, no +/- travelers',0),
        ('time overlap',1);	
    COMMIT TRANSACTION

--+ Household error flags +--
    BEGIN TRANSACTION
	DROP TABLE IF EXISTS HHSurvey.hh_error_flags;
	CREATE TABLE HHSurvey.hh_error_flags (hhid decimal(19,0), error_flag NVARCHAR(100));
	COMMIT TRANSACTION

    BEGIN TRANSACTION
	INSERT INTO HHSurvey.hh_error_flags (hhid, error_flag)
	SELECT h.hhid, 'zero trips' FROM HHSurvey.household AS h LEFT JOIN HHSurvey.Trip AS t ON h.hhid = t.hhid
		WHERE t.hhid IS NULL
		GROUP BY h.hhid;
	COMMIT TRANSACTION

--+ Trip error flags +--
    BEGIN TRANSACTION
	DROP TABLE IF EXISTS HHSurvey.trip_error_flags;
	CREATE TABLE HHSurvey.trip_error_flags(
		recid decimal(19,0) not NULL,
		person_id decimal(19,0) not NULL,
		tripnum int not null,
		error_flag varchar(100)
		PRIMARY KEY (person_id, recid, error_flag)
		);
	COMMIT TRANSACTION

    --Populated via HHSurvey.generate_error_flags
END
GO

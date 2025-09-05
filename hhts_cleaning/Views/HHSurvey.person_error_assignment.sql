SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE   VIEW [HHSurvey].[person_error_assignment] WITH SCHEMABINDING AS
WITH FlagPriority AS (
    SELECT v.error_flag, v.priority
    FROM (VALUES
        ('change mode purpose',1),
        ('lone trip',2),
        ('purpose missing',3),
        ('mode_1 missing',4),
        ('time overlap',5),
        ('instantaneous',6),
        ('excessive speed',7),
        ('too slow',8),
        ('same dest as prior',9),
        ('purpose at odds w/ dest',10),
        ('too long at dest?',11),
        ('o purpose not equal to prior d purpose',12),
        ('no activity time after',13),
        ('missing next trip link',14),
        ('ends day, not home',15),
        ('starts, not from home',16),
        ('initial trip purpose missing',17),
        ('non-student + school trip',18),
        ('non-worker + work trip',19),
        ('underage_detailed driver',20)
    ) v(error_flag, priority)
), PersonFlags AS (
    SELECT t.person_id,
           fp.priority,
           fp.error_flag AS assignment
    FROM HHSurvey.trip_error_flags tef
    JOIN HHSurvey.Trip t ON t.recid = tef.recid
    JOIN FlagPriority fp ON fp.error_flag = tef.error_flag
)
SELECT person_id, assignment
FROM (
    SELECT person_id, assignment,
           ROW_NUMBER() OVER (PARTITION BY person_id ORDER BY priority) AS rn
    FROM PersonFlags
 ) x
WHERE rn = 1;


GO

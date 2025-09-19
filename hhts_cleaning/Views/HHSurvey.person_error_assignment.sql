SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE   VIEW [HHSurvey].[person_error_assignment] WITH SCHEMABINDING AS
WITH FlagPriority AS (
    SELECT v.error_flag, v.priority
    FROM (VALUES
        ('underage driver',1),
        ('non-worker + work trip',2),
        ('non-student + school trip',3),
        ('starts, not from home',4),
        ('ends day, not home',5),
        ('same dest as prior',6),
        ('mode_1 missing',7),
        ('lone trip',8),
        ('missing next trip link',9),
        ('initial trip purpose missing',10),
        ('time overlap',11),
        ('no activity time after',12),
        ('o purpose not equal to prior d purpose',13),
        ('time overlap',14),
        ('"change mode" purpose',15),       
        ('purpose missing',16),
        ('instantaneous',17),
        ('excessive speed',18),
        ('too slow',19),
        ('purpose at odds w/ dest',20),
        ('too long at dest?',21)
    ) v(error_flag, priority)
), PersonFlags AS (
    SELECT t.person_id,
           CASE WHEN t.psrc_comment IS NOT NULL THEN 0 ELSE fp.priority END AS priority,
           CASE WHEN t.psrc_comment IS NOT NULL THEN 'Elevated' ELSE fp.error_flag END AS assignment
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

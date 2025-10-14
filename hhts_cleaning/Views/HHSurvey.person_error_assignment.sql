SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE   VIEW [HHSurvey].[person_error_assignment] WITH SCHEMABINDING AS
WITH FlagPriority AS (
    SELECT v.error_flag, v.priority
    FROM (VALUES
        ('initial trip purpose missing',1),
        ('underage driver',2),
        ('non-worker + work trip',3),
        ('non-student + school trip',4),
        ('starts, not from home',5),
        ('ends day, not home',6),
        ('same dest as prior',7),
        ('mode_1 missing',8),
        ('lone trip',9),
        ('missing next trip link',10),
        ('time overlap',12),
        ('no activity time after',13),
        ('o purpose not equal to prior d purpose',14),
        ('time overlap',15),
        ('"change mode" purpose',16),       
        ('purpose missing',17),
        ('instantaneous',18),
        ('excessive speed',19),
        ('too slow',20),
        ('purpose at odds w/ dest',21),
        ('too long at dest?',22)
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

SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [HHSurvey].[fix_mistaken_passenger_carryovers]
AS BEGIN

	--recode driver flag when mistakenly applied to passengers and a hh driver is present
	UPDATE t
		SET t.driver = 2, t.revision_code = CONCAT(t.revision_code, '10a,')
		FROM HHSurvey.Trip AS t JOIN HHSurvey.person AS p ON t.person_id = p.person_id
		WHERE t.driver = 1 AND (p.age_detailed < 16)
			AND EXISTS (SELECT 1 FROM (VALUES (t.hhmember1),(t.hhmember2),(t.hhmember3),(t.hhmember4),(t.hhmember5),
											  (t.hhmember6),(t.hhmember7),(t.hhmember8),(t.hhmember9),(t.hhmember10),
											  (t.hhmember11),(t.hhmember12),(t.hhmember13)) AS hhmem(member) 
			            JOIN HHSurvey.person as p2 ON hhmem.member = p2.pernum WHERE p2.age_detailed > 15);

	--recode driver flag when another traveler may have been a driver
	UPDATE t
		SET t.driver = 2, t.revision_code = CONCAT(t.revision_code, '10b,')
		FROM HHSurvey.Trip AS t JOIN HHSurvey.person AS p ON t.person_id = p.person_id
		WHERE t.driver = 1 AND (p.age_detailed < 16) AND t.travelers_total > 1;

	--recode work purpose when mistakenly applied to passengers and a hh worker is present
	UPDATE t
		SET t.dest_purpose = 97, t.revision_code = CONCAT(t.revision_code, '11,')
		FROM HHSurvey.Trip AS t JOIN HHSurvey.person AS p ON t.person_id = p.person_id
		WHERE t.dest_purpose IN(10,11,14) AND (p.age_detailed < 4 OR p.employment = 0)
			AND EXISTS (SELECT 1 FROM (VALUES (t.hhmember1),(t.hhmember2),(t.hhmember3),(t.hhmember4),(t.hhmember5),
											  (t.hhmember6),(t.hhmember7),(t.hhmember8),(t.hhmember9),(t.hhmember10),
											  (t.hhmember11),(t.hhmember12),(t.hhmember13)) AS hhmem(member) 
			            JOIN HHSurvey.person as p2 ON hhmem.member = p2.pernum WHERE p2.employment = 1 AND p2.age_detailed > 15);


END
GO

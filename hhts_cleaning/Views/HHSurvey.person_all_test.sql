SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
        CREATE VIEW [HHSurvey].[person_all_test] WITH SCHEMABINDING AS
		SELECT p.person_id AS personid, p.hhid AS hhid, p.pernum, p.age_detailed AS Age, 
			CASE WHEN p.employment BETWEEN 1 AND 4 THEN 'Yes' ELSE 'No' END AS Works, 
			CASE WHEN p.student = 1 THEN 'No' WHEN student IN(2,4,5) THEN 'PT' WHEN p.student IN(3,6,7) THEN 'FT' ELSE 'No' END AS Studies, 
			CASE WHEN h.hhgroup=11 THEN 'rMove' ELSE 'rSurvey' END AS HHGroup
		FROM HHSurvey.Person AS p JOIN HHSurvey.Household AS h on h.hhid=p.hhid
        WHERE p.person_id IN (SELECT person_id FROM HHSurvey.Trip)
GO

SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
		CREATE VIEW [HHSurvey].[person_all] WITH SCHEMABINDING AS
		SELECT p.person_id AS personid, p.hhid AS hhid, p.pernum, ac.agedesc AS Age, 
			CASE WHEN p.employment BETWEEN 1 AND 4 THEN 'Yes' ELSE 'No' END AS Works, 
			CASE WHEN p.student = 1 THEN 'No' WHEN student IN(2,4,5) THEN 'PT' WHEN p.student IN(3,6,7) THEN 'FT' ELSE 'No' END AS Studies, 
			CASE WHEN h.hhgroup=11 THEN 'rMove' ELSE 'rSurvey' END AS HHGroup
		FROM HHSurvey.Person AS p INNER JOIN HHSurvey.AgeCategories AS ac ON p.age_detailed = ac.agecode JOIN HHSurvey.Household AS h on h.hhid=p.hhid
		WHERE EXISTS (SELECT 1 FROM HHSurvey.Trip AS t WHERE p.person_id = t.person_id);
GO

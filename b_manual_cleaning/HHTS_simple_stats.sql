--Modes summary
    WITH cte AS
    (SELECT t.person_id, (SELECT MAX(member) FROM (VALUES (t.mode_1), (t.mode_2),(t.mode_3),(t.mode_4)) AS modes(member) WHERE member <> 97) AS mode_x FROM HHSurvey.Trip AS t)
    SELECT cte.mode_x, count(*) AS tripcount
    FROM cte 
    GROUP BY cte.mode_x ORDER BY cte.mode_x;

--Purposes summary
    SELECT t.dest_purpose, count(t.tripid) FROM HHSurvey.Trip AS t GROUP BY t.dest_purpose;

--Distance category summary
    WITH cte AS (SELECT round(t.distance_miles,0) AS trip_miles FROM HHSurvey.Trip AS t)
    SELECT CASE WHEN cte.trip_miles < 10  THEN ROUND(cte.trip_miles,0)
                WHEN cte.trip_miles < 100 THEN ROUND(cte.trip_miles,-1)
                WHEN cte.trip_miles < 1000 THEN ROUND(cte.trip_miles,-2) 
                WHEN cte.trip_miles > 1000 THEN ROUND(cte.trip_miles,-3)
                END,
                count(*) AS dist_count
    FROM cte /*WHERE COALESCE(dbo.RgxFind(t.revision_code,'5,',1),0) = 0*/
    GROUP BY CASE WHEN cte.trip_miles < 10  THEN ROUND(cte.trip_miles,0)
                WHEN cte.trip_miles < 100 THEN ROUND(cte.trip_miles,-1)
                WHEN cte.trip_miles < 1000 THEN ROUND(cte.trip_miles,-2) 
                WHEN cte.trip_miles > 1000 THEN ROUND(cte.trip_miles,-3)
                  END
    ORDER BY CASE WHEN cte.trip_miles < 10  THEN ROUND(cte.trip_miles,0)
                WHEN cte.trip_miles < 100 THEN ROUND(cte.trip_miles,-1)
                WHEN cte.trip_miles < 1000 THEN ROUND(cte.trip_miles,-2) 
                WHEN cte.trip_miles > 1000 THEN ROUND(cte.trip_miles,-3)
                END;
WITH cte AS (
	SELECT t.hhid
		   FROM HHSurvey.Trip AS t JOIN HHSurvey.trip_error_flags AS tef ON t.recid=tef.recid 
		   WHERE tef.error_flag='missing next trip link'
		   GROUP BY t.hhid
)
SELECT CASE WHEN cte.hhid IS NOT NULL THEN 'missing' ELSE 'complete' END AS link_status, 
CASE WHEN h.hh_iscomplete_b=1 THEN 'complete' ELSE 'incomplete' END AS complete_b , count(*) AS n
FROM HHSurvey.Household AS h LEFT JOIN cte ON cte.hhid=h.hhid
GROUP BY CASE WHEN cte.hhid IS NOT NULL THEN 'missing' ELSE 'complete' END, 
CASE WHEN h.hh_iscomplete_b=1 THEN 'complete' ELSE 'incomplete' END;

--Trip error code count
SELECT error_flag, [1] AS rMove, [2] AS rSurvey
FROM
(
    SELECT 
        CASE WHEN h.hhgroup = 11 THEN 1 ELSE 2 END AS hhgroup, 
        tef.error_flag, 
        t.recid
    FROM HHSurvey.trip_error_flags AS tef 
    JOIN HHSurvey.Trip AS t ON t.recid = tef.recid 
    JOIN hhts_cleaning.HHSurvey.Household AS h ON t.hhid = h.hhid
) AS base_data
PIVOT
(
    COUNT(recid)
    FOR hhgroup IN ([1], [2])
) AS pvt
ORDER BY pvt.error_flag;

--Trip error code count by iOS-affected persons
SELECT error_flag, [1] AS iOS_flag, [0] AS all_else
FROM
(SELECT CASE WHEN EXISTS(SELECT 1 FROM HHSurvey.Trip AS tref WHERE tref.person_id=t.person_id AND tref.trace_quality_flag=1) THEN 1 ELSE 0 END AS quality_group, tef.error_flag, t.recid
FROM HHSurvey.trip_error_flags AS tef JOIN HHSurvey.Trip as t ON t.recid=tef.recid JOIN HHSurvey.Household AS h ON t.hhid=h.hhid WHERE h.hhgroup=11) AS SourceTable
PIVOT
(
 count(recid)
 FOR quality_group IN ([1], [0])
) AS pvt
ORDER BY pvt.error_flag;

--Trip error code count
SELECT error_flag, [1] AS rMove, [2] AS rSurvey
FROM
(
    SELECT CASE WHEN h.hhgroup IN(5,8,11) THEN 1 ELSE 2 END AS hhgroup, tef.error_flag, t.recid
    FROM HHSurvey.trip_error_flags AS tef 
    JOIN HHSurvey.Trip as t ON t.recid=tef.recid 
    JOIN hhts_cleaning.HHSurvey.Household AS h ON t.hhid=h.hhid
) AS source_data
PIVOT
(
    COUNT(recid)
    FOR hhgroup IN ([1], [2])
) AS pvt
ORDER BY pvt.error_flag;

SELECT CASE WHEN home_geog.STEquals(sample_geog)=1 THEN 'Same' ELSE 'Differ' END AS loc_cat, count(*)
FROM hhts_cleaning.HHSurvey.Household WHERE hh_iscomplete_b=1
GROUP BY CASE WHEN home_geog.STEquals(sample_geog)=1 THEN 'Same' ELSE 'Differ' END

SELECT t.trace_quality_flag, count(*) FROM HHSurvey.Trip as t JOIN hhts_cleaning.HHSurvey.Household AS h ON t.hhid=h.hhid GROUP BY t.trace_quality_flag;
--Error Flag reporting crosstab

		WITH elevated AS 
			(SELECT cte_t.person_id FROM HHSurvey.Trip AS cte_t
				WHERE (cte_t.psrc_comment IS NOT NULL) 
				GROUP BY cte_t.person_id)
		SELECT error_flag, pivoted.[1] AS rMove, pivoted.[2] AS rSurvey, pivoted.[3] AS elevated
		FROM (SELECT tef.error_flag, CASE WHEN e.person_id IS NOT NULL THEN 3 ELSE t.hhgroup END AS category, count(t.recid) AS n
				FROM HHSurvey.Trip AS t 
					JOIN HHSurvey.trip_error_flags AS tef ON t.recid = tef.recid 
					LEFT JOIN elevated AS e ON t.person_id = e.person_id 
				WHERE t.psrc_resolved IS NULL
				GROUP BY tef.error_flag, CASE WHEN e.person_id IS NOT NULL THEN 3 ELSE t.hhgroup END) AS source
		PIVOT (SUM(n) FOR category IN ([1], [2], [3])) AS pivoted
		ORDER BY pivoted.[1] DESC;


		SELECT error_flag, pivoted.[1] AS rMove, pivoted.[2] AS rSurvey
		FROM (SELECT tef.error_flag, h.hhgroup AS category, count(t.recid) AS n
				FROM HHSurvey.Trip AS t 
					JOIN HHSurvey.trip_error_flags AS tef ON t.recid = tef.recid JOIN HHSurvey.Household AS h ON t.hhid=h.hhid
				WHERE t.psrc_resolved IS NULL
				GROUP BY tef.error_flag, h.hhgroup) AS source
		PIVOT (SUM(n) FOR category IN ([1], [2])) AS pivoted
		ORDER BY pivoted.[1] DESC;

--Revision Code count

			  SELECT 1, count(*) FROM HHSurvey.Trip AS t WHERE Elmer.dbo.rgx_find(t.revision_code,'\b1,',1)=1
		UNION SELECT 2, count(*) FROM HHSurvey.Trip AS t WHERE Elmer.dbo.rgx_find(t.revision_code,'\b2,',1)=1
		UNION SELECT 3, count(*) FROM HHSurvey.Trip AS t WHERE Elmer.dbo.rgx_find(t.revision_code,'\b3,',1)=1
		UNION SELECT 4, count(*) FROM HHSurvey.Trip AS t WHERE Elmer.dbo.rgx_find(t.revision_code,'\b4,',1)=1
		UNION SELECT 5, count(*) FROM HHSurvey.Trip AS t WHERE Elmer.dbo.rgx_find(t.revision_code,'\b5b?,',1)=1
		UNION SELECT 6, count(*) FROM HHSurvey.Trip AS t WHERE Elmer.dbo.rgx_find(t.revision_code,'\b6,',1)=1
		UNION SELECT 7, count(*) FROM HHSurvey.Trip AS t WHERE Elmer.dbo.rgx_find(t.revision_code,'\b7,',1)=1
		UNION SELECT 8, count(*) FROM HHSurvey.Trip AS t WHERE Elmer.dbo.rgx_find(t.revision_code,'\b8,',1)=1
		UNION SELECT 9, count(*) FROM HHSurvey.Trip AS t WHERE Elmer.dbo.rgx_find(t.revision_code,'\b9,',1)=1
		UNION SELECT 10, count(*) FROM HHSurvey.Trip AS t WHERE Elmer.dbo.rgx_find(t.revision_code,'\b10,',1)=1
		UNION SELECT 11, count(*) FROM HHSurvey.Trip AS t WHERE Elmer.dbo.rgx_find(t.revision_code,'\b11,',1)=1
		UNION SELECT 12, count(*) FROM HHSurvey.Trip AS t WHERE Elmer.dbo.rgx_find(t.revision_code,'\b12,',1)=1
		UNION SELECT 13, count(*) FROM HHSurvey.Trip AS t WHERE Elmer.dbo.rgx_find(t.revision_code,'\b13,',1)=1
		UNION SELECT 14, count(*) FROM HHSurvey.Trip AS t WHERE Elmer.dbo.rgx_find(t.revision_code,'\b14,',1)=1
		UNION SELECT 15, count(*) FROM HHSurvey.Trip AS t WHERE Elmer.dbo.rgx_find(t.revision_code,'15,',1)=1
		UNION SELECT 16, count(*) FROM HHSurvey.Trip AS t WHERE Elmer.dbo.rgx_find(t.revision_code,'\b16,',1)=1
		UNION SELECT 17, count(*) FROM HHSurvey.Trip AS t WHERE Elmer.dbo.rgx_find(t.revision_code,'\b17,',1)=1;

WITH cte AS (SELECT DISTINCT tefw.recid, STUFF((SELECT ',' + tef.error_flag				--non-adjacent repeated modes, i.e. suggests a loop trip
					FROM HHSurvey.trip_error_flags AS tef
					WHERE tef.recid=tefw.recid 
					GROUP BY tef.error_flag
					ORDER BY tefw.recid, tef.error_flag	
					FOR XML PATH('')), 1, 1, NULL) AS flags FROM HHSurvey.trip_error_flags AS tefw)
SELECT flags, count(*) FROM cte GROUP BY flags;


SELECT DISTINCT ti_wndw2.person_id, ti_wndw2.trip_link, Elmer.dbo.TRIM(Elmer.dbo.rgx_replace(
				STUFF((SELECT ',' + ti2.modes				--non-adjacent repeated modes, i.e. suggests a loop trip
					FROM #trip_ingredient AS ti2
					WHERE ti2.person_id = ti_wndw2.person_id AND ti2.trip_link = ti_wndw2.trip_link 
					GROUP BY ti2.modes
					ORDER BY ti_wndw2.person_id DESC, ti_wndw2.tripnum DESC
					FOR XML PATH('')), 1, 1, NULL),'(\b\d+\b),(?=\1)','',1)) AS modes	
			FROM #trip_ingredient as ti_wndw2


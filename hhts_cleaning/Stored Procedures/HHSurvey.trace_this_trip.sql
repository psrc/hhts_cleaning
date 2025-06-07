SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
		CREATE PROCEDURE [HHSurvey].[trace_this_trip]
			@target_recid numeric NULL --provide recid of reference member
		
		AS BEGIN
		SET NOCOUNT OFF;
		WITH cte AS
		(SELECT t.tripid, t.recid FROM HHSurvey.Trip AS t WHERE t.recid = @target_recid)
		SELECT c.traceid, CONVERT(NVARCHAR, c.collected_at, 22) AS timepoint, Round(DATEDIFF(Second, c.collected_at, cnxt.collected_at)/60,1) AS minutes_btwn, ROUND(c.point_geog.STDistance(cnxt.point_geog)/1609,2) AS miles_btwn, CONCAT(CAST(c.lat AS VARCHAR(20)),', ',CAST(c.lng AS VARCHAR(20))) AS coords
		FROM HHSurvey.Trace AS c JOIN cte ON c.tripid = cte.tripid LEFT JOIN HHSurvey.Trace AS cnxt ON c.traceid + 1 = cnxt.traceid AND c.tripid = cnxt.tripid
		WHERE cte.recid = @target_recid
		ORDER BY c.collected_at ASC;
		END
GO

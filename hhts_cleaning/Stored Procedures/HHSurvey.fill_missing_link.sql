SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/* Add trips in cases the origin of a trip is over 500m from the destination of the prior, with conditions */

CREATE    PROCEDURE [HHSurvey].[fill_missing_link]
	@GoogleKey NVARCHAR(100)
AS
BEGIN

	-- Ensure trip numbers are current before evaluating gaps
	EXECUTE HHSurvey.tripnum_update;

	-- Build a prefiltered worklist to minimize routing API calls
	IF OBJECT_ID('tempdb..#worklist') IS NOT NULL DROP TABLE #worklist;

	WITH base_candidates AS (
		SELECT 
			t.recid,
			t.hhid,
			t.person_id,
			t.pernum,
			t.dest_lat AS gap_origin_lat,
			t.dest_lng AS gap_origin_lng,
			t.dest_geog AS gap_origin_geog,
			nxt.origin_lat AS gap_dest_lat,
			nxt.origin_lng AS gap_dest_lng,
			nxt.origin_geog AS gap_dest_geog,
			-- Preserve mode if same across the gap; else unknown/imputed (995)
			CASE WHEN t.mode_1 = nxt.mode_1 THEN t.mode_1 ELSE 995 END AS mode_imputed,
			-- Rev code: 16, same-day; 17, cross-day
			CASE WHEN DATEDIFF(DAY, t.arrival_time_timestamp, nxt.depart_time_timestamp) = 0 THEN '16a,' ELSE '16b,' END AS revision_code,
			-- Travel window start/end
			t.arrival_time_timestamp  AS travelwindow_start,
			nxt.depart_time_timestamp AS travelwindow_end,
			-- Traveler counts: carry if consistent, else unknowns
			CASE WHEN t.travelers_hh     = nxt.travelers_hh     THEN t.travelers_hh     ELSE -9997 END AS travelers_hh,
			CASE WHEN t.travelers_nonhh  = nxt.travelers_nonhh  THEN t.travelers_nonhh  ELSE -9997 END AS travelers_nonhh,
			CASE WHEN t.travelers_total  = nxt.travelers_total  THEN t.travelers_total  ELSE -9997 END AS travelers_total,
			-- For routing mode selection
			t.mode_1 AS mode_for_route,
			-- Straight-line gap and naive feasibility
			t.dest_geog.STDistance(nxt.origin_geog) AS gap_meters,
			(t.dest_geog.STDistance(nxt.origin_geog) * 0.000621371) AS gap_miles,
			DATEDIFF(MINUTE, t.arrival_time_timestamp, nxt.depart_time_timestamp) AS window_minutes,
			CASE 
				WHEN EXISTS (SELECT 1 FROM HHSurvey.automodes WITH (NOLOCK)    WHERE mode_id = t.mode_1) THEN 25
				WHEN EXISTS (SELECT 1 FROM HHSurvey.transitmodes WITH (NOLOCK) WHERE mode_id = t.mode_1) THEN 12
				WHEN EXISTS (SELECT 1 FROM HHSurvey.bikemodes WITH (NOLOCK)    WHERE mode_id = t.mode_1) THEN 10
				WHEN t.mode_1 = 1 THEN 3
				ELSE 25
			END AS naive_speed_mph
		FROM HHSurvey.Trip AS t WITH (NOLOCK)
		JOIN HHSurvey.Trip AS nxt WITH (NOLOCK)
			ON nxt.person_id = t.person_id AND nxt.tripnum = t.tripnum + 1
		WHERE 
			COALESCE(t.psrc_inserted, 0) = 0 AND COALESCE(nxt.psrc_inserted, 0) = 0
			AND t.dest_geog IS NOT NULL AND nxt.origin_geog IS NOT NULL
			AND t.dest_geog.STDistance(nxt.origin_geog) > 500
			AND NOT EXISTS (
				SELECT 1 
				FROM HHSurvey.Trip AS x WITH (NOLOCK)
				WHERE x.person_id = t.person_id
				  AND x.psrc_inserted = 1
				  AND x.dest_purpose = -9998
				  AND x.depart_time_timestamp >= t.arrival_time_timestamp
				  AND x.arrival_time_timestamp <= nxt.depart_time_timestamp
				  AND x.origin_geog.STDistance(t.dest_geog) < 100
				  AND x.dest_geog.STDistance(nxt.origin_geog) < 100
			)
	),
	prefilter AS (
		SELECT 
			b.*,
			CEILING((b.gap_miles / NULLIF(b.naive_speed_mph,0)) * 60.0) + 5 AS naive_min_minutes,
			DATEDIFF(MINUTE, b.travelwindow_start, b.travelwindow_end) - (CEILING((b.gap_miles / NULLIF(b.naive_speed_mph,0)) * 60.0) + 5) AS slack_minutes
		FROM base_candidates b
	)
	SELECT 
		recid, hhid, person_id, pernum,
		gap_origin_lat, gap_origin_lng, gap_origin_geog,
		gap_dest_lat, gap_dest_lng, gap_dest_geog,
		mode_imputed, revision_code,
		travelers_hh, travelers_nonhh, travelers_total,
		travelwindow_start, travelwindow_end,
		mode_for_route, gap_miles, slack_minutes
	INTO #worklist
	FROM prefilter
	WHERE naive_min_minutes IS NOT NULL
		AND DATEDIFF(MINUTE, travelwindow_start, travelwindow_end) >= naive_min_minutes
		AND gap_miles <= 50.0;

	-- Nothing to do
	IF NOT EXISTS (SELECT 1 FROM #worklist) GOTO done;

	-- Process in batches of 25; always advance the worklist regardless of insert count
	WHILE EXISTS (SELECT 1 FROM #worklist)
	BEGIN
		IF OBJECT_ID('tempdb..#batch25') IS NOT NULL DROP TABLE #batch25;
		SELECT TOP (25) *
		INTO #batch25
		FROM #worklist
		ORDER BY slack_minutes DESC, gap_miles ASC, person_id, recid;

		;WITH cte_ref AS (
			SELECT 
				b.*,
				-- Midpoint of the window for time-dependent routing (e.g., transit)
				DATEADD(MINUTE, DATEDIFF(MINUTE, b.travelwindow_start, b.travelwindow_end) / 2, b.travelwindow_start) AS mid_time,
				Elmer.dbo.route_mi_min(
					b.gap_origin_lng, b.gap_origin_lat, 
					b.gap_dest_lng,   b.gap_dest_lat,
					CASE 
						WHEN EXISTS (SELECT 1 FROM HHSurvey.automodes WITH (NOLOCK)    WHERE mode_id = b.mode_for_route) THEN 'driving' 
						WHEN EXISTS (SELECT 1 FROM HHSurvey.transitmodes WITH (NOLOCK) WHERE mode_id = b.mode_for_route) THEN 'transit'
						WHEN EXISTS (SELECT 1 FROM HHSurvey.bikemodes WITH (NOLOCK)    WHERE mode_id = b.mode_for_route) THEN 'bicycling'
						WHEN b.mode_for_route = 1 THEN 'walking' 
						ELSE 'driving' 
					END,   
					@GoogleKey,
					DATEADD(MINUTE, DATEDIFF(MINUTE, b.travelwindow_start, b.travelwindow_end) / 2, b.travelwindow_start)
				) AS mi_min_result
			FROM #batch25 AS b
		),
		parsed AS (
			SELECT r.*, CHARINDEX(',', r.mi_min_result) AS comma_pos
			FROM cte_ref AS r
			WHERE r.mi_min_result IS NOT NULL
		),
		aml AS (
			SELECT 
				p.recid,
				TRY_CONVERT(float, LEFT(p.mi_min_result, p.comma_pos - 1)) AS distance_mi,
				TRY_CONVERT(float, SUBSTRING(p.mi_min_result, p.comma_pos + 1, LEN(p.mi_min_result))) AS travel_minutes
			FROM parsed AS p
			WHERE p.comma_pos > 1
		),
		feasible AS (
			SELECT 
				r.recid,
				r.hhid,
				r.person_id,
				r.pernum,
				r.gap_origin_lat,
				r.gap_origin_lng,
				r.gap_origin_geog,
				r.gap_dest_lat,
				r.gap_dest_lng,
				r.gap_dest_geog,
				r.mode_imputed,
				r.revision_code,
				r.travelers_hh,
				r.travelers_nonhh,
				r.travelers_total,
				CAST(r.travelwindow_start AS datetime2) AS window_start,
				CAST(r.travelwindow_end   AS datetime2) AS window_end,
				a.distance_mi,
				TRY_CONVERT(int, ROUND(a.travel_minutes, 0)) AS travel_minutes
			FROM cte_ref AS r
			JOIN aml AS a ON a.recid = r.recid
			WHERE a.distance_mi IS NOT NULL AND a.distance_mi > 0.3
		),
		windowed AS (
			SELECT 
				f.*,
				f.window_start AS earliest_depart,
				DATEADD(MINUTE, -ISNULL(f.travel_minutes, 0), f.window_end) AS latest_depart
			FROM feasible AS f
			WHERE DATEDIFF(MINUTE, f.window_start, f.window_end) > ISNULL(f.travel_minutes, 0)
		),
		placed AS (
			SELECT 
				w.*,
				DATETIME2FROMPARTS(DATEPART(year, w.window_start), DATEPART(month, w.window_start), DATEPART(day, w.window_start), 5, 30, 0, 0, 0) AS band1_start,
				DATETIME2FROMPARTS(DATEPART(year, w.window_start), DATEPART(month, w.window_start), DATEPART(day, w.window_start), 22, 30, 0, 0, 0) AS band1_end,
				DATETIME2FROMPARTS(DATEPART(year, w.window_end),   DATEPART(month, w.window_end),   DATEPART(day, w.window_end),   5, 30, 0, 0, 0) AS band2_start,
				DATETIME2FROMPARTS(DATEPART(year, w.window_end),   DATEPART(month, w.window_end),   DATEPART(day, w.window_end),   22, 30, 0, 0, 0) AS band2_end
			FROM windowed AS w
		),
		candidates AS (
			SELECT 
				p.*,
				CASE 
					WHEN (CASE WHEN p.earliest_depart > p.band1_start THEN p.earliest_depart ELSE p.band1_start END)
					   <= (CASE WHEN p.latest_depart   < p.band1_end   THEN p.latest_depart   ELSE p.band1_end   END)
					THEN (CASE WHEN p.earliest_depart > p.band1_start THEN p.earliest_depart ELSE p.band1_start END)
				END AS cand1_depart,
				CASE 
					WHEN (CASE WHEN p.earliest_depart > p.band2_start THEN p.earliest_depart ELSE p.band2_start END)
					   <= (CASE WHEN p.latest_depart   < p.band2_end   THEN p.latest_depart   ELSE p.band2_end   END)
					THEN (CASE WHEN p.earliest_depart > p.band2_start THEN p.earliest_depart ELSE p.band2_start END)
				END AS cand2_depart,
				DATEADD(MINUTE, DATEDIFF(MINUTE, p.earliest_depart, p.latest_depart) / 2, p.earliest_depart) AS center_depart
			FROM placed AS p
		),
		final_pick AS (
			SELECT 
				c.*,
				DATETIME2FROMPARTS(DATEPART(year, c.center_depart), DATEPART(month, c.center_depart), DATEPART(day, c.center_depart), 0, 30, 0, 0, 0) AS bad_start,
				DATETIME2FROMPARTS(DATEPART(year, c.center_depart), DATEPART(month, c.center_depart), DATEPART(day, c.center_depart), 4, 30, 0, 0, 0) AS bad_end,
				DATETIME2FROMPARTS(DATEPART(year, c.center_depart), DATEPART(month, c.center_depart), DATEPART(day, c.center_depart), 3, 0, 0, 0, 0) AS three_am,
				DATETIME2FROMPARTS(DATEPART(year, c.center_depart), DATEPART(month, c.center_depart), DATEPART(day, c.center_depart), 5, 30, 0, 0, 0) AS five30,
				DATETIME2FROMPARTS(DATEPART(year, c.center_depart), DATEPART(month, c.center_depart), DATEPART(day, c.center_depart), 22, 0, 0, 0, 0) AS ten_pm
			FROM candidates AS c
		),
		choose_time AS (
			SELECT 
				f.*,
				CASE 
					WHEN f.cand1_depart IS NOT NULL THEN f.cand1_depart
					WHEN f.cand2_depart IS NOT NULL THEN f.cand2_depart
					ELSE 
						CASE 
							WHEN (f.center_depart BETWEEN f.bad_start AND f.bad_end)
								 OR (f.center_depart < f.three_am AND DATEADD(MINUTE, ISNULL(f.travel_minutes,0), f.center_depart) >= f.three_am)
							THEN 
								CASE 
									WHEN (CASE WHEN f.earliest_depart > f.five30 THEN f.earliest_depart ELSE f.five30 END) <= f.latest_depart 
										THEN (CASE WHEN f.earliest_depart > f.five30 THEN f.earliest_depart ELSE f.five30 END)
									WHEN f.earliest_depart <= (CASE WHEN f.latest_depart < f.ten_pm THEN f.latest_depart ELSE f.ten_pm END)
										THEN (CASE WHEN f.latest_depart < f.ten_pm THEN f.latest_depart ELSE f.ten_pm END)
									ELSE f.center_depart
								END
						ELSE f.center_depart
					END
				END AS depart_time_timestamp
			FROM final_pick AS f
		)
		INSERT INTO HHSurvey.Trip (
			hhid, person_id, pernum, tripnum, psrc_inserted, revision_code, dest_purpose,
			mode_1, modes, travelers_hh, travelers_nonhh, travelers_total,
			origin_lat, origin_lng, origin_geog, dest_lat, dest_lng, dest_geog,
			distance_miles, depart_time_timestamp, arrival_time_timestamp, travel_time
		)
		SELECT 
			ch.hhid,
			ch.person_id,
			ch.pernum,
			99 AS tripnum,
			1  AS psrc_inserted,
			ch.revision_code,
			-9998 AS dest_purpose,
			ch.mode_imputed AS mode_1,
			CAST(ch.mode_imputed AS NVARCHAR(20)) AS modes,
			ch.travelers_hh,
			ch.travelers_nonhh,
			ch.travelers_total,
			ch.gap_origin_lat,
			ch.gap_origin_lng,
			ch.gap_origin_geog,
			ch.gap_dest_lat,
			ch.gap_dest_lng,
			ch.gap_dest_geog,
			ch.distance_mi,
			ch.depart_time_timestamp,
			DATEADD(MINUTE, ch.travel_minutes, ch.depart_time_timestamp) AS arrival_time_timestamp,
			ch.travel_minutes
		FROM choose_time AS ch
		ORDER BY ch.person_id, ch.recid;

		-- Remove processed items regardless of insert success
		DELETE w
		FROM #worklist w
		JOIN #batch25 b ON b.recid = w.recid;

		-- Gentle delay to avoid long-held locks and API stress
		WAITFOR DELAY '00:00:00.250';
	END

done:
	-- Recalculate once after all batches
	EXECUTE HHSurvey.recalculate_after_edit;
END
GO

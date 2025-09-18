SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/* Add trips in cases the origin of a trip is over 500m from the destination of the prior, with conditions */

CREATE   PROCEDURE [HHSurvey].[fill_missing_link]
	@GoogleKey NVARCHAR(100)
AS
BEGIN

	-- Ensure trip numbers are current before evaluating gaps
	EXECUTE HHSurvey.tripnum_update;

	-- Batch insert bridging trips in chunks of 25 with a short delay, avoiding long-held locks
	DECLARE @rows int = 1;
	WHILE (@rows > 0)
	BEGIN
		;WITH base_candidates AS (
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
				-- Travel window start/end: prefer the actual observed times; we'll avoid placing in undesirable bands later
				t.arrival_time_timestamp  AS travelwindow_start,
				nxt.depart_time_timestamp AS travelwindow_end,
				-- Traveler counts: carry if consistent, else unknowns
				CASE WHEN t.travelers_hh     = nxt.travelers_hh     THEN t.travelers_hh     ELSE -9997 END AS travelers_hh,
				CASE WHEN t.travelers_nonhh  = nxt.travelers_nonhh  THEN t.travelers_nonhh  ELSE -9997 END AS travelers_nonhh,
				CASE WHEN t.travelers_total  = nxt.travelers_total  THEN t.travelers_total  ELSE -9997 END AS travelers_total,
				-- For routing mode selection
				t.mode_1 AS mode_for_route
			FROM HHSurvey.Trip AS t WITH (NOLOCK)
			JOIN HHSurvey.Trip AS nxt WITH (NOLOCK)
				ON nxt.person_id = t.person_id AND nxt.tripnum = t.tripnum + 1
			WHERE 
				t.psrc_inserted = 0 AND nxt.psrc_inserted = 0
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
		pick25 AS (
			SELECT TOP (25) *
			FROM base_candidates
			ORDER BY person_id, recid
		),
		cte_ref AS (
			SELECT 
				b.*,
				-- Route between the gap endpoints (t.dest -> nxt.origin) for just 25 records per batch
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
					NULL
				) AS mi_min_result
			FROM pick25 AS b
		),
		-- Robust parsing with guards
		parsed AS (
			SELECT 
				r.*,
				CHARINDEX(',', r.mi_min_result) AS comma_pos
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
				-- Round travel minutes to whole minutes
				TRY_CONVERT(int, ROUND(a.travel_minutes, 0)) AS travel_minutes
			FROM cte_ref AS r
			JOIN aml AS a ON a.recid = r.recid
			WHERE a.distance_mi IS NOT NULL AND a.distance_mi > 0.3
		),
		windowed AS (
			SELECT 
				f.*,
				-- Earliest and latest feasible departure times
				f.window_start AS earliest_depart,
				DATEADD(MINUTE, -ISNULL(f.travel_minutes, 0), f.window_end) AS latest_depart
			FROM feasible AS f
			WHERE DATEDIFF(MINUTE, f.window_start, f.window_end) > ISNULL(f.travel_minutes, 0)
		),
		-- Time-band placement: prefer 05:30–22:30 local times, avoid 03:00 crossing when possible
		placed AS (
			SELECT 
				w.*,
				-- Band on date of window_start
				DATETIME2FROMPARTS(DATEPART(year, w.window_start), DATEPART(month, w.window_start), DATEPART(day, w.window_start), 5, 30, 0, 0, 0) AS band1_start,
				DATETIME2FROMPARTS(DATEPART(year, w.window_start), DATEPART(month, w.window_start), DATEPART(day, w.window_start), 22, 30, 0, 0, 0) AS band1_end,
				-- Band on date of window_end
				DATETIME2FROMPARTS(DATEPART(year, w.window_end), DATEPART(month, w.window_end), DATEPART(day, w.window_end), 5, 30, 0, 0, 0) AS band2_start,
				DATETIME2FROMPARTS(DATEPART(year, w.window_end), DATEPART(month, w.window_end), DATEPART(day, w.window_end), 22, 30, 0, 0, 0) AS band2_end
			FROM windowed AS w
		),
		candidates AS (
			SELECT 
				p.*,
				-- Intersections with preferred bands
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
				-- Center of feasible window
				DATEADD(MINUTE, DATEDIFF(MINUTE, p.earliest_depart, p.latest_depart) / 2, p.earliest_depart) AS center_depart
			FROM placed AS p
		),
		-- Final depart time selection with guardrails around 00:30–04:30 and 03:00 crossing
		final_pick AS (
			SELECT 
				c.*,
				-- Helper clocks
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
							-- If center is in 00:30–04:30 or would cross 03:00, try 05:30 or 22:00 within window
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
		INSERT TOP (25) INTO HHSurvey.Trip (
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
		-- Deterministic order across batches
		ORDER BY ch.person_id, ch.recid;

		SET @rows = @@ROWCOUNT;

		IF (@rows > 0)
			WAITFOR DELAY '00:00:00.250';
	END

	-- Recalculate once after all batches
	EXECUTE HHSurvey.recalculate_after_edit;
END
GO

SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*
Purpose: Enhanced gap filling procedure.
Strategy order:
 1. Household donor replication (preferred)
 2. Impute single bridging trip (sample dwell + routed travel) if no donor
Skip only when routing fails (no distance/minutes returned).
Revisions vs legacy:
 - No min dwell or jitter params; dwell sampled from distribution.
 - Home (dest_purpose=1) dwells stratified by overnight crossing 3am.
 - Center trip in window if sampled dwell + travel exceeds window slack.
*/
CREATE   PROCEDURE [HHSurvey].[fill_gaps_between_trips]
   @GoogleKey NVARCHAR(100),
   @Debug BIT = 0,
   @Seed  BIGINT = NULL -- optional deterministic randomness
AS
BEGIN
  SET NOCOUNT ON;
  BEGIN TRY

    /* 0a. Identify gaps: use table variable @gaps to guarantee compile-time metadata */
    DECLARE @gaps TABLE (
      gap_id INT NOT NULL PRIMARY KEY,
      prior_recid DECIMAL(19,0) NULL,
      person_id DECIMAL(19,0) NULL,
      hhid DECIMAL(19,0) NULL,
      pernum INT NULL,
      gap_start_time DATETIME2 NULL,
      gap_start_geog GEOGRAPHY NULL,
      gap_start_lat FLOAT NULL,
      gap_start_lng FLOAT NULL,
      next_recid DECIMAL(19,0) NULL,
      gap_end_time DATETIME2 NULL,
      gap_end_geog GEOGRAPHY NULL,
      gap_end_lat FLOAT NULL,
      gap_end_lng FLOAT NULL,
      gap_meters FLOAT NULL,
      window_minutes INT NULL,
      prior_mode INT NULL,
      next_mode INT NULL,
      mode_imputed INT NULL,
      status INT NOT NULL -- 0=pending 1=donor 2=imputed 3=skipped
    );

    ;WITH f AS (
      SELECT prior_recid, person_id, hhid, pernum, gap_start_time, gap_start_geog, gap_start_lat, gap_start_lng,
             next_recid, gap_end_time, gap_end_geog, gap_end_lat, gap_end_lng, gap_meters, window_minutes,
             prior_mode, next_mode, mode_imputed, [status]
      FROM HHSurvey.fnIdentifyGaps(500)
    )
    INSERT INTO @gaps (gap_id, prior_recid, person_id, hhid, pernum, gap_start_time, gap_start_geog, gap_start_lat, gap_start_lng,
        next_recid, gap_end_time, gap_end_geog, gap_end_lat, gap_end_lng, gap_meters, window_minutes,
        prior_mode, next_mode, mode_imputed, [status])
    SELECT ROW_NUMBER() OVER (ORDER BY person_id, gap_start_time) AS gap_id,
           prior_recid, person_id, hhid, pernum, gap_start_time, gap_start_geog, gap_start_lat, gap_start_lng,
           next_recid, gap_end_time, gap_end_geog, gap_end_lat, gap_end_lng, gap_meters, window_minutes,
           prior_mode, next_mode, mode_imputed, [status]
    FROM f;

    /* 0. Preparation */
    EXEC HHSurvey.tripnum_update; -- ensure sequential

    /* @gaps now populated by helper */
    IF @Debug=1 SELECT * FROM @gaps;
  IF NOT EXISTS (SELECT 1 FROM @gaps) GOTO finalize;

  /* Debug-only assertion: ensure no overlapping gap windows for the same person */
  IF @Debug = 1 AND EXISTS (
    SELECT 1
    FROM @gaps g1
    JOIN @gaps g2 ON g1.person_id = g2.person_id AND g1.gap_id < g2.gap_id
    WHERE g1.gap_start_time < g2.gap_end_time
      AND g2.gap_start_time < g1.gap_end_time
  )
  BEGIN
    RAISERROR('Debug assertion failed: overlapping gaps detected for a person. Review fnIdentifyGaps logic.',16,1);
    RETURN; -- abort early in debug mode to prevent ambiguous gap_id attribution
  END;

    /* 2. Self-donor (same respondent other day) replication */
    IF EXISTS (SELECT 1 FROM @gaps WHERE status=0)
    BEGIN
      -- Gather other-day trips for persons with gaps
      IF OBJECT_ID('tempdb..#gap_base') IS NOT NULL DROP TABLE #gap_base;

      CREATE TABLE #gap_base(
        gap_id INT NOT NULL,
        person_id DECIMAL(19,0) NULL,
        gap_start_geog GEOGRAPHY NULL,
        gap_end_geog GEOGRAPHY NULL,
        gap_start_time DATETIME2 NULL,
        gap_end_time DATETIME2 NULL
      );
      INSERT INTO #gap_base(gap_id, person_id, gap_start_geog, gap_end_geog, gap_start_time, gap_end_time)
      SELECT g.gap_id, g.person_id, g.gap_start_geog, g.gap_end_geog, g.gap_start_time, g.gap_end_time
      FROM @gaps g
      WHERE g.status=0;

      IF OBJECT_ID('tempdb..#other_day_trips') IS NOT NULL DROP TABLE #other_day_trips;
      SELECT t.person_id, t.recid, t.tripnum,
        t.depart_time_timestamp, t.arrival_time_timestamp,
        t.origin_geog, t.dest_geog,
        CONVERT(date, t.depart_time_timestamp) AS trip_date
      INTO #other_day_trips
      FROM HHSurvey.Trip t WITH (NOLOCK)
      WHERE COALESCE(t.psrc_inserted,0)=0 AND t.origin_geog IS NOT NULL AND t.dest_geog IS NOT NULL;

      IF OBJECT_ID('tempdb..#self_candidates') IS NOT NULL DROP TABLE #self_candidates;
      CREATE TABLE #self_candidates (
        gap_id INT NOT NULL,
        person_id DECIMAL(19,0) NULL,
        recid DECIMAL(19,0) NULL,
        tripnum INT NULL,
        depart_time_timestamp DATETIME2 NULL,
        arrival_time_timestamp DATETIME2 NULL,
        origin_geog GEOGRAPHY NULL,
        dest_geog GEOGRAPHY NULL,
        trip_date DATE NULL,
        gap_start_time DATETIME2 NULL,
        gap_end_time DATETIME2 NULL,
        o_dist_start FLOAT NULL,
        d_dist_start FLOAT NULL,
        o_dist_end FLOAT NULL,
        d_dist_end FLOAT NULL
      );
      INSERT INTO #self_candidates (
        gap_id, person_id, recid, tripnum, depart_time_timestamp, arrival_time_timestamp,
        origin_geog, dest_geog, trip_date, gap_start_time, gap_end_time,
        o_dist_start, d_dist_start, o_dist_end, d_dist_end)
      SELECT gb.gap_id, odt.person_id, odt.recid, odt.tripnum, odt.depart_time_timestamp, odt.arrival_time_timestamp,
             odt.origin_geog, odt.dest_geog, odt.trip_date, gb.gap_start_time, gb.gap_end_time,
             odt.origin_geog.STDistance(gb.gap_start_geog) AS o_dist_start,
             odt.dest_geog.STDistance(gb.gap_start_geog)   AS d_dist_start,
             odt.origin_geog.STDistance(gb.gap_end_geog)   AS o_dist_end,
             odt.dest_geog.STDistance(gb.gap_end_geog)     AS d_dist_end
      FROM #gap_base gb
      JOIN #other_day_trips odt ON odt.person_id = gb.person_id
      WHERE CONVERT(date, gb.gap_start_time) <> odt.trip_date; -- exclude same-day

      IF @Debug=1 SELECT TOP 50 * FROM #self_candidates;

      -- Build start/end anchor sequences
      IF OBJECT_ID('tempdb..#self_selected') IS NOT NULL DROP TABLE #self_selected;
      CREATE TABLE #self_selected(
        gap_id INT NOT NULL,
        start_recid DECIMAL(19,0) NULL,
        end_recid DECIMAL(19,0) NULL,
        seq_start DATETIME2 NULL,
        seq_end DATETIME2 NULL,
        trip_count INT NULL,
        seq_minutes INT NULL
      );

      ;WITH anchors AS (
        SELECT sc.*, CASE WHEN sc.o_dist_start < 100 OR sc.d_dist_start < 100 THEN 1 ELSE 0 END AS start_anchor_flag,
               CASE WHEN sc.o_dist_end   < 100 OR sc.d_dist_end   < 100 THEN 1 ELSE 0 END AS end_anchor_flag
        FROM #self_candidates sc
      ), start_trips AS (
        SELECT a1.gap_id, a1.recid AS start_recid, a1.tripnum AS start_tripnum, a1.trip_date
        FROM anchors a1 WHERE a1.start_anchor_flag=1
      ), end_trips AS (
        SELECT a2.gap_id, a2.recid AS end_recid, a2.tripnum AS end_tripnum, a2.trip_date
        FROM anchors a2 WHERE a2.end_anchor_flag=1
      ), sequences AS (
        SELECT s.gap_id, s.start_recid, e.end_recid, s.trip_date,
               s.start_tripnum, e.end_tripnum
        FROM start_trips s
        JOIN end_trips e ON e.gap_id=s.gap_id AND e.trip_date=s.trip_date
        WHERE e.end_tripnum >= s.start_tripnum
      ), span_stats AS (
        SELECT seq.gap_id, seq.start_recid, seq.end_recid,
               MIN(c.depart_time_timestamp) AS seq_start,
               MAX(c.arrival_time_timestamp) AS seq_end,
               COUNT(*) AS trip_count
        FROM sequences seq
        JOIN #self_candidates c ON c.gap_id=seq.gap_id AND c.tripnum BETWEEN seq.start_tripnum AND seq.end_tripnum AND c.trip_date=seq.trip_date
        GROUP BY seq.gap_id, seq.start_recid, seq.end_recid
      ), ranked AS (
        SELECT ss.*, DATEDIFF(MINUTE, ss.seq_start, ss.seq_end) AS seq_minutes,
               ROW_NUMBER() OVER (PARTITION BY ss.gap_id ORDER BY trip_count ASC, DATEDIFF(MINUTE, ss.seq_start, ss.seq_end) ASC, NEWID()) AS rnk
        FROM span_stats ss
      )
      INSERT INTO #self_selected(gap_id, start_recid, end_recid, seq_start, seq_end, trip_count, seq_minutes)
      SELECT gap_id, start_recid, end_recid, seq_start, seq_end, trip_count, seq_minutes
      FROM ranked WHERE rnk=1;

      IF @Debug=1 SELECT * FROM #self_selected;

      IF EXISTS (SELECT 1 FROM #self_selected)
      BEGIN
        IF OBJECT_ID('tempdb..#self_inserted') IS NOT NULL DROP TABLE #self_inserted;
        CREATE TABLE #self_inserted(new_trip_recid DECIMAL(19,0) PRIMARY KEY, gap_id INT NULL);
        ;WITH chosen AS (
          SELECT gap_id, start_recid, end_recid, seq_start, seq_end, seq_minutes FROM #self_selected
        ), seq_trips AS (
          SELECT c.gap_id, c.recid, c.tripnum, c.depart_time_timestamp, c.arrival_time_timestamp,
                 DATEDIFF(SECOND, ch.seq_start, c.depart_time_timestamp) AS depart_offset_sec,
                 DATEDIFF(SECOND, ch.seq_start, c.arrival_time_timestamp) AS arrive_offset_sec,
                 DATEDIFF(SECOND, c.depart_time_timestamp, c.arrival_time_timestamp) AS orig_travel_sec,
                 ch.seq_minutes
          FROM chosen ch
          JOIN #self_candidates c ON c.gap_id=ch.gap_id
          WHERE c.depart_time_timestamp >= ch.seq_start AND c.arrival_time_timestamp <= ch.seq_end
        ), gap_win AS (
            SELECT g.gap_id, g.gap_start_time, g.gap_end_time, DATEDIFF(SECOND, g.gap_start_time, g.gap_end_time) AS window_seconds
            FROM @gaps g WHERE g.status=0
        ), fitted AS (
          SELECT st.*, gw.gap_start_time, gw.gap_end_time, gw.window_seconds,
                 CASE WHEN st.seq_minutes*60 <= gw.window_seconds THEN 1 ELSE 0 END AS fits_no_scale
          FROM seq_trips st JOIN gap_win gw ON gw.gap_id=st.gap_id
        ), timing AS (
          SELECT f.*, 
            CASE WHEN f.fits_no_scale=1 THEN DATEADD(SECOND, f.depart_offset_sec + ((f.window_seconds - MAX(f.seq_minutes*60) OVER(PARTITION BY f.gap_id))/2), f.gap_start_time) END AS shifted_depart_time
          FROM fitted f
        ), scaled AS (
          SELECT t.*, 
            CASE WHEN t.fits_no_scale=0 THEN DATEADD(SECOND, CAST(1.0*t.depart_offset_sec*(t.window_seconds-60)/NULLIF(t.seq_minutes*60,0) AS INT), t.gap_start_time)
                 ELSE t.shifted_depart_time END AS final_depart,
            CASE WHEN t.fits_no_scale=0 THEN DATEADD(SECOND, CAST(1.0*t.arrive_offset_sec*(t.window_seconds-60)/NULLIF(t.seq_minutes*60,0) AS INT), t.gap_start_time)
                 ELSE DATEADD(SECOND, DATEDIFF(SECOND, t.depart_time_timestamp, t.arrival_time_timestamp), t.shifted_depart_time) END AS final_arrive
          FROM timing t
        )
        INSERT INTO HHSurvey.Trip (
          hhid, person_id, pernum, tripnum, psrc_inserted, revision_code, dest_purpose,
          mode_1, modes, travelers_hh, travelers_nonhh, travelers_total,
          origin_lat, origin_lng, origin_geog, dest_lat, dest_lng, dest_geog,
          distance_miles, depart_time_timestamp, arrival_time_timestamp, travel_time
        )
        /* OUTPUT cannot reference SELECT-scope alias g in a plain INSERT; capture recid now, gap_id later */
        OUTPUT inserted.recid, NULL INTO #self_inserted(new_trip_recid, gap_id)
        SELECT g.hhid, g.person_id, g.pernum, 997 AS tripnum, 1, '16s,' AS revision_code, t.dest_purpose,
               t.mode_1, t.modes, t.travelers_hh, t.travelers_nonhh, t.travelers_total,
               t.origin_lat, t.origin_lng, t.origin_geog, t.dest_lat, t.dest_lng, t.dest_geog,
               t.distance_miles,
               sc.final_depart, sc.final_arrive, DATEDIFF(MINUTE, sc.final_depart, sc.final_arrive) AS travel_time
        FROM scaled sc
        JOIN HHSurvey.Trip t ON t.recid = sc.recid
        JOIN @gaps g ON g.gap_id = sc.gap_id
        WHERE sc.final_depart >= g.gap_start_time AND sc.final_arrive <= g.gap_end_time
          AND NOT EXISTS (
            SELECT 1 FROM HHSurvey.Trip r
            WHERE r.person_id = g.person_id
              AND r.depart_time_timestamp < sc.final_arrive
              AND r.arrival_time_timestamp > sc.final_depart
          );

        /* Populate gap_id for inserted self-donor trips by locating gap window containing the trip */
        UPDATE si
          SET gap_id = g.gap_id
        FROM #self_inserted si
        JOIN HHSurvey.Trip it ON it.recid = si.new_trip_recid
        JOIN @gaps g ON g.person_id = it.person_id
          AND it.depart_time_timestamp >= g.gap_start_time
          AND it.arrival_time_timestamp <= g.gap_end_time
        WHERE si.gap_id IS NULL;

        UPDATE g SET status=1
        FROM @gaps g
        WHERE EXISTS (SELECT 1 FROM #self_inserted si WHERE si.gap_id=g.gap_id) AND g.status=0;

        EXEC HHSurvey.tripnum_update;
      END
    END

    /* 3. Household donor search */
    /* Candidate donor events: build simplified timeline of other household members */
    IF OBJECT_ID('tempdb..#donor_candidates') IS NOT NULL DROP TABLE #donor_candidates;
    CREATE TABLE #donor_candidates(
      gap_id INT NOT NULL,
      hhid DECIMAL(19,0) NULL,
      recipient_person_id DECIMAL(19,0) NULL,
      donor_person_id DECIMAL(19,0) NULL,
      recid DECIMAL(19,0) NULL,
      tripnum INT NULL,
      depart_time_timestamp DATETIME2 NULL,
      arrival_time_timestamp DATETIME2 NULL,
      origin_geog GEOGRAPHY NULL,
      dest_geog GEOGRAPHY NULL,
      gap_start_time DATETIME2 NULL,
      gap_end_time DATETIME2 NULL,
      o_dist_start FLOAT NULL,
      d_dist_start FLOAT NULL,
      o_dist_end FLOAT NULL,
      d_dist_end FLOAT NULL
    );
    INSERT INTO #donor_candidates(
      gap_id, hhid, recipient_person_id, donor_person_id, recid, tripnum,
      depart_time_timestamp, arrival_time_timestamp, origin_geog, dest_geog,
      gap_start_time, gap_end_time, o_dist_start, d_dist_start, o_dist_end, d_dist_end)
    SELECT 
      g.gap_id,
      g.hhid,
      g.person_id AS recipient_person_id,
      m.person_id AS donor_person_id,
      t.recid,
      t.tripnum,
      t.depart_time_timestamp,
      t.arrival_time_timestamp,
      t.origin_geog,
      t.dest_geog,
      g.gap_start_time,
      g.gap_end_time,
      t.origin_geog.STDistance(g.gap_start_geog) AS o_dist_start,
      t.dest_geog.STDistance(g.gap_start_geog) AS d_dist_start,
      t.origin_geog.STDistance(g.gap_end_geog)   AS o_dist_end,
      t.dest_geog.STDistance(g.gap_end_geog)     AS d_dist_end
    FROM @gaps g
      JOIN HHSurvey.Trip t WITH (NOLOCK) ON t.hhid = g.hhid AND t.person_id <> g.person_id
      JOIN HHSurvey.person m WITH (NOLOCK) ON m.person_id = t.person_id
    WHERE g.status = 0
      AND COALESCE(t.psrc_inserted,0) = 0
      AND t.arrival_time_timestamp IS NOT NULL AND t.depart_time_timestamp IS NOT NULL
      AND t.depart_time_timestamp >= g.gap_start_time
      AND t.arrival_time_timestamp <= g.gap_end_time;

    /* Identify donors whose sequence spans the entire window with spatial anchors near both endpoints */
    IF OBJECT_ID('tempdb..#selected_donors') IS NOT NULL DROP TABLE #selected_donors;
    CREATE TABLE #selected_donors(
      gap_id INT NOT NULL,
      donor_person_id DECIMAL(19,0) NULL,
      first_depart DATETIME2 NULL,
      last_arrive DATETIME2 NULL,
      has_start_anchor INT NULL,
      has_end_anchor INT NULL,
      trip_count INT NULL,
      span_trip_count INT NULL
    );
    ;WITH anchors AS (
      SELECT dc.*, 
        CASE WHEN dc.d_dist_start < 150 OR dc.o_dist_start < 150 THEN 1 ELSE 0 END AS start_anchor_flag,
        CASE WHEN dc.o_dist_end   < 150 OR dc.d_dist_end   < 150 THEN 1 ELSE 0 END AS end_anchor_flag
      FROM #donor_candidates dc
    ), anchor_bounds AS (
      SELECT gap_id, donor_person_id,
        MIN(CASE WHEN start_anchor_flag=1 THEN depart_time_timestamp END) AS earliest_start_anchor_depart,
        MAX(CASE WHEN end_anchor_flag=1   THEN arrival_time_timestamp END) AS latest_end_anchor_arrive
      FROM anchors
      GROUP BY gap_id, donor_person_id
    ), span_eval AS (
      SELECT a.gap_id, a.donor_person_id,
        ab.earliest_start_anchor_depart AS first_depart,
        ab.latest_end_anchor_arrive     AS last_arrive,
        CASE WHEN ab.earliest_start_anchor_depart IS NOT NULL THEN 1 ELSE 0 END AS has_start_anchor,
        CASE WHEN ab.latest_end_anchor_arrive     IS NOT NULL THEN 1 ELSE 0 END AS has_end_anchor,
        COUNT(DISTINCT a.recid) AS trip_count,
        SUM(CASE WHEN a.depart_time_timestamp BETWEEN ab.earliest_start_anchor_depart AND ab.latest_end_anchor_arrive THEN 1 ELSE 0 END) AS trips_in_span
      FROM anchors a
      JOIN anchor_bounds ab ON ab.gap_id=a.gap_id AND ab.donor_person_id=a.donor_person_id
      GROUP BY a.gap_id, a.donor_person_id, ab.earliest_start_anchor_depart, ab.latest_end_anchor_arrive
    ), qualified AS (
      SELECT s.*, (s.trips_in_span) AS span_trip_count
      FROM span_eval s
  JOIN @gaps g ON g.gap_id = s.gap_id
      WHERE has_start_anchor=1 AND has_end_anchor=1
        AND s.first_depart >= g.gap_start_time
        AND s.last_arrive  <= g.gap_end_time
    ), ranked AS (
      SELECT q.*, ROW_NUMBER() OVER (PARTITION BY q.gap_id ORDER BY q.span_trip_count ASC, NEWID()) AS rnk
      FROM qualified q
    )
    INSERT INTO #selected_donors(gap_id, donor_person_id, first_depart, last_arrive, has_start_anchor, has_end_anchor, trip_count, span_trip_count)
    SELECT gap_id, donor_person_id, first_depart, last_arrive, has_start_anchor, has_end_anchor, trip_count, span_trip_count
    FROM ranked WHERE rnk=1;

    IF @Debug=1 SELECT * FROM #selected_donors;

  /* Replicate donor trips (minimal contiguous anchor sequence with home-home tour pruning) */
    IF EXISTS (SELECT 1 FROM #selected_donors)
    BEGIN
      IF OBJECT_ID('tempdb..#donor_inserted') IS NOT NULL DROP TABLE #donor_inserted;
      /* new_trip_recid captured first; gap_id assigned in a follow-up update to avoid alias binding issue in OUTPUT */
      CREATE TABLE #donor_inserted(new_trip_recid DECIMAL(19,0) PRIMARY KEY, gap_id INT NULL);
      ;WITH donor_span AS (
        SELECT sd.gap_id, t.recid, t.person_id, t.depart_time_timestamp, t.arrival_time_timestamp,
               t.origin_geog, t.dest_geog, t.dest_purpose, t.mode_1, t.modes,
               t.travelers_hh, t.travelers_nonhh, t.travelers_total, t.distance_miles,
               t.origin_lat, t.origin_lng, t.dest_lat, t.dest_lng,
               ROW_NUMBER() OVER (PARTITION BY sd.gap_id ORDER BY t.depart_time_timestamp) AS rn
        FROM #selected_donors sd
        JOIN HHSurvey.Trip t ON t.person_id = sd.donor_person_id
          AND t.depart_time_timestamp >= sd.first_depart
          AND t.arrival_time_timestamp <= sd.last_arrive
          AND COALESCE(t.psrc_inserted,0)=0
      ), paired AS (
        SELECT d.*, LEAD(recid) OVER (PARTITION BY gap_id ORDER BY rn) AS next_recid,
               LEAD(origin_geog) OVER (PARTITION BY gap_id ORDER BY rn) AS next_origin_geog,
               LEAD(dest_geog) OVER (PARTITION BY gap_id ORDER BY rn)   AS next_dest_geog,
               LEAD(dest_purpose) OVER (PARTITION BY gap_id ORDER BY rn) AS next_dest_purpose
        FROM donor_span d
      ), loops AS (
        -- Identify simple out-and-back tours (home -> place -> home) or redundant home-home
        SELECT p.gap_id, p.recid, p.next_recid
        FROM paired p
        WHERE p.next_recid IS NOT NULL
          AND (
                (p.dest_purpose <> 1 AND p.next_dest_purpose = 1 AND p.dest_geog.STDistance(p.next_origin_geog) < 120
                 AND EXISTS (SELECT 1 FROM donor_span h WHERE h.gap_id=p.gap_id AND h.dest_purpose=1 AND h.dest_geog.STDistance(p.origin_geog) < 120)
                 AND EXISTS (SELECT 1 FROM donor_span h2 WHERE h2.gap_id=p.gap_id AND h2.dest_purpose=1 AND h2.dest_geog.STDistance(p.next_dest_geog) < 120)
                )
             OR
                (p.dest_purpose = 1 AND p.next_dest_purpose = 1 AND p.dest_geog.STDistance(p.next_origin_geog) < 80)
              )
      ), to_drop AS (
        SELECT gap_id, recid FROM loops
        UNION ALL
        SELECT gap_id, next_recid FROM loops
      ), filtered AS (
        SELECT d.* FROM donor_span d
        LEFT JOIN to_drop x ON x.gap_id=d.gap_id AND x.recid=d.recid
        WHERE x.recid IS NULL
      )
      INSERT INTO HHSurvey.Trip (
        hhid, person_id, pernum, tripnum, psrc_inserted, revision_code, dest_purpose,
        mode_1, modes, travelers_hh, travelers_nonhh, travelers_total,
        origin_lat, origin_lng, origin_geog, dest_lat, dest_lng, dest_geog,
        distance_miles, depart_time_timestamp, arrival_time_timestamp, travel_time
      )
      OUTPUT inserted.recid, NULL INTO #donor_inserted(new_trip_recid, gap_id)
      SELECT g.hhid, g.person_id, g.pernum, 999, 1, '16d,', f.dest_purpose,
             f.mode_1, f.modes, f.travelers_hh, f.travelers_nonhh, f.travelers_total,
             f.origin_lat, f.origin_lng, f.origin_geog, f.dest_lat, f.dest_lng, f.dest_geog,
             f.distance_miles, f.depart_time_timestamp, f.arrival_time_timestamp,
             DATEDIFF(MINUTE, f.depart_time_timestamp, f.arrival_time_timestamp)
      FROM filtered f
      JOIN #selected_donors sd ON sd.gap_id = f.gap_id
  JOIN @gaps g ON g.gap_id = f.gap_id
      WHERE NOT EXISTS (
        SELECT 1 FROM HHSurvey.Trip r
        WHERE r.person_id = g.person_id
          AND r.recid NOT IN (g.prior_recid, g.next_recid)
          AND r.depart_time_timestamp < f.arrival_time_timestamp
          AND r.arrival_time_timestamp > f.depart_time_timestamp
      );

      /* Derive gap_id for each inserted donor trip by matching its temporal window inside the gap window */
      UPDATE di
        SET gap_id = g.gap_id
      FROM #donor_inserted di
      JOIN HHSurvey.Trip it ON it.recid = di.new_trip_recid
  JOIN @gaps g ON g.person_id = it.person_id
        AND it.depart_time_timestamp >= g.gap_start_time
        AND it.arrival_time_timestamp <= g.gap_end_time
        AND g.status = 0;

      -- Mark gaps with successful donor insertion
      UPDATE g SET status=1
  FROM @gaps g
      WHERE EXISTS (SELECT 1 FROM #donor_inserted di WHERE di.gap_id = g.gap_id) AND g.status=0;

      -- Any selected donors with zero inserted trips become skipped (status=3)
      UPDATE g SET status=3
  FROM @gaps g
      JOIN #selected_donors sd ON sd.gap_id = g.gap_id
      WHERE g.status=0;

      -- Re-sequence affected persons (distinct recipients with donor fills)
      EXEC HHSurvey.tripnum_update;
    END

    /* 3. Dwell statistics table (placeholder) */
    IF OBJECT_ID('tempdb..#dwell_stats') IS NOT NULL DROP TABLE #dwell_stats;
    /* Build dwell duration empirical stats by (dest_purpose, employment, student, overnight_home_flag) */
    ;WITH base_dwells AS (
      SELECT 
        t.person_id,
        t.recid,
        t.dest_purpose,
        p.employment,
        p.student,
        t.arrival_time_timestamp AS arrive_time,
        nxt.depart_time_timestamp AS next_depart,
        t.dest_geog,
        nxt.origin_geog,
        CASE WHEN t.dest_purpose = 1 AND 
                  (DATEPART(HOUR, t.arrival_time_timestamp) <= 3 OR DATEPART(HOUR, nxt.depart_time_timestamp) <= 3) AND
                  DATEDIFF(HOUR, t.arrival_time_timestamp, nxt.depart_time_timestamp) >= 3 THEN 1 ELSE 0 END AS overnight_home_flag,
        DATEDIFF(MINUTE, t.arrival_time_timestamp, nxt.depart_time_timestamp) AS dwell_minutes
      FROM HHSurvey.Trip t WITH (NOLOCK)
      JOIN HHSurvey.Trip nxt WITH (NOLOCK)
        ON nxt.person_id = t.person_id AND nxt.tripnum = t.tripnum + 1
      JOIN HHSurvey.person p WITH (NOLOCK) ON p.person_id = t.person_id
      WHERE t.dest_geog IS NOT NULL AND nxt.origin_geog IS NOT NULL
        AND t.dest_geog.STDistance(nxt.origin_geog) < 100 -- same place
        AND t.arrival_time_timestamp IS NOT NULL AND nxt.depart_time_timestamp IS NOT NULL
        AND DATEDIFF(MINUTE, t.arrival_time_timestamp, nxt.depart_time_timestamp) BETWEEN 1 AND 720
    ), marked AS (
      SELECT *, 
        CASE WHEN dest_purpose <> 1 THEN 0 ELSE overnight_home_flag END AS overnight_home_strat
      FROM base_dwells
    ), stats AS (
      SELECT 
        dest_purpose,
        employment,
        student,
        overnight_home_strat,
        COUNT(*) AS n,
        AVG(CAST(dwell_minutes AS FLOAT)) AS mean_dwell,
        STDEV(CAST(dwell_minutes AS FLOAT)) AS stdev_dwell
      FROM marked
      GROUP BY dest_purpose, employment, student, overnight_home_strat
      HAVING COUNT(*) >= 5
    )
    SELECT * INTO #dwell_stats FROM stats;
    IF @Debug=1 SELECT TOP 50 * FROM #dwell_stats ORDER BY n DESC;

    /* Fallback aggregated levels for sparse matches will be handled via CROSS APPLY during sampling */

    /* 4. Imputation for remaining gaps (placeholder) */
  -- For each status=0 gap: sample dwell, route, insert bridging trip, status=2; if routing fails status=3.
  -- Implement sampling + routing below.
  IF EXISTS (SELECT 1 FROM @gaps WHERE status = 0)
    BEGIN
      -- Random helper (deterministic optional)
      DECLARE @R BIGINT = COALESCE(@Seed, ABS(CHECKSUM(NEWID())));
      DECLARE @A BIGINT = 1103515245, @C BIGINT = 12345, @M BIGINT = 2147483648; -- LCG params

      IF OBJECT_ID('tempdb..#impute') IS NOT NULL DROP TABLE #impute;
      CREATE TABLE #impute(
        gap_id INT PRIMARY KEY,
        prior_recid DECIMAL(19,0) NULL,
        person_id DECIMAL(19,0) NULL,
        hhid DECIMAL(19,0) NULL,
        pernum INT NULL,
        gap_start_time DATETIME2 NULL,
        gap_start_geog GEOGRAPHY NULL,
        gap_start_lat FLOAT NULL,
        gap_start_lng FLOAT NULL,
        next_recid DECIMAL(19,0) NULL,
        gap_end_time DATETIME2 NULL,
        gap_end_geog GEOGRAPHY NULL,
        gap_end_lat FLOAT NULL,
        gap_end_lng FLOAT NULL,
        gap_meters FLOAT NULL,
        window_minutes INT NULL,
        prior_mode INT NULL,
        next_mode INT NULL,
        mode_imputed INT NULL,
        status INT NULL,
        employment INT NULL,
        student INT NULL,
        chosen_mode INT NULL,
        overnight_home_strat INT NULL
      );
      INSERT INTO #impute(
        gap_id, prior_recid, person_id, hhid, pernum, gap_start_time, gap_start_geog, gap_start_lat, gap_start_lng,
        next_recid, gap_end_time, gap_end_geog, gap_end_lat, gap_end_lng, gap_meters, window_minutes, prior_mode,
        next_mode, mode_imputed, status, employment, student, chosen_mode)
      SELECT g.gap_id, g.prior_recid, g.person_id, g.hhid, g.pernum, g.gap_start_time, g.gap_start_geog, g.gap_start_lat, g.gap_start_lng,
             g.next_recid, g.gap_end_time, g.gap_end_geog, g.gap_end_lat, g.gap_end_lng, g.gap_meters, g.window_minutes, g.prior_mode,
             g.next_mode, g.mode_imputed, g.status, p.employment, p.student,
             CASE WHEN g.prior_mode = g.next_mode THEN g.prior_mode ELSE 995 END AS chosen_mode
      FROM @gaps g
      JOIN HHSurvey.person p WITH (NOLOCK) ON p.person_id = g.person_id
      WHERE g.status = 0;

      -- Add overnight strat flag for home start
      ALTER TABLE #impute ADD overnight_home_strat INT NULL;
      UPDATE i SET overnight_home_strat = CASE 
          WHEN EXISTS (SELECT 1 FROM HHSurvey.Trip t WHERE t.recid = i.prior_recid AND t.dest_purpose = 1) AND DATEPART(HOUR, i.gap_start_time) <= 3 THEN 1 ELSE 0 END
      FROM #impute i;

      -- Sample dwell and call routing per row using a cursor (limits API stress). Could batch later if needed.
      DECLARE gap_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT gap_id, gap_start_time, gap_end_time, gap_start_lat, gap_start_lng, gap_end_lat, gap_end_lng,
               employment, student, overnight_home_strat, chosen_mode
        FROM #impute;

      DECLARE @gap_id INT, @start DATETIME2, @end DATETIME2, @olat FLOAT, @olng FLOAT, @dlat FLOAT, @dlng FLOAT,
              @emp INT, @stu INT, @overnight INT, @mode INT;
      DECLARE @window_minutes INT, @sampled_dwell INT, @route_result NVARCHAR(200), @comma INT,
              @distance_mi FLOAT, @travel_minutes INT, @depart DATETIME2, @arrival DATETIME2, @usable INT;

      OPEN gap_cursor;
      FETCH NEXT FROM gap_cursor INTO @gap_id, @start, @end, @olat, @olng, @dlat, @dlng, @emp, @stu, @overnight, @mode;
      WHILE @@FETCH_STATUS = 0
      BEGIN
        SET @window_minutes = DATEDIFF(MINUTE, @start, @end);
        -- Advance RNG
        SET @R = (@A * @R + @C) % @M;
        DECLARE @u FLOAT = CAST(@R AS FLOAT)/@M; -- uniform 0..1
        -- Pull dwell stats with fallback cascade
        DECLARE @mean FLOAT = NULL, @sd FLOAT = NULL;
        SELECT TOP 1 @mean = mean_dwell, @sd = NULLIF(stdev_dwell,0)
        FROM #dwell_stats ds
        WHERE ds.dest_purpose = (SELECT dest_purpose FROM HHSurvey.Trip t WHERE t.recid = (SELECT prior_recid FROM @gaps WHERE gap_id=@gap_id))
          AND ds.employment = @emp AND ds.student = @stu AND ds.overnight_home_strat = COALESCE(@overnight,0)
        ORDER BY n DESC;
        IF @mean IS NULL
        BEGIN
          SELECT TOP 1 @mean = mean_dwell, @sd = NULLIF(stdev_dwell,0)
          FROM #dwell_stats ds
          WHERE ds.employment = @emp AND ds.student = @stu
          ORDER BY n DESC;
        END
        IF @mean IS NULL SELECT TOP 1 @mean = mean_dwell, @sd = NULLIF(stdev_dwell,0) FROM #dwell_stats ORDER BY n DESC; -- global fallback
        IF @mean IS NULL SET @mean = 10; -- absolute fallback
        IF @sd   IS NULL SET @sd = @mean * 0.25; -- heuristic

        -- Simple approx normal using sum of 3 uniforms (central limit)
        SET @R = (@A * @R + @C) % @M; DECLARE @u2 FLOAT = CAST(@R AS FLOAT)/@M;
        SET @R = (@A * @R + @C) % @M; DECLARE @u3 FLOAT = CAST(@R AS FLOAT)/@M;
        DECLARE @z FLOAT = ((@u + @u2 + @u3) / 3.0) - 0.5; -- centered ~uniform-ish; scale to [-0.5,0.5]
        SET @sampled_dwell = CAST(ROUND(@mean + @z * 2 * @sd,0) AS INT); -- expand factor 2 for variability
        IF @sampled_dwell < 1 SET @sampled_dwell = 1;
        IF @sampled_dwell > (@window_minutes - 1) SET @sampled_dwell = @window_minutes / 2; -- quick clamp

        -- Routing call
        SET @route_result = Elmer.dbo.route_mi_min(@olng, @olat, @dlng, @dlat,
          CASE 
            WHEN EXISTS (SELECT 1 FROM HHSurvey.automodes WHERE mode_id=@mode) THEN 'driving'
            WHEN EXISTS (SELECT 1 FROM HHSurvey.transitmodes WHERE mode_id=@mode) THEN 'transit'
            WHEN EXISTS (SELECT 1 FROM HHSurvey.bikemodes WHERE mode_id=@mode) THEN 'bicycling'
            WHEN @mode = 1 THEN 'walking'
            ELSE 'driving'
          END, @GoogleKey, DATEADD(MINUTE, @window_minutes/2, @start));

        IF @route_result IS NULL
        BEGIN
          UPDATE @gaps SET status = 3 WHERE gap_id=@gap_id; -- skipped due to routing fail
        END
        ELSE
        BEGIN
          SET @comma = CHARINDEX(',', @route_result);
          SET @distance_mi = TRY_CONVERT(FLOAT, LEFT(@route_result, @comma-1));
          SET @travel_minutes = TRY_CONVERT(INT, ROUND(TRY_CONVERT(FLOAT, SUBSTRING(@route_result, @comma+1, 50)),0));
          IF @travel_minutes IS NULL OR @travel_minutes <=0
          BEGIN
            UPDATE @gaps SET status=3 WHERE gap_id=@gap_id;
          END
          ELSE
          BEGIN
             -- If dwell + travel > window, center
             IF (@sampled_dwell + @travel_minutes) > @window_minutes
             BEGIN
               DECLARE @total INT = @sampled_dwell + @travel_minutes;
               DECLARE @excess INT = @total - @window_minutes;
               -- Reduce dwell proportionally
               SET @sampled_dwell = @sampled_dwell - (@excess/2);
               IF @sampled_dwell < 1 SET @sampled_dwell = 1;
             END
             SET @depart = DATEADD(MINUTE, @sampled_dwell, @start);
             SET @arrival = DATEADD(MINUTE, @travel_minutes, @depart);
             IF @arrival > @end
             BEGIN
               -- Center trip instead: place travel in middle
               DECLARE @mid DATETIME2 = DATEADD(MINUTE, @window_minutes/2, @start);
               SET @depart = DATEADD(MINUTE, -(@travel_minutes/2), @mid);
               SET @arrival = DATEADD(MINUTE, @travel_minutes, @depart);
             END

             INSERT INTO HHSurvey.Trip (
               hhid, person_id, pernum, tripnum, psrc_inserted, revision_code, dest_purpose,
               mode_1, modes, travelers_hh, travelers_nonhh, travelers_total,
               origin_lat, origin_lng, origin_geog, dest_lat, dest_lng, dest_geog,
               distance_miles, depart_time_timestamp, arrival_time_timestamp, travel_time
             )
             SELECT g.hhid, g.person_id, g.pernum, 998, 1, '16i,', -9998,
               @mode, CAST(@mode AS NVARCHAR(20)), -9997, -9997, -9997,
               g.gap_start_lat, g.gap_start_lng, g.gap_start_geog,
               g.gap_end_lat, g.gap_end_lng, g.gap_end_geog,
               @distance_mi, @depart, @arrival, @travel_minutes
             FROM @gaps g 
             WHERE g.gap_id=@gap_id
               AND NOT EXISTS (
                 SELECT 1 FROM HHSurvey.Trip r
                 WHERE r.person_id = g.person_id
                   AND r.depart_time_timestamp < @arrival
                   AND r.arrival_time_timestamp > @depart
               );

            IF @Debug=1
            BEGIN
              SELECT TOP 5 *
              FROM @gaps;
            END  

             UPDATE @gaps SET status=2 WHERE gap_id=@gap_id;
          END
        END

        FETCH NEXT FROM gap_cursor INTO @gap_id, @start, @end, @olat, @olng, @dlat, @dlng, @emp, @stu, @overnight, @mode;
      END
      CLOSE gap_cursor; DEALLOCATE gap_cursor;

      -- Resequence after imputed inserts
      EXEC HHSurvey.tripnum_update;
    END

    -- Final sequencing prior to finalize
    EXEC HHSurvey.tripnum_update;

finalize:
    EXEC HHSurvey.recalculate_after_edit;

    -- Summary logging
    IF @Debug=1 OR 1=1 -- always output basic counts
    BEGIN
      SELECT 
        COUNT(*) AS gaps_total,
        SUM(CASE WHEN status=1 THEN 1 ELSE 0 END) AS donor_filled,
        SUM(CASE WHEN status=2 THEN 1 ELSE 0 END) AS imputed_filled,
        SUM(CASE WHEN status=3 THEN 1 ELSE 0 END) AS skipped
  FROM @gaps;
    END

  END TRY
  BEGIN CATCH
    IF @Debug=1 SELECT ERROR_NUMBER() AS err_no, ERROR_MESSAGE() AS err_msg;
    THROW;
  END CATCH
END
GO

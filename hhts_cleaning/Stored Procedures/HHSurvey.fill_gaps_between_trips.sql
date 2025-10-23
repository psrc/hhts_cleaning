SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*
Procedure: HHSurvey.fill_gaps_between_trips
Purpose: Fill person-level gaps between trips using three-tier hierarchy:
  1. Household donor replication (same day, other HH member) with optional compression
  2. Self donor (other day) with minimal forward shift (1-min dwell buffers) if needed
  3. Single imputed bridging trip (sampled dwell + routed travel) with enforced 1-min buffers
Status codes: 0=unfilled, 1=donor filled, 2=imputed, 3=skipped/failed
Tripnum placeholders before resequencing: HH=999, Self=997, Imputed=998
Revision codes appended: '16d,' / '16s,' / '16i,'
Assumptions: dest_is_home column exists; if not, home identified by dest_purpose=1.
*/
CREATE    PROCEDURE [HHSurvey].[fill_gaps_between_trips]
  @GoogleKey NVARCHAR(100),
  @Debug BIT = 0,
  @Seed BIGINT = NULL

AS
BEGIN
  SET NOCOUNT ON;
  SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
  BEGIN TRY

    ------------------------------------------------------------
    -- Phase 0: Identify gaps
    ------------------------------------------------------------
    DECLARE @gaps TABLE(
      gap_id INT PRIMARY KEY,
      prior_recid DECIMAL(19,0), person_id DECIMAL(19,0), hhid DECIMAL(19,0), pernum INT,
      gap_start_time DATETIME2, gap_start_geog GEOGRAPHY, gap_start_lat FLOAT, gap_start_lng FLOAT,
      next_recid DECIMAL(19,0), gap_end_time DATETIME2, gap_end_geog GEOGRAPHY, gap_end_lat FLOAT, gap_end_lng FLOAT,
      gap_meters FLOAT, window_minutes INT,
      prior_mode INT, next_mode INT, mode_imputed INT, [status] INT
    );
    INSERT INTO @gaps SELECT * FROM HHSurvey.fnIdentifyGaps(500);
    IF @Debug=1 SELECT TOP 20 * FROM @gaps ORDER BY gap_id;

    ------------------------------------------------------------
    -- Phase 1: Household donor replication
    ------------------------------------------------------------
  IF EXISTS (SELECT 1 FROM @gaps WHERE [status]=0)
    BEGIN
      DECLARE @AnchorHH INT = 250;
      IF OBJECT_ID('tempdb..#hh_candidates') IS NOT NULL DROP TABLE #hh_candidates;
      CREATE TABLE #hh_candidates(
        gap_id INT, donor_person_id DECIMAL(19,0), recid DECIMAL(19,0), tripnum INT,
        depart_time DATETIME2, arrive_time DATETIME2,
        origin_geog GEOGRAPHY, dest_geog GEOGRAPHY,
        origin_lat FLOAT, origin_lng FLOAT, dest_lat FLOAT, dest_lng FLOAT,
        start_origin_dist FLOAT, end_dest_dist FLOAT,
        dest_is_home BIT, dest_purpose INT, travelers_hh INT, distance_miles FLOAT
      );
      INSERT INTO #hh_candidates
      SELECT g.gap_id, t.person_id, t.recid, t.tripnum,
             t.depart_time_timestamp, t.arrival_time_timestamp,
             t.origin_geog, t.dest_geog,
             t.origin_lat, t.origin_lng, t.dest_lat, t.dest_lng,
             t.origin_geog.STDistance(g.gap_start_geog) AS start_origin_dist,
             t.dest_geog.STDistance(g.gap_end_geog) AS end_dest_dist,
             COALESCE(t.dest_is_home, CASE WHEN t.dest_purpose=1 THEN 1 ELSE 0 END) AS dest_is_home,
             t.dest_purpose, t.travelers_hh, t.distance_miles
      FROM @gaps g
      JOIN HHSurvey.Trip t WITH (NOLOCK) ON t.hhid=g.hhid AND t.person_id<>g.person_id
      WHERE g.[status]=0 AND COALESCE(t.psrc_inserted,0)=0
        AND t.origin_geog IS NOT NULL AND t.dest_geog IS NOT NULL
        AND t.depart_time_timestamp >= g.gap_start_time
        AND t.arrival_time_timestamp <= g.gap_end_time;

      IF OBJECT_ID('tempdb..#hh_sequences') IS NOT NULL DROP TABLE #hh_sequences;
      CREATE TABLE #hh_sequences(
        gap_id INT, donor_person_id DECIMAL(19,0), start_recid DECIMAL(19,0), end_recid DECIMAL(19,0),
        seq_start DATETIME2, seq_end DATETIME2, trip_count INT,
        travelers_hh_sum INT, distance_sum FLOAT
      );

      ;WITH starts AS (SELECT * FROM #hh_candidates WHERE start_origin_dist <= @AnchorHH),
           ends   AS (SELECT * FROM #hh_candidates WHERE end_dest_dist   <= @AnchorHH),
           pairs  AS (
             SELECT s.gap_id, s.donor_person_id, s.recid AS start_recid, e.recid AS end_recid,
                    s.depart_time AS seq_start, e.arrive_time AS seq_end
             FROM starts s
             JOIN ends e ON e.gap_id=s.gap_id AND e.donor_person_id=s.donor_person_id AND e.arrive_time>=s.depart_time
           ), seq_trips AS (
             SELECT p.gap_id, p.donor_person_id, p.start_recid, p.end_recid,
                    c.recid, c.depart_time, c.arrive_time, c.dest_is_home, c.dest_purpose, c.travelers_hh, c.distance_miles,
                    p.seq_start, p.seq_end,
                    ROW_NUMBER() OVER(PARTITION BY p.gap_id,p.donor_person_id,p.start_recid,p.end_recid ORDER BY c.depart_time, c.recid) AS pos,
                    COUNT(*) OVER(PARTITION BY p.gap_id,p.donor_person_id,p.start_recid,p.end_recid) AS total_trips
             FROM pairs p
             JOIN #hh_candidates c ON c.gap_id=p.gap_id AND c.donor_person_id=p.donor_person_id
               AND c.depart_time>=p.seq_start AND c.arrive_time<=p.seq_end
           ),
           -- Exclude any sequence where any trip has dest_purpose=10
           valid_sequences AS (
             SELECT gap_id, donor_person_id, start_recid, end_recid
             FROM seq_trips
             GROUP BY gap_id, donor_person_id, start_recid, end_recid
             HAVING SUM(CASE WHEN dest_purpose = 10 THEN 1 ELSE 0 END) = 0
           ),
           aggregated AS (
             SELECT gap_id, donor_person_id, start_recid, end_recid,
                    MIN(seq_start) AS seq_start, MAX(seq_end) AS seq_end,
                    COUNT(*) AS trip_count,
                    SUM(travelers_hh) AS travelers_hh_sum,
                    SUM(distance_miles) AS distance_sum
             FROM seq_trips
             WHERE EXISTS (
               SELECT 1 FROM valid_sequences v
               WHERE v.gap_id = seq_trips.gap_id
                 AND v.donor_person_id = seq_trips.donor_person_id
                 AND v.start_recid = seq_trips.start_recid
                 AND v.end_recid = seq_trips.end_recid
             )
             GROUP BY gap_id, donor_person_id, start_recid, end_recid
           )
      INSERT INTO #hh_sequences
      SELECT gap_id, donor_person_id, start_recid, end_recid, seq_start, seq_end, trip_count, travelers_hh_sum, distance_sum
      FROM aggregated;

      IF OBJECT_ID('tempdb..#hh_selected') IS NOT NULL DROP TABLE #hh_selected;
      CREATE TABLE #hh_selected(
        gap_id INT PRIMARY KEY,
        donor_person_id DECIMAL(19,0), start_recid DECIMAL(19,0), end_recid DECIMAL(19,0),
        seq_start DATETIME2, seq_end DATETIME2, trip_count INT,
        travelers_hh_sum INT, distance_sum FLOAT
      );
      ;WITH ranked AS (
        SELECT hs.*, ROW_NUMBER() OVER(PARTITION BY hs.gap_id ORDER BY hs.trip_count ASC, hs.travelers_hh_sum DESC, hs.distance_sum ASC, NEWID()) AS rnk
        FROM #hh_sequences hs
      )
      INSERT INTO #hh_selected
      SELECT gap_id, donor_person_id, start_recid, end_recid, seq_start, seq_end, trip_count, travelers_hh_sum, distance_sum
      FROM ranked WHERE rnk=1;

      IF EXISTS (SELECT 1 FROM #hh_selected)
      BEGIN
        IF OBJECT_ID('tempdb..#hh_inserted') IS NOT NULL DROP TABLE #hh_inserted;
        CREATE TABLE #hh_inserted(new_trip_recid DECIMAL(19,0) PRIMARY KEY, gap_id INT NOT NULL);

        -- List donor trips to copy (respect compression trimming)
        ;WITH chosen AS (
          SELECT s.*, g.person_id AS target_person_id, g.hhid, g.pernum
          FROM #hh_selected s JOIN @gaps g ON g.gap_id=s.gap_id
        )
        INSERT INTO HHSurvey.Trip (
          hhid, person_id, pernum, tripnum, psrc_inserted, revision_code, dest_purpose,
          mode_1, modes, travelers_hh, travelers_nonhh, travelers_total,
          origin_lat, origin_lng, origin_geog, dest_lat, dest_lng, dest_geog,
          distance_miles, depart_time_timestamp, arrival_time_timestamp, travel_time
        )
        SELECT chosen.hhid, chosen.target_person_id, chosen.pernum, 999, 1, '16d,', t.dest_purpose,
               t.mode_1, t.modes, t.travelers_hh,
               0 AS travelers_nonhh, t.travelers_hh AS travelers_total,
               t.origin_lat, t.origin_lng, t.origin_geog, t.dest_lat, t.dest_lng, t.dest_geog,
               t.distance_miles, t.depart_time_timestamp, t.arrival_time_timestamp,
               DATEDIFF(MINUTE, t.depart_time_timestamp, t.arrival_time_timestamp) AS travel_time
        FROM chosen
        JOIN #hh_candidates c ON c.gap_id=chosen.gap_id AND c.donor_person_id=chosen.donor_person_id
          AND c.depart_time>=chosen.seq_start AND c.arrive_time<=chosen.seq_end
        JOIN HHSurvey.Trip t ON t.recid=c.recid
        WHERE NOT EXISTS (
          SELECT 1 FROM HHSurvey.Trip r
          WHERE r.person_id = chosen.target_person_id
            AND r.depart_time_timestamp < t.arrival_time_timestamp
            AND r.arrival_time_timestamp > t.depart_time_timestamp
        );
        INSERT INTO #hh_inserted(new_trip_recid, gap_id)
        SELECT t2.recid, g.gap_id
        FROM @gaps g
        JOIN HHSurvey.Trip t2 ON t2.person_id = g.person_id
        WHERE g.[status]=0
          AND t2.tripnum = 999
          AND t2.revision_code LIKE '%16d,%'
          AND t2.depart_time_timestamp >= g.gap_start_time
          AND t2.arrival_time_timestamp <= g.gap_end_time;

        UPDATE g SET [status]=1 FROM @gaps g WHERE EXISTS (SELECT 1 FROM #hh_inserted h WHERE h.gap_id=g.gap_id) AND g.[status]=0;
        EXEC HHSurvey.tripnum_update;
      END
    END

    ------------------------------------------------------------
    -- Phase 2: Self donor replication
    ------------------------------------------------------------
  IF EXISTS (SELECT 1 FROM @gaps WHERE [status]=0)
    BEGIN
      DECLARE @AnchorSelf INT = 250;
      IF OBJECT_ID('tempdb..#self_candidates') IS NOT NULL DROP TABLE #self_candidates;
      CREATE TABLE #self_candidates(
        gap_id INT, person_id DECIMAL(19,0), recid DECIMAL(19,0), tripnum INT,
        trip_date DATE, depart_time DATETIME2, arrive_time DATETIME2,
        origin_geog GEOGRAPHY, dest_geog GEOGRAPHY,
        origin_lat FLOAT, origin_lng FLOAT, dest_lat FLOAT, dest_lng FLOAT,
        start_origin_dist FLOAT, end_dest_dist FLOAT, distance_miles FLOAT
      );
      INSERT INTO #self_candidates
      SELECT g.gap_id, t.person_id, t.recid, t.tripnum,
             CAST(t.depart_time_timestamp AS DATE) AS trip_date,
             t.depart_time_timestamp, t.arrival_time_timestamp,
             t.origin_geog, t.dest_geog,
             t.origin_lat, t.origin_lng, t.dest_lat, t.dest_lng,
             t.origin_geog.STDistance(g.gap_start_geog) AS start_origin_dist,
             t.dest_geog.STDistance(g.gap_end_geog) AS end_dest_dist,
             t.distance_miles
      FROM @gaps g
      JOIN HHSurvey.Trip t ON t.person_id=g.person_id
      WHERE g.[status]=0 AND COALESCE(t.psrc_inserted,0)=0
        AND t.origin_geog IS NOT NULL AND t.dest_geog IS NOT NULL
        AND CAST(t.depart_time_timestamp AS DATE) <> CAST(g.gap_start_time AS DATE);

      IF OBJECT_ID('tempdb..#self_sequences') IS NOT NULL DROP TABLE #self_sequences;
      CREATE TABLE #self_sequences(
        gap_id INT, person_id DECIMAL(19,0), start_recid DECIMAL(19,0), end_recid DECIMAL(19,0),
        seq_start DATETIME2, seq_end DATETIME2, trip_count INT,
        distance_sum FLOAT, needs_shift BIT
      );
      ;WITH starts AS (SELECT * FROM #self_candidates WHERE start_origin_dist <= @AnchorSelf),
           ends   AS (SELECT * FROM #self_candidates WHERE end_dest_dist   <= @AnchorSelf),
           pairs  AS (
             SELECT s.gap_id, s.person_id, s.recid AS start_recid, e.recid AS end_recid, s.trip_date
             FROM starts s JOIN ends e ON e.gap_id=s.gap_id AND e.person_id=s.person_id AND e.trip_date=s.trip_date AND e.tripnum>=s.tripnum
           ), seq AS (
             /* Use TOP 1 with gap filter to avoid multi-row scalar subquery errors */
             SELECT p.gap_id, p.person_id, p.start_recid, p.end_recid,
                    c.recid, c.depart_time, c.arrive_time, c.distance_miles,
                    MIN(c.depart_time) OVER(PARTITION BY p.gap_id,p.person_id,p.start_recid,p.end_recid) AS seq_start,
                    MAX(c.arrive_time) OVER(PARTITION BY p.gap_id,p.person_id,p.start_recid,p.end_recid) AS seq_end
             FROM pairs p
             JOIN #self_candidates c 
               ON c.gap_id=p.gap_id 
              AND c.person_id=p.person_id 
              AND c.trip_date=p.trip_date 
              AND c.tripnum BETWEEN 
                    (SELECT TOP 1 sc.tripnum FROM #self_candidates sc WHERE sc.recid=p.start_recid AND sc.gap_id=p.gap_id ORDER BY sc.tripnum)
                    AND 
                    (SELECT TOP 1 sc.tripnum FROM #self_candidates sc WHERE sc.recid=p.end_recid AND sc.gap_id=p.gap_id ORDER BY sc.tripnum)
           ), agg AS (
             SELECT gap_id, person_id, start_recid, end_recid,
                    MIN(seq_start) AS seq_start, MAX(seq_end) AS seq_end,
                    COUNT(DISTINCT recid) AS trip_count,
                    SUM(distance_miles) AS distance_sum
             FROM seq GROUP BY gap_id, person_id, start_recid, end_recid
           )
      INSERT INTO #self_sequences
      SELECT a.gap_id, a.person_id, a.start_recid, a.end_recid, a.seq_start, a.seq_end, a.trip_count,
             a.distance_sum,
             CASE WHEN DATEADD(MINUTE,-1,a.seq_start) >= g.gap_start_time AND DATEADD(MINUTE,1,a.seq_end) <= g.gap_end_time THEN 0 ELSE 1 END AS needs_shift
      FROM agg a JOIN @gaps g ON g.gap_id=a.gap_id AND g.[status]=0;

      IF OBJECT_ID('tempdb..#self_selected') IS NOT NULL DROP TABLE #self_selected;
      CREATE TABLE #self_selected(
        gap_id INT PRIMARY KEY, person_id DECIMAL(19,0), start_recid DECIMAL(19,0), end_recid DECIMAL(19,0),
        seq_start DATETIME2, seq_end DATETIME2, trip_count INT, distance_sum FLOAT, needs_shift BIT
      );
      ;WITH ranked AS (
        SELECT s.*, ROW_NUMBER() OVER(PARTITION BY s.gap_id ORDER BY s.trip_count ASC, s.needs_shift ASC, s.distance_sum ASC, NEWID()) AS rnk
        FROM #self_sequences s
      )
      INSERT INTO #self_selected
      SELECT gap_id, person_id, start_recid, end_recid, seq_start, seq_end, trip_count, distance_sum, needs_shift FROM ranked WHERE rnk=1;

      IF EXISTS (SELECT 1 FROM #self_selected)
      BEGIN
        IF OBJECT_ID('tempdb..#self_inserted') IS NOT NULL DROP TABLE #self_inserted;
        CREATE TABLE #self_inserted(new_trip_recid DECIMAL(19,0) PRIMARY KEY, gap_id INT);

        ;WITH chosen AS (
          SELECT s.*, g.gap_start_time, g.gap_end_time, g.hhid, g.pernum
          FROM #self_selected s JOIN @gaps g ON g.gap_id=s.gap_id
        ), trips AS (
          SELECT c.*, ch.gap_start_time, ch.gap_end_time, ch.needs_shift
          FROM chosen ch
          JOIN #self_candidates c ON c.gap_id=ch.gap_id AND c.person_id=ch.person_id
           AND c.depart_time>=ch.seq_start AND c.arrive_time<=ch.seq_end
        ), shift_calc AS (
          SELECT gap_id,
                 MIN(depart_time) AS seq_start,
                 MAX(arrive_time) AS seq_end,
                 MIN(gap_start_time) AS gap_start_time,
                 MAX(gap_end_time) AS gap_end_time
          FROM trips GROUP BY gap_id
        ), shift_amt AS (
          SELECT sc.*, CASE WHEN (DATEADD(MINUTE,-1,seq_start) >= gap_start_time AND DATEADD(MINUTE,1,seq_end) <= gap_end_time) THEN 0
                            ELSE CASE 
                                   WHEN DATEDIFF(SECOND, seq_start, seq_end) > DATEDIFF(SECOND, DATEADD(MINUTE,1,gap_start_time), DATEADD(MINUTE,-1,gap_end_time)) THEN NULL -- cannot fit
                                   WHEN seq_start < DATEADD(MINUTE,1,gap_start_time) THEN DATEDIFF(SECOND, seq_start, DATEADD(MINUTE,1,gap_start_time))
                                   ELSE 0 END END AS shift_seconds
          FROM shift_calc sc
        ), shifted AS (
          SELECT t.*, sa.shift_seconds
          FROM trips t JOIN shift_amt sa ON sa.gap_id=t.gap_id
          WHERE sa.shift_seconds IS NOT NULL
        ), final_times AS (
          SELECT gap_id, person_id, recid,
                 DATEADD(SECOND, shift_seconds, depart_time) AS final_depart,
                 DATEADD(SECOND, shift_seconds, arrive_time) AS final_arrive
          FROM shifted
        )
        INSERT INTO HHSurvey.Trip (
          hhid, person_id, pernum, tripnum, psrc_inserted, revision_code, dest_purpose,
          mode_1, modes, travelers_hh, travelers_nonhh, travelers_total,
          origin_lat, origin_lng, origin_geog, dest_lat, dest_lng, dest_geog,
          distance_miles, depart_time_timestamp, arrival_time_timestamp, travel_time
        )
        SELECT g.hhid, g.person_id, g.pernum, 997, 1, '16s,', src.dest_purpose,
               src.mode_1, src.modes, src.travelers_hh, src.travelers_nonhh, src.travelers_total,
               src.origin_lat, src.origin_lng, src.origin_geog, src.dest_lat, src.dest_lng, src.dest_geog,
               src.distance_miles, ft.final_depart, ft.final_arrive,
               DATEDIFF(MINUTE, ft.final_depart, ft.final_arrive) AS travel_time
        FROM final_times ft
        JOIN #self_candidates sc ON sc.recid=ft.recid
        JOIN HHSurvey.Trip src ON src.recid = sc.recid
        JOIN #self_selected sel ON sel.gap_id=ft.gap_id
        JOIN @gaps g ON g.gap_id=sel.gap_id
        WHERE ft.final_depart >= g.gap_start_time AND ft.final_arrive <= g.gap_end_time
          AND NOT EXISTS (
            SELECT 1 FROM HHSurvey.Trip r
            WHERE r.person_id=g.person_id
              AND r.depart_time_timestamp < ft.final_arrive
              AND r.arrival_time_timestamp > ft.final_depart);
        INSERT INTO #self_inserted(new_trip_recid, gap_id)
        SELECT t2.recid, g.gap_id
        FROM @gaps g
        JOIN HHSurvey.Trip t2 ON t2.person_id = g.person_id
        WHERE g.[status]=0
          AND t2.tripnum = 997
          AND t2.revision_code LIKE '%16s,%'
          AND t2.depart_time_timestamp >= g.gap_start_time
          AND t2.arrival_time_timestamp <= g.gap_end_time;

        UPDATE g SET [status]=1 FROM @gaps g WHERE EXISTS (SELECT 1 FROM #self_inserted s WHERE s.gap_id=g.gap_id) AND g.[status]=0;
        EXEC HHSurvey.tripnum_update;
      END
    END

    ------------------------------------------------------------
    -- Phase 3: Dwell statistics for imputation
    ------------------------------------------------------------
    IF OBJECT_ID('tempdb..#dwell_stats') IS NOT NULL DROP TABLE #dwell_stats;
    ;WITH base AS (
      SELECT t.person_id, t.recid, t.dest_purpose, p.employment, p.student,
             t.arrival_time_timestamp AS arrive_time,
             nxt.depart_time_timestamp AS next_depart,
             DATEDIFF(MINUTE, t.arrival_time_timestamp, nxt.depart_time_timestamp) AS dwell_minutes,
             CASE WHEN t.dest_purpose=1 AND (DATEPART(HOUR,t.arrival_time_timestamp)<=3 OR DATEPART(HOUR,nxt.depart_time_timestamp)<=3)
                       AND DATEDIFF(HOUR,t.arrival_time_timestamp,nxt.depart_time_timestamp) >=3 THEN 1 ELSE 0 END AS overnight_home_flag
      FROM HHSurvey.Trip t WITH (NOLOCK)
      JOIN HHSurvey.Trip nxt WITH (NOLOCK) ON nxt.person_id=t.person_id AND nxt.tripnum=t.tripnum+1
      JOIN HHSurvey.Person p WITH (NOLOCK) ON p.person_id=t.person_id
      WHERE t.arrival_time_timestamp IS NOT NULL AND nxt.depart_time_timestamp IS NOT NULL
        AND DATEDIFF(MINUTE, t.arrival_time_timestamp, nxt.depart_time_timestamp) BETWEEN 1 AND 720
    ), strat AS (
      SELECT *, CASE WHEN dest_purpose<>1 THEN 0 ELSE overnight_home_flag END AS overnight_home_strat FROM base
    ), stats AS (
      SELECT dest_purpose, employment, student, overnight_home_strat,
             COUNT(*) AS n,
             AVG(CAST(dwell_minutes AS FLOAT)) AS mean_dwell,
             STDEV(CAST(dwell_minutes AS FLOAT)) AS stdev_dwell
      FROM strat GROUP BY dest_purpose, employment, student, overnight_home_strat HAVING COUNT(*)>=5
    )
    SELECT * INTO #dwell_stats FROM stats;

    ------------------------------------------------------------
    -- Phase 4: Imputation (remaining gaps) with prefilter + batching
    -- 1) Prefilter gaps for feasibility (distance/time) similar to legacy function
    -- 2) Prune mode profile (walk/bike/transit) by distance thresholds; fallback to driving
    -- 3) Process in batches of 25 with a 250ms delay between batches
    ------------------------------------------------------------
  IF EXISTS (SELECT 1 FROM @gaps WHERE [status]=0)
    BEGIN
      DECLARE @R BIGINT = COALESCE(@Seed, ABS(CHECKSUM(NEWID())));
      DECLARE @A BIGINT=1103515245,@C BIGINT=12345,@M BIGINT=2147483648; -- LCG for deterministic sampling
      IF OBJECT_ID('tempdb..#imputed') IS NOT NULL DROP TABLE #imputed;
      CREATE TABLE #imputed(new_recid DECIMAL(19,0), gap_id INT);

      /* Prefilter candidate gaps into a work table (#imp_candidates) */
      IF OBJECT_ID('tempdb..#imp_candidates') IS NOT NULL DROP TABLE #imp_candidates;
      ;WITH base AS (
        SELECT g.*, 
               (g.gap_meters * 0.000621371) AS gap_miles,
               DATEDIFF(MINUTE, g.gap_start_time, g.gap_end_time) AS window_minutes_calc,
               CASE 
                 WHEN EXISTS (SELECT 1 FROM HHSurvey.automodes    am WHERE am.mode_id = g.mode_imputed) THEN 25
                 WHEN EXISTS (SELECT 1 FROM HHSurvey.transitmodes tm WHERE tm.mode_id = g.mode_imputed) THEN 12
                 WHEN EXISTS (SELECT 1 FROM HHSurvey.bikemodes    bm WHERE bm.mode_id = g.mode_imputed) THEN 10
                 WHEN g.mode_imputed = 1 THEN 3
                 ELSE 25
               END AS naive_speed_mph
        FROM @gaps g
        WHERE g.[status]=0
          AND g.gap_start_lat IS NOT NULL AND g.gap_start_lng IS NOT NULL
          AND g.gap_end_lat   IS NOT NULL AND g.gap_end_lng   IS NOT NULL
      ), pre AS (
        SELECT *,
               CASE WHEN naive_speed_mph>0 THEN CEILING((gap_miles/naive_speed_mph)*60.0)+5 END AS naive_min_minutes,
               window_minutes_calc - ISNULL(CEILING((gap_miles/NULLIF(naive_speed_mph,0))*60.0)+5, 999999) AS slack_minutes
        FROM base
      )
      SELECT gap_id, prior_recid, person_id, hhid, pernum,
             gap_start_time, gap_end_time, gap_start_lat, gap_start_lng, gap_end_lat, gap_end_lng,
             gap_meters, gap_miles, window_minutes_calc AS window_minutes,
             prior_mode, next_mode, mode_imputed,
             naive_speed_mph, naive_min_minutes, slack_minutes
      INTO #imp_candidates
      FROM pre
      WHERE naive_min_minutes IS NOT NULL
        AND window_minutes_calc >= naive_min_minutes
        AND gap_miles <= 50.0;  -- legacy upper bound

      IF EXISTS (SELECT 1 FROM #imp_candidates)
      BEGIN
        DECLARE @BATCH_SIZE INT = 25;
        WHILE EXISTS (SELECT 1 FROM #imp_candidates)
        BEGIN
          IF OBJECT_ID('tempdb..#imp_batch') IS NOT NULL DROP TABLE #imp_batch;
          SELECT TOP (@BATCH_SIZE) *
          INTO #imp_batch
          FROM #imp_candidates
          ORDER BY slack_minutes DESC, gap_miles ASC, person_id, gap_id;

          /* Process this batch row-by-row using a cursor (simpler integration with existing dwell sampling code) */
          DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT gap_id, prior_recid, gap_start_time, gap_end_time, gap_start_lat, gap_start_lng, gap_end_lat, gap_end_lng,
                   prior_mode, next_mode, person_id, hhid, pernum, gap_meters, gap_miles, mode_imputed
            FROM #imp_batch;

          DECLARE @gap_id INT,@prior_recid DECIMAL(19,0),@gs DATETIME2,@ge DATETIME2,@olat FLOAT,@olng FLOAT,@dlat FLOAT,@dlng FLOAT,
                  @pmode INT,@nmode INT,@pid DECIMAL(19,0),@hhid DECIMAL(19,0),@pernum INT,
                  @gap_meters FLOAT,@gap_miles FLOAT,@mode_imputed INT;

          DECLARE @window INT,@sample_dwell INT,@mean FLOAT,@sd FLOAT,@route NVARCHAR(200),@comma INT,@dist FLOAT,@travel INT;
          DECLARE @depart DATETIME2,@arrive DATETIME2,@mode INT,@Buffer INT=1;

          OPEN cur; FETCH NEXT FROM cur INTO @gap_id,@prior_recid,@gs,@ge,@olat,@olng,@dlat,@dlng,@pmode,@nmode,@pid,@hhid,@pernum,@gap_meters,@gap_miles,@mode_imputed;
          WHILE @@FETCH_STATUS = 0
          BEGIN
            /* Determine working mode (same as legacy: if prior==next else 995 placeholder) */
            SET @mode = CASE WHEN @pmode=@nmode THEN @pmode ELSE 995 END;
            SET @window = DATEDIFF(MINUTE,@gs,@ge);

            /* RNG uniforms for dwell sampling */
            SET @R = (@A*@R+@C)%@M; DECLARE @u1 FLOAT = CAST(@R AS FLOAT)/@M;
            SET @R = (@A*@R+@C)%@M; DECLARE @u2 FLOAT = CAST(@R AS FLOAT)/@M;
            SET @R = (@A*@R+@C)%@M; DECLARE @u3 FLOAT = CAST(@R AS FLOAT)/@M;

            SET @mean=NULL; SET @sd=NULL;
            SELECT TOP 1 @mean=mean_dwell,@sd=NULLIF(stdev_dwell,0)
            FROM #dwell_stats ds
            WHERE ds.dest_purpose=(SELECT dest_purpose FROM HHSurvey.Trip WHERE recid=@prior_recid)
            ORDER BY n DESC;
            IF @mean IS NULL SELECT TOP 1 @mean=mean_dwell,@sd=NULLIF(stdev_dwell,0) FROM #dwell_stats ORDER BY n DESC;
            IF @mean IS NULL SET @mean=10; IF @sd IS NULL SET @sd=@mean*0.25;
            DECLARE @z FLOAT = (((@u1+@u2+@u3)/3.0)-0.5)*2; -- approx [-1,1]
            SET @sample_dwell = CAST(ROUND(@mean + @z*@sd,0) AS INT); IF @sample_dwell<1 SET @sample_dwell=1;

            /* Prune routing profile by distance thresholds */
            DECLARE @profile NVARCHAR(15);
            IF @mode=1 AND @gap_miles <= 2.5
              SET @profile='walking';
            ELSE IF EXISTS (SELECT 1 FROM HHSurvey.bikemodes WHERE mode_id=@mode) AND @gap_miles <= 25.0
              SET @profile='bicycling';
            ELSE IF EXISTS (SELECT 1 FROM HHSurvey.transitmodes WHERE mode_id=@mode) AND @gap_miles <= 60.0
              SET @profile='transit';
            ELSE IF EXISTS (SELECT 1 FROM HHSurvey.automodes WHERE mode_id=@mode)
              SET @profile='driving';
            ELSE
              SET @profile='driving'; -- fallback

            /* Midpoint departure time for routing */
            DECLARE @mid_depart DATETIME2 = DATEADD(MINUTE,@window/2,@gs);
            SET @route = Elmer.dbo.route_mi_min(@olng,@olat,@dlng,@dlat,@profile,@GoogleKey,@mid_depart);
            IF @route IS NULL GOTO NextImpBatch;
            SET @comma=CHARINDEX(',',@route);
            SET @dist = TRY_CONVERT(FLOAT,LEFT(@route,@comma-1));
            SET @travel = TRY_CONVERT(INT,ROUND(TRY_CONVERT(FLOAT,SUBSTRING(@route,@comma+1,50)),0));
            IF @travel IS NULL OR @travel<=0 GOTO NextImpBatch;

            DECLARE @usable INT = @window - 2*@Buffer; IF @usable<1 SET @usable=1;
            IF @travel >= @usable
            BEGIN
              SET @depart = DATEADD(MINUTE,@Buffer,@gs);
              SET @arrive = DATEADD(MINUTE,-@Buffer,@ge);
              IF DATEDIFF(MINUTE,@depart,@arrive)<1 SET @arrive=DATEADD(MINUTE,1,@depart);
              SET @travel = DATEDIFF(MINUTE,@depart,@arrive);
            END
            ELSE IF (@sample_dwell + @travel) <= @usable
            BEGIN
              SET @depart = DATEADD(MINUTE,@Buffer+@sample_dwell,@gs);
              SET @arrive = DATEADD(MINUTE,@travel,@depart);
            END
            ELSE
            BEGIN
              DECLARE @remain INT=@usable-@travel; IF @remain<1 SET @remain=1;
              IF @sample_dwell>@remain SET @sample_dwell=@remain;
              DECLARE @pre INT=@sample_dwell/2; DECLARE @post INT=@sample_dwell-@pre;
              SET @depart=DATEADD(MINUTE,@Buffer+@pre,@gs);
              SET @arrive=DATEADD(MINUTE,@travel,@depart);
              DECLARE @latest DATETIME2=DATEADD(MINUTE,-@Buffer-@post,@ge);
              IF @arrive>@latest BEGIN DECLARE @shift INT=DATEDIFF(MINUTE,@latest,@arrive); SET @depart=DATEADD(MINUTE,-@shift,@depart); SET @arrive=@latest; END
            END

            INSERT INTO HHSurvey.Trip(
              hhid, person_id, pernum, tripnum, psrc_inserted, revision_code,
              origin_lat, origin_lng, origin_geog, dest_lat, dest_lng, dest_geog,
              depart_time_timestamp, arrival_time_timestamp, distance_miles, dest_purpose,
              travelers_hh, travelers_nonhh, travelers_total, mode_1, modes, travel_time
            )
            OUTPUT inserted.recid,@gap_id INTO #imputed(new_recid,gap_id)
            SELECT @hhid,@pid,@pernum,998,1,'16i,',
                   @olat,@olng,geography::STGeomFromText('POINT('+CAST(@olng AS VARCHAR(20))+' '+CAST(@olat AS VARCHAR(20))+')',4326),
                   @dlat,@dlng,geography::STGeomFromText('POINT('+CAST(@dlng AS VARCHAR(20))+' '+CAST(@dlat AS VARCHAR(20))+')',4326),
                   @depart,@arrive,@dist,-9998,
                   -9997,-9997,-9997,@mode,CAST(@mode AS NVARCHAR(10)),@travel
            WHERE NOT EXISTS (
              SELECT 1 FROM HHSurvey.Trip r
              WHERE r.person_id=@pid AND r.depart_time_timestamp < @arrive AND r.arrival_time_timestamp > @depart);

            IF EXISTS (SELECT 1 FROM #imputed WHERE gap_id=@gap_id)
              UPDATE @gaps SET [status]=2 WHERE gap_id=@gap_id;
            ELSE
              UPDATE @gaps SET [status]=3 WHERE gap_id=@gap_id AND [status]=0;

            NextImpBatch:
            FETCH NEXT FROM cur INTO @gap_id,@prior_recid,@gs,@ge,@olat,@olng,@dlat,@dlng,@pmode,@nmode,@pid,@hhid,@pernum,@gap_meters,@gap_miles,@mode_imputed;
          END
          CLOSE cur; DEALLOCATE cur;

          /* Remove processed rows from candidate list */
          DELETE c FROM #imp_candidates c JOIN #imp_batch b ON b.gap_id=c.gap_id;

          /* Batch throttle */
          WAITFOR DELAY '00:00:00.250';
        END

        EXEC HHSurvey.tripnum_update;
      END
    END

    ------------------------------------------------------------
    -- Final Recalc & Summary
    ------------------------------------------------------------
    EXEC HHSurvey.tripnum_update;
    EXEC HHSurvey.recalculate_after_edit;

    SELECT COUNT(*) AS gaps_total,
           SUM(CASE WHEN [status]=1 THEN 1 END) AS donor_filled,
           SUM(CASE WHEN [status]=2 THEN 1 END) AS imputed_filled,
           SUM(CASE WHEN [status]=3 THEN 1 END) AS skipped
    FROM @gaps;

  END TRY
  BEGIN CATCH
    IF @Debug=1 SELECT ERROR_NUMBER() AS err_no, ERROR_SEVERITY() AS err_severity, ERROR_STATE() AS err_state, ERROR_LINE() AS err_line, ERROR_MESSAGE() AS err_msg;
    THROW;
  END CATCH
END
GO

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
CREATE   PROCEDURE [HHSurvey].[fill_missing_link]
  @GoogleKey NVARCHAR(100),
  @Debug BIT = 0,
  @Seed  BIGINT = NULL -- optional deterministic randomness
AS
BEGIN
  SET NOCOUNT ON;
  BEGIN TRY

    /* 0. Preparation */
    EXEC HHSurvey.tripnum_update; -- ensure sequential

    /* 1. Identify gaps */
    IF OBJECT_ID('tempdb..#gaps') IS NOT NULL DROP TABLE #gaps;
    ;WITH pairings AS (
      SELECT 
        t.recid AS prior_recid,
        t.person_id,
        t.hhid,
        t.pernum,
        t.arrival_time_timestamp AS gap_start_time,
        t.dest_geog AS gap_start_geog,
        t.dest_lat  AS gap_start_lat,
        t.dest_lng  AS gap_start_lng,
        nxt.recid AS next_recid,
        nxt.depart_time_timestamp AS gap_end_time,
        nxt.origin_geog AS gap_end_geog,
        nxt.origin_lat  AS gap_end_lat,
        nxt.origin_lng  AS gap_end_lng,
        t.dest_geog.STDistance(nxt.origin_geog) AS gap_meters,
        DATEDIFF(MINUTE, t.arrival_time_timestamp, nxt.depart_time_timestamp) AS window_minutes,
        t.mode_1 AS prior_mode,
        nxt.mode_1 AS next_mode
      FROM HHSurvey.Trip t WITH (NOLOCK)
      JOIN HHSurvey.Trip nxt WITH (NOLOCK)
        ON nxt.person_id = t.person_id AND nxt.tripnum = t.tripnum + 1
      WHERE COALESCE(t.psrc_inserted,0) = 0
        AND COALESCE(nxt.psrc_inserted,0) = 0
        AND t.dest_geog IS NOT NULL AND nxt.origin_geog IS NOT NULL
        AND t.dest_geog.STDistance(nxt.origin_geog) > 500
        AND NOT EXISTS (
          SELECT 1 FROM HHSurvey.Trip x WITH (NOLOCK)
          WHERE x.person_id = t.person_id
            AND x.psrc_inserted = 1 AND x.dest_purpose = -9998
            AND x.depart_time_timestamp >= t.arrival_time_timestamp
            AND x.arrival_time_timestamp <= nxt.depart_time_timestamp
            AND x.origin_geog.STDistance(t.dest_geog) < 100
            AND x.dest_geog.STDistance(nxt.origin_geog) < 100
        )
    )
    SELECT 
      ROW_NUMBER() OVER (ORDER BY person_id, gap_start_time) AS gap_id,
      * ,
      CASE WHEN prior_mode = next_mode THEN prior_mode ELSE 995 END AS mode_imputed,
      0 AS status -- 0=pending 1=donor 2=imputed 3=skipped
    INTO #gaps
    FROM pairings;

    IF @Debug=1 SELECT * FROM #gaps;
  IF NOT EXISTS (SELECT 1 FROM #gaps) GOTO finalize;

    /* 2. Household donor search */
    IF OBJECT_ID('tempdb..#donor_candidates') IS NOT NULL DROP TABLE #donor_candidates;
    /* Candidate donor events: build simplified timeline of other household members */
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
    INTO #donor_candidates
    FROM #gaps g
    JOIN HHSurvey.Trip t WITH (NOLOCK) ON t.hhid = g.hhid AND t.person_id <> g.person_id
    JOIN HHSurvey.person m WITH (NOLOCK) ON m.person_id = t.person_id
    WHERE g.status = 0
      AND COALESCE(t.psrc_inserted,0) = 0
      AND t.arrival_time_timestamp IS NOT NULL AND t.depart_time_timestamp IS NOT NULL
      -- Strictly within window (no outside-of-window donor trips copied)
      AND t.depart_time_timestamp >= g.gap_start_time
      AND t.arrival_time_timestamp <= g.gap_end_time;

    /* Identify donors whose sequence spans the entire window with spatial anchors near both endpoints */
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
      JOIN #gaps g ON g.gap_id = s.gap_id
      WHERE has_start_anchor=1 AND has_end_anchor=1
        AND s.first_depart >= g.gap_start_time
        AND s.last_arrive  <= g.gap_end_time
    ), ranked AS (
      SELECT q.*, ROW_NUMBER() OVER (PARTITION BY q.gap_id ORDER BY q.span_trip_count ASC, NEWID()) AS rnk
      FROM qualified q
    )
    SELECT * INTO #selected_donors FROM ranked WHERE rnk=1;

    IF @Debug=1 SELECT * FROM #selected_donors;

    /* Replicate donor trips (only minimal contiguous sequence between anchor trips) */
    IF EXISTS (SELECT 1 FROM #selected_donors)
    BEGIN
      IF OBJECT_ID('tempdb..#donor_inserted') IS NOT NULL DROP TABLE #donor_inserted;
      /* new_trip_recid captured first; gap_id assigned in a follow-up update to avoid alias binding issue in OUTPUT */
      CREATE TABLE #donor_inserted(new_trip_recid INT PRIMARY KEY, gap_id INT NULL);
      INSERT INTO HHSurvey.Trip (
        hhid, person_id, pernum, tripnum, psrc_inserted, revision_code, dest_purpose,
        mode_1, modes, travelers_hh, travelers_nonhh, travelers_total,
        origin_lat, origin_lng, origin_geog, dest_lat, dest_lng, dest_geog,
        distance_miles, depart_time_timestamp, arrival_time_timestamp, travel_time
      )
      OUTPUT inserted.recid, NULL INTO #donor_inserted(new_trip_recid, gap_id)
      SELECT 
        t.hhid,
        g.person_id AS person_id,
        g.pernum,
        999 AS tripnum,
        1 AS psrc_inserted,
        '16d,' AS revision_code,
        t.dest_purpose,
        t.mode_1,
        t.modes,
        t.travelers_hh,
        t.travelers_nonhh,
        t.travelers_total,
        t.origin_lat, t.origin_lng, t.origin_geog,
        t.dest_lat,   t.dest_lng,   t.dest_geog,
        t.distance_miles,
        t.depart_time_timestamp,
        t.arrival_time_timestamp,
        t.travel_time
      FROM #selected_donors sd
      JOIN #gaps g ON g.gap_id = sd.gap_id
      JOIN HHSurvey.Trip t ON t.person_id = sd.donor_person_id
        AND t.depart_time_timestamp >= sd.first_depart
        AND t.arrival_time_timestamp <= sd.last_arrive
        AND COALESCE(t.psrc_inserted,0)=0
      WHERE NOT EXISTS (
        SELECT 1 FROM HHSurvey.Trip r
        WHERE r.person_id = g.person_id
          AND r.recid NOT IN (g.prior_recid, g.next_recid)
          AND r.depart_time_timestamp < t.arrival_time_timestamp
          AND r.arrival_time_timestamp > t.depart_time_timestamp
      );

      /* Derive gap_id for each inserted donor trip by matching its temporal window inside the gap window */
      UPDATE di
        SET gap_id = g.gap_id
      FROM #donor_inserted di
      JOIN HHSurvey.Trip it ON it.recid = di.new_trip_recid
      JOIN #gaps g ON g.person_id = it.person_id
        AND it.depart_time_timestamp >= g.gap_start_time
        AND it.arrival_time_timestamp <= g.gap_end_time
        AND g.status = 0;

      -- Mark gaps with successful donor insertion
      UPDATE g SET status=1
      FROM #gaps g
      WHERE EXISTS (SELECT 1 FROM #donor_inserted di WHERE di.gap_id = g.gap_id) AND g.status=0;

      -- Any selected donors with zero inserted trips become skipped (status=3)
      UPDATE g SET status=3
      FROM #gaps g
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
  IF EXISTS (SELECT 1 FROM #gaps WHERE status = 0)
    BEGIN
      -- Random helper (deterministic optional)
      DECLARE @R BIGINT = COALESCE(@Seed, ABS(CHECKSUM(NEWID())));
      DECLARE @A BIGINT = 1103515245, @C BIGINT = 12345, @M BIGINT = 2147483648; -- LCG params

      IF OBJECT_ID('tempdb..#impute') IS NOT NULL DROP TABLE #impute;
      SELECT g.*, p.employment, p.student,
        CASE WHEN g.prior_mode = g.next_mode THEN g.prior_mode ELSE 995 END AS chosen_mode
      INTO #impute
      FROM #gaps g
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
        WHERE ds.dest_purpose = (SELECT dest_purpose FROM HHSurvey.Trip t WHERE t.recid = (SELECT prior_recid FROM #gaps WHERE gap_id=@gap_id))
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
          UPDATE #gaps SET status = 3 WHERE gap_id=@gap_id; -- skipped due to routing fail
        END
        ELSE
        BEGIN
          SET @comma = CHARINDEX(',', @route_result);
          SET @distance_mi = TRY_CONVERT(FLOAT, LEFT(@route_result, @comma-1));
          SET @travel_minutes = TRY_CONVERT(INT, ROUND(TRY_CONVERT(FLOAT, SUBSTRING(@route_result, @comma+1, 50)),0));
          IF @travel_minutes IS NULL OR @travel_minutes <=0
          BEGIN
            UPDATE #gaps SET status=3 WHERE gap_id=@gap_id;
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
             FROM #gaps g 
             WHERE g.gap_id=@gap_id
               AND NOT EXISTS (
                 SELECT 1 FROM HHSurvey.Trip r
                 WHERE r.person_id = g.person_id
                   AND r.depart_time_timestamp < @arrival
                   AND r.arrival_time_timestamp > @depart
               );

             UPDATE #gaps SET status=2 WHERE gap_id=@gap_id;
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
      FROM #gaps;
    END

  END TRY
  BEGIN CATCH
    IF @Debug=1 SELECT ERROR_NUMBER() AS err_no, ERROR_MESSAGE() AS err_msg;
    THROW;
  END CATCH
END
GO

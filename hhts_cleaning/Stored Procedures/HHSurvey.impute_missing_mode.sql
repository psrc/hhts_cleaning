SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE     PROCEDURE [HHSurvey].[impute_missing_mode]
    @GoogleKey                nvarchar(256) = NULL,
    @max_api_calls_per_run    int           = 2000,
    @radius_meters            int           = 150,
    @allow_low_confidence     bit           = 0,
    @dry_run                  bit           = 1
AS
/*
Impute primary mode_1 for trips with missing/unknown mode, using:
- Trip metrics (distance, duration, avg speed)
- Same-tour donors and reverse donors
- Same-respondent cross-day donors
- Google Routes API tie-breaker (Elmer.dbo.route_mi_min) in throttled batches (25 calls per batch, 25ms delay)
- Detect airplane (code 31) for long/high-speed trips

Assumptions:
- HHSurvey.Trip has: recid, person_id, tripnum, depart_time_timestamp, arrival_time_timestamp,
  distance_miles, speed_mph (if null, computed), mode_1, origin_geog (Lat/Long), dest_geog (Lat/Long), traveldate (if not, derived from depart).
- Missing mode when mode_1 IS NULL OR mode_1 IN (0, 97, 98, 99) -- adjust as needed
*/
BEGIN
    SET NOCOUNT ON;

    /* Ensure log table exists for audit output */
    IF OBJECT_ID('HHSurvey.mode_imputation_log') IS NULL
    BEGIN
        CREATE TABLE HHSurvey.mode_imputation_log (
            log_id            bigint IDENTITY(1,1) PRIMARY KEY,
            recid             decimal(19,0) NOT NULL,
            person_id         decimal(19,0) NULL,
            tripnum           int           NULL,
            traveldate        date          NULL,
            method            nvarchar(50)  NOT NULL,
            confidence        nvarchar(20)  NOT NULL,
            chosen_family     nvarchar(20)  NULL,
            chosen_mode_id    int           NULL,
            -- chosen_mode_label removed per request
            prev_mode_id      int           NULL,
            distance_miles    float         NULL,
            duration_minutes  float         NULL,
            avg_speed_mph     float         NULL,
            tour_id           int           NULL,
            donor_recid       decimal(19,0) NULL,
            donor_person_id   decimal(19,0) NULL,
            donor_tripnum     int           NULL,
            api_driving_min   float         NULL,
            api_transit_min   float         NULL,
            api_bicycling_min float         NULL,
            api_walking_min   float         NULL,
            api_best_mode     nvarchar(20)  NULL,
            api_diff_minutes  float         NULL,
            api_calls_used    int           NULL,
            notes             nvarchar(max) NULL,
            created_at        datetime2      NOT NULL CONSTRAINT DF_mode_imp_log_created_at DEFAULT (SYSUTCDATETIME())
        );
    END
    ELSE
    BEGIN
        /* Ensure existing table has wide ID column types to avoid int overflows */
        IF EXISTS (
            SELECT 1 FROM sys.columns c
            JOIN sys.types t ON c.user_type_id=t.user_type_id
            WHERE c.object_id = OBJECT_ID('HHSurvey.mode_imputation_log') AND c.name='recid' AND t.name='int'
        )
        BEGIN
            ALTER TABLE HHSurvey.mode_imputation_log ALTER COLUMN recid decimal(19,0) NOT NULL;
        END
        IF EXISTS (
            SELECT 1 FROM sys.columns c
            JOIN sys.types t ON c.user_type_id=t.user_type_id
            WHERE c.object_id = OBJECT_ID('HHSurvey.mode_imputation_log') AND c.name='person_id' AND t.name='int'
        )
        BEGIN
            ALTER TABLE HHSurvey.mode_imputation_log ALTER COLUMN person_id decimal(19,0) NULL;
        END
        IF EXISTS (
            SELECT 1 FROM sys.columns c
            JOIN sys.types t ON c.user_type_id=t.user_type_id
            WHERE c.object_id = OBJECT_ID('HHSurvey.mode_imputation_log') AND c.name='donor_recid' AND t.name='int'
        )
        BEGIN
            ALTER TABLE HHSurvey.mode_imputation_log ALTER COLUMN donor_recid decimal(19,0) NULL;
        END
        IF EXISTS (
            SELECT 1 FROM sys.columns c
            JOIN sys.types t ON c.user_type_id=t.user_type_id
            WHERE c.object_id = OBJECT_ID('HHSurvey.mode_imputation_log') AND c.name='donor_person_id' AND t.name='int'
        )
        BEGIN
            ALTER TABLE HHSurvey.mode_imputation_log ALTER COLUMN donor_person_id decimal(19,0) NULL;
        END
    END

    /* Parameters and thresholds */
    DECLARE @walk_max_mi     float = 0.75,
            @walk_max_mph    float = 4.5,
            @walk_max_min    float = 25,
            @bike_max_mi     float = 5.0,
            @bike_min_mph    float = 6.0,
            @bike_max_mph    float = 20.0,
            @bike_max_min    float = 60.0,
            @auto_min_mi     float = 1.0,
            @auto_min_mph    float = 20.0,
            @transit_max_mph float = 15.0,
            @long_trip_mi    float = 150.0,  -- airplane distance heuristic
            @air_min_mph     float = 80.0;    -- airplane speed heuristic

    /* Candidate mode families */
    DECLARE @WALK_CODE int = 1;  -- pedestrian fixed

    IF OBJECT_ID('tempdb..#known_modes') IS NOT NULL DROP TABLE #known_modes;
    SELECT mode_id, family
    INTO #known_modes
    FROM (
        SELECT mode_id, 'AUTO' AS family FROM HHSurvey.automodes
        UNION ALL SELECT mode_id, 'BIKE' FROM HHSurvey.bikemodes
        UNION ALL SELECT mode_id, 'TRANSIT' FROM HHSurvey.transitmodes
        UNION ALL SELECT @WALK_CODE, 'WALK'
    ) x;

    /* Identify candidate trips (targets) */
    IF OBJECT_ID('tempdb..#targets') IS NOT NULL DROP TABLE #targets;
    WITH base AS (
        SELECT t.recid, t.person_id, t.tripnum,
               CAST(COALESCE(t.traveldate, CAST(t.depart_time_timestamp AS date)) AS date) AS traveldate,
               t.depart_time_timestamp, t.arrival_time_timestamp,
               t.distance_miles,
               CASE WHEN t.speed_mph IS NULL OR t.speed_mph <= 0
                    THEN NULL ELSE t.speed_mph END AS speed_mph,
               DATEDIFF(SECOND, t.depart_time_timestamp, t.arrival_time_timestamp) / 60.0 AS duration_min,
               TRY_CONVERT(float, t.origin_geog.Lat) AS o_lat,
               TRY_CONVERT(float, t.origin_geog.Long) AS o_lon,
               TRY_CONVERT(float, t.dest_geog.Lat) AS d_lat,
               TRY_CONVERT(float, t.dest_geog.Long) AS d_lon,
               t.origin_geog AS o_geog,
               t.dest_geog AS d_geog,
               t.mode_1,
               t.origin_purpose,
               t.dest_purpose
        FROM HHSurvey.Trip AS t WITH (NOLOCK)
        WHERE (t.mode_1 IS NULL OR t.mode_1 IN (SELECT flag_value FROM HHSurvey.NullFlags))
    )
    SELECT *,
           CASE WHEN speed_mph IS NULL AND duration_min > 0 AND distance_miles IS NOT NULL
                THEN NULLIF(distance_miles / (duration_min/60.0), 0) END AS calc_mph
    INTO #targets
    FROM base;

    /* Guard: nothing to do */
    IF NOT EXISTS(SELECT 1 FROM #targets) RETURN;

    /* Compute tours per person-day as home->home sequences using dest/origin purpose code 1 (Went home) */
    IF OBJECT_ID('tempdb..#tours') IS NOT NULL DROP TABLE #tours;
    ;WITH base AS (
        SELECT t.person_id,
               CAST(COALESCE(t.traveldate, CAST(t.depart_time_timestamp AS date)) AS date) AS traveldate,
               t.tripnum,
               CASE WHEN t.origin_purpose = 1 THEN 1 ELSE 0 END AS is_home_start
        FROM HHSurvey.Trip t WITH (NOLOCK)
    ), ranked AS (
        SELECT b.*, SUM(is_home_start) OVER (PARTITION BY b.person_id, b.traveldate ORDER BY b.tripnum ROWS UNBOUNDED PRECEDING) AS tour_num
        FROM base b
    )
    SELECT person_id, traveldate, tripnum, NULLIF(tour_num, 0) AS tour_num
    INTO #tours
    FROM ranked;

    CREATE INDEX IX_tours ON #tours(person_id, traveldate, tripnum);

    /* Join targets with derived metrics and tours */
    IF OBJECT_ID('tempdb..#work') IS NOT NULL DROP TABLE #work;
    SELECT t.recid, t.person_id, t.tripnum, t.traveldate,
           t.depart_time_timestamp, t.arrival_time_timestamp,
           t.distance_miles,
           COALESCE(t.speed_mph, t.calc_mph) AS mph,
           t.duration_min,
           t.o_lat, t.o_lon, t.d_lat, t.d_lon,
           t.o_geog, t.d_geog,
           tr.tour_num,
           t.origin_purpose, t.dest_purpose
    INTO #work
    FROM #targets t
    LEFT JOIN #tours tr ON tr.person_id=t.person_id AND tr.traveldate=t.traveldate AND tr.tripnum=t.tripnum;

    CREATE INDEX IX_work_person ON #work(person_id, traveldate, tripnum);

    /* Helper function: meters between two lat/lon (Haversine) */
    -- Inline scalar approximation in T-SQL
    IF OBJECT_ID('tempdb..#pairs') IS NOT NULL DROP TABLE #pairs;

    /* Step 1: Airplane detection (code 31) */
    IF OBJECT_ID('tempdb..#air_candidates') IS NOT NULL DROP TABLE #air_candidates;
    SELECT w.*, 31 AS proposed_mode, 'AIR' AS family, 'airplane' AS method, 'High' AS conf
    INTO #air_candidates
    FROM #work w
    WHERE (w.distance_miles >= @long_trip_mi OR w.mph >= @air_min_mph)
      AND w.distance_miles IS NOT NULL AND w.duration_min IS NOT NULL
      AND w.duration_min > 0;

    /* Exclude any already assigned by air when writing later */

    /* Step 2: Tour consensus (same family) */
    IF OBJECT_ID('tempdb..#tour_donors') IS NOT NULL DROP TABLE #tour_donors;
    ;WITH in_tour AS (
        SELECT w.person_id, w.traveldate, w.tour_num
        FROM #work w
        WHERE w.tour_num IS NOT NULL
        GROUP BY w.person_id, w.traveldate, w.tour_num
    ), trip_tours AS (
        SELECT t.person_id,
               CAST(COALESCE(t.traveldate, CAST(t.depart_time_timestamp AS date)) AS date) AS traveldate,
               t.tripnum, t.mode_1,
               tr.tour_num
        FROM HHSurvey.Trip t WITH (NOLOCK)
        JOIN #tours tr ON tr.person_id=t.person_id AND tr.tripnum=t.tripnum AND tr.traveldate=CAST(COALESCE(t.traveldate, CAST(t.depart_time_timestamp AS date)) AS date)
        WHERE t.mode_1 IS NOT NULL AND t.mode_1 NOT IN (0,97,98,99)
    ), tour_family_counts AS (
        SELECT it.person_id, it.traveldate, it.tour_num, km.family, COUNT(*) AS cnt
        FROM in_tour it
        JOIN trip_tours tt ON tt.person_id=it.person_id AND tt.traveldate=it.traveldate AND tt.tour_num=it.tour_num
        JOIN #known_modes km ON km.mode_id=tt.mode_1
        GROUP BY it.person_id, it.traveldate, it.tour_num, km.family
    ), tour_family_distinct AS (
        SELECT person_id, traveldate, tour_num, COUNT(*) AS fam_count
        FROM tour_family_counts
        GROUP BY person_id, traveldate, tour_num
    ), consensus AS (
        SELECT f.person_id, f.traveldate, f.tour_num, MIN(f.family) AS consensus_family
        FROM tour_family_counts f
        JOIN tour_family_distinct d ON d.person_id=f.person_id AND d.traveldate=f.traveldate AND d.tour_num=f.tour_num AND d.fam_count=1
        GROUP BY f.person_id, f.traveldate, f.tour_num
    )
    SELECT w.*, c.consensus_family
    INTO #tour_donors
    FROM #work w
    JOIN consensus c ON c.person_id=w.person_id AND c.traveldate=w.traveldate AND c.tour_num=w.tour_num;

    /* Step 3: Reverse-trip donor in tour */
    -- We approximate reversal by adjacent or near-adjacent tripnums with swapped ends.
    IF OBJECT_ID('tempdb..#rev_donors') IS NOT NULL DROP TABLE #rev_donors;
    ;WITH tour_trips AS (
        SELECT t.recid, t.person_id, CAST(COALESCE(t.traveldate, CAST(t.depart_time_timestamp AS date)) AS date) AS traveldate,
               t.tripnum, t.mode_1,
               t.origin_geog AS o_geog,
               t.dest_geog AS d_geog,
               DATEDIFF(SECOND, t.depart_time_timestamp, t.arrival_time_timestamp)/60.0 AS dur,
               t.distance_miles
        FROM HHSurvey.Trip t WITH (NOLOCK)
        WHERE t.mode_1 IS NOT NULL AND t.mode_1 NOT IN (SELECT flag_value FROM HHSurvey.NullFlags)
    )
    SELECT w.recid AS target_recid, d.recid AS donor_recid, d.mode_1 AS donor_mode
    INTO #rev_donors
    FROM #work w
    JOIN tour_trips d
         ON d.person_id = w.person_id AND d.traveldate = w.traveldate
        AND ABS(d.dur - w.duration_min) <= (CASE WHEN w.duration_min >= 20 THEN 0.25*w.duration_min ELSE 5 END)
        AND (d.distance_miles IS NULL OR w.distance_miles IS NULL OR ABS(d.distance_miles - w.distance_miles) <= 0.2*NULLIF(w.distance_miles,0))
        AND w.o_geog.STDistance(d.d_geog) <= @radius_meters
        AND w.d_geog.STDistance(d.o_geog) <= @radius_meters;

    CREATE INDEX IX_rev ON #rev_donors(target_recid);

    /* Step 4: Cross-day donor per person (habit trips) */
    IF OBJECT_ID('tempdb..#cross_donors') IS NOT NULL DROP TABLE #cross_donors;
    ;WITH person_trips AS (
        SELECT t.recid, t.person_id,
               t.origin_geog AS o_geog,
               t.dest_geog AS d_geog,
               DATEDIFF(SECOND, t.depart_time_timestamp, t.arrival_time_timestamp)/60.0 AS dur,
               t.distance_miles, t.mode_1
        FROM HHSurvey.Trip t WITH (NOLOCK)
        WHERE t.mode_1 IS NOT NULL AND t.mode_1 NOT IN (SELECT flag_value FROM HHSurvey.NullFlags)
    )
    SELECT w.recid AS target_recid, d.recid AS donor_recid, d.mode_1 AS donor_mode
    INTO #cross_donors
    FROM #work w
    JOIN person_trips d ON d.person_id = w.person_id
        AND ABS(d.dur - w.duration_min) <= (CASE WHEN w.duration_min >= 20 THEN 0.25*w.duration_min ELSE 5 END)
        AND (d.distance_miles IS NULL OR w.distance_miles IS NULL OR ABS(d.distance_miles - w.distance_miles) <= 0.2*NULLIF(w.distance_miles,0))
        AND (
            (w.o_geog.STDistance(d.o_geog) <= @radius_meters AND w.d_geog.STDistance(d.d_geog) <= @radius_meters)
         OR (w.o_geog.STDistance(d.d_geog) <= @radius_meters AND w.d_geog.STDistance(d.o_geog) <= @radius_meters)
        );

    CREATE INDEX IX_cross ON #cross_donors(target_recid);

    /* Personal-gates: derive respondent-specific ranges per mode family and score targets */
    -- Build base metrics from known (non-null) trips with assigned modes
    IF OBJECT_ID('tempdb..#metric_base') IS NOT NULL DROP TABLE #metric_base;
    WITH base AS (
        SELECT t.person_id,
               km.family,
               t.distance_miles,
               CASE WHEN t.speed_mph IS NULL OR t.speed_mph <= 0 THEN
                    CASE WHEN DATEDIFF(SECOND, t.depart_time_timestamp, t.arrival_time_timestamp) > 0 AND t.distance_miles IS NOT NULL
                         THEN NULLIF(t.distance_miles / (DATEDIFF(SECOND, t.depart_time_timestamp, t.arrival_time_timestamp)/3600.0), 0)
                         ELSE NULL END
               ELSE t.speed_mph END AS mph,
               NULLIF(DATEDIFF(SECOND, t.depart_time_timestamp, t.arrival_time_timestamp)/60.0, 0) AS duration_min
        FROM HHSurvey.Trip t WITH (NOLOCK)
        JOIN #known_modes km ON km.mode_id = t.mode_1
        WHERE t.mode_1 IS NOT NULL AND t.mode_1 NOT IN (SELECT flag_value FROM HHSurvey.NullFlags)
    )
    SELECT person_id, family, distance_miles, mph, duration_min
    INTO #metric_base
    FROM base
    WHERE (distance_miles IS NOT NULL AND distance_miles >= 0)
      AND (duration_min IS NULL OR duration_min > 0)
      AND (mph IS NULL OR mph > 0);

    -- Compute per-person-family percentile ranges (P10-P90) for distance and mph (duration optional)
    IF OBJECT_ID('tempdb..#person_family_stats') IS NOT NULL DROP TABLE #person_family_stats;
    SELECT DISTINCT
        person_id,
        family,
        PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY distance_miles) OVER (PARTITION BY person_id, family) AS dist_p10,
        PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY distance_miles) OVER (PARTITION BY person_id, family) AS dist_p90,
        PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY mph) OVER (PARTITION BY person_id, family) AS mph_p10,
        PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY mph) OVER (PARTITION BY person_id, family) AS mph_p90,
        PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY duration_min) OVER (PARTITION BY person_id, family) AS dur_p10,
        PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY duration_min) OVER (PARTITION BY person_id, family) AS dur_p90
    INTO #person_family_stats
    FROM #metric_base;

    -- Compute cohort-level percentile ranges (P10-P90) per family as fallback when personal history is absent
    IF OBJECT_ID('tempdb..#cohort_family_stats') IS NOT NULL DROP TABLE #cohort_family_stats;
    SELECT DISTINCT
        family,
        PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY distance_miles) OVER (PARTITION BY family) AS dist_p10,
        PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY distance_miles) OVER (PARTITION BY family) AS dist_p90,
        PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY mph) OVER (PARTITION BY family) AS mph_p10,
        PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY mph) OVER (PARTITION BY family) AS mph_p90,
        PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY duration_min) OVER (PARTITION BY family) AS dur_p10,
        PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY duration_min) OVER (PARTITION BY family) AS dur_p90
    INTO #cohort_family_stats
    FROM #metric_base;

    -- Build personal gates for each target using the person's own family ranges (with ±10% buffer)
    IF OBJECT_ID('tempdb..#personal_gates') IS NOT NULL DROP TABLE #personal_gates;
    SELECT w.recid,
           CASE 
                WHEN sw.person_id IS NOT NULL AND (
                        (w.distance_miles IS NULL OR (w.distance_miles BETWEEN sw.dist_p10*0.9 AND sw.dist_p90*1.1))
                    AND (w.mph IS NULL OR (w.mph BETWEEN sw.mph_p10*0.9 AND sw.mph_p90*1.1))
                    AND (w.duration_min IS NULL OR (w.duration_min BETWEEN sw.dur_p10*0.9 AND sw.dur_p90*1.1))
                ) THEN 1
                WHEN cw.family IS NOT NULL AND (
                        (w.distance_miles IS NULL OR (w.distance_miles BETWEEN cw.dist_p10*0.9 AND cw.dist_p90*1.1))
                    AND (w.mph IS NULL OR (w.mph BETWEEN cw.mph_p10*0.9 AND cw.mph_p90*1.1))
                    AND (w.duration_min IS NULL OR (w.duration_min BETWEEN cw.dur_p10*0.9 AND cw.dur_p90*1.1))
                ) THEN 1
                ELSE 0 END AS walk_ok,
           CASE 
                WHEN sb.person_id IS NOT NULL AND (
                        (w.distance_miles IS NULL OR (w.distance_miles BETWEEN sb.dist_p10*0.9 AND sb.dist_p90*1.1))
                    AND (w.mph IS NULL OR (w.mph BETWEEN sb.mph_p10*0.9 AND sb.mph_p90*1.1))
                    AND (w.duration_min IS NULL OR (w.duration_min BETWEEN sb.dur_p10*0.9 AND sb.dur_p90*1.1))
                ) THEN 1
                WHEN cb.family IS NOT NULL AND (
                        (w.distance_miles IS NULL OR (w.distance_miles BETWEEN cb.dist_p10*0.9 AND cb.dist_p90*1.1))
                    AND (w.mph IS NULL OR (w.mph BETWEEN cb.mph_p10*0.9 AND cb.mph_p90*1.1))
                    AND (w.duration_min IS NULL OR (w.duration_min BETWEEN cb.dur_p10*0.9 AND cb.dur_p90*1.1))
                ) THEN 1
                ELSE 0 END AS bike_ok,
           CASE 
                WHEN sa.person_id IS NOT NULL AND (
                        (w.distance_miles IS NULL OR (w.distance_miles BETWEEN sa.dist_p10*0.9 AND sa.dist_p90*1.1))
                    AND (w.mph IS NULL OR (w.mph BETWEEN sa.mph_p10*0.9 AND sa.mph_p90*1.1))
                    AND (w.duration_min IS NULL OR (w.duration_min BETWEEN sa.dur_p10*0.9 AND sa.dur_p90*1.1))
                ) THEN 1
                WHEN ca.family IS NOT NULL AND (
                        (w.distance_miles IS NULL OR (w.distance_miles BETWEEN ca.dist_p10*0.9 AND ca.dist_p90*1.1))
                    AND (w.mph IS NULL OR (w.mph BETWEEN ca.mph_p10*0.9 AND ca.mph_p90*1.1))
                    AND (w.duration_min IS NULL OR (w.duration_min BETWEEN ca.dur_p10*0.9 AND ca.dur_p90*1.1))
                ) THEN 1
                ELSE 0 END AS auto_ok,
           CASE 
                WHEN st.person_id IS NOT NULL AND (
                        (w.distance_miles IS NULL OR (w.distance_miles BETWEEN st.dist_p10*0.9 AND st.dist_p90*1.1))
                    AND (w.mph IS NULL OR (w.mph BETWEEN st.mph_p10*0.9 AND st.mph_p90*1.1))
                    AND (w.duration_min IS NULL OR (w.duration_min BETWEEN st.dur_p10*0.9 AND st.dur_p90*1.1))
                ) THEN 1
                WHEN ct.family IS NOT NULL AND (
                        (w.distance_miles IS NULL OR (w.distance_miles BETWEEN ct.dist_p10*0.9 AND ct.dist_p90*1.1))
                    AND (w.mph IS NULL OR (w.mph BETWEEN ct.mph_p10*0.9 AND ct.mph_p90*1.1))
                    AND (w.duration_min IS NULL OR (w.duration_min BETWEEN ct.dur_p10*0.9 AND ct.dur_p90*1.1))
                ) THEN 1
                ELSE 0 END AS transit_ok
    INTO #personal_gates
    FROM #work w
    LEFT JOIN #person_family_stats sw ON sw.person_id=w.person_id AND sw.family='WALK'
    LEFT JOIN #person_family_stats sb ON sb.person_id=w.person_id AND sb.family='BIKE'
    LEFT JOIN #person_family_stats sa ON sa.person_id=w.person_id AND sa.family='AUTO'
    LEFT JOIN #person_family_stats st ON st.person_id=w.person_id AND st.family='TRANSIT'
    LEFT JOIN #cohort_family_stats cw ON cw.family='WALK'
    LEFT JOIN #cohort_family_stats cb ON cb.family='BIKE'
    LEFT JOIN #cohort_family_stats ca ON ca.family='AUTO'
    LEFT JOIN #cohort_family_stats ct ON ct.family='TRANSIT';

    CREATE INDEX IX_personal_gates ON #personal_gates(recid);

    /* Compatibility matrix for audit: personal vs cohort range flags per family */
    IF OBJECT_ID('tempdb..#compatibility') IS NOT NULL DROP TABLE #compatibility;
    SELECT w.recid,
           CASE WHEN sw.person_id IS NOT NULL AND (
                    (w.distance_miles IS NULL OR (w.distance_miles BETWEEN sw.dist_p10*0.9 AND sw.dist_p90*1.1))
                AND (w.mph IS NULL OR (w.mph BETWEEN sw.mph_p10*0.9 AND sw.mph_p90*1.1))
                AND (w.duration_min IS NULL OR (w.duration_min BETWEEN sw.dur_p10*0.9 AND sw.dur_p90*1.1))
           ) THEN 1 ELSE 0 END AS walk_personal_ok,
           CASE WHEN cw.family IS NOT NULL AND (
                    (w.distance_miles IS NULL OR (w.distance_miles BETWEEN cw.dist_p10*0.9 AND cw.dist_p90*1.1))
                AND (w.mph IS NULL OR (w.mph BETWEEN cw.mph_p10*0.9 AND cw.mph_p90*1.1))
                AND (w.duration_min IS NULL OR (w.duration_min BETWEEN cw.dur_p10*0.9 AND cw.dur_p90*1.1))
           ) THEN 1 ELSE 0 END AS walk_cohort_ok,
           CASE WHEN sb.person_id IS NOT NULL AND (
                    (w.distance_miles IS NULL OR (w.distance_miles BETWEEN sb.dist_p10*0.9 AND sb.dist_p90*1.1))
                AND (w.mph IS NULL OR (w.mph BETWEEN sb.mph_p10*0.9 AND sb.mph_p90*1.1))
                AND (w.duration_min IS NULL OR (w.duration_min BETWEEN sb.dur_p10*0.9 AND sb.dur_p90*1.1))
           ) THEN 1 ELSE 0 END AS bike_personal_ok,
           CASE WHEN cb.family IS NOT NULL AND (
                    (w.distance_miles IS NULL OR (w.distance_miles BETWEEN cb.dist_p10*0.9 AND cb.dist_p90*1.1))
                AND (w.mph IS NULL OR (w.mph BETWEEN cb.mph_p10*0.9 AND cb.mph_p90*1.1))
                AND (w.duration_min IS NULL OR (w.duration_min BETWEEN cb.dur_p10*0.9 AND cb.dur_p90*1.1))
           ) THEN 1 ELSE 0 END AS bike_cohort_ok,
           CASE WHEN sa.person_id IS NOT NULL AND (
                    (w.distance_miles IS NULL OR (w.distance_miles BETWEEN sa.dist_p10*0.9 AND sa.dist_p90*1.1))
                AND (w.mph IS NULL OR (w.mph BETWEEN sa.mph_p10*0.9 AND sa.mph_p90*1.1))
                AND (w.duration_min IS NULL OR (w.duration_min BETWEEN sa.dur_p10*0.9 AND sa.dur_p90*1.1))
           ) THEN 1 ELSE 0 END AS auto_personal_ok,
           CASE WHEN ca.family IS NOT NULL AND (
                    (w.distance_miles IS NULL OR (w.distance_miles BETWEEN ca.dist_p10*0.9 AND ca.dist_p90*1.1))
                AND (w.mph IS NULL OR (w.mph BETWEEN ca.mph_p10*0.9 AND ca.mph_p90*1.1))
                AND (w.duration_min IS NULL OR (w.duration_min BETWEEN ca.dur_p10*0.9 AND ca.dur_p90*1.1))
           ) THEN 1 ELSE 0 END AS auto_cohort_ok,
           CASE WHEN st.person_id IS NOT NULL AND (
                    (w.distance_miles IS NULL OR (w.distance_miles BETWEEN st.dist_p10*0.9 AND st.dist_p90*1.1))
                AND (w.mph IS NULL OR (w.mph BETWEEN st.mph_p10*0.9 AND st.mph_p90*1.1))
                AND (w.duration_min IS NULL OR (w.duration_min BETWEEN st.dur_p10*0.9 AND st.dur_p90*1.1))
           ) THEN 1 ELSE 0 END AS transit_personal_ok,
           CASE WHEN ct.family IS NOT NULL AND (
                    (w.distance_miles IS NULL OR (w.distance_miles BETWEEN ct.dist_p10*0.9 AND ct.dist_p90*1.1))
                AND (w.mph IS NULL OR (w.mph BETWEEN ct.mph_p10*0.9 AND ct.mph_p90*1.1))
                AND (w.duration_min IS NULL OR (w.duration_min BETWEEN ct.dur_p10*0.9 AND ct.dur_p90*1.1))
           ) THEN 1 ELSE 0 END AS transit_cohort_ok
    INTO #compatibility
    FROM #work w
    LEFT JOIN #person_family_stats sw ON sw.person_id=w.person_id AND sw.family='WALK'
    LEFT JOIN #person_family_stats sb ON sb.person_id=w.person_id AND sb.family='BIKE'
    LEFT JOIN #person_family_stats sa ON sa.person_id=w.person_id AND sa.family='AUTO'
    LEFT JOIN #person_family_stats st ON st.person_id=w.person_id AND st.family='TRANSIT'
    LEFT JOIN #cohort_family_stats cw ON cw.family='WALK'
    LEFT JOIN #cohort_family_stats cb ON cb.family='BIKE'
    LEFT JOIN #cohort_family_stats ca ON ca.family='AUTO'
    LEFT JOIN #cohort_family_stats ct ON ct.family='TRANSIT';

    /* Aggregate respondent preferences for tie-breaking */
    IF OBJECT_ID('tempdb..#person_mode_freq') IS NOT NULL DROP TABLE #person_mode_freq;
    SELECT person_id, mode_1 AS mode_id, COUNT(*) AS cnt
    INTO #person_mode_freq
    FROM HHSurvey.Trip WITH (NOLOCK)
    WHERE mode_1 IS NOT NULL AND mode_1 NOT IN (SELECT flag_value FROM HHSurvey.NullFlags)
    GROUP BY person_id, mode_1;

    IF OBJECT_ID('tempdb..#family_defaults') IS NOT NULL DROP TABLE #family_defaults;
    ;WITH fam_counts AS (
        SELECT km.family, t.mode_1 AS mode_id, COUNT(*) AS cnt
    FROM HHSurvey.Trip t WITH (NOLOCK)
    JOIN #known_modes km ON km.mode_id=t.mode_1
        GROUP BY km.family, t.mode_1
    ), ranked AS (
        SELECT family, mode_id, cnt,
               ROW_NUMBER() OVER (PARTITION BY family ORDER BY cnt DESC, mode_id) AS rn
        FROM fam_counts
    )
    SELECT family, mode_id
    INTO #family_defaults
    FROM ranked
    WHERE rn = 1;

    /* Staging for decisions */
    IF OBJECT_ID('tempdb..#decisions') IS NOT NULL DROP TABLE #decisions;
    CREATE TABLE #decisions (
        recid decimal(19,0) PRIMARY KEY,
        method nvarchar(50) NOT NULL,
        confidence nvarchar(20) NOT NULL,
        family nvarchar(20) NULL,
        chosen_mode int NULL,
        donor_recid decimal(19,0) NULL,
        api_driving_min float NULL,
        api_transit_min float NULL,
        api_bicycling_min float NULL,
        api_walking_min float NULL,
        api_best_mode nvarchar(20) NULL,
        api_diff_minutes float NULL,
        api_calls_used int NULL
    );

    /* Apply airplane where applicable */
    INSERT INTO #decisions (recid, method, confidence, family, chosen_mode)
    SELECT recid, 'airplane', 'High', 'AIR', 31
    FROM #air_candidates;

     /* Tour consensus where single family (no global gating; allow personal history to dominate) */
          INSERT INTO #decisions (recid, method, confidence, family, chosen_mode)
          SELECT td.recid, 'tour-consensus', 'High', td.consensus_family,
              COALESCE(
                  (SELECT TOP 1 t.mode_1 FROM HHSurvey.Trip t WHERE t.person_id=td.person_id AND CAST(COALESCE(t.traveldate, CAST(t.depart_time_timestamp AS date)) AS date)=td.traveldate AND t.mode_1 IN (SELECT mode_id FROM #known_modes WHERE family=td.consensus_family)
                    GROUP BY t.mode_1 ORDER BY COUNT(*) DESC),
                  (SELECT mode_id FROM #family_defaults WHERE family=td.consensus_family)
              )
          FROM #tour_donors td
          WHERE NOT EXISTS (SELECT 1 FROM #decisions d WHERE d.recid=td.recid);

    /* Reverse donor (no global gating) - dedupe to 1 row per target */
        ;WITH ranked AS (
            SELECT rd.*, ROW_NUMBER() OVER (PARTITION BY rd.target_recid ORDER BY rd.donor_recid) AS rn
            FROM #rev_donors rd
        )
        INSERT INTO #decisions (recid, method, confidence, family, chosen_mode, donor_recid)
        SELECT r.target_recid, 'reverse-donor', 'High', km.family, r.donor_mode, r.donor_recid
        FROM ranked r
        JOIN #known_modes km ON km.mode_id=r.donor_mode
        WHERE r.rn = 1
          AND NOT EXISTS (SELECT 1 FROM #decisions d WHERE d.recid=r.target_recid);

    /* Cross-day donor (no global gating) - dedupe to 1 row per target */
        ;WITH ranked AS (
            SELECT cd.*, ROW_NUMBER() OVER (PARTITION BY cd.target_recid ORDER BY cd.donor_recid) AS rn
            FROM #cross_donors cd
        )
        INSERT INTO #decisions (recid, method, confidence, family, chosen_mode, donor_recid)
        SELECT r.target_recid, 'cross-day', 'Medium', km.family, r.donor_mode, r.donor_recid
        FROM ranked r
        JOIN #known_modes km ON km.mode_id=r.donor_mode
        WHERE r.rn = 1
          AND NOT EXISTS (SELECT 1 FROM #decisions d WHERE d.recid=r.target_recid);

    /* Simple fallback when no donors/tour decisions:
       - If slow and short: WALK (<4 mph and <=2 mi)
       - Else if respondent has auto trips: AUTO
       Note: applies only to trips not already decided and outside airplane assignment */
    INSERT INTO #decisions (recid, method, confidence, family, chosen_mode)
    SELECT w.recid, 'simple-fallback', 'Low', 'WALK',
           COALESCE(
               (SELECT TOP 1 pmf.mode_id FROM #person_mode_freq pmf JOIN #known_modes km ON km.mode_id=pmf.mode_id AND km.family='WALK' WHERE pmf.person_id=w.person_id ORDER BY pmf.cnt DESC),
               (SELECT mode_id FROM #family_defaults WHERE family='WALK')
           )
    FROM #work w
    WHERE NOT EXISTS (SELECT 1 FROM #decisions d WHERE d.recid=w.recid)
      AND w.mph IS NOT NULL AND w.mph < 4.0
      AND w.distance_miles IS NOT NULL AND w.distance_miles <= 2.0;

        -- Note: Removed AUTO simple-fallback per request; rely on cohort-level gates, family-heuristic, and API tie-breaker

    /* Family-only gating using personal gates */
    IF OBJECT_ID('tempdb..#family_candidates') IS NOT NULL DROP TABLE #family_candidates;
    SELECT pg.recid,
        CASE WHEN pg.walk_ok=1 THEN 1 ELSE 0 END AS walk_ok,
        CASE WHEN pg.bike_ok=1 THEN 1 ELSE 0 END AS bike_ok,
        CASE WHEN pg.auto_ok=1 THEN 1 ELSE 0 END AS auto_ok,
        CASE WHEN pg.transit_ok=1 THEN 1 ELSE 0 END AS transit_ok
    INTO #family_candidates
    FROM #personal_gates pg
    WHERE NOT EXISTS (SELECT 1 FROM #decisions d WHERE d.recid=pg.recid);

    /* Choose specific code via personal frequency then default */
    INSERT INTO #decisions (recid, method, confidence, family, chosen_mode)
    SELECT fc.recid,
           'family-heuristic', 'Low', fam.family,
           COALESCE(
              (SELECT TOP 1 pmf.mode_id FROM #person_mode_freq pmf JOIN #known_modes km ON km.mode_id=pmf.mode_id AND km.family=fam.family WHERE pmf.person_id=w.person_id ORDER BY pmf.cnt DESC),
              (SELECT mode_id FROM #family_defaults WHERE family=fam.family)
           )
    FROM #family_candidates fc
    JOIN #work w ON w.recid=fc.recid
    CROSS APPLY (
        SELECT TOP 1 family FROM (
            SELECT 'WALK' AS family, fc.walk_ok AS ok UNION ALL
            SELECT 'BIKE', fc.bike_ok UNION ALL
            SELECT 'AUTO', fc.auto_ok UNION ALL
            SELECT 'TRANSIT', fc.transit_ok
        ) z WHERE z.ok=1 ORDER BY CASE z.family WHEN 'AUTO' THEN 1 WHEN 'TRANSIT' THEN 2 WHEN 'BIKE' THEN 3 WHEN 'WALK' THEN 4 END
    ) fam
    WHERE (fc.walk_ok+fc.bike_ok+fc.auto_ok+fc.transit_ok)=1
      AND NOT EXISTS (SELECT 1 FROM #decisions d WHERE d.recid=fc.recid);

    /* API tie-breaker for remaining with 2-3 families (use personal gates); include departure time */
    IF @GoogleKey IS NOT NULL AND @max_api_calls_per_run > 0
    BEGIN
        IF OBJECT_ID('tempdb..#api_queue') IS NOT NULL DROP TABLE #api_queue;
        CREATE TABLE #api_queue (
            recid decimal(19,0) PRIMARY KEY,
            person_id decimal(19,0),
            o_lon float, o_lat float, d_lon float, d_lat float,
            duration_min float,
            depart_time_timestamp datetime2 NULL,
            want_drive bit, want_transit bit, want_bike bit, want_walk bit
        );

        INSERT INTO #api_queue(recid, person_id, o_lon, o_lat, d_lon, d_lat, duration_min, depart_time_timestamp, want_drive, want_transit, want_bike, want_walk)
        SELECT w.recid, w.person_id, w.o_lon, w.o_lat, w.d_lon, w.d_lat, w.duration_min, w.depart_time_timestamp,
               CASE WHEN fc.auto_ok=1 THEN 1 ELSE 0 END,
               CASE WHEN fc.transit_ok=1 THEN 1 ELSE 0 END,
               CASE WHEN fc.bike_ok=1 THEN 1 ELSE 0 END,
               CASE WHEN fc.walk_ok=1 THEN 1 ELSE 0 END
        FROM #family_candidates fc
        JOIN #work w ON w.recid=fc.recid
        WHERE (fc.walk_ok + fc.bike_ok + fc.auto_ok + fc.transit_ok) BETWEEN 2 AND 3
          AND NOT EXISTS (SELECT 1 FROM #decisions d WHERE d.recid=fc.recid)
          AND w.o_lon IS NOT NULL AND w.o_lat IS NOT NULL AND w.d_lon IS NOT NULL AND w.d_lat IS NOT NULL;

        IF OBJECT_ID('tempdb..#api_results') IS NOT NULL DROP TABLE #api_results;
        CREATE TABLE #api_results (
            recid decimal(19,0) PRIMARY KEY,
            driving_min float NULL,
            transit_min float NULL,
            bicycling_min float NULL,
            walking_min float NULL,
            calls_used int NOT NULL
        );

        DECLARE @calls_used int = 0;
        DECLARE @batch_size int = 25;

        WHILE EXISTS (SELECT 1 FROM #api_queue) AND @calls_used < @max_api_calls_per_run
        BEGIN
            ;WITH takeN AS (
                SELECT TOP (@batch_size) * FROM #api_queue ORDER BY recid
            )
            SELECT * INTO #batch FROM takeN;

            DECLARE @dcount int = 0;
            DECLARE @qcount int = (SELECT COUNT(*) FROM #batch);

            /* For each recid in batch, call API for requested modes */
        DECLARE @recid decimal(19,0), @o_lon float, @o_lat float, @d_lon float, @d_lat float, @dur float, @depart datetime2,
                    @drive bit, @transit bit, @bike bit, @walk bit;

            DECLARE c CURSOR LOCAL FAST_FORWARD FOR
                SELECT recid, o_lon, o_lat, d_lon, d_lat, duration_min, depart_time_timestamp, want_drive, want_transit, want_bike, want_walk FROM #batch;
            OPEN c;
            FETCH NEXT FROM c INTO @recid, @o_lon, @o_lat, @d_lon, @d_lat, @dur, @depart, @drive, @transit, @bike, @walk;
            WHILE @@FETCH_STATUS = 0 AND @calls_used < @max_api_calls_per_run
            BEGIN
                DECLARE @drive_min float = NULL, @transit_min float = NULL, @bike_min float = NULL, @walk_min float = NULL;

                IF @drive = 1 BEGIN
                    DECLARE @r_driving nvarchar(200), @p_driving int;
                    SELECT @r_driving = Elmer.dbo.route_mi_min(@o_lon, @o_lat, @d_lon, @d_lat, 'driving', @GoogleKey, @depart);
                    SET @p_driving = CHARINDEX(',', @r_driving);
                    IF @p_driving > 0
                        SELECT @drive_min = TRY_CONVERT(float, LTRIM(RTRIM(SUBSTRING(@r_driving, @p_driving+1, 4000))));
                    ELSE
                        SELECT @drive_min = TRY_CONVERT(float, @r_driving);
                    SET @calls_used += 1;
                END
                IF @transit = 1 AND @calls_used < @max_api_calls_per_run BEGIN
                    DECLARE @r_transit nvarchar(200), @p_transit int;
                    SELECT @r_transit = Elmer.dbo.route_mi_min(@o_lon, @o_lat, @d_lon, @d_lat, 'transit', @GoogleKey, @depart);
                    SET @p_transit = CHARINDEX(',', @r_transit);
                    IF @p_transit > 0
                        SELECT @transit_min = TRY_CONVERT(float, LTRIM(RTRIM(SUBSTRING(@r_transit, @p_transit+1, 4000))));
                    ELSE
                        SELECT @transit_min = TRY_CONVERT(float, @r_transit);
                    SET @calls_used += 1;
                END
                IF @bike = 1 AND @calls_used < @max_api_calls_per_run BEGIN
                    -- Skip biking if distance obviously too long: rely on queue prefilter; still allow
                    DECLARE @r_bike nvarchar(200), @p_bike int;
                    SELECT @r_bike = Elmer.dbo.route_mi_min(@o_lon, @o_lat, @d_lon, @d_lat, 'bicycling', @GoogleKey, @depart);
                    SET @p_bike = CHARINDEX(',', @r_bike);
                    IF @p_bike > 0
                        SELECT @bike_min = TRY_CONVERT(float, LTRIM(RTRIM(SUBSTRING(@r_bike, @p_bike+1, 4000))));
                    ELSE
                        SELECT @bike_min = TRY_CONVERT(float, @r_bike);
                    SET @calls_used += 1;
                END
                IF @walk = 1 AND @calls_used < @max_api_calls_per_run BEGIN
                    DECLARE @r_walk nvarchar(200), @p_walk int;
                    SELECT @r_walk = Elmer.dbo.route_mi_min(@o_lon, @o_lat, @d_lon, @d_lat, 'walking', @GoogleKey, @depart);
                    SET @p_walk = CHARINDEX(',', @r_walk);
                    IF @p_walk > 0
                        SELECT @walk_min = TRY_CONVERT(float, LTRIM(RTRIM(SUBSTRING(@r_walk, @p_walk+1, 4000))));
                    ELSE
                        SELECT @walk_min = TRY_CONVERT(float, @r_walk);
                    SET @calls_used += 1;
                END

                INSERT INTO #api_results(recid, driving_min, transit_min, bicycling_min, walking_min, calls_used)
                VALUES(@recid, @drive_min, @transit_min, @bike_min, @walk_min, @calls_used);

                -- throttle 25ms between records in the batch
                WAITFOR DELAY '00:00:00.025';

                SET @dcount += 1;
                FETCH NEXT FROM c INTO @recid, @o_lon, @o_lat, @d_lon, @d_lat, @dur, @depart, @drive, @transit, @bike, @walk;
            END
            CLOSE c; DEALLOCATE c;

            -- Decide based on closest minutes
            INSERT INTO #decisions (recid, method, confidence, family, chosen_mode, api_driving_min, api_transit_min, api_bicycling_min, api_walking_min, api_best_mode, api_diff_minutes, api_calls_used)
            SELECT q.recid,
                   'api-tie-breaker', CASE WHEN ABS(r.best_min - q.duration_min) <= 0.2*q.duration_min THEN 'Medium' ELSE 'Low' END,
                   CASE r.best_mode WHEN 'driving' THEN 'AUTO' WHEN 'transit' THEN 'TRANSIT' WHEN 'bicycling' THEN 'BIKE' WHEN 'walking' THEN 'WALK' END,
                   COALESCE(
                       (SELECT TOP 1 pmf.mode_id FROM #person_mode_freq pmf JOIN #known_modes km ON km.mode_id=pmf.mode_id AND (
                            (r.best_mode='driving' AND km.family='AUTO') OR
                            (r.best_mode='transit' AND km.family='TRANSIT') OR
                            (r.best_mode='bicycling' AND km.family='BIKE') OR
                            (r.best_mode='walking' AND km.family='WALK')
                       ) WHERE pmf.person_id=w.person_id ORDER BY pmf.cnt DESC),
                       (SELECT mode_id FROM #family_defaults WHERE family=CASE r.best_mode WHEN 'driving' THEN 'AUTO' WHEN 'transit' THEN 'TRANSIT' WHEN 'bicycling' THEN 'BIKE' WHEN 'walking' THEN 'WALK' END)
                   ),
                   ar.driving_min, ar.transit_min, ar.bicycling_min, ar.walking_min, r.best_mode, ABS(r.best_min - q.duration_min), ar.calls_used
            FROM #api_queue q
            JOIN #api_results ar ON ar.recid=q.recid
            JOIN #work w ON w.recid=q.recid
            CROSS APPLY (
                SELECT TOP 1 best_mode, best_min
                FROM (VALUES
                        ('driving', ar.driving_min),
                        ('transit', ar.transit_min),
                        ('bicycling', ar.bicycling_min),
                        ('walking', ar.walking_min)
                     ) v(best_mode, best_min)
                WHERE best_min IS NOT NULL
                ORDER BY ABS(best_min - q.duration_min) ASC
            ) r
            WHERE NOT EXISTS (SELECT 1 FROM #decisions d WHERE d.recid=q.recid);

            DELETE q FROM #api_queue q WHERE EXISTS (SELECT 1 FROM #api_results r WHERE r.recid=q.recid);
            DROP TABLE #batch;
        END
    END

    /* For any remaining unresolved: if allow_low_confidence, pick AUTO default */
    IF @allow_low_confidence = 1
    BEGIN
        INSERT INTO #decisions (recid, method, confidence, family, chosen_mode)
        SELECT w.recid, 'low-confidence', 'Low', 'AUTO', (SELECT mode_id FROM #family_defaults WHERE family='AUTO')
        FROM #work w
        WHERE NOT EXISTS (SELECT 1 FROM #decisions d WHERE d.recid=w.recid);
    END

    /* Write results: update Trip.mode_1 unless dry-run */
    ;WITH chosen AS (
        SELECT d.recid, d.method, d.confidence, d.family, d.chosen_mode, d.donor_recid,
               d.api_driving_min, d.api_transit_min, d.api_bicycling_min, d.api_walking_min, d.api_best_mode, d.api_diff_minutes, d.api_calls_used
        FROM #decisions d
    )
    INSERT INTO HHSurvey.mode_imputation_log (
    recid, person_id, tripnum, traveldate,
    method, confidence, chosen_family, chosen_mode_id,
    prev_mode_id, distance_miles, duration_minutes, avg_speed_mph, tour_id,
    donor_recid, donor_person_id, donor_tripnum,
    api_driving_min, api_transit_min, api_bicycling_min, api_walking_min,
        api_best_mode, api_diff_minutes, api_calls_used, notes
    )
    SELECT w.recid, w.person_id, w.tripnum, w.traveldate,
       c.method, c.confidence, c.family, c.chosen_mode,
           t.mode_1, w.distance_miles, w.duration_min, w.mph, w.tour_num,
           c.donor_recid, td.person_id, td.tripnum,
           c.api_driving_min, c.api_transit_min, c.api_bicycling_min, c.api_walking_min,
                     c.api_best_mode, c.api_diff_minutes, c.api_calls_used,
                     CONCAT(
                         CASE WHEN @dry_run=1 THEN 'DRY RUN: Trip not updated; ' ELSE '' END,
                         'compatibility=',
                         CASE 
                             WHEN c.family='WALK' THEN CASE WHEN comp.walk_personal_ok=1 THEN 'personal' WHEN comp.walk_cohort_ok=1 THEN 'cohort' ELSE 'outside' END
                             WHEN c.family='BIKE' THEN CASE WHEN comp.bike_personal_ok=1 THEN 'personal' WHEN comp.bike_cohort_ok=1 THEN 'cohort' ELSE 'outside' END
                             WHEN c.family='AUTO' THEN CASE WHEN comp.auto_personal_ok=1 THEN 'personal' WHEN comp.auto_cohort_ok=1 THEN 'cohort' ELSE 'outside' END
                             WHEN c.family='TRANSIT' THEN CASE WHEN comp.transit_personal_ok=1 THEN 'personal' WHEN comp.transit_cohort_ok=1 THEN 'cohort' ELSE 'outside' END
                             WHEN c.family='AIR' THEN 'air'
                             ELSE 'unknown'
                         END
                     )
    FROM chosen c
    JOIN #work w ON w.recid=c.recid
    JOIN HHSurvey.Trip t ON t.recid=w.recid
        LEFT JOIN #compatibility comp ON comp.recid=w.recid
    LEFT JOIN HHSurvey.Trip td ON td.recid=c.donor_recid;

    IF @dry_run = 0
    BEGIN
        UPDATE t
        SET t.mode_1 = c.chosen_mode,
            t.revision_code = CONCAT(t.revision_code,
                CASE 
                    WHEN c.family='WALK' AND comp.walk_personal_ok=1 THEN '18a,'
                    WHEN c.family='WALK' AND comp.walk_cohort_ok=1 THEN '18b,'
                    WHEN c.family='BIKE' AND comp.bike_personal_ok=1 THEN '18a,'
                    WHEN c.family='BIKE' AND comp.bike_cohort_ok=1 THEN '18b,'
                    WHEN c.family='AUTO' AND comp.auto_personal_ok=1 THEN '18a,'
                    WHEN c.family='AUTO' AND comp.auto_cohort_ok=1 THEN '18b,'
                    WHEN c.family='TRANSIT' AND comp.transit_personal_ok=1 THEN '18a,'
                    WHEN c.family='TRANSIT' AND comp.transit_cohort_ok=1 THEN '18b,'
                    ELSE '18c,'
                END)
        FROM HHSurvey.Trip t
        JOIN #decisions c ON c.recid=t.recid
        LEFT JOIN #compatibility comp ON comp.recid=t.recid;
    END

    /* Return summary */
    SELECT method, confidence, COUNT(*) AS imputed_count
    FROM #decisions
    GROUP BY method, confidence
    ORDER BY method;
END
GO

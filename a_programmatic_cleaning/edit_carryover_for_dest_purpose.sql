-- Enable SQLCMD mode in your client (VS Code SQL tools / ADS / SSMS).
-- Adjust these variables as needed:
:setvar OLD_TABLE      [HHSurvey].[Trip_20251021]  -- archived, system-versioned
:setvar NEW_TABLE      [HHSurvey].[Trip]           -- current, system-versioned
:setvar OLD_START_COL  [valid_from]                -- your period start column in OLD

-- Toggle: 0 = preview (no update), 1 = perform update
DECLARE @do_update bit = 1;

SET XACT_ABORT ON;
BEGIN TRAN;

-- 1) Initial dest_purpose per TripID from OLD across all history
DROP TABLE IF EXISTS #old_first;
SELECT s.tripid,
       s.dest_purpose AS initial_dest_purpose
INTO #old_first
FROM (
    SELECT
        h.tripid,
        h.dest_purpose,
        ROW_NUMBER() OVER (
            PARTITION BY h.tripid
            ORDER BY h.$(OLD_START_COL) ASC, h.tripid
        ) AS rn
    FROM $(OLD_TABLE) FOR SYSTEM_TIME ALL AS h
) AS s
WHERE s.rn = 1;

-- 2) Candidate matches between current OLD and current NEW by keys
DROP TABLE IF EXISTS #matches;
SELECT
    n.person_id,
    n.arrival_time_timestamp,
    n.dest_lat,
    n.dest_lng,

    n.tripid               AS new_tripid,
    n.dest_purpose         AS current_new_dest_purpose,

    o.tripid               AS old_tripid,
    o.dest_purpose         AS final_old_dest_purpose,

    ofi.initial_dest_purpose
INTO #matches
FROM $(NEW_TABLE) AS n
JOIN $(OLD_TABLE) AS o
  ON o.person_id = n.person_id
 AND o.arrival_time_timestamp = n.arrival_time_timestamp
 AND o.dest_lat = n.dest_lat
 AND o.dest_lng = n.dest_lng
JOIN #old_first AS ofi
  ON ofi.tripid = o.tripid
WHERE
    -- (1) final OLD value not in {995, 60}
    o.dest_purpose NOT IN (995, 60)
    -- (2) initial OLD value equals current NEW value
    AND ofi.initial_dest_purpose = n.dest_purpose
    -- Avoid no-op updates (null-safe)
    AND (
        n.dest_purpose <> o.dest_purpose
        OR (n.dest_purpose IS NULL AND o.dest_purpose IS NOT NULL)
        OR (n.dest_purpose IS NOT NULL AND o.dest_purpose IS NULL)
    );

-- Optional: indexes for join performance (uncomment if needed)
-- CREATE INDEX IX_matches_keys ON #matches(person_id, arrival_time_timestamp, dest_lat, dest_lng);

IF (@do_update = 1)
BEGIN
    -- 3) Apply updates: set NEW.dest_purpose to OLD final dest_purpose
    UPDATE n
    SET n.dest_purpose = m.final_old_dest_purpose
    FROM $(NEW_TABLE) AS n
    JOIN #matches AS m
      ON m.person_id = n.person_id
     AND m.arrival_time_timestamp = n.arrival_time_timestamp
     AND m.dest_lat = n.dest_lat
     AND m.dest_lng = n.dest_lng;

    PRINT CONCAT('Rows updated: ', @@ROWCOUNT);
END
ELSE
BEGIN
    -- Preview only
    SELECT COUNT(*) AS would_update_count FROM #matches;

    SELECT TOP (50)
        person_id,
        arrival_time_timestamp,
        dest_lat,
        dest_lng,
        current_new_dest_purpose,
        initial_dest_purpose,
        final_old_dest_purpose
    FROM #matches
    ORDER BY person_id, arrival_time_timestamp;
END

COMMIT TRAN;

-- Cleanup
DROP TABLE IF EXISTS #matches;
DROP TABLE IF EXISTS #old_first;
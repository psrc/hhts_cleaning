SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE   FUNCTION [HHSurvey].[fnIdentifyGaps](
  @MinGapMeters INT = 500
)
RETURNS TABLE
AS
RETURN (
    WITH pairings AS (
        SELECT 
          CAST(t.recid AS DECIMAL(19,0)) AS prior_recid,
          CAST(t.person_id AS DECIMAL(19,0)) AS person_id,
          CAST(t.hhid AS DECIMAL(19,0)) AS hhid,
          t.pernum,
          t.arrival_time_timestamp AS gap_start_time,
          t.dest_geog AS gap_start_geog,
          t.dest_lat  AS gap_start_lat,
          t.dest_lng  AS gap_start_lng,
          CAST(nxt.recid AS DECIMAL(19,0)) AS next_recid,
          nxt.depart_time_timestamp AS gap_end_time,
          nxt.origin_geog AS gap_end_geog,
          nxt.origin_lat  AS gap_end_lat,
          nxt.origin_lng  AS gap_end_lng,
          CAST(t.dest_geog.STDistance(nxt.origin_geog) AS FLOAT) AS gap_meters,
          DATEDIFF(MINUTE, t.arrival_time_timestamp, nxt.depart_time_timestamp) AS window_minutes,
          t.mode_1 AS prior_mode,
          nxt.mode_1 AS next_mode
        FROM HHSurvey.Trip t WITH (NOLOCK)
        JOIN HHSurvey.Trip nxt WITH (NOLOCK)
          ON nxt.person_id = t.person_id AND nxt.tripnum = t.tripnum + 1
        WHERE COALESCE(t.psrc_inserted,0) = 0
          AND COALESCE(nxt.psrc_inserted,0) = 0
          AND t.dest_geog IS NOT NULL AND nxt.origin_geog IS NOT NULL
          AND t.dest_geog.STDistance(nxt.origin_geog) > @MinGapMeters
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
      CAST(ROW_NUMBER() OVER (ORDER BY p.person_id, p.gap_start_time) AS INT) AS gap_id,
      p.prior_recid, p.person_id, p.hhid, p.pernum,
      p.gap_start_time, p.gap_start_geog, p.gap_start_lat, p.gap_start_lng,
      p.next_recid, p.gap_end_time, p.gap_end_geog, p.gap_end_lat, p.gap_end_lng,
      p.gap_meters, p.window_minutes,
      p.prior_mode, p.next_mode,
      CAST(CASE WHEN p.prior_mode = p.next_mode THEN p.prior_mode ELSE 995 END AS INT) AS mode_imputed,
      CAST(0 AS INT) AS status
    FROM pairings p
);
GO

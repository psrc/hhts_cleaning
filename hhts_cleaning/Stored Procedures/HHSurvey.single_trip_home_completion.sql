SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/*
Purpose: Handle respondents with exactly one trip where both ends aren't overnighting locations.

Behavior:
1) For single-trip persons where exactly one trip end is at home:
   a) If the existing trip arrives home (x -> home): insert a reverse trip BEFORE it (home -> x).
      - Insert initially with no dwell (arrival at x equals existing.depart_time).
      - Optionally impute inserted.dest_purpose using HHSurvey.impute_purpose_from_location (@GoogleKey, or NULL for OSM mapping).
      - Compute dwell at x based on the trip that leaves home (the inserted trip):
           • 8 hours for work purposes (dest_purpose IN HHSurvey.work_purposes)
           • 6.5 hours for K12 school (dest_purpose = 21 AND Person.age_detailed < 19 AND STDistance(Person.school_geog) < 50m)
           • 30 minutes for personal business (dest_purpose = 33)
        Default dwell = 60 minutes otherwise.
      - Shift the inserted trip times earlier by dwell so that inserted.arrival_time = existing.depart_time - dwell.
   b) If the existing trip leaves home (home -> x): insert a reverse trip AFTER it (x -> home).
      - Compute dwell based on the existing trip's dest_purpose (the trip leaving home).
      - Insert the reverse trip to depart at existing.arrival_time + dwell.
   In both cases, finish by calling HHSurvey.recalculate_after_edit @target_person_id to refresh ordering and derived fields.

2) For single-trip persons where both ends are home OR neither end is home: remove the trip using HHSurvey.remove_trip.

Notes:
• "Home" is determined via geometry distance: origin_geog or dest_geog within 50m of HHSurvey.Household.home_geog.
• This procedure is idempotent per person-day shape if re-run cautiously; it only targets people with exactly one trip at time of execution.
*/
CREATE   PROCEDURE [HHSurvey].[single_trip_home_completion]
    @GoogleKey nvarchar(100) = NULL, -- if NULL, imputation uses OSM types; otherwise Google EntityType
    @ImputeMissing bit = 1            -- when 1, run HHSurvey.impute_purpose_from_location to enrich inserted trip purposes
AS
BEGIN
    SET NOCOUNT ON;

    -- Working set: persons with exactly 1 trip
    DROP TABLE IF EXISTS #single_trip;
    SELECT t.recid,
           t.person_id,
           t.hhid,
           t.tripnum,
           t.depart_time_timestamp,
           t.arrival_time_timestamp,
           t.origin_geog,
           t.dest_geog,
           t.origin_purpose,
           t.dest_purpose,
           DATEDIFF(minute, t.depart_time_timestamp, t.arrival_time_timestamp) AS travel_min
    INTO #single_trip
    FROM HHSurvey.Trip AS t
    WHERE EXISTS (
        SELECT 1 FROM HHSurvey.Trip AS t2 WHERE t2.person_id = t.person_id GROUP BY t2.person_id HAVING COUNT(*) = 1
    );

    -- Classify home-at-origin / home-at-destination using 150m proximity
    DROP TABLE IF EXISTS #single_trip_classified;
    SELECT s.*,
           CASE WHEN s.origin_geog.STDistance(h.home_geog) < 150 THEN 1 ELSE 0 END AS origin_is_home,
           CASE WHEN s.dest_geog.STDistance(h.home_geog)   < 150 THEN 1 ELSE 0 END AS dest_is_home
    INTO #single_trip_classified
    FROM #single_trip AS s
    JOIN HHSurvey.Household AS h ON s.hhid = h.hhid;

    -- Remove trivial/invalid shapes: both-home or neither-home
    DROP TABLE IF EXISTS #to_remove;
    SELECT c.recid INTO #to_remove
    FROM #single_trip_classified AS c
    WHERE (c.origin_is_home = 1 AND c.dest_is_home = 1)
       OR (c.origin_is_home = 0 AND c.dest_is_home = 0);

    DECLARE @rid decimal(19,0);
    WHILE EXISTS (SELECT 1 FROM #to_remove)
    BEGIN
        SELECT TOP (1) @rid = recid FROM #to_remove;
        DELETE FROM #to_remove WHERE recid = @rid;
        EXEC HHSurvey.remove_trip @target_recid = @rid; -- logs to HHSurvey.removed_trip via the procedure
    END

    -- Process single trips where exactly one end is at home
    DROP TABLE IF EXISTS #home_arrive, #home_depart;
    -- Case (a): arrives home (x -> home) => insert BEFORE (home -> x)
    SELECT c.*, p.age_detailed
    INTO #home_arrive
    FROM #single_trip_classified AS c
    JOIN HHSurvey.Person AS p ON c.person_id = p.person_id
    WHERE c.origin_is_home = 0 AND c.dest_is_home = 1;

    -- Case (b): leaves home (home -> x) => insert AFTER (x -> home)
    SELECT c.*, p.age_detailed
    INTO #home_depart
    FROM #single_trip_classified AS c
    JOIN HHSurvey.Person AS p ON c.person_id = p.person_id
    WHERE c.origin_is_home = 1 AND c.dest_is_home = 0;

    -- Helper: compute dwell based on a trip's destination purpose and context
    -- Returns dwell minutes; default 60 when not matched
    DROP TABLE IF EXISTS #dwell_after, #dwell_before;

    /* For home_depart (existing is home -> x), dwell is based on existing.dest_purpose at x */
    SELECT d.recid,
           CASE 
             WHEN d.dest_purpose IN (SELECT purpose_id FROM HHSurvey.work_purposes) THEN 8*60
             WHEN d.dest_purpose = 21 AND d.age_detailed < 19 AND d.dest_geog.STDistance(p.school_geog) < 150 THEN 390
             WHEN d.dest_purpose = 33 THEN 30
             ELSE 60
           END AS dwell_min
    INTO #dwell_after
    FROM #home_depart AS d
    JOIN HHSurvey.Person AS p ON d.person_id = p.person_id;

    /* For home_arrive (existing is x -> home), dwell is based on the inserted (home -> x) trip's destination.
       We'll first insert the reverse trip with no dwell, then (optionally) impute purpose, then compute dwell and shift times. */

    -- Insert reverse trips for case (b) (after): depart at existing.arrival + dwell
    DECLARE @startdt nvarchar(19);
    DECLARE @startdt_dt datetime2;
    DECLARE @person_id decimal(19,0);
    DECLARE @travel_min int;

    DECLARE after_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT hd.recid, hd.person_id, DATEADD(minute, dw.dwell_min, hd.arrival_time_timestamp) AS start_dt
        FROM #home_depart AS hd
        JOIN #dwell_after AS dw ON hd.recid = dw.recid;

    OPEN after_cursor;
    FETCH NEXT FROM after_cursor INTO @rid, @person_id, @startdt_dt;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @startdt = CONVERT(nvarchar(19), @startdt_dt, 120);
        EXEC HHSurvey.insert_reverse_trip @target_recid = @rid, @startdatetime = @startdt;
        -- Recalc for this person to set tripnums and derived fields
        EXEC HHSurvey.recalculate_after_edit @target_person_id = @person_id;
        FETCH NEXT FROM after_cursor INTO @rid, @person_id, @startdt_dt;
    END
    CLOSE after_cursor; DEALLOCATE after_cursor;

    -- Insert reverse trips for case (a) (before): initial arrival equals existing.depart_time (no dwell yet)
    -- startdatetime = existing.depart_time - travel_min
    DECLARE before_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT ha.recid, ha.person_id, CONVERT(nvarchar(19), DATEADD(minute, -ha.travel_min, ha.depart_time_timestamp), 120) AS start_dt
        FROM #home_arrive AS ha;

    OPEN before_cursor;
    FETCH NEXT FROM before_cursor INTO @rid, @person_id, @startdt;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC HHSurvey.insert_reverse_trip @target_recid = @rid, @startdatetime = @startdt;
        FETCH NEXT FROM before_cursor INTO @rid, @person_id, @startdt;
    END
    CLOSE before_cursor; DEALLOCATE before_cursor;

    -- Optionally impute destination purposes from location for any newly inserted trips that need it
    IF @ImputeMissing = 1
    BEGIN
        EXEC HHSurvey.impute_purpose_from_location @GoogleKey = @GoogleKey; -- global enrichment, uses temp table and safe guards
    END

    -- Ensure reverse trips that return to home have dest_purpose = 1 (home)
    UPDATE i
    SET i.dest_purpose = 1,
        i.revision_code = CONCAT(i.revision_code,'19,')
    FROM HHSurvey.Trip AS i
    JOIN HHSurvey.Household AS h ON i.hhid = h.hhid
    WHERE i.psrc_inserted = 1 AND i.dest_geog.STDistance(h.home_geog) < 150 AND (i.dest_purpose IS NULL OR i.dest_purpose <> 1);

    -- For each case (a) person, find the just-inserted reverse trip (home->x), compute dwell, and shift its times earlier
    -- Identify inserted rows by person_id + psrc_inserted=1 + geometry match and by matching the pairing to the original recid
    DROP TABLE IF EXISTS #inserted_before;
    SELECT i.recid AS inserted_recid,
           ha.recid AS original_recid,
           i.person_id,
           -- travel time for the inserted reverse trip (should equal original travel_min)
           DATEDIFF(minute, i.depart_time_timestamp, i.arrival_time_timestamp) AS insert_travel_min
    INTO #inserted_before
    FROM #home_arrive AS ha
    JOIN HHSurvey.Trip AS i ON i.person_id = ha.person_id AND i.psrc_inserted = 1
        AND i.origin_geog.STDistance(ha.dest_geog) < 10 AND i.dest_geog.STDistance(ha.origin_geog) < 10
        AND i.arrival_time_timestamp = ha.depart_time_timestamp; -- initially inserted to end exactly at original depart

    -- Compute dwell for inserted-before trips based on the inserted trip's dest_purpose and person context
    DROP TABLE IF EXISTS #dwell_before_calc;
    SELECT ib.inserted_recid,
           CASE 
             WHEN it.dest_purpose IN (SELECT purpose_id FROM HHSurvey.work_purposes) THEN 8*60
             WHEN it.dest_purpose = 21 AND p.age_detailed < 19 AND it.dest_geog.STDistance(p.school_geog) < 150 THEN 390
             WHEN it.dest_purpose = 33 THEN 30
             ELSE 60
           END AS dwell_min
    INTO #dwell_before_calc
    FROM #inserted_before AS ib
    JOIN HHSurvey.Trip AS it ON ib.inserted_recid = it.recid
    JOIN HHSurvey.Person AS p ON it.person_id = p.person_id;

    -- Shift inserted-before times earlier by dwell so arrival = original.depart_time - dwell
    UPDATE i
    SET i.arrival_time_timestamp = DATEADD(minute, -d.dwell_min, ha.depart_time_timestamp),
        i.depart_time_timestamp  = DATEADD(minute, -ib.insert_travel_min, DATEADD(minute, -d.dwell_min, ha.depart_time_timestamp))
    FROM HHSurvey.Trip AS i
    JOIN #inserted_before AS ib ON i.recid = ib.inserted_recid
    JOIN #dwell_before_calc AS d ON ib.inserted_recid = d.inserted_recid
    JOIN #home_arrive AS ha ON ib.original_recid = ha.recid;

    -- Recalculate for all persons we touched
    DROP TABLE IF EXISTS #affected_people;
    SELECT DISTINCT person_id INTO #affected_people FROM #home_depart
    UNION
    SELECT DISTINCT person_id FROM #home_arrive
    UNION
    SELECT DISTINCT person_id FROM #inserted_before;

    DECLARE @pid decimal(19,0);
    WHILE EXISTS (SELECT 1 FROM #affected_people)
    BEGIN
        SELECT TOP (1) @pid = person_id FROM #affected_people;
        DELETE FROM #affected_people WHERE person_id = @pid;
        EXEC HHSurvey.recalculate_after_edit @target_person_id = @pid;
    END

END
GO

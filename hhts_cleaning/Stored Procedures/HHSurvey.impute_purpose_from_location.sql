SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [HHSurvey].[impute_purpose_from_location] @GoogleKey nvarchar(100)
AS BEGIN 

    BEGIN TRANSACTION;
    -- Ensure a fresh staging table for each run (use local temp table to avoid persistent schema conflicts)
    IF OBJECT_ID('tempdb..#api_purpose') IS NOT NULL DROP TABLE #api_purpose;
    COMMIT TRANSACTION;

    BEGIN TRANSACTION;
    -- attempted flag ensures each record is sent to the API at most once
    SELECT t.recid, t.dest_lat, t.dest_lng, DATEDIFF(Minute, t.arrival_time_timestamp, nxt.depart_time_timestamp) AS dwell,
        CAST('PENDING' AS nvarchar(255)) AS loc_result,
        CAST(0 AS bit) AS attempted,
        0 AS new_dest_purpose
    INTO #api_purpose 
        FROM HHSurvey.Trip AS t LEFT JOIN HHSurvey.Trip AS nxt ON t.person_id = nxt.person_id AND t.tripnum +1 = nxt.tripnum JOIN HHSurvey.Person AS p ON t.person_id = p.person_id
        WHERE (t.dest_purpose IN(SELECT flag_value FROM HHSurvey.NullFlags UNION SELECT 97)                                     --"other"
               OR (t.dest_purpose=60 AND DATEDIFF(Minute, t.arrival_time_timestamp, nxt.depart_time_timestamp) > 60)            --"change mode" but didn't qualify for trip linking
               OR t.dest_purpose IN(45, 46, 48) AND DATEDIFF(Minute, t.arrival_time_timestamp, nxt.depart_time_timestamp) > 35) --PUDO but unreasonably long
        AND t.dest_is_home<>1 AND t.dest_is_work<>1;
    COMMIT TRANSACTION;		

    DECLARE @i int
    -- Process only unattempted rows to avoid re-calling the API for the same record
    SET @i = (SELECT count(*) FROM #api_purpose WHERE attempted = 0)
    WHILE @i > 0
    BEGIN 
        BEGIN TRANSACTION;
        UPDATE TOP (25) #api_purpose  -- Batch to avoid API limits
        SET attempted = 1,
            loc_result = Elmer.dbo.loc_recognize(dest_lng, dest_lat, @GoogleKey)
        WHERE attempted = 0;

        WAITFOR DELAY '00:00:02'; 

        SET @i = (SELECT count(*) FROM #api_purpose WHERE attempted = 0)
        COMMIT TRANSACTION;
    END

    BEGIN TRANSACTION;
    -- Map recognized location type to destination purpose.
    -- If @GoogleKey IS NULL, Elmer.dbo.loc_recognize used Nominatim; use OSM type lookup. Otherwise use Google EntityType lookup.
    IF @GoogleKey IS NULL
    BEGIN
        -- Normalize loc_result to the OSM "type" only (strip optional "class:" prefix),
        -- trim whitespace, and compare case-insensitively to improve matching robustness.
        UPDATE a 
        SET a.new_dest_purpose = b.dest_purpose
        FROM #api_purpose AS a
        JOIN HHSurvey.OsmType_purpose_lookup AS b
            ON LOWER(LTRIM(RTRIM(b.OsmType))) = LOWER(LTRIM(RTRIM(
                CASE
                    WHEN a.loc_result IS NULL THEN ''
                    WHEN CHARINDEX(':', a.loc_result) > 0 THEN SUBSTRING(a.loc_result, CHARINDEX(':', a.loc_result) + 1, LEN(a.loc_result))
                    ELSE a.loc_result
                END
            )))
        WHERE a.new_dest_purpose = 0 AND b.dest_purpose IS NOT NULL;
    END
    ELSE
    BEGIN
        UPDATE a 
        SET a.new_dest_purpose = b.dest_purpose
        FROM #api_purpose AS a
        JOIN HHSurvey.EntityType_purpose_lookup AS b ON b.EntityType = a.loc_result
        WHERE a.new_dest_purpose = 0 AND b.dest_purpose IS NOT NULL;
    END

    UPDATE t 
    SET t.dest_purpose=a.new_dest_purpose,
    t.revision_code=CONCAT(t.revision_code,'13,')
    FROM HHSurvey.Trip AS t JOIN #api_purpose AS a ON t.recid=a.recid JOIN HHSurvey.Person AS p ON t.person_id=p.person_id JOIN HHSurvey.Household AS h ON t.hhid=h.hhid
    WHERE a.new_dest_purpose<>0 AND t.dest_geog.STDistance(h.home_geog) > 150 AND (t.dest_geog.STDistance(p.work_geog) > 150 OR p.work_geog IS NULL);
    COMMIT TRANSACTION;

END
GO

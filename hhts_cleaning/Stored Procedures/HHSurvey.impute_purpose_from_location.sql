SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [HHSurvey].[impute_purpose_from_location] @GoogleKey nvarchar(100)
AS BEGIN 

    BEGIN TRANSACTION;
    DROP TABLE IF EXISTS dbo.api_purpose;
    COMMIT TRANSACTION;

    BEGIN TRANSACTION;
    SELECT t.recid, t.dest_lat, t.dest_lng, DATEDIFF(Minute, t.arrival_time_timestamp, nxt.depart_time_timestamp) AS dwell, CAST('PENDING' AS nvarchar(255)) AS loc_result, 0 AS new_dest_purpose
    INTO dbo.api_purpose 
        FROM HHSurvey.Trip AS t LEFT JOIN HHSurvey.Trip AS nxt ON t.person_id = nxt.person_id AND t.tripnum +1 = nxt.tripnum JOIN HHSurvey.Person AS p ON t.person_id = p.person_id
        WHERE t.dest_purpose IN(SELECT flag_value FROM HHSurvey.NullFlags UNION SELECT 97) OR (t.dest_purpose=60 AND DATEDIFF(Minute, t.arrival_time_timestamp, nxt.depart_time_timestamp) > 60)
        AND t.dest_is_home<>1 AND t.dest_is_work<>1;
    COMMIT TRANSACTION;		

    DECLARE @i int
    SET @i = (SELECT count(*) FROM dbo.api_purpose WHERE loc_result = 'PENDING')
    WHILE @i > 0
    BEGIN 
        BEGIN TRANSACTION;
        UPDATE TOP (25) dbo.api_purpose  -- Batch to avoid API limits
        SET loc_result = Elmer.dbo.loc_recognize(dest_lng, dest_lat, @GoogleKey)
        WHERE loc_result = 'PENDING';

        WAITFOR DELAY '00:00:02'; 

        SET @i = (SELECT count(*) FROM dbo.api_purpose WHERE loc_result = 'PENDING')
        COMMIT TRANSACTION;
    END

    BEGIN TRANSACTION;
    UPDATE a 
    SET a.new_dest_purpose=b.dest_purpose
    FROM dbo.api_purpose AS a JOIN HHSurvey.EntityType_purpose_lookup AS b ON b.EntityType=a.loc_result
    WHERE a.new_dest_purpose=0 AND b.dest_purpose IS NOT NULL;

    UPDATE t 
    SET t.dest_purpose=a.new_dest_purpose,
    t.revision_code=CONCAT(t.revision_code,'13,')
    FROM HHSurvey.Trip AS t JOIN dbo.api_purpose AS a ON t.recid=a.recid JOIN HHSurvey.Person AS p ON t.person_id=p.person_id JOIN HHSurvey.Household AS h ON t.hhid=h.hhid
    WHERE a.new_dest_purpose<>0 AND t.dest_geog.STDistance(h.home_geog) > 150 AND (t.dest_geog.STDistance(p.work_geog) > 150 OR p.work_geog IS NULL);
    COMMIT TRANSACTION;

END
GO

SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [HHSurvey].[initial_origin_purpose]
AS BEGIN

    -- to 'home' (should be largest share of cases)
    BEGIN TRANSACTION
    UPDATE t
    SET 	t.origin_purpose = 1,
            t.origin_geog = h.home_geog,
            t.origin_lat  = h.home_lat,
            t.origin_lng  = h.home_lng
    FROM HHSurvey.Trip AS t JOIN HHSurvey.Household AS h ON t.hhid = h.hhid
        WHERE t.tripnum = 1 AND t.origin_purpose NOT IN(1,10)
            AND t.origin_geog.STDistance(h.home_geog) < 300;
    COMMIT TRANSACTION

    -- to 'work'
    BEGIN TRANSACTION
    UPDATE t
    SET 	t.origin_purpose = 10,
            t.origin_geog = p.work_geog,
            t.origin_lat  = p.work_lat,
            t.origin_lng  = p.work_lng
    FROM HHSurvey.Trip AS t JOIN HHSurvey.Person AS p ON t.person_id = p.person_id
        WHERE t.tripnum = 1 AND t.origin_purpose NOT IN(1,10)
            AND t.origin_geog.STDistance(p.work_geog) < 300;
    COMMIT TRANSACTION
END
GO

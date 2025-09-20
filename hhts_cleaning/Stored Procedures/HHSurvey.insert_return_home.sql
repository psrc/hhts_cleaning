SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE   PROCEDURE [HHSurvey].[insert_return_home]
    @target_recid int = NULL,
    @startdatetime nvarchar(19) = NULL,
    @GoogleKey nvarchar(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @StartDT datetime2(0) = TRY_CONVERT(datetime2(0), @startdatetime);

    IF OBJECT_ID('tempdb..#tmpApi2Home') IS NOT NULL DROP TABLE #tmpApi2Home;
    CREATE TABLE #tmpApi2Home
    (
        rownum int IDENTITY(1,1) PRIMARY KEY,
        init_recid int NOT NULL,
        hhid int NOT NULL,
        person_id decimal(19,0) NOT NULL,
        pernum int NOT NULL,
        depart_time_timestamp datetime2(0) NOT NULL,
        origin_geog geography NOT NULL,
        home_geog geography NOT NULL,
        mode_1 int NOT NULL,
        travelers_hh int NULL,
        travelers_nonhh int NULL,
        travelers_total int NULL,
        api_miles float NULL,
        api_minutes float NULL
    );

    BEGIN TRY
        BEGIN TRAN;

        ;WITH cand AS
        (
            SELECT
                t.recid AS init_recid,
                t.hhid,
                t.person_id,
                t.pernum,
                t.dest_geog AS origin_geog,
                h.home_geog AS home_geog,
                t.mode_1,
                t.travelers_hh,
                t.travelers_nonhh,
                t.travelers_total,
                COALESCE(@StartDT, TRY_CONVERT(datetime2(0), t.arrival_time_timestamp)) AS depart_time_timestamp
            FROM [HHSurvey].[Trip] AS t
            INNER JOIN [HHSurvey].[Household] AS h ON t.hhid = h.hhid
            WHERE t.recid = @target_recid 
                AND t.dest_geog IS NOT NULL 
                AND h.home_geog IS NOT NULL
        )
        INSERT #tmpApi2Home
        (
            init_recid, hhid, person_id, pernum, depart_time_timestamp,
            origin_geog, home_geog, mode_1, travelers_hh, travelers_nonhh, travelers_total,
            api_miles, api_minutes
        )
        SELECT
            c.init_recid, c.hhid, c.person_id, c.pernum, c.depart_time_timestamp,
            c.origin_geog, c.home_geog, c.mode_1, c.travelers_hh, c.travelers_nonhh, c.travelers_total,
            TRY_CONVERT(float, Elmer.dbo.rgx_replace(r.api_response,'^(.*),.*','$1',1)) AS api_miles,
            TRY_CONVERT(float, Elmer.dbo.rgx_replace(r.api_response,'.*,(.*)$','$1',1)) AS api_minutes
        FROM cand AS c
        OUTER APPLY (
            SELECT api_response = Elmer.dbo.route_mi_min(
                    c.origin_geog.Long, c.origin_geog.Lat,
                    c.home_geog.Long, c.home_geog.Lat,
                    CASE
                        WHEN c.mode_1 = 1 THEN 'walking'
                        WHEN c.mode_1 IN (SELECT mode_id FROM HHSurvey.automodes) THEN 'driving'
                        WHEN c.mode_1 IN (SELECT mode_id FROM HHSurvey.transitmodes) THEN 'transit'
                        WHEN c.mode_1 IN (SELECT mode_id FROM HHSurvey.bikemodes) THEN 'cycling'
                        ELSE 'driving'
                    END,
                    @GoogleKey,
                    c.depart_time_timestamp
                )
        ) AS r;

        -- Nothing to insert
        IF NOT EXISTS (SELECT 1 FROM #tmpApi2Home)
        BEGIN
            ROLLBACK TRAN;
            RETURN;
        END

        -- Insert new trips using identity for recid
        INSERT [HHSurvey].[Trip]
        (
            hhid, person_id, pernum, psrc_inserted, tripnum, dest_is_home,
            dest_lat, dest_lng,
            origin_lat, origin_lng,
            depart_time_timestamp, arrival_time_timestamp, distance_miles,
            dest_purpose, mode_1, travelers_hh, travelers_nonhh, travelers_total
        )
        SELECT
            s.hhid, s.person_id, s.pernum, 1, 0, 1,
            s.home_geog.Lat, s.home_geog.Long,
            s.origin_geog.Lat, s.origin_geog.Long,
            s.depart_time_timestamp,
            CASE WHEN s.api_minutes IS NOT NULL THEN DATEADD(MINUTE, ROUND(s.api_minutes, 0), s.depart_time_timestamp) END,
            s.api_miles,
            1, s.mode_1, s.travelers_hh, s.travelers_nonhh, s.travelers_total
        FROM #tmpApi2Home AS s;

        -- Update the origin of the trip that originally followed the source trip
        UPDATE nxt
           SET nxt.origin_purpose = 1,
               nxt.origin_lat = s.home_geog.Lat,
               nxt.origin_lng = s.home_geog.Long
    FROM [HHSurvey].[Trip] AS t0
        INNER JOIN [HHSurvey].[Trip] AS nxt
                ON t0.person_id = nxt.person_id
               AND t0.tripnum + 1 = nxt.tripnum
    INNER JOIN #tmpApi2Home AS s
        ON t0.recid = s.init_recid;

        COMMIT TRAN;

        -- Ensure sequence alignment and dependent recalculations
        EXEC [HHSurvey].[tripnum_update];
        EXEC [HHSurvey].[recalculate_after_edit];
        EXEC [HHSurvey].[generate_error_flags];

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        DECLARE @msg nvarchar(4000) = ERROR_MESSAGE(),
                @num int = ERROR_NUMBER(),
                @sev int = ERROR_SEVERITY(),
                @state int = ERROR_STATE(),
                @line int = ERROR_LINE(),
                @proc sysname = ERROR_PROCEDURE();
        RAISERROR('insert_return_home failed (error %d, state %d) at line %d in %s: %s', @sev, 1, @num, @state, @line, @proc, @msg);
        RETURN;
    END CATCH
END
GO

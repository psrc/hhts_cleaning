SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   PROCEDURE [HHSurvey].[rulesy_setup_triptable]
AS BEGIN

    BEGIN TRANSACTION;
    DROP TABLE IF EXISTS HHSurvey.Trip;
    COMMIT TRANSACTION;

    BEGIN TRANSACTION  ;  
          CREATE TABLE HHSurvey.Trip (
               [recid] decimal(19,0) IDENTITY NOT NULL,
               [hhid] decimal(19,0) NOT NULL,
               [person_id] decimal(19,0) NOT NULL,
               [pernum] [int] NULL,
               [tripid] decimal(19,0) NULL,
               [tripnum] [int] NOT NULL DEFAULT 0,
               [traveldate] datetime2 NULL,
               [daynum] [int] NULL,
               [depart_time_timestamp] datetime2 NULL,
               [arrival_time_timestamp] datetime2 NULL,
               [origin_lat] [float] NULL,
               [origin_lng] [float] NULL,
               [dest_lat] [float] NULL,
               [dest_lng] [float] NULL,
               [distance_miles] [float] NULL,
               travel_time float null, -- duration as single field
               [hhmember1] decimal(19,0) NULL,
               [hhmember2] decimal(19,0) NULL,
               [hhmember3] decimal(19,0) NULL,
               [hhmember4] decimal(19,0) NULL,
               [hhmember5] decimal(19,0) NULL,
               [hhmember6] decimal(19,0) NULL,
               [hhmember7] decimal(19,0) NULL,
               [hhmember8] decimal(19,0) NULL,
               [hhmember9] decimal(19,0) NULL,
               [hhmember10] decimal(19,0) NULL,
               [hhmember11] decimal(19,0) NULL,
               [hhmember12] decimal(19,0) NULL,
               [hhmember13] decimal(19,0) NULL,
               [travelers_hh] [int] NOT NULL,
               [travelers_nonhh] [int] NOT NULL,
               [travelers_total] [int] NOT NULL,
               [origin_purpose] [int] NULL,
               [dest_purpose] [int] NULL,
               [dest_purpose_other] nvarchar(255) null,
               [mode_1] int NOT NULL,
               [mode_2] int NULL,
               [mode_3] int NULL,
               [mode_4] int NULL,
               [driver] int NULL,                            
               [mode_acc] int NULL,
               [mode_egr] int NULL,
               [speed_mph] [float] NULL,
               [mode_other_specify] [nvarchar](1000) NULL
          );
          COMMIT TRANSACTION;

        BEGIN TRANSACTION;
          INSERT INTO HHSurvey.Trip(
                [hhid]
               ,[person_id]
               ,[pernum]
               ,[tripid]
               ,[tripnum]
               ,[traveldate]
               ,[daynum]
               ,[depart_time_timestamp]
               ,[arrival_time_timestamp]
               ,[origin_lat]
               ,[origin_lng]
               ,[dest_lat]
               ,[dest_lng]
               ,[distance_miles]
               ,[travel_time]
               ,[hhmember1]
               ,[hhmember2]
               ,[hhmember3]
               ,[hhmember4]
               ,[hhmember5]
               ,[hhmember6]
               ,[hhmember7]
               ,[hhmember8]
               ,[hhmember9]
               ,[hhmember10]
               ,[hhmember11]
               ,[hhmember12]
               ,[hhmember13]
               ,[travelers_hh]
               ,[travelers_nonhh]
               ,[travelers_total]
               ,[origin_purpose]
               ,[dest_purpose]
               ,[dest_purpose_other]             
               ,[mode_1]
               ,[mode_2]
               ,[mode_3]
               ,[mode_4]            
               ,[driver]              
               ,[mode_acc]
               ,[mode_egr]               
               ,[speed_mph]
               ,[mode_other_specify]
                              )
          SELECT
               CAST(t.hhid AS decimal(19,0) )
               ,CAST(t.person_id AS decimal(19,0) )
               ,CAST(t.pernum AS [int])
               ,CAST(t.tripid AS decimal(19,0))
               ,CAST(t.tripnum AS [int])
               ,convert(date, t.travel_date, 121)
               ,CAST(t.daynum AS [int])
               ,DATETIME2FROMPARTS(CAST(LEFT(t.depart_date, 4) AS int), 
                                CAST(SUBSTRING(CAST(t.depart_date AS nvarchar), 6, 2) AS int), 
                                CAST(RIGHT(t.depart_date, 2) AS int), CAST(t.depart_time_hour AS int), 
                                CAST(t.depart_time_minute AS int), 0, 0, 0)
               ,DATETIME2FROMPARTS(CAST(LEFT(t.arrive_date, 4) AS int), 
                                CAST(SUBSTRING(CAST(t.arrive_date AS nvarchar), 6, 2) AS int), 
                                CAST(RIGHT(t.arrive_date, 2) AS int), 
                                CAST(t.arrival_time_hour AS int), 
                                CAST(t.arrival_time_minute AS int), 0, 0, 0)
               ,CAST(t.origin_lat AS [float])
               ,CAST(t.origin_lng AS [float])
               ,CAST(t.dest_lat AS [float])
               ,CAST(t.dest_lng AS [float])            
               ,CAST(t.distance_miles AS [float])
               ,CAST(t.duration_minutes AS FLOAT) + t.duration_seconds/60
               ,CAST(t.hhmember1 AS decimal(19,0))
               ,CAST(t.hhmember2 AS decimal(19,0))
               ,CAST(t.hhmember3 AS decimal(19,0))
               ,CAST(t.hhmember4 AS decimal(19,0))
               ,CAST(t.hhmember5 AS decimal(19,0))
               ,CAST(t.hhmember6 AS decimal(19,0))
               ,CAST(t.hhmember7 AS decimal(19,0))
               ,CAST(t.hhmember8 AS decimal(19,0))
               ,CAST(t.hhmember9 AS decimal(19,0))
               ,CAST(t.hhmember10 AS decimal(19,0))
               ,CAST(t.hhmember11 AS decimal(19,0))
               ,CAST(t.hhmember12 AS decimal(19,0))
               ,CAST(t.hhmember13 AS decimal(19,0))
               ,CAST(COALESCE(t.travelers_hh,1) AS [int])
               ,CAST(t.travelers_nonhh AS [int])
               ,CAST(t.travelers_total AS [int])
               ,CAST(t.origin_purpose AS [int])
               ,CAST(COALESCE(x.dest_purpose, t.dest_purpose) AS [int])
               ,CAST(t.dest_purpose_other AS nvarchar(255))
               ,cast(t.mode_1 as int)
               ,cast(t.mode_2 as int)
               ,cast(t.mode_3 as int)
               ,cast(t.mode_4 as int)
               ,cast(t.driver as int) 
               ,cast(t.mode_acc as int)
               ,cast(t.mode_egr as int)
               ,CAST(t.speed_mph AS [float])
               ,CAST(t.mode_other_specify as nvarchar(1000))
               FROM HouseholdTravelSurvey2025.dbo.ex_trip_unlinked AS t
               LEFT JOIN HouseholdTravelSurvey2025.dbo.ex_trip_linked AS x 
                  ON t.linked_trip_id=x.linked_trip_id 
                  AND t.arrive_date=x.arrive_date 
                  AND t.arrival_time_hour=x.arrival_time_hour 
                  AND t.arrival_time_minute=x.arrival_time_minute 
                  AND t.arrival_time_second=x.arrival_time_second
               WHERE transit_quality_flag NOT IN('SA','SE')
               ORDER BY tripid;
          COMMIT TRANSACTION;

        BEGIN TRANSACTION;
          ALTER TABLE HHSurvey.Trip --additional destination address fields
               ADD origin_geog    GEOGRAPHY NULL,
                    dest_geog     GEOGRAPHY NULL,
                    dest_is_home  bit NULL, 
                    dest_is_work  bit NULL,
                    modes         nvarchar(255),
                    psrc_inserted bit NULL,
                    revision_code nvarchar(255) NULL,
                    psrc_resolved int NULL,
                    psrc_comment  nvarchar(255) NULL;

          ALTER TABLE HHSurvey.household ADD home_geog   GEOGRAPHY NULL,
                                             home_lat    FLOAT     NULL,
                                             home_lng    FLOAT     NULL,
                                             sample_geog GEOGRAPHY NULL;
          ALTER TABLE HHSurvey.person    ADD work_geog   GEOGRAPHY NULL,
                                             school_geog GEOGRAPHY NULL;
        COMMIT TRANSACTION;

        BEGIN TRANSACTION;
          UPDATE HHSurvey.Trip 
            SET dest_geog = geography::STGeomFromText('POINT(' + CAST(dest_lng       AS VARCHAR(20)) + ' ' + CAST(dest_lat       AS VARCHAR(20)) + ')', 4326),
              origin_geog = geography::STGeomFromText('POINT(' + CAST(origin_lng     AS VARCHAR(20)) + ' ' + CAST(origin_lat     AS VARCHAR(20)) + ')', 4326);
          UPDATE HHSurvey.household 
            SET home_geog = geography::STGeomFromText('POINT(' + CAST(reported_lng   AS VARCHAR(20)) + ' ' + CAST(reported_lat   AS VARCHAR(20)) + ')', 4326),
              sample_geog = geography::STGeomFromText('POINT(' + CAST(sample_lng     AS VARCHAR(20)) + ' ' + CAST(sample_lat     AS VARCHAR(20)) + ')', 4326);
          UPDATE HHSurvey.person
            SET work_geog = geography::STGeomFromText('POINT(' + CAST(work_lng       AS VARCHAR(20)) + ' ' + CAST(work_lat       AS VARCHAR(20)) + ')', 4326),
              school_geog = geography::STGeomFromText('POINT(' + CAST(school_loc_lng AS VARCHAR(20)) + ' ' + CAST(school_loc_lat AS VARCHAR(20)) + ')', 4326);

          ALTER TABLE HHSurvey.Household ALTER COLUMN hhid decimal(19,0) NOT NULL;
          ALTER TABLE HHSurvey.Person ALTER COLUMN person_id decimal(19,0) NOT NULL;

          ALTER TABLE HHSurvey.Trip ADD CONSTRAINT PK_recid PRIMARY KEY CLUSTERED (recid) WITH FILLFACTOR=80;
          ALTER TABLE HHSurvey.Household ADD CONSTRAINT PK_hhid PRIMARY KEY CLUSTERED (hhid) WITH FILLFACTOR=80;
          ALTER TABLE HHSurvey.Person ADD CONSTRAINT PK_person_id PRIMARY KEY CLUSTERED (person_id) WITH FILLFACTOR=80;
          CREATE INDEX person_idx          ON HHSurvey.Trip(person_id ASC);
          CREATE INDEX tripnum_idx         ON HHSurvey.Trip(tripnum ASC);
          CREATE INDEX dest_purpose_idx    ON HHSurvey.Trip(dest_purpose);
          CREATE INDEX travelers_total_idx ON HHSurvey.Trip(travelers_total);
          CREATE INDEX person_tripnum_idx  ON HHSurvey.Trip(person_id, tripnum);
          CREATE INDEX person_timestamps   ON HHSurvey.Trip (person_id, depart_time_timestamp, arrival_time_timestamp);
          CREATE SPATIAL INDEX dest_geog_idx   ON HHSurvey.Trip(dest_geog)        USING GEOGRAPHY_AUTO_GRID;
          CREATE SPATIAL INDEX origin_geog_idx ON HHSurvey.Trip(origin_geog)      USING GEOGRAPHY_AUTO_GRID;
          CREATE SPATIAL INDEX home_geog_idx   ON HHSurvey.household(home_geog)   USING GEOGRAPHY_AUTO_GRID;
          CREATE SPATIAL INDEX sample_geog_idx ON HHSurvey.household(sample_geog) USING GEOGRAPHY_AUTO_GRID;
          CREATE SPATIAL INDEX work_geog_idx   ON HHSurvey.person(work_geog)      USING GEOGRAPHY_AUTO_GRID;
          COMMIT TRANSACTION;

END
GO

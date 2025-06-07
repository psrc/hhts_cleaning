SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/* Bring Trip data into hhts_cleaning with correct datatypes, 
   additional fields, and spatial indices 
   
   --you must update to reflect the source table name, line 340
*/

CREATE PROCEDURE [HHSurvey].[rulesy_setup_triptable]
AS BEGIN

    BEGIN TRANSACTION;
    DROP TABLE IF EXISTS HHSurvey.Trip;
    COMMIT TRANSACTION;

    BEGIN TRANSACTION  ;  
          CREATE TABLE HHSurvey.Trip (
               [recid] [int] IDENTITY NOT NULL,
               [hhid] decimal(19,0) NOT NULL,
               [person_id] decimal(19,0) NOT NULL,
               [pernum] [int] NULL,
               [tripid] decimal(19,0) NULL,
               [tripnum] [int] NOT NULL DEFAULT 0,
               [traveldate] datetime2 NULL,
               [daynum] [int] NULL,
               [copied_trip] [int] NULL,
               [svy_complete] [int] NULL,
               [depart_time_timestamp] datetime2 NULL,
               [arrival_time_timestamp] datetime2 NULL,
               [origin_lat] [float] NULL,
               [origin_lng] [float] NULL,
               [origin_label] [nvarchar](255) NULL,
               [dest_lat] [float] NULL,
               [dest_lng] [float] NULL,
               [dest_label] [nvarchar](255) NULL,
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
               [travelers_hh] [int] NOT NULL,
               [travelers_nonhh] [int] NOT NULL,
               [travelers_total] [int] NOT NULL,
               [origin_purpose] [int] NULL,
               [origin_purpose_cat] int null,
               [dest_purpose] [int] NULL,
               [dest_purpose_other] nvarchar(255) null,
               [dest_purpose_cat] int null,
               [mode_1] smallint NOT NULL,
               [mode_2] smallint NULL,
               [mode_3] smallint NULL,
               [mode_4] smallint NULL,
               mode_type int null,
               [driver] smallint NULL,
               [change_vehicles] smallint NULL,
               [is_access] smallint NULL,
               [is_egress] smallint NULL,
               [has_access] smallint NULL,
               [has_egress] smallint NULL,                              
               [mode_acc] smallint NULL,
               [mode_egr] smallint NULL,
               [speed_mph] [float] NULL,
               trace_quality_flag smallint NULL,
               [user_added] smallint null,
               [user_merged] smallint NULL,
               [user_split] smallint NULL,
               [analyst_merged] smallint NULL,
               [analyst_split] smallint NULL,
               [analyst_split_loop] smallint null,
               [day_id] [bigint] NOT NULL,
               [travel_day] [int] NOT NULL,
               [travel_date] [date] NOT NULL,
               [travel_dow] [int] NOT NULL,
               [day_iscomplete] [smallint] NULL,
               [depart_date] [date] NOT NULL,
               [depart_dow] [int] NOT NULL,
               [depart_time_hour] [int] NOT NULL,
               [depart_time_minute] [int] NOT NULL,
               [depart_time_second] [int] NOT NULL,
               [arrive_date] [date] NOT NULL,
               [arrive_dow] [int] NOT NULL,
               [arrival_time_hour] [int] NOT NULL,
               [arrival_time_minute] [int] NOT NULL,
               [arrival_time_second] [int] NOT NULL,
               [o_in_region] [int] NOT NULL,
               [o_puma10] [int] NULL,
               [o_bg] [bigint] NULL,
               [d_in_region] [int] NOT NULL,
               [d_puma10] [int] NULL,
               [d_bg] [bigint] NULL,
               [distance_meters] [float] NULL,
               [duration_minutes] [int] NOT NULL,
               [duration_seconds] [int] NOT NULL,
               [speed_flag] [int] NOT NULL,
               [dwell_mins] [float] NOT NULL,
               [days_first_trip] [int] NOT NULL,
               [days_last_trip] [int] NOT NULL,
               [mode_other_specify] [nvarchar](1000)  NULL,
               [is_transit] [int] NOT NULL,
               [hhmember10] [int] NOT NULL,
               [hhmember11] [int] NOT NULL,
               [hhmember12] [int] NOT NULL,
               [taxi_cost_known] [int] NOT NULL,
               [taxi_cost_int] [int] NULL,
               [flag_teleport] [int] NOT NULL,
               [pt_density] [float] NULL,
               [point_dist_index] [float] NULL,
               [trip_weight] [int] NOT NULL,
               [survey_year] [int] NOT NULL,
               [day_is_complete_a] [smallint] NULL,
               [day_is_complete_b] [smallint] NULL,
               [hh_day_iscomplete] [smallint] NULL,
               [hh_day_iscomplete_a] [smallint] NULL,
               [hh_day_iscomplete_b] [smallint] NULL,
               [psrc_comment] NVARCHAR(255) NULL,
               [psrc_resolved] smallint NULL,
               PRIMARY KEY CLUSTERED ([recid])
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
               ,[copied_trip]
               ,[svy_complete]
               ,[depart_time_timestamp]
               ,[arrival_time_timestamp]
               ,[origin_lat]
               ,[origin_lng]
               ,[origin_label]
               ,[dest_lat]
               ,[dest_lng]
               ,[dest_label]
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
               ,[travelers_hh]
               ,[travelers_nonhh]
               ,[travelers_total]
               ,[origin_purpose]
               ,origin_purpose_cat
               ,[dest_purpose]
               ,[dest_purpose_other]
               ,dest_purpose_cat               
               ,[mode_1]
               ,[mode_2]
               ,[mode_3]
               ,[mode_4]
               ,mode_type               
               ,[driver]
               ,[change_vehicles]
               ,[is_access]
               ,[is_egress]
               ,[has_access]
               ,[has_egress]               
               ,[mode_acc]
               ,[mode_egr]               
               ,[speed_mph]
               ,[trace_quality_flag]
               ,[user_added]
               ,[user_merged]
               ,[user_split]
               ,[analyst_merged]
               ,[analyst_split]
               ,[analyst_split_loop]
               ,[day_id]
               ,[travel_day]
               ,[travel_date] 
               ,[travel_dow] 
               ,[day_iscomplete]
               ,[depart_date] 
               ,[depart_dow]
               ,[depart_time_hour]
               ,[depart_time_minute]
               ,[depart_time_second]
               ,[arrive_date]
               ,[arrive_dow]
               ,[arrival_time_hour]
               ,[arrival_time_minute]
               ,[arrival_time_second]
               ,[o_in_region]
               ,[o_puma10]
               ,[o_bg]
               ,[d_in_region]
               ,[d_puma10]
               ,[d_bg]
               ,[distance_meters]
               ,[duration_minutes]
               ,[duration_seconds]
               ,[speed_flag]
               ,[dwell_mins]
               ,[days_first_trip] 
               ,[days_last_trip]
               ,[mode_other_specify]
               ,[is_transit]
               ,[hhmember10]
               ,[hhmember11]
               ,[hhmember12]
               ,[taxi_cost_known]
               ,[taxi_cost_int]
               ,[flag_teleport]
               ,[pt_density]
               ,[point_dist_index]
               ,[trip_weight]
               ,[survey_year] 
               ,[day_is_complete_a]
               ,[day_is_complete_b]
               ,[hh_day_iscomplete]
               ,[hh_day_iscomplete_a]
               ,[hh_day_iscomplete_b]
                              )
          SELECT
               CAST(hhid AS decimal(19,0) )
               ,CAST(person_id AS decimal(19,0) )
               ,CAST(pernum AS [int])
               ,CAST(tripid AS decimal(19,0))
               ,CAST(tripnum AS [int])
               ,convert(date, [travel_date], 121)
               ,CAST(daynum AS [int])
               ,CAST(copied_trip AS [int])
               ,CAST(svy_complete AS [int])
               ,DATETIME2FROMPARTS(CAST(LEFT(depart_date, 4) AS int), 
                                CAST(SUBSTRING(CAST(depart_date AS nvarchar), 6, 2) AS int), 
                                CAST(RIGHT(depart_date, 2) AS int), CAST(depart_time_hour AS int), 
                                CAST(depart_time_minute AS int), 0, 0, 0)
               ,DATETIME2FROMPARTS(CAST(LEFT(arrive_date, 4) AS int), 
                                CAST(SUBSTRING(CAST(arrive_date AS nvarchar), 6, 2) AS int), 
                                CAST(RIGHT(arrive_date, 2) AS int), 
                                CAST(arrival_time_hour AS int), 
                                CAST(arrival_time_minute AS int), 0, 0, 0)
               ,CAST(origin_lat AS [float])
               ,CAST(origin_lng AS [float])
               ,CAST(origin_label AS [nvarchar](255))
               ,CAST(dest_lat AS [float])
               ,CAST(dest_lng AS [float])
               ,CAST(dest_label AS [nvarchar](255))               
               ,CAST(distance_miles AS [float])
               ,CAST([duration_minutes] AS FLOAT) + [duration_seconds]/60
               ,CAST(hhmember1 AS decimal(19,0))
               ,CAST(hhmember2 AS decimal(19,0))
               ,CAST(hhmember3 AS decimal(19,0))
               ,CAST(hhmember4 AS decimal(19,0))
               ,CAST(hhmember5 AS decimal(19,0))
               ,CAST(hhmember6 AS decimal(19,0))
               ,CAST(hhmember7 AS decimal(19,0))
               ,CAST(hhmember8 AS decimal(19,0))
               ,NULL
               ,CAST(travelers_hh AS [int] )
               ,CAST(travelers_nonhh AS [int] )
               ,CAST(travelers_total AS [int] )
               ,CAST(origin_purpose AS [int])
               ,CAST(origin_purpose_cat AS int)
               ,CAST(dest_purpose AS [int])
               ,CAST(dest_purpose_other AS nvarchar(255))
               ,CAST(dest_purpose_cat AS int)
               ,cast([mode_1] as smallint)
               ,cast([mode_2] as smallint)
               ,cast([mode_3] as smallint)
               ,cast([mode_4] as smallint)
               ,CAST(mode_type AS int)
               ,cast([driver] as smallint)
               ,cast([change_vehicles] as smallint)
               ,cast([is_access] as smallint)
               ,cast([is_egress] as smallint)     
               ,cast([has_access] as smallint)
               ,cast([has_egress] as smallint)     
               ,cast([mode_acc] as smallint)
               ,cast([mode_egr] as smallint)
               ,CAST(speed_mph AS [float])
               ,CAST(trace_quality_flag AS nvarchar(20))
               ,CAST(user_added AS smallint)
               ,CAST(user_merged AS smallint)
               ,CAST(user_split AS smallint)
               ,CAST(analyst_merged AS smallint)
               ,CAST(analyst_split AS smallint)
               ,CAST(analyst_split_loop AS smallint)
               ,CAST(day_id AS bigint)
               ,CAST(travel_day AS smallint)
               ,CAST(travel_date AS date)
               ,CAST(travel_dow AS  smallint)
               ,CAST(day_iscomplete AS smallint)
               ,CAST(depart_date as date)
               ,CAST(depart_dow as smallint)
               ,CAST(depart_time_hour as smallint)
               ,CAST(depart_time_minute as smallint)
               ,CAST(depart_time_second as smallint)
               ,CAST(arrive_date as date)
               ,CAST(arrive_dow as smallint)
               ,CAST(arrival_time_hour as smallint)
               ,CAST(arrival_time_minute as smallint)
               ,CAST(arrival_time_second as smallint)
               ,CAST(o_in_region as int)
               ,CAST(o_puma10 as int)
               ,CAST(o_bg as bigint)
               ,CAST(d_in_region as int)
               ,CAST(d_puma10 as int)
               ,CAST(d_bg as bigint)
               ,CAST(distance_meters as float)
               ,CAST(duration_minutes as int)
               ,CAST(duration_seconds as int)
               ,CAST(speed_flag as int)
               ,CAST(dwell_mins as float)
               ,CAST(days_first_trip as int)
               ,CAST(days_last_trip as int)
               ,CAST(mode_other_specify as nvarchar(1000))
               ,CAST(is_transit as int)
               ,CAST(hhmember10 as int)
               ,CAST(hhmember11 as int)
               ,CAST(hhmember12 as int)
               ,CAST(taxi_cost_known as int)
               ,CAST(taxi_cost_int as int)
               ,CAST(flag_teleport as int)
               ,CAST(pt_density as float)
               ,CAST(point_dist_index as float)
               ,CAST(trip_weight as int)
               ,CAST(survey_year as int)
               ,CAST(day_is_complete_a as smallint)
               ,CAST(day_is_complete_b as smallint)
               ,CAST(hh_day_iscomplete as smallint)
               ,CAST(hh_day_iscomplete_a as smallint)
               ,CAST(hh_day_iscomplete_b as smallint)
               FROM HouseholdTravelSurvey2023.[combined_data].[v_trip]
               ORDER BY tripid;
          COMMIT TRANSACTION;

        BEGIN TRANSACTION;
          ALTER TABLE HHSurvey.Trip --additional destination address fields
               ADD origin_geog    GEOGRAPHY NULL,
                    dest_geog     GEOGRAPHY NULL,
                    dest_county   varchar(3) NULL,
                    dest_city     varchar(25) NULL,
                    dest_zip      varchar(5) NULL,
                    dest_is_home  bit NULL, 
                    dest_is_work  bit NULL,
                    modes         nvarchar(255),
                    psrc_inserted bit NULL,
                    revision_code nvarchar(255) NULL,
                    psrc_resolved smallint NULL,
                    psrc_comment  nvarchar(255) NULL;

          ALTER TABLE HHSurvey.household ADD home_geog   GEOGRAPHY NULL,
                                             home_lat    FLOAT     NULL,
                                             home_lng    FLOAT     NULL,
                                             sample_geog GEOGRAPHY NULL;
          ALTER TABLE HHSurvey.person    ADD work_geog   GEOGRAPHY NULL,
                                             school_geog GEOGRAPHY NULL;
        COMMIT TRANSACTION;

          UPDATE HHSurvey.Trip 
            SET dest_geog = geography::STGeomFromText('POINT(' + CAST(dest_lng       AS VARCHAR(20)) + ' ' + CAST(dest_lat       AS VARCHAR(20)) + ')', 4326),
              origin_geog = geography::STGeomFromText('POINT(' + CAST(origin_lng     AS VARCHAR(20)) + ' ' + CAST(origin_lat     AS VARCHAR(20)) + ')', 4326);
          UPDATE HHSurvey.household 
            SET home_geog = geography::STGeomFromText('POINT(' + CAST(reported_lng   AS VARCHAR(20)) + ' ' + CAST(reported_lat   AS VARCHAR(20)) + ')', 4326),
              sample_geog = geography::STGeomFromText('POINT(' + CAST(sample_lng     AS VARCHAR(20)) + ' ' + CAST(sample_lat     AS VARCHAR(20)) + ')', 4326);
          UPDATE HHSurvey.person
            SET work_geog = geography::STGeomFromText('POINT(' + CAST(work_lng       AS VARCHAR(20)) + ' ' + CAST(work_lat       AS VARCHAR(20)) + ')', 4326),
              school_geog = geography::STGeomFromText('POINT(' + CAST(school_loc_lng AS VARCHAR(20)) + ' ' + CAST(school_loc_lat AS VARCHAR(20)) + ')', 4326);

          ALTER TABLE HHSurvey.Trip ADD CONSTRAINT PK_recid PRIMARY KEY CLUSTERED (recid) WITH FILLFACTOR=80;
          CREATE INDEX person_idx          ON HHSurvey.Trip(person_id ASC);
          CREATE INDEX tripnum_idx         ON HHSurvey.Trip(tripnum ASC);
          CREATE INDEX dest_purpose_idx    ON HHSurvey.Trip(dest_purpose);
          CREATE INDEX travelers_total_idx ON HHSurvey.Trip(travelers_total);
          CREATE INDEX person_tripnum_idx  ON HHSurvey.Trip(person_id, tripnum);
          CREATE SPATIAL INDEX dest_geog_idx   ON HHSurvey.Trip(dest_geog)        USING GEOGRAPHY_AUTO_GRID;
          CREATE SPATIAL INDEX origin_geog_idx ON HHSurvey.Trip(origin_geog)      USING GEOGRAPHY_AUTO_GRID;
          CREATE SPATIAL INDEX home_geog_idx   ON HHSurvey.household(home_geog)   USING GEOGRAPHY_AUTO_GRID;
          CREATE SPATIAL INDEX sample_geog_idx ON HHSurvey.household(sample_geog) USING GEOGRAPHY_AUTO_GRID;
          CREATE SPATIAL INDEX work_geog_idx   ON HHSurvey.person(work_geog)      USING GEOGRAPHY_AUTO_GRID;

END
GO

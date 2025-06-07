SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
		CREATE PROCEDURE [HHSurvey].[insert_return_home]
		AS BEGIN
		DROP TABLE IF EXISTS tmpApi2Home;
		CREATE TABLE tmpApi2Home(rownum int identity(1,1),
								 init_recid int,
								 new_recid int,
								 hhid int, 
								 person_id decimal(19,0),
								 pernum int,
								 api_response nvarchar(255), 
								 depart_time_timestamp datetime2,
								 api_minutes float, 
								 origin_geog geography, 
							     home_geog geography, 
								 mode_1 int, 
								 travelers_hh int, 
								 travelers_nonhh int, 
								 travelers_total int, 
								 api_miles float);

		
		INSERT INTO tmpApi2Home(init_recid, hhid, person_id, pernum, api_response, mode_1, depart_time_timestamp, origin_geog, home_geog, travelers_hh, travelers_nonhh, travelers_total)
		SELECT t.recid AS init_recid, t.hhid, t.person_id, t.pernum,
			   Elmer.dbo.route_mi_min(t.dest_geog.Long, t.dest_geog.Lat, h.home_geog.Long, h.home_geog.Lat, 
			   						  CASE WHEN p.age <5 AND t.dest_purpose=6 AND t.dest_geog.STDistance(h.home_geog) < 1500 THEN 'walking' ELSE 'driving' END,'AlrP-dw5WRAoOohAABv5EhKtvgp_plo8hnfBM-FJsfvi9UdFCe0AdqT7oURMTGLC') AS api_response,
			   CASE WHEN p.age <5 AND t.dest_purpose=6 AND t.dest_geog.STDistance(h.home_geog) < 1500 THEN 1 ELSE 16 END	AS mode_1, 
			   DATETIME2FROMPARTS(YEAR(t.arrival_time_timestamp), 
			   					  MONTH(t.arrival_time_timestamp), 
								  DAY(t.arrival_time_timestamp), 
								  CAST(Elmer.dbo.rgx_replace(t.psrc_comment,'ADD RETURN HOME( \d?\d):\d\d.*',LTRIM('$1'),1) AS int), 
								  CAST(RIGHT(Elmer.dbo.rgx_extract(t.psrc_comment,':\d\d',1),2) AS int), 0 ,0 ,0) AS depart_time_timestamp,
			   t.dest_geog,
			   h.home_geog,
			   t.travelers_hh, 
			   t.travelers_nonhh,
			   t.travelers_total
			FROM HHSurvey.Trip AS t JOIN HHSurvey.Household AS h ON t.hhid=h.hhid JOIN HHSurvey.Person AS p ON t.person_id=p.person_id
			WHERE Elmer.dbo.rgx_find(t.psrc_comment, 'ADD RETURN HOME \d?\d:\d\d',1) =1;

		WITH cte AS (SELECT max(recid) AS max_recid FROM HHSurvey.Trip)	
		UPDATE ta
			SET new_recid = (cte.max_recid + ta.rownum),
				api_miles = CAST(Elmer.dbo.rgx_replace(api_response,'^(.*),.*','$1',1) AS float), 
		        api_minutes = CAST(Elmer.dbo.rgx_replace(api_response,'.*,(.*)$','$1',1) AS float)
			FROM tmpApi2Home AS ta JOIN cte ON 1=1;		

		SET IDENTITY_INSERT hhts_cleaning.HHSurvey.Trip ON;

		INSERT INTO	HHSurvey.Trip (recid, hhid, person_id, pernum, psrc_inserted, tripnum,
				dest_lat, dest_lng, dest_label, origin_lat, origin_lng, depart_time_timestamp, arrival_time_timestamp, distance_miles,
				dest_purpose, mode_1, travelers_hh, travelers_nonhh, travelers_total)
		SELECT  ta.new_recid AS recid, ta.hhid, ta.person_id, ta.pernum, 1, 0,
				ta.home_geog.Lat, ta.home_geog.Long, 'HOME', ta.origin_geog.Lat, ta.origin_geog.Long, depart_time_timestamp, 
				DATEADD(Minute, ROUND(ta.api_minutes,0), ta.depart_time_timestamp) AS arrival_time_timestamp,
				ta.api_miles, 1 AS dest_purpose, ta.mode_1, ta.travelers_hh, ta.travelers_nonhh, ta.travelers_total
			FROM tmpApi2Home AS ta;

		SET IDENTITY_INSERT hhts_cleaning.HHSurvey.Trip OFF;

		UPDATE t 
			SET t.psrc_comment = Elmer.dbo.rgx_replace(t.psrc_comment, 'ADD RETURN HOME \d?\d:\d\d','',1) 
			FROM HHSurvey.Trip AS t JOIN tmpApi2Home AS ta ON t.recid = ta.init_recid;
		UPDATE nxt
		 	SET nxt.origin_purpose=1, nxt.origin_lat=ta.home_geog.Lat, nxt.origin_lng=ta.home_geog.Long
			FROM HHSurvey.Trip AS t JOIN HHSurvey.Trip AS nxt ON t.person_id = nxt.person_id AND t.tripnum + 1 = nxt.tripnum JOIN tmpApi2Home AS ta ON t.recid = ta.new_recid;

		EXECUTE HHSurvey.recalculate_after_edit;
		EXECUTE HHSurvey.tripnum_update
		EXECUTE HHSurvey.generate_error_flags;	
		END
GO

use hhts_cleaning
go

/******************
Restore hhts_cleaning_250903 
***************/

	RESTORE DATABASE hhts_cleaning_20250903
	FROM DISK = '\\aws-prod-file01\SQL2022\hhts_cleaning\Archive\hhts_cleaning_backup_202509031800.bak'
	WITH RECOVERY, REPLACE
		,MOVE 'hhts_cleaning_Data' TO N'D:\Elmer_dB\hhts_cleaning_20250903.mdf'
		,MOVE 'hhts_cleaning_Log' TO N'D:\Elmer_dB\hhts_cleaning_20250903.ldf'

-- drop dependent views  data2fixie and person_all
	drop view HHSurvey.data2fixie

	drop view HHSurvey.person_all

	drop view HHSurvey.pass2trip

	drop view HHSurvey.person_error_assignment

-- turn system versioning off 

    ALTER TABLE HHSurvey.Trip 
    set (system_versioning = OFF);

    ALTER TABLE HHSurvey.trip_error_flags
    set (system_versioning = OFF);

-- delete post-rulesy rows from the history table for Trip

    delete 
    from History.HHSurvey__Trip
	where valid_to > '2025-08-29'

	DELETE
	from History.HHSurvey__trip_error_flags 
	where valid_to > '2025-08-29'

-- replace all rows to the version in hhts_cleaning_20250903

	--HHSurvey.Trip
		delete 
		from HHSurvey.Trip

		set IDENTITY_INSERT HHSurvey.TRIP on


		INSERT INTO hhts_cleaning.HHSurvey.Trip (
			[recid] ,[hhid] ,[person_id] ,[pernum] ,[tripid] ,[tripnum] ,[traveldate] ,[daynum] ,[depart_time_timestamp] ,[arrival_time_timestamp]
			,[origin_lat] ,[origin_lng] ,[dest_lat] ,[dest_lng] ,[distance_miles] ,[travel_time] ,[hhmember1] ,[hhmember2] ,[hhmember3] ,[hhmember4]
			,[hhmember5] ,[hhmember6] ,[hhmember7] ,[hhmember8] ,[hhmember9] ,[hhmember10] ,[hhmember11] ,[hhmember12] ,[hhmember13] ,[travelers_hh]
			,[travelers_nonhh] ,[travelers_total] ,[origin_purpose] ,[dest_purpose] ,[dest_purpose_other] ,[mode_1] ,[mode_2] ,[mode_3] ,[mode_4] ,[driver]
			,[mode_acc] ,[mode_egr] ,[speed_mph] ,[mode_other_specify] ,[origin_geog] ,[dest_geog] ,[dest_is_home] ,[dest_is_work] ,[modes] ,[psrc_inserted]
			,[revision_code] ,[psrc_resolved] ,[psrc_comment]
		)
		SELECT 
			[recid] ,[hhid] ,[person_id] ,[pernum] ,[tripid] ,[tripnum] ,[traveldate] ,[daynum] ,[depart_time_timestamp] ,[arrival_time_timestamp]
			,[origin_lat] ,[origin_lng] ,[dest_lat] ,[dest_lng] ,[distance_miles] ,[travel_time] ,[hhmember1] ,[hhmember2] ,[hhmember3] ,[hhmember4]
			,[hhmember5] ,[hhmember6] ,[hhmember7] ,[hhmember8] ,[hhmember9] ,[hhmember10] ,[hhmember11] ,[hhmember12] ,[hhmember13] ,[travelers_hh]
			,[travelers_nonhh] ,[travelers_total] ,[origin_purpose] ,[dest_purpose] ,[dest_purpose_other] ,[mode_1] ,[mode_2] ,[mode_3] ,[mode_4] ,[driver]
			,[mode_acc] ,[mode_egr] ,[speed_mph] ,[mode_other_specify] ,[origin_geog] ,[dest_geog] ,[dest_is_home] ,[dest_is_work] ,[modes] ,[psrc_inserted]
			,[revision_code] ,[psrc_resolved] ,[psrc_comment]
		FROM [hhts_cleaning_20250903].[HHSurvey].[Trip]

		set IDENTITY_INSERT HHSurvey.TRIP off

	-- HHSurvey.trip_error_flags

		delete 
		from HHSurvey.trip_error_flags
		go

		INSERT INTO hhts_cleaning.HHSurvey.trip_error_flags(
			[recid] ,[person_id] ,[tripnum] ,[error_flag]
		)
		SELECT 
			[recid] ,[person_id] ,[tripnum] ,[error_flag]
		FROM [hhts_cleaning_20250903].[HHSurvey].[trip_error_flags]


-- reinstate system versioning 

    alter table HHSurvey.Trip
	set (system_versioning = on (history_table = History.HHSurvey__Trip));
    go

	alter table HHSurvey.trip_error_flags
	set (system_versioning = on (history_table = History.HHSurvey__trip_error_flags));
	go

-- restore view data2fixie
	CREATE VIEW [HHSurvey].[data2fixie] WITH SCHEMABINDING  
		AS
		SELECT 
			t1.recid, 
			t1.person_id,
			t1.daynum,	
			t1.tripnum, 
			STUFF((SELECT ',' + tef.error_flag
					FROM HHSurvey.trip_error_flags AS tef
					WHERE tef.recid = t1.recid
					ORDER BY tef.error_flag DESC
					FOR XML PATH('')), 1, 1, NULL) AS Error,
			STUFF((SELECT DISTINCT ',' + mode_desc
					FROM (
						SELECT ma.mode_desc UNION ALL
						SELECT m1.mode_desc UNION ALL  
						SELECT m2.mode_desc UNION ALL
						SELECT m3.mode_desc UNION ALL
						SELECT m4.mode_desc UNION ALL
						SELECT me.mode_desc
					) AS all_modes
					WHERE mode_desc IS NOT NULL
					FOR XML PATH('')
				), 1, 1, '') AS Modes, 
			FORMAT(t1.depart_time_timestamp,N'hh\:mm tt','en-US') AS DepartTime,
			FORMAT(t1.arrival_time_timestamp,N'hh\:mm tt','en-US') AS ArriveTime,
			ROUND(t1.distance_miles,1) AS Miles,
			ROUND(t1.speed_mph,1) AS MPH, 
			t1.travelers_total AS TotalTravelers,
			CONCAT(t1.origin_purpose, ': ',tpo.purpose) AS OriginPurpose, 
			CONCAT(t1.dest_purpose, ': ',tpd.purpose) AS DestPurpose,
			t1.dest_purpose_other AS OtherPurpose,
			CONCAT(CONVERT(varchar(30), (DATEDIFF(mi, t1.arrival_time_timestamp, t2.depart_time_timestamp) / 60)),'h',RIGHT('00'+CONVERT(varchar(30), (DATEDIFF(mi, t1.arrival_time_timestamp, CASE WHEN t2.recid IS NULL 
									THEN DATETIME2FROMPARTS(DATEPART(year,t1.arrival_time_timestamp),DATEPART(month,t1.arrival_time_timestamp),DATEPART(day,t1.arrival_time_timestamp),3,0,0,0,0) 
									ELSE t2.depart_time_timestamp END) % 60)),2),'m') AS DurationAtDest,
			t1.revision_code--, 
			-- t1.psrc_comment AS ElevateIssue,
			-- CASE WHEN EXISTS (SELECT 1 FROM HHSurvey.Trip WHERE Trip.psrc_comment IS NOT NULL AND t1.person_id = Trip.person_id) THEN 1 ELSE 0 END AS Elevated
			
		FROM HHSurvey.trip AS t1 LEFT JOIN HHSurvey.trip as t2 ON t1.person_id = t2.person_id AND (t1.tripnum+1) = t2.tripnum JOIN HHSurvey.Household AS h on h.hhid=t1.hhid
			LEFT JOIN HHSurvey.trip_mode AS ma ON t1.mode_acc=ma.mode_id AND ma.mode_id NOT IN(SELECT flag_value FROM HHSurvey.NullFlags)
			LEFT JOIN HHSurvey.trip_mode AS m1 ON t1.mode_1=m1.mode_id AND m1.mode_id NOT IN(SELECT flag_value FROM HHSurvey.NullFlags)
			LEFT JOIN HHSurvey.trip_mode AS m2 ON t1.mode_2=m2.mode_id AND m2.mode_id NOT IN(SELECT flag_value FROM HHSurvey.NullFlags)
			LEFT JOIN HHSurvey.trip_mode AS m3 ON t1.mode_3=m3.mode_id AND m3.mode_id NOT IN(SELECT flag_value FROM HHSurvey.NullFlags)
			LEFT JOIN HHSurvey.trip_mode AS m4 ON t1.mode_4=m4.mode_id AND m4.mode_id NOT IN(SELECT flag_value FROM HHSurvey.NullFlags)
			LEFT JOIN HHSurvey.trip_mode AS me ON t1.mode_egr=me.mode_id AND me.mode_id NOT IN(SELECT flag_value FROM HHSurvey.NullFlags)
			LEFT JOIN HHSurvey.trip_purpose AS tpo ON t1.origin_purpose=tpo.purpose_id
			LEFT JOIN HHSurvey.trip_purpose AS tpd ON t1.dest_purpose=tpd.purpose_id;
	GO

  -- restore view person_all
		CREATE VIEW [HHSurvey].[person_all] WITH SCHEMABINDING AS
		SELECT 
			p.person_id, 
			p.age_detailed AS Age, 
			CASE WHEN p.employment BETWEEN 1 AND 4 THEN 'Yes' ELSE 'No' END AS Works, 
			CASE WHEN p.student = 1 THEN 'No' WHEN student IN(2,4,5) THEN 'PT' WHEN p.student IN(3,6,7) THEN 'FT' ELSE 'No' END AS Studies, 
			CASE WHEN h.hhgroup=11 THEN 'rMove' ELSE 'rSurvey' END AS HHGroup
		FROM HHSurvey.Person AS p 
			JOIN HHSurvey.Household AS h on h.hhid=p.hhid
		WHERE p.person_id IN (SELECT person_id FROM HHSurvey.Trip);
	GO

	-- restore pass2trip
		CREATE VIEW [HHSurvey].[pass2trip] WITH SCHEMABINDING
		AS
		SELECT t.[recid]
			,h.[hhid]
			,t.[person_id] AS person_id
			,t.[pernum]
			,t.[tripid]
			,t.[tripnum]
			,t.[traveldate]
			,t.[daynum]
			,CASE WHEN h.hhgroup=11 THEN 'rMove' ELSE 'rSurvey' END AS hhgroup
			,t.[depart_time_timestamp]
			,t.[arrival_time_timestamp]
			,'' AS origin_name
			,t.[origin_lat]
			,t.[origin_lng]
			,'' AS dest_name
			,t.[dest_lat]
			,t.[dest_lng]
			,t.distance_miles AS trip_path_distance
			,t.[travel_time]
			,t.[hhmember1]
			,t.[hhmember2]
			,t.[hhmember3]
			,t.[hhmember4]
			,t.[hhmember5]
			,t.[hhmember6]
			,t.[hhmember7]
			,t.[hhmember8]
			,t.[hhmember9]
			,t.[travelers_hh]
			,t.[travelers_nonhh]
			,t.[travelers_total]
			,t.[origin_purpose]
			,t.[dest_purpose]
			,t.[mode_1]
			,t.[mode_2]
			,t.[mode_3]
			,t.[mode_4]
			,t.[driver]
			,t.[mode_acc]
			,t.[mode_egr]
			,t.[speed_mph]
			,t.[psrc_comment]
			,t.[psrc_resolved]
		FROM HHSurvey.Trip AS t JOIN HHSurvey.Household AS h on h.hhid=t.hhid;
	GO
	SET ARITHABORT ON
	SET CONCAT_NULL_YIELDS_NULL ON
	SET QUOTED_IDENTIFIER ON
	SET ANSI_NULLS ON
	SET ANSI_PADDING ON
	SET ANSI_WARNINGS ON
	SET NUMERIC_ROUNDABORT OFF
	GO
	CREATE UNIQUE CLUSTERED INDEX [PK_pass2trip] ON [HHSurvey].[pass2trip]
	(
		[recid] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
	GO

 -- restore view person_error_assignment
	CREATE   VIEW [HHSurvey].[person_error_assignment] WITH SCHEMABINDING AS
	WITH FlagPriority AS (
		SELECT v.error_flag, v.priority
		FROM (VALUES
			('"change mode" purpose',1),
			('lone trip',2),
			('purpose missing',3),
			('mode_1 missing',4),
			('time overlap',5),
			('instantaneous',6),
			('excessive speed',7),
			('too slow',8),
			('same dest as prior',9),
			('purpose at odds w/ dest',10),
			('too long at dest?',11),
			('o purpose not equal to prior d purpose',12),
			('no activity time after',13),
			('missing next trip link',14),
			('ends day, not home',15),
			('starts, not from home',16),
			('initial trip purpose missing',17),
			('non-student + school trip',18),
			('non-worker + work trip',19),
			('underage_detailed driver',20)
		) v(error_flag, priority)
	), PersonFlags AS (
		SELECT t.person_id,
			CASE WHEN t.psrc_comment IS NOT NULL THEN 0 ELSE fp.priority END AS priority,
			CASE WHEN t.psrc_comment IS NOT NULL THEN 'Elevated' ELSE fp.error_flag END AS assignment
		FROM HHSurvey.trip_error_flags tef
		JOIN HHSurvey.Trip t ON t.recid = tef.recid
		JOIN FlagPriority fp ON fp.error_flag = tef.error_flag
	)
	SELECT person_id, assignment
	FROM (
		SELECT person_id, assignment,
			ROW_NUMBER() OVER (PARTITION BY person_id ORDER BY priority) AS rn
		FROM PersonFlags
	) x
	WHERE rn = 1;


/*****
trip_ingredients_done
********/
	delete 
	from HHSurvey.trip_ingredients_done
	go


	INSERT INTO HHSurvey.trip_ingredients_done (
		[recid] ,[hhid] ,[person_id] ,[pernum] ,[tripid] ,[tripnum] ,[traveldate] ,[daynum]
		,[depart_time_timestamp] ,[arrival_time_timestamp] ,[origin_lat] ,[origin_lng] ,[dest_lat] ,[dest_lng] ,[distance_miles] ,[travel_time]
		,[hhmember1] ,[hhmember2] ,[hhmember3] ,[hhmember4] ,[hhmember5] ,[hhmember6] ,[hhmember7] ,[hhmember8]
		,[hhmember9] ,[hhmember10] ,[hhmember11] ,[hhmember12] ,[hhmember13] ,[travelers_hh] ,[travelers_nonhh] ,[travelers_total]
		,[origin_purpose] ,[dest_purpose] ,[dest_purpose_other] ,[mode_1] ,[mode_2] ,[mode_3] ,[mode_4] ,[driver]
		,[mode_acc] ,[mode_egr] ,[speed_mph] ,[mode_other_specify] ,[origin_geog] ,[dest_geog] ,[dest_is_home] ,[dest_is_work]
		,[modes] ,[psrc_inserted] ,[revision_code] ,[psrc_resolved] ,[psrc_comment] ,[trip_link]
	)
	SELECT 
		[recid] ,[hhid] ,[person_id] ,[pernum] ,[tripid] ,[tripnum] ,[traveldate] ,[daynum]
		,[depart_time_timestamp] ,[arrival_time_timestamp] ,[origin_lat] ,[origin_lng] ,[dest_lat] ,[dest_lng] ,[distance_miles] ,[travel_time]
		,[hhmember1] ,[hhmember2] ,[hhmember3] ,[hhmember4] ,[hhmember5] ,[hhmember6] ,[hhmember7] ,[hhmember8]
		,[hhmember9] ,[hhmember10] ,[hhmember11] ,[hhmember12] ,[hhmember13] ,[travelers_hh] ,[travelers_nonhh] ,[travelers_total]
		,[origin_purpose] ,[dest_purpose] ,[dest_purpose_other] ,[mode_1] ,[mode_2] ,[mode_3] ,[mode_4] ,[driver]
		,[mode_acc] ,[mode_egr] ,[speed_mph] ,[mode_other_specify] ,[origin_geog] ,[dest_geog] ,[dest_is_home] ,[dest_is_work]
		,[modes] ,[psrc_inserted] ,[revision_code] ,[psrc_resolved] ,[psrc_comment] ,[trip_link]
	FROM [hhts_cleaning_20250903].[HHSurvey].[trip_ingredients_done]


/*****
removed_trip
********/

	delete 
	from HHSurvey.removed_trip
	go

	INSERT INTO HHSurvey.removed_trip (
		[recid],[hhid] ,[person_id] ,[pernum] ,[tripid] ,[tripnum] ,[traveldate] ,[daynum] ,[depart_time_timestamp]
		,[arrival_time_timestamp] ,[origin_lat] ,[origin_lng] ,[dest_lat] ,[dest_lng] ,[distance_miles] ,[travel_time] ,[hhmember1]
		,[hhmember2] ,[hhmember3] ,[hhmember4] ,[hhmember5] ,[hhmember6] ,[hhmember7] ,[hhmember8] ,[hhmember9]
		,[hhmember10] ,[hhmember11] ,[hhmember12] ,[hhmember13] ,[travelers_hh] ,[travelers_nonhh] ,[travelers_total] ,[origin_purpose]
		,[dest_purpose] ,[dest_purpose_other] ,[mode_1] ,[mode_2] ,[mode_3] ,[mode_4] ,[driver] ,[mode_acc]
		,[mode_egr] ,[speed_mph] ,[mode_other_specify] ,[origin_geog] ,[dest_geog] ,[dest_is_home] ,[dest_is_work] ,[modes]
		,[psrc_inserted] ,[revision_code] ,[psrc_resolved] ,[psrc_comment] ,[valid_from] ,[valid_to] 
	)
	SELECT 
			[recid] ,[hhid] ,[person_id] ,[pernum] ,[tripid] ,[tripnum] ,[traveldate] ,[daynum] ,[depart_time_timestamp]
		,[arrival_time_timestamp] ,[origin_lat] ,[origin_lng] ,[dest_lat] ,[dest_lng] ,[distance_miles] ,[travel_time] ,[hhmember1]
		,[hhmember2] ,[hhmember3] ,[hhmember4] ,[hhmember5] ,[hhmember6] ,[hhmember7] ,[hhmember8] ,[hhmember9]
		,[hhmember10] ,[hhmember11] ,[hhmember12] ,[hhmember13] ,[travelers_hh] ,[travelers_nonhh] ,[travelers_total] ,[origin_purpose]
		,[dest_purpose] ,[dest_purpose_other] ,[mode_1] ,[mode_2] ,[mode_3] ,[mode_4] ,[driver] ,[mode_acc]
		,[mode_egr] ,[speed_mph] ,[mode_other_specify] ,[origin_geog] ,[dest_geog] ,[dest_is_home] ,[dest_is_work] ,[modes]
		,[psrc_inserted] ,[revision_code] ,[psrc_resolved] ,[psrc_comment] ,[valid_from] ,[valid_to] 
		FROM [hhts_cleaning_20250903].[HHSurvey].[removed_trip]
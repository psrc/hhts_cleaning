/*  Import 2025 tables */

USE hhts_cleaning
GO
DROP VIEW IF EXISTS HHSurvey.person_all, HHSurvey.person_Elevated, HHSurvey.data2fixie, HHSurvey.pass2trip;
GO
DROP TABLE HHSurvey.Household;
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [HHSurvey].[Household](
	[diary_platform] [varchar](255) NULL,
	[hhid] [int] NULL,
	[num_complete_thu] [int] NULL,
	[num_complete_tue] [int] NULL,
	[num_days_complete_weekday] [int] NULL,
	[num_days_complete_weekend] [int] NULL,
	[num_participants] [int] NULL,
	[num_trips] [int] NULL,
	[numdayscomplete] [int] NULL,
	[prev_home_lat] [float] NULL,
	[prev_home_lng] [float] NULL,
	[prev_home_notwa_zip] [varchar](255) NULL,
	[prev_res_factors_specify] [varchar](255) NULL,
	[reported_lat] [float] NULL,
	[reported_lng] [float] NULL,
	[sample_lat] [float] NULL,
	[sample_lng] [float] NULL,
	[signup_platform] [varchar](255) NULL,
	[survey_year] [varchar](255) NULL,
	[traveldate_end] [date] NULL,
	[traveldate_start] [date] NULL,
	[home_state] [int] NULL,
	[home_county] [int] NULL,
	[home_bg_2010] [varchar](255) NULL,
	[home_bg_2020] [varchar](255) NULL,
	[home_puma_2012] [int] NULL,
	[home_puma_2022] [int] NULL,
	[sample_home_bg] [varchar](255) NULL,
	[hh_is_complete] [int] NULL,
	[hhgroup] [int] NULL,
	[hhincome_broad] [int] NULL,
	[hhincome_detailed] [int] NULL,
	[hhincome_followup] [int] NULL,
	[hhsize] [int] NULL,
	[home_in_region] [int] NULL,
	[num_students] [int] NULL,
	[num_surveyable] [int] NULL,
	[numadults] [int] NULL,
	[numchildren] [int] NULL,
	[numworkers] [int] NULL,
	[prev_home_notwa_state] [int] NULL,
	[prev_home_wa] [int] NULL,
	[prev_rent_own] [int] NULL,
	[prev_res_factors_amenities] [int] NULL,
	[prev_res_factors_community_change] [int] NULL,
	[prev_res_factors_crime] [int] NULL,
	[prev_res_factors_employment] [int] NULL,
	[prev_res_factors_forced] [int] NULL,
	[prev_res_factors_hh_size] [int] NULL,
	[prev_res_factors_housing_cost] [int] NULL,
	[prev_res_factors_income_change] [int] NULL,
	[prev_res_factors_less_space] [int] NULL,
	[prev_res_factors_more_space] [int] NULL,
	[prev_res_factors_no_answer] [int] NULL,
	[prev_res_factors_other] [int] NULL,
	[prev_res_factors_quality] [int] NULL,
	[prev_res_factors_school] [int] NULL,
	[prev_res_factors_telework] [int] NULL,
	[prev_res_type] [int] NULL,
	[rent_own] [int] NULL,
	[res_dur] [int] NULL,
	[res_type] [int] NULL,
	[sample_segment] [int] NULL,
	[vehicle_count] [int] NULL,
	[num_complete_fri] [int] NULL,
	[num_complete_mon] [int] NULL,
	[num_complete_sat] [int] NULL,
	[num_complete_sun] [int] NULL,
	[num_complete_wed] [int] NULL
) ON [PRIMARY]
GO

INSERT INTO HHSurvey.Household([diary_platform]
      ,[hhid]
      ,[num_complete_thu]
      ,[num_complete_tue]
      ,[num_days_complete_weekday]
      ,[num_days_complete_weekend]
      ,[num_participants]
      ,[num_trips]
      ,[numdayscomplete]
      ,[prev_home_lat]
      ,[prev_home_lng]
      ,[prev_home_notwa_zip]
      ,[prev_res_factors_specify]
      ,[reported_lat]
      ,[reported_lng]
      ,[sample_lat]
      ,[sample_lng]
      ,[signup_platform]
      ,[survey_year]
      ,[traveldate_end]
      ,[traveldate_start]
      ,[home_state]
      ,[home_county]
      ,[home_bg_2010]
      ,[home_bg_2020]
      ,[home_puma_2012]
      ,[home_puma_2022]
      ,[sample_home_bg]
      ,[hh_is_complete]
      ,[hhgroup]
      ,[hhincome_broad]
      ,[hhincome_detailed]
      ,[hhincome_followup]
      ,[hhsize]
      ,[home_in_region]
      ,[num_students]
      ,[num_surveyable]
      ,[numadults]
      ,[numchildren]
      ,[numworkers]
      ,[prev_home_notwa_state]
      ,[prev_home_wa]
      ,[prev_rent_own]
      ,[prev_res_factors_amenities]
      ,[prev_res_factors_community_change]
      ,[prev_res_factors_crime]
      ,[prev_res_factors_employment]
      ,[prev_res_factors_forced]
      ,[prev_res_factors_hh_size]
      ,[prev_res_factors_housing_cost]
      ,[prev_res_factors_income_change]
      ,[prev_res_factors_less_space]
      ,[prev_res_factors_more_space]
      ,[prev_res_factors_no_answer]
      ,[prev_res_factors_other]
      ,[prev_res_factors_quality]
      ,[prev_res_factors_school]
      ,[prev_res_factors_telework]
      ,[prev_res_type]
      ,[rent_own]
      ,[res_dur]
      ,[res_type]
      ,[sample_segment]
      ,[vehicle_count]
      ,[num_complete_fri]
      ,[num_complete_mon]
      ,[num_complete_sat]
      ,[num_complete_sun]
      ,[num_complete_wed])
SELECT [diary_platform]
      ,[hhid]
      ,[num_complete_thu]
      ,[num_complete_tue]
      ,[num_days_complete_weekday]
      ,[num_days_complete_weekend]
      ,[num_participants]
      ,[num_trips]
      ,[numdayscomplete]
      ,[prev_home_lat]
      ,[prev_home_lng]
      ,[prev_home_notwa_zip]
      ,[prev_res_factors_specify]
      ,[reported_lat]
      ,[reported_lng]
      ,[sample_lat]
      ,[sample_lng]
      ,[signup_platform]
      ,[survey_year]
      ,[traveldate_end]
      ,[traveldate_start]
      ,[home_state]
      ,[home_county]
      ,[home_bg_2010]
      ,[home_bg_2020]
      ,[home_puma_2012]
      ,[home_puma_2022]
      ,[sample_home_bg]
      ,[hh_is_complete]
      ,[hhgroup]
      ,[hhincome_broad]
      ,[hhincome_detailed]
      ,[hhincome_followup]
      ,[hhsize]
      ,[home_in_region]
      ,[num_students]
      ,[num_surveyable]
      ,[numadults]
      ,[numchildren]
      ,[numworkers]
      ,[prev_home_notwa_state]
      ,[prev_home_wa]
      ,[prev_rent_own]
      ,[prev_res_factors_amenities]
      ,[prev_res_factors_community_change]
      ,[prev_res_factors_crime]
      ,[prev_res_factors_employment]
      ,[prev_res_factors_forced]
      ,[prev_res_factors_hh_size]
      ,[prev_res_factors_housing_cost]
      ,[prev_res_factors_income_change]
      ,[prev_res_factors_less_space]
      ,[prev_res_factors_more_space]
      ,[prev_res_factors_no_answer]
      ,[prev_res_factors_other]
      ,[prev_res_factors_quality]
      ,[prev_res_factors_school]
      ,[prev_res_factors_telework]
      ,[prev_res_type]
      ,[rent_own]
      ,[res_dur]
      ,[res_type]
      ,[sample_segment]
      ,[vehicle_count]
      ,[num_complete_fri]
      ,[num_complete_mon]
      ,[num_complete_sat]
      ,[num_complete_sun]
      ,[num_complete_wed]
	  FROM HouseholdTravelSurvey2025.dbo.ex_hh;
	  GO
        CREATE TABLE HHSurvey.Person(
	[ethnicity_other] [varchar](255) NULL,
	[hhid] [varchar](255) NULL,
	[industry_other] [varchar](356) NULL,
	[can_drive] [varchar](255) NULL,
	[num_trips] [varchar](255) NULL,
	[numdayscomplete] [varchar](255) NULL,
	[pernum] [varchar](255) NULL,
	[person_id] [varchar](255) NULL,
	[race_other_specify] [varchar](255) NULL,
	[school_bg] [varchar](255) NULL,
	[school_loc_lat] [float] NULL,
	[school_loc_lng] [float] NULL,
	[school_puma10] [varchar](255) NULL,
	[second_home_lat] [float] NULL,
	[second_home_lon] [float] NULL,
	[survey_year] [varchar](255) NULL,
	[work_bg] [varchar](255) NULL,
	[work_lat] [float] NULL,
	[work_lng] [float] NULL,
	[work_puma10] [varchar](255) NULL,
	[bike_freq] [int] NULL,
	[carshare_freq] [int] NULL,
	[commute_freq] [int] NULL,
	[commute_subsidy_1] [int] NULL,
	[commute_subsidy_2] [int] NULL,
	[commute_subsidy_3] [int] NULL,
	[commute_subsidy_4] [int] NULL,
	[commute_subsidy_5] [int] NULL,
	[commute_subsidy_6] [int] NULL,
	[commute_subsidy_7] [int] NULL,
	[commute_subsidy_996] [int] NULL,
	[commute_subsidy_998] [int] NULL,
	[commute_subsidy_use_1] [int] NULL,
	[commute_subsidy_use_2] [int] NULL,
	[commute_subsidy_use_3] [int] NULL,
	[commute_subsidy_use_4] [int] NULL,
	[commute_subsidy_use_5] [int] NULL,
	[commute_subsidy_use_6] [int] NULL,
	[commute_subsidy_use_7] [int] NULL,
	[commute_subsidy_use_996] [int] NULL,
	[disability_person] [int] NULL,
	[education] [int] NULL,
	[employment] [int] NULL,
	[ethnicity_1] [int] NULL,
	[ethnicity_2] [int] NULL,
	[ethnicity_3] [int] NULL,
	[ethnicity_4] [int] NULL,
	[ethnicity_997] [int] NULL,
	[ethnicity_999] [int] NULL,
	[ev_typical_charge_1] [int] NULL,
	[ev_typical_charge_2] [int] NULL,
	[ev_typical_charge_3] [int] NULL,
	[ev_typical_charge_4] [int] NULL,
	[ev_typical_charge_5] [int] NULL,
	[ev_typical_charge_6] [int] NULL,
	[ev_typical_charge_997] [int] NULL,
	[gender] [int] NULL,
	[hours_work] [int] NULL,
	[industry] [int] NULL,
	[is_participant] [int] NULL,
	[mobility_aides] [int] NULL,
	[office_available] [int] NULL,
	[participate] [int] NULL,
	[person_is_complete] [int] NULL,
	[proxy] [int] NULL,
	[proxy_parent] [int] NULL,
	[race_afam] [int] NULL,
	[race_aiak] [int] NULL,
	[race_asian] [int] NULL,
	[race_hapi] [int] NULL,
	[race_noanswer] [int] NULL,
	[race_other] [int] NULL,
	[race_white] [int] NULL,
	[relationship] [int] NULL,
	[remote_class_freq] [int] NULL,
	[school_freq] [int] NULL,
	[school_in_region] [int] NULL,
	[school_mode_typical] [int] NULL,
	[schooltype] [int] NULL,
	[second_home] [int] NULL,
	[second_home_in_region] [int] NULL,
	[sexuality] [int] NULL,
	[share_1] [int] NULL,
	[share_2] [int] NULL,
	[share_3] [int] NULL,
	[share_4] [int] NULL,
	[share_5] [int] NULL,
	[share_996] [int] NULL,
	[smartphone_type] [int] NULL,
	[student] [int] NULL,
	[surveyable] [int] NULL,
	[telecommute_freq] [int] NULL,
	[tnc_freq] [int] NULL,
	[transit_freq] [int] NULL,
	[walk_freq] [int] NULL,
	[work_in_region] [int] NULL,
	[work_mode] [int] NULL,
	[workplace] [int] NULL,
	[age_detailed] [int] NULL,
	[drive_for_work] [int] NULL,
	[employment_followup] [int] NULL,
	[paid_work] [int] NULL,
	[return_from_leave] [int] NULL,
	[transportation_statement_car] [int] NULL,
	[transportation_statement_environ] [int] NULL,
	[transportation_statement_retail] [int] NULL,
	[transportation_statement_telework] [float] NULL,
	[transportation_statement_transit] [int] NULL,
	[transportation_statement_travel] [int] NULL,
	[transportation_statement_walk] [int] NULL,
	[work_from_home] [int] NULL
) ON [PRIMARY]
GO
INSERT INTO HHSurvey.Person(
	[ethnicity_other]
      ,[hhid]
      ,[industry_other]
      ,[can_drive]
      ,[num_trips]
      ,[numdayscomplete]
      ,[pernum]
      ,[person_id]
      ,[race_other_specify]
      ,[school_bg]
      ,[school_loc_lat]
      ,[school_loc_lng]
      ,[school_puma10]
      ,[second_home_lat]
      ,[second_home_lon]
      ,[survey_year]
      ,[work_bg]
      ,[work_lat]
      ,[work_lng]
      ,[work_puma10]
      ,[bike_freq]
      ,[carshare_freq]
      ,[commute_freq]
      ,[commute_subsidy_1]
      ,[commute_subsidy_2]
      ,[commute_subsidy_3]
      ,[commute_subsidy_4]
      ,[commute_subsidy_5]
      ,[commute_subsidy_6]
      ,[commute_subsidy_7]
      ,[commute_subsidy_996]
      ,[commute_subsidy_998]
      ,[commute_subsidy_use_1]
      ,[commute_subsidy_use_2]
      ,[commute_subsidy_use_3]
      ,[commute_subsidy_use_4]
      ,[commute_subsidy_use_5]
      ,[commute_subsidy_use_6]
      ,[commute_subsidy_use_7]
      ,[commute_subsidy_use_996]
      ,[disability_person]
      ,[education]
      ,[employment]
      ,[ethnicity_1]
      ,[ethnicity_2]
      ,[ethnicity_3]
      ,[ethnicity_4]
      ,[ethnicity_997]
      ,[ethnicity_999]
      ,[ev_typical_charge_1]
      ,[ev_typical_charge_2]
      ,[ev_typical_charge_3]
      ,[ev_typical_charge_4]
      ,[ev_typical_charge_5]
      ,[ev_typical_charge_6]
      ,[ev_typical_charge_997]
      ,[gender]
      ,[hours_work]
      ,[industry]
      ,[is_participant]
      ,[mobility_aides]
      ,[office_available]
      ,[participate]
      ,[person_is_complete]
      ,[proxy]
      ,[proxy_parent]
      ,[race_afam]
      ,[race_aiak]
      ,[race_asian]
      ,[race_hapi]
      ,[race_noanswer]
      ,[race_other]
      ,[race_white]
      ,[relationship]
      ,[remote_class_freq]
      ,[school_freq]
      ,[school_in_region]
      ,[school_mode_typical]
      ,[schooltype]
      ,[second_home]
      ,[second_home_in_region]
      ,[sexuality]
      ,[share_1]
      ,[share_2]
      ,[share_3]
      ,[share_4]
      ,[share_5]
      ,[share_996]
      ,[smartphone_type]
      ,[student]
      ,[surveyable]
      ,[telecommute_freq]
      ,[tnc_freq]
      ,[transit_freq]
      ,[walk_freq]
      ,[work_in_region]
      ,[work_mode]
      ,[workplace]
      ,[age_detailed]
      ,[drive_for_work]
      ,[employment_followup]
      ,[paid_work]
      ,[return_from_leave]
      ,[transportation_statement_car]
      ,[transportation_statement_environ]
      ,[transportation_statement_retail]
      ,[transportation_statement_telework]
      ,[transportation_statement_transit]
      ,[transportation_statement_travel]
      ,[transportation_statement_walk]
      ,[work_from_home]
)
SELECT [ethnicity_other]
      ,[hhid]
      ,[industry_other]
      ,[can_drive]
      ,[num_trips]
      ,[numdayscomplete]
      ,[pernum]
      ,[person_id]
      ,[race_other_specify]
      ,[school_bg]
      ,[school_loc_lat]
      ,[school_loc_lng]
      ,[school_puma10]
      ,[second_home_lat]
      ,[second_home_lon]
      ,[survey_year]
      ,[work_bg]
      ,[work_lat]
      ,[work_lng]
      ,[work_puma10]
      ,[bike_freq]
      ,[carshare_freq]
      ,[commute_freq]
      ,[commute_subsidy_1]
      ,[commute_subsidy_2]
      ,[commute_subsidy_3]
      ,[commute_subsidy_4]
      ,[commute_subsidy_5]
      ,[commute_subsidy_6]
      ,[commute_subsidy_7]
      ,[commute_subsidy_996]
      ,[commute_subsidy_998]
      ,[commute_subsidy_use_1]
      ,[commute_subsidy_use_2]
      ,[commute_subsidy_use_3]
      ,[commute_subsidy_use_4]
      ,[commute_subsidy_use_5]
      ,[commute_subsidy_use_6]
      ,[commute_subsidy_use_7]
      ,[commute_subsidy_use_996]
      ,[disability_person]
      ,[education]
      ,[employment]
      ,[ethnicity_1]
      ,[ethnicity_2]
      ,[ethnicity_3]
      ,[ethnicity_4]
      ,[ethnicity_997]
      ,[ethnicity_999]
      ,[ev_typical_charge_1]
      ,[ev_typical_charge_2]
      ,[ev_typical_charge_3]
      ,[ev_typical_charge_4]
      ,[ev_typical_charge_5]
      ,[ev_typical_charge_6]
      ,[ev_typical_charge_997]
      ,[gender]
      ,[hours_work]
      ,[industry]
      ,[is_participant]
      ,[mobility_aides]
      ,[office_available]
      ,[participate]
      ,[person_is_complete]
      ,[proxy]
      ,[proxy_parent]
      ,[race_afam]
      ,[race_aiak]
      ,[race_asian]
      ,[race_hapi]
      ,[race_noanswer]
      ,[race_other]
      ,[race_white]
      ,[relationship]
      ,[remote_class_freq]
      ,[school_freq]
      ,[school_in_region]
      ,[school_mode_typical]
      ,[schooltype]
      ,[second_home]
      ,[second_home_in_region]
      ,[sexuality]
      ,[share_1]
      ,[share_2]
      ,[share_3]
      ,[share_4]
      ,[share_5]
      ,[share_996]
      ,[smartphone_type]
      ,[student]
      ,[surveyable]
      ,[telecommute_freq]
      ,[tnc_freq]
      ,[transit_freq]
      ,[walk_freq]
      ,[work_in_region]
      ,[work_mode]
      ,[workplace]
      ,[age_detailed]
      ,[drive_for_work]
      ,[employment_followup]
      ,[paid_work]
      ,[return_from_leave]
      ,[transportation_statement_car]
      ,[transportation_statement_environ]
      ,[transportation_statement_retail]
      ,[transportation_statement_telework]
      ,[transportation_statement_transit]
      ,[transportation_statement_travel]
      ,[transportation_statement_walk]
      ,[work_from_home]
	  FROM [HouseholdTravelSurvey2025].[dbo].[ex_person];
        GO
        CREATE TABLE HHSurvey.Day(
	[day_id] [varchar](255) NULL,
	[daynum] [varchar](255) NULL,
	[hhid] [varchar](255) NULL,
	[num_complete_trip_surveys] [varchar](255) NULL,
	[num_trips] [varchar](255) NULL,
	[pernum] [varchar](255) NULL,
	[person_id] [varchar](255) NULL,
	[survey_year] [varchar](255) NULL,
	[travel_date] [varchar](255) NULL,
	[attend_school_1] [int] NULL,
	[attend_school_2] [int] NULL,
	[attend_school_3] [int] NULL,
	[attend_school_998] [int] NULL,
	[attend_school_999] [int] NULL,
	[day_iscomplete] [int] NULL,
	[deliver_elsewhere] [int] NULL,
	[deliver_food] [int] NULL,
	[deliver_grocery] [int] NULL,
	[deliver_none] [int] NULL,
	[deliver_office] [int] NULL,
	[deliver_other] [int] NULL,
	[deliver_package] [int] NULL,
	[deliver_work] [int] NULL,
	[hh_day_iscomplete] [int] NULL,
	[is_participant] [int] NULL,
	[loc_end] [int] NULL,
	[loc_start] [int] NULL,
	[proxy_complete] [int] NULL,
	[summary_complete] [int] NULL,
	[surveyable] [int] NULL,
	[telework_time] [int] NULL,
	[travel_day] [int] NULL,
	[travel_dow] [int] NULL,
	[no_travel] [int] NULL
) ON [PRIMARY]
GO
INSERT INTO HHSurvey.Day(
	[day_id]
      ,[daynum]
      ,[hhid]
      ,[num_complete_trip_surveys]
      ,[num_trips]
      ,[pernum]
      ,[person_id]
      ,[survey_year]
      ,[travel_date]
      ,[attend_school_1]
      ,[attend_school_2]
      ,[attend_school_3]
      ,[attend_school_998]
      ,[attend_school_999]
      ,[day_iscomplete]
      ,[deliver_elsewhere]
      ,[deliver_food]
      ,[deliver_grocery]
      ,[deliver_none]
      ,[deliver_office]
      ,[deliver_other]
      ,[deliver_package]
      ,[deliver_work]
      ,[hh_day_iscomplete]
      ,[is_participant]
      ,[loc_end]
      ,[loc_start]
      ,[proxy_complete]
      ,[summary_complete]
      ,[surveyable]
      ,[telework_time]
      ,[travel_day]
      ,[travel_dow]
      ,[no_travel]) 
SELECT [day_id]
      ,[daynum]
      ,[hhid]
      ,[num_complete_trip_surveys]
      ,[num_trips]
      ,[pernum]
      ,[person_id]
      ,[survey_year]
      ,[travel_date]
      ,[attend_school_1]
      ,[attend_school_2]
      ,[attend_school_3]
      ,[attend_school_998]
      ,[attend_school_999]
      ,[day_iscomplete]
      ,[deliver_elsewhere]
      ,[deliver_food]
      ,[deliver_grocery]
      ,[deliver_none]
      ,[deliver_office]
      ,[deliver_other]
      ,[deliver_package]
      ,[deliver_work]
      ,[hh_day_iscomplete]
      ,[is_participant]
      ,[loc_end]
      ,[loc_start]
      ,[proxy_complete]
      ,[summary_complete]
      ,[surveyable]
      ,[telework_time]
      ,[travel_day]
      ,[travel_dow]
      ,[no_travel]
FROM HouseholdTravelSurvey2025.dbo.ex_day;
GO
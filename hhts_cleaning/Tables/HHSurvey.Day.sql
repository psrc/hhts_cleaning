CREATE TABLE [HHSurvey].[Day]
(
[day_id] [float] NULL,
[day_weight_2023] [float] NULL,
[daynum] [float] NULL,
[hhid] [float] NULL,
[num_complete_trip_surveys] [float] NULL,
[num_trips] [float] NULL,
[pernum] [float] NULL,
[person_id] [float] NULL,
[survey_year] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[travel_date] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[attend_school_1] [float] NULL,
[attend_school_2] [float] NULL,
[attend_school_3] [float] NULL,
[attend_school_998] [float] NULL,
[attend_school_999] [float] NULL,
[day_iscomplete] [float] NULL,
[deliver_elsewhere] [float] NULL,
[deliver_food] [float] NULL,
[deliver_grocery] [float] NULL,
[deliver_none] [float] NULL,
[deliver_office] [float] NULL,
[deliver_other] [float] NULL,
[deliver_package] [float] NULL,
[deliver_work] [float] NULL,
[hh_day_iscomplete] [float] NULL,
[hh_is_complete] [float] NULL,
[is_participant] [float] NULL,
[loc_end] [float] NULL,
[loc_start] [float] NULL,
[proxy_complete] [float] NULL,
[summary_complete] [float] NULL,
[surveyable] [float] NULL,
[telework_time] [float] NULL,
[travel_day] [float] NULL,
[travel_dow] [float] NULL,
[no_travel] [float] NULL
) ON [PRIMARY]
GO

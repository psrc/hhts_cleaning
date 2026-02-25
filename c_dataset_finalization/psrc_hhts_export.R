library(psrcelmer)
library(magrittr)
library(data.table)

day <- psrcelmer::get_table("hhts_cleaning", "HHSurvey", "Day")
chg_day_datatype_cols <- c("num_complete_trip_surveys","num_trips")
day %<>% setDT() %>% setnames(c("hhid","daynum","pernum","loc_end","loc_start"),
                              c("hh_id","day_num","person_num","begin_day","end_day")) %>%
  .[, (chg_day_datatype_cols) := lapply(.SD, as.numeric), .SDcols = chg_day_datatype_cols] 
readr::write_rds(day, "C:/Users/mjensen/projects/hts_weighting_psrc_client/hts_data_for_weighting/Cleaned_20251217/day.rds")

person <- psrcelmer::get_table("hhts_cleaning", "HHSurvey", "Person")
person %<>% setDT() %>% .[, c("school_geog", "work_geog", "school_geom", "work_geom"):=NULL] %>% 
  setnames(paste0("race_",c("afam","aiak","asian","hapi","white","other","noanswer")),
           paste0("race_",c(1:5,997,999))) %>% 
  setnames(c("hhid","pernum", "numdayscomplete", "school_bg", "work_bg", "work_puma10", "proxy",
             "person_is_complete", "disability_person", "schooltype", "school_mode_typical", "school_puma10"),
           c("hh_id","person_num", "disability", "num_days_complete", "school_bg_2020", "work_bg_2020", "work_puma_2012", "is_proxy",
             "is_complete", "school_type", "school_mode", "school_puma_2012")) %>%
  .[, person_id:=as.character(person_id)] %>% .[, c("can_drive","num_trips"):= lapply(.SD, as.numeric), .SDcols = c("can_drive","num_trips")]
readr::write_rds(person, "C:/Users/mjensen/projects/hts_weighting_psrc_client/hts_data_for_weighting/Cleaned_20251217/person.rds")

hh <- psrcelmer::get_table("hhts_cleaning", "HHSurvey", "Household")
hh %<>% setDT() %>% .[, c("home_geog", "sample_geog", "home_geom"):=NULL] %>%
  .[, hhid:=as.character(hhid)] %>% .[, sample_home_bg:=as.numeric(sample_home_bg)] %>%
  setnames(c("hhid", "hh_is_complete", "hhincome_detailed", "hhincome_broad", "hhincome_followup", "hhsize", "numdayscomplete", "rent_own",
             "numworkers", "numadults", "numchildren", "traveldate_end", "traveldate_start", "prev_home_notwa_zip" ,"vehicle_count", 
             "hhgroup", "res_dur", "res_type", "sample_lat", "sample_lng", "prev_home_notwa_state"),
           c("hh_id", "is_complete", "income_detailed", "income_broad", "income_followup", "num_people", "num_days_complete", "residence_rent_own",
             "num_workers", "num_adults", "num_kids", "first_travel_date", "last_travel_date", "prev_home_not_wa_zip", "num_vehicles", 
             "participation_group", "residence_duration", "residence_type", "sample_home_lat", "sample_home_lon", "prev_home_not_wa_state"))
readr::write_rds(hh, "C:/Users/mjensen/projects/hts_weighting_psrc_client/hts_data_for_weighting/Cleaned_20251217/hh.rds")

id_cols <- c("hh_id","person_id","trip_id")
trip <- psrcelmer::get_table("hhts_cleaning", "HHSurvey", "Trip")
trip %<>% setDT() %>% .[, c("origin_geog", "dest_geog", "origin_geom", "dest_geom", "recid", "initial_tripid"):=NULL] %>%
  setnames(c("hhid", "tripid", "traveldate", "hh_day_iscomplete", "day_iscomplete", "svy_complete", "origin_lat", "origin_lng", 
             "dest_lat", "dest_lng", "travelers_total", "travelers_hh", "travelers_nonhh"),
           c("hh_id", "trip_id", "travel_date", "hh_day_complete", "day_is_complete", "trip_survey_complete", "o_lat", "o_lon", 
             "d_lat", "d_lon", "num_travelers", "num_hh_travelers", "num_non_hh_travelers")) %>%
  .[, (id_cols) := lapply(.SD, as.character), .SDcols = id_cols]
readr::write_rds(trip, "C:/Users/mjensen/projects/hts_weighting_psrc_client/hts_data_for_weighting/Cleaned_20251217/trip.rds")

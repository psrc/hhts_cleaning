
/*
Populate the history table for [HHSurvey].[Trip_20251021] 
because for some reason it was empty.
*/
    

ALTER TABLE HHSurvey.Trip_20251021
set (system_versioning = OFF);

insert into History.HHSurvey__Trip_20251021 (
    [recid] ,[hhid] ,[person_id] ,[pernum] ,[tripid] ,[tripnum] ,[traveldate] ,[daynum] ,[depart_time_timestamp] ,[arrival_time_timestamp]
      ,[origin_lat] ,[origin_lng] ,[dest_lat] ,[dest_lng] ,[distance_miles] ,[travel_time] ,[hhmember1] ,[hhmember2] ,[hhmember3] ,[hhmember4]
      ,[hhmember5] ,[hhmember6] ,[hhmember7] ,[hhmember8] ,[hhmember9] ,[hhmember10] ,[hhmember11] ,[hhmember12] ,[hhmember13] ,[travelers_hh]
      ,[travelers_nonhh] ,[travelers_total] ,[origin_purpose] ,[dest_purpose] ,[dest_purpose_other] ,[mode_1] ,[mode_2] ,[mode_3] ,[mode_4] ,[driver]
      ,[mode_acc] ,[mode_egr] ,[speed_mph] ,[mode_other_specify] ,[origin_geog] ,[dest_geog] ,[dest_is_home] ,[dest_is_work] ,[modes] ,[psrc_inserted]
      ,[revision_code] ,[psrc_resolved] ,[psrc_comment] ,[valid_from] ,[valid_to]
)
select 
    [recid] ,[hhid] ,[person_id] ,[pernum] ,[tripid] ,[tripnum] ,[traveldate] ,[daynum] ,[depart_time_timestamp] ,[arrival_time_timestamp]
      ,[origin_lat] ,[origin_lng] ,[dest_lat] ,[dest_lng] ,[distance_miles] ,[travel_time] ,[hhmember1] ,[hhmember2] ,[hhmember3] ,[hhmember4]
      ,[hhmember5] ,[hhmember6] ,[hhmember7] ,[hhmember8] ,[hhmember9] ,[hhmember10] ,[hhmember11] ,[hhmember12] ,[hhmember13] ,[travelers_hh]
      ,[travelers_nonhh] ,[travelers_total] ,[origin_purpose] ,[dest_purpose] ,[dest_purpose_other] ,[mode_1] ,[mode_2] ,[mode_3] ,[mode_4] ,[driver]
      ,[mode_acc] ,[mode_egr] ,[speed_mph] ,[mode_other_specify] ,[origin_geog] ,[dest_geog] ,[dest_is_home] ,[dest_is_work] ,[modes] ,[psrc_inserted]
      ,[revision_code] ,[psrc_resolved] ,[psrc_comment] ,[valid_from] ,[valid_to]
from History.[History.HHSurvey__Trip_20251021]

alter table HHSurvey.Trip_20251021
    set (system_versioning = on (history_table = [History].[HHSurvey__Trip_20251021]));
go

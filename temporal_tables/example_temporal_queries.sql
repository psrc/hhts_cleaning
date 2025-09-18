use hhts_cleaning

-- Query a temporal table as of a date in the past, e.g. September 3 at 10:17 AM

    declare @utctime datetime2 = dbo.LocalToUtc('2025-09-03 10:17')

    select *
    from HHSurvey.Trip 
    for SYSTEM_TIME AS OF @utctime
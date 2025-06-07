SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [HHSurvey].[update_membercounts]
AS BEGIN

WITH membercounts (tripid, membercount)
AS (
    select tripid, count(member) 
    from (		  SELECT tripid, hhmember1 AS member FROM HHSurvey.Trip 
        union all SELECT tripid, hhmember2 AS member FROM HHSurvey.Trip 
        union all SELECT tripid, hhmember3 AS member FROM HHSurvey.Trip 
        union all SELECT tripid, hhmember4 AS member FROM HHSurvey.Trip 
        union all SELECT tripid, hhmember5 AS member FROM HHSurvey.Trip 
        union all SELECT tripid, hhmember6 AS member FROM HHSurvey.Trip 
        union all SELECT tripid, hhmember7 AS member FROM HHSurvey.Trip 
        union all SELECT tripid, hhmember8 AS member FROM HHSurvey.Trip 
        union all SELECT tripid, hhmember9 AS member FROM HHSurvey.Trip
    ) AS members
    where member not in (SELECT flag_value FROM HHSurvey.NullFlags)
    group by tripid
)
update t
set t.travelers_hh = membercounts.membercount
from membercounts
    join HHSurvey.Trip AS t ON t.tripid = membercounts.tripid
where t.travelers_hh > membercounts.membercount 
    or t.travelers_hh is null
    or t.travelers_hh in (SELECT flag_value FROM HHSurvey.NullFlags);

UPDATE t
    SET t.travelers_total = t.travelers_hh
    FROM HHSurvey.Trip AS t
    WHERE t.travelers_total < t.travelers_hh	
        or t.travelers_total in (SELECT flag_value FROM HHSurvey.NullFlags);
END
GO

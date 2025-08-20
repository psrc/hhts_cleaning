--flag invalid households based on criteria of shared valid weekday--either travel or a day notravel excuse--for each member over 5
      TRUNCATE TABLE HHSurvey.trip_invalid;
      GO
      WITH cte AS (SELECT t.person_id, count(*) AS tripcount FROM HHSurvey.Trip AS t GROUP BY t.person_id HAVING count(*) = 1)
                  DELETE FROM HHSurvey.Trip
                  OUTPUT deleted.* INTO HHSurvey.trip_invalid
                  WHERE EXISTS (SELECT 1 FROM cte WHERE trip.person_id = cte.person_id);

      WITH travel_valid AS (SELECT t.hhid, t.travel_date, t.person_id 
                              FROM HHSurvey.Trip AS t JOIN HHSurvey.Person AS p ON t.person_id = p.person_id 
                              WHERE p.age_detailed > 1 AND DATEPART(dw, t.travel_date) BETWEEN 2 and 6
                              GROUP BY t.hhid, t.travel_date, t.person_id),
      stay_valid AS (SELECT d.hhid, d.travel_date, d.person_id FROM HHSurvey.Day AS d JOIN HHSurvey.Person AS p ON d.person_id = p.person_id  
                  WHERE p.age_detailed > 1 AND DATEPART(dw,d.travel_date) BETWEEN 2 and 6 
                      AND (d.notravel_vacation = 1 
                        OR d.notravel_telecommute = 1
                        OR d.notravel_housework = 1
                        OR d.notravel_kidsbreak = 1
                        OR d.notravel_kidshomeschool = 1
                        OR d.notravel_notransport = 1
                        OR d.notravel_sick = 1
                        OR d.notravel_delivery = 1
                        OR d.notravel_other = 1)
                  GROUP BY d.hhid, d.travel_date, d.person_id),
            either_valid AS (SELECT tv.hhid, tv.travel_date, tv.person_id FROM travel_valid AS tv UNION SELECT sv.hhid, sv.travel_date, sv.person_id FROM stay_valid AS sv),          
            valid_hhmember_count AS (SELECT hhid, travel_date, count(person_id) AS member_count FROM either_valid GROUP BY hhid, travel_date),
            highest_valid AS (SELECT hhid, max(member_count) AS shared_valid_hhmember FROM valid_hhmember_count GROUP BY hhid),
            members_over5 AS (SELECT p.hhid, count(p.person_id) AS memcount FROM HHSurvey.Person AS p WHERE p.age_detailed > 1 GROUP BY p.hhid)
      SELECT h.hhid, h.hhsize, h.numadults, hv.shared_valid_hhmember --INTO HHSurvey.invalid_hh
      FROM HHSurvey.Household AS h JOIN highest_valid AS hv ON h.hhid = hv.hhid LEFT JOIN members_over5 AS m5 ON h.hhid = m5.hhid
      WHERE m5.memcount > hv.shared_valid_hhmember ORDER BY h.numadults - hv.shared_valid_hhmember DESC;     

--Create tables for invalid records

      SELECT TOP 0 * INTO HHSurvey.household_invalid
            FROM HHSurvey.Household 
            UNION ALL SELECT TOP 0 * 
            FROM HHSurvey.Household ;

      SELECT TOP 0 * INTO HHSurvey.vehicle_invalid
            FROM HHSurvey.Vehicle
            UNION ALL SELECT TOP 0 * 
            FROM HHSurvey.Vehicle;

      SELECT TOP 0 * INTO HHSurvey.day_invalid
            FROM HHSurvey.[Day]
            UNION ALL SELECT TOP 0 * 
            FROM HHSurvey.[Day];

      SELECT TOP 0 * INTO HHSurvey.person_invalid
            FROM HHSurvey.Person
            UNION ALL SELECT TOP 0 * 
            FROM HHSurvey.Person;

--remove invalid records into these tables

      DELETE t 
      OUTPUT deleted.* INTO HHSurvey.trip_invalid
      FROM HHSurvey.Trip AS t WHERE EXISTS (SELECT 1 FROM HHSurvey.invalid_hh AS i WHERE t.hhid = i.hhid);

      DELETE h 
      OUTPUT deleted.* INTO HHSurvey.household_invalid
      FROM HHSurvey.Household AS h WHERE EXISTS (SELECT 1 FROM HHSurvey.invalid_hh AS i WHERE h.hhid = i.hhid);

      DELETE v
      OUTPUT deleted.* INTO HHSurvey.vehicle_invalid
      FROM HHSurvey.Vehicle AS v WHERE EXISTS (SELECT 1 FROM HHSurvey.invalid_hh AS i WHERE v.hhid = i.hhid);

      DELETE d 
      OUTPUT deleted.* INTO HHSurvey.day_invalid
      FROM HHSurvey.Day AS d WHERE EXISTS (SELECT 1 FROM HHSurvey.invalid_hh AS i WHERE d.hhid = i.hhid);

      DELETE p
      OUTPUT deleted.* INTO HHSurvey.person_invalid
      FROM HHSurvey.Person AS p WHERE EXISTS (SELECT 1 FROM HHSurvey.invalid_hh AS i WHERE p.hhid = i.hhid);
      GO

--update trip counts

      WITH cte AS (SELECT hhid, count(*) AS tripcount FROM HHSurvey.Trip GROUP BY hhid)
      UPDATE h SET h.num_trips = cte.tripcount 
      FROM HHSurvey.Household AS h JOIN cte ON h.hhid = cte.hhid;

      WITH cte AS (SELECT person_id, count(*) AS tripcount FROM HHSurvey.Trip GROUP BY person_id)
      UPDATE p SET p.num_trips = cte.tripcount 
      FROM HHSurvey.Person AS p JOIN cte ON p.person_id = cte.person_id;

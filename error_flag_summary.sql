-- Summary of error_flag by count from HHSurvey.trip_error_flags table
SELECT 
    error_flag,
    COUNT(*) as flag_count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) as percentage
FROM hhts_cleaning.HHSurvey.trip_error_flags
GROUP BY error_flag
ORDER BY COUNT(*) DESC;

-- Additional summary statistics
SELECT 
    COUNT(*) as total_error_records,
    COUNT(DISTINCT error_flag) as unique_error_types,
    COUNT(DISTINCT person_id) as persons_with_errors,
    COUNT(DISTINCT CONCAT(person_id, '_', tripnum)) as trips_with_errors
FROM hhts_cleaning.HHSurvey.trip_error_flags;



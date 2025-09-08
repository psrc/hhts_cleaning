#!/usr/bin/env python3
"""
Final summary report with specific examples and edge cases
"""

import csv
from collections import defaultdict

def safe_float(value):
    try:
        return float(value)
    except (ValueError, TypeError):
        return None

def safe_int(value):
    try:
        return int(value)
    except (ValueError, TypeError):
        return None

def generate_final_report():
    """Generate final comprehensive report"""
    
    print("=" * 80)
    print("FINAL ANALYSIS REPORT: CHANGE MODE TRIP PATTERNS")
    print("Dataset: persons_with_change_purpose_trips.csv (4,934 records)")
    print("=" * 80)
    
    # Read data
    all_trips = []
    with open(r'persons_with_change_purpose_trips.csv', 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            trip = {
                'person_id': row['person_id'],
                'tripnum': safe_int(row['tripnum']),
                'dest_purpose': row['dest_purpose'],
                'distance_miles': safe_float(row['distance_miles']),
                'speed_mph': safe_float(row['speed_mph']),
                'mode_1': row['mode_1'],
                'origin_lat': safe_float(row['origin_lat']),
                'origin_lng': safe_float(row['origin_lng']),
                'dest_lat': safe_float(row['dest_lat']),
                'dest_lng': safe_float(row['dest_lng'])
            }
            if trip['tripnum'] is not None:
                all_trips.append(trip)
    
    change_mode_trips = [t for t in all_trips if 'Changed or transferred mode' in t['dest_purpose']]
    
    # Group by person
    person_trips = defaultdict(list)
    for trip in sorted(all_trips, key=lambda x: (x['person_id'], x['tripnum'] or 0)):
        person_trips[trip['person_id']].append(trip)
    
    print(f"\nEXECUTIVE SUMMARY:")
    print(f"- Total records analyzed: {len(all_trips):,}")
    print(f"- Change mode trips: {len(change_mode_trips):,} ({len(change_mode_trips)/len(all_trips)*100:.1f}%)")
    print(f"- Unique persons: {len(person_trips):,}")
    print(f"- Persons with change mode trips: {len(set(t['person_id'] for t in change_mode_trips)):,}")
    
    # Detailed analysis
    linking_analysis = []
    error_analysis = []
    edge_cases = []
    
    for person_id, trips in person_trips.items():
        for i, trip in enumerate(trips):
            if 'Changed or transferred mode' in trip['dest_purpose']:
                
                analysis = {
                    'person_id': person_id,
                    'tripnum': trip['tripnum'],
                    'trip': trip,
                    'prev_trip': trips[i-1] if i > 0 else None,
                    'next_trip': trips[i+1] if i < len(trips)-1 else None,
                    'coord_continuous_before': False,
                    'coord_continuous_after': False
                }
                
                # Check coordinate continuity
                if analysis['prev_trip'] and trip['origin_lat'] and analysis['prev_trip']['dest_lat']:
                    if (abs(trip['origin_lat'] - analysis['prev_trip']['dest_lat']) < 0.001 and
                        abs(trip['origin_lng'] - analysis['prev_trip']['dest_lng']) < 0.001):
                        analysis['coord_continuous_before'] = True
                
                if analysis['next_trip'] and trip['dest_lat'] and analysis['next_trip']['origin_lat']:
                    if (abs(trip['dest_lat'] - analysis['next_trip']['origin_lat']) < 0.001 and
                        abs(trip['dest_lng'] - analysis['next_trip']['origin_lng']) < 0.001):
                        analysis['coord_continuous_after'] = True
                
                # Categorize
                if (trip['distance_miles'] is not None and trip['speed_mph'] is not None):
                    # Clear errors
                    if (trip['distance_miles'] <= 0.01 or trip['speed_mph'] > 100):
                        error_analysis.append(analysis)
                    # High confidence linking
                    elif (analysis['coord_continuous_before'] and analysis['coord_continuous_after'] and
                          trip['distance_miles'] <= 2.0 and trip['speed_mph'] <= 25 and
                          trip['mode_1'] in ['Bus (public transit)', 'Rail (e.g., train, subway)', 'Walk (or jog/wheelchair)']):
                        linking_analysis.append(analysis)
                    # Edge cases
                    else:
                        edge_cases.append(analysis)
                else:
                    edge_cases.append(analysis)
    
    print(f"\nPATTERN CLASSIFICATION:")
    print(f"- Clear linking candidates: {len(linking_analysis)} ({len(linking_analysis)/len(change_mode_trips)*100:.1f}%)")
    print(f"- Clear error cases: {len(error_analysis)} ({len(error_analysis)/len(change_mode_trips)*100:.1f}%)")
    print(f"- Edge cases requiring manual review: {len(edge_cases)} ({len(edge_cases)/len(change_mode_trips)*100:.1f}%)")
    
    print(f"\n" + "="*80)
    print("CONSERVATIVE RULE DEVELOPMENT")
    print("="*80)
    
    print(f"\nRULE 1: AUTOMATIC LINKING (High Confidence)")
    print(f"Apply to {len(linking_analysis)} trips ({len(linking_analysis)/len(change_mode_trips)*100:.1f}%)")
    print("CONDITIONS:")
    print("  1. Origin coordinates match previous trip destination (within 0.001°)")
    print("  2. Destination coordinates match next trip origin (within 0.001°)")
    print("  3. Distance <= 2.0 miles")
    print("  4. Speed <= 25 mph")  
    print("  5. Mode is Bus, Rail, or Walk")
    print("ACTION: Automatically link to adjacent trips")
    
    if linking_analysis:
        print(f"\nEXAMPLES OF RULE 1 CANDIDATES:")
        for analysis in linking_analysis[:3]:
            trip = analysis['trip']
            prev = analysis['prev_trip']['dest_purpose'][:50] if analysis['prev_trip'] else "N/A"
            next_purpose = analysis['next_trip']['dest_purpose'][:50] if analysis['next_trip'] else "N/A"
            print(f"  Person {analysis['person_id']}, Trip {trip['tripnum']}:")
            print(f"    Distance: {trip['distance_miles']:.2f} miles, Speed: {trip['speed_mph']:.1f} mph")
            print(f"    Mode: {trip['mode_1']}")
            print(f"    Previous purpose: {prev}")
            print(f"    Next purpose: {next_purpose}")
            print()
    
    print(f"RULE 2: ERROR FLAGGING (Clear Errors)")
    print(f"Apply to {len(error_analysis)} trips ({len(error_analysis)/len(change_mode_trips)*100:.1f}%)")
    print("CONDITIONS:")
    print("  1. Distance <= 0.01 miles (near-zero) OR")
    print("  2. Speed > 100 mph (impossible)")
    print("ACTION: Flag for manual correction or removal")
    
    if error_analysis:
        print(f"\nEXAMPLES OF RULE 2 CANDIDATES:")
        for analysis in error_analysis[:3]:
            trip = analysis['trip']
            print(f"  Person {analysis['person_id']}, Trip {trip['tripnum']}:")
            print(f"    Distance: {trip['distance_miles']} miles, Speed: {trip['speed_mph']} mph")
            print(f"    Mode: {trip['mode_1']}")
            print()
    
    print(f"RULE 3: MANUAL REVIEW REQUIRED")
    print(f"Apply to {len(edge_cases)} trips ({len(edge_cases)/len(change_mode_trips)*100:.1f}%)")
    print("CONDITIONS: All other change mode trips")
    print("REASONS FOR MANUAL REVIEW:")
    
    # Analyze reasons for manual review
    no_coord_continuity = sum(1 for a in edge_cases if not a['coord_continuous_before'] and not a['coord_continuous_after'])
    partial_continuity = sum(1 for a in edge_cases if (a['coord_continuous_before'] and not a['coord_continuous_after']) or (not a['coord_continuous_before'] and a['coord_continuous_after']))
    high_distance = sum(1 for a in edge_cases if a['trip']['distance_miles'] and a['trip']['distance_miles'] > 2.0)
    high_speed = sum(1 for a in edge_cases if a['trip']['speed_mph'] and 25 < a['trip']['speed_mph'] <= 100)
    missing_data = sum(1 for a in edge_cases if not a['trip']['distance_miles'] or not a['trip']['speed_mph'])
    
    print(f"  - No coordinate continuity: {no_coord_continuity}")
    print(f"  - Partial coordinate continuity: {partial_continuity}")
    print(f"  - High distance (>2 miles): {high_distance}")
    print(f"  - High speed (25-100 mph): {high_speed}")
    print(f"  - Missing distance/speed data: {missing_data}")
    
    print(f"\n" + "="*80)
    print("IMPLEMENTATION RECOMMENDATIONS")
    print("="*80)
    
    print(f"\nPHASE 1: IMMEDIATE IMPLEMENTATION")
    print(f"- Implement Rule 1 for {len(linking_analysis)} trips")
    print(f"- Expected impact: {len(linking_analysis)*2} trip records linked (each change mode links to 2 adjacent trips)")
    print(f"- Risk level: Very low (conservative criteria)")
    
    print(f"\nPHASE 2: ERROR CLEANUP")
    print(f"- Review and correct {len(error_analysis)} error cases")
    print(f"- Likely actions: Delete trips or correct data entry errors")
    print(f"- Risk level: Low (clear data quality issues)")
    
    print(f"\nPHASE 3: MANUAL REVIEW")
    print(f"- Review {len(edge_cases)} edge cases")
    print(f"- Priority: Focus on high-frequency users first")
    print(f"- Timeline: Can be done iteratively over time")
    
    # High-frequency users analysis
    person_counts = defaultdict(int)
    for trip in change_mode_trips:
        person_counts[trip['person_id']] += 1
    
    high_freq_users = [p for p, count in person_counts.items() if count >= 5]
    high_freq_edge_cases = [a for a in edge_cases if a['person_id'] in high_freq_users]
    
    print(f"\nHIGH-FREQUENCY USER FOCUS:")
    print(f"- {len(high_freq_users)} persons have 5+ change mode trips")
    print(f"- {len(high_freq_edge_cases)} edge cases are from high-frequency users")
    print(f"- Recommend prioritizing these for manual review")
    
    print(f"\n" + "="*80)
    print("EXPECTED OUTCOMES")
    print("="*80)
    
    total_to_process = len(linking_analysis) + len(error_analysis)
    print(f"\nIMMEDIATE AUTOMATED PROCESSING:")
    print(f"- {total_to_process} trips ({total_to_process/len(change_mode_trips)*100:.1f}%) can be processed automatically")
    print(f"- {len(linking_analysis)} trips will be linked to adjacent trips")
    print(f"- {len(error_analysis)} trips will be flagged as errors")
    
    print(f"\nREMAINING MANUAL WORK:")
    print(f"- {len(edge_cases)} trips ({len(edge_cases)/len(change_mode_trips)*100:.1f}%) require manual review")
    print(f"- Focus on {len(high_freq_edge_cases)} trips from frequent users first")
    
    print(f"\nDATA QUALITY IMPROVEMENT:")
    print(f"- Eliminate {len(error_analysis)} clear data errors")
    print(f"- Link {len(linking_analysis)} legitimate transfer trips")
    print(f"- Reduce manual review workload by {total_to_process/len(change_mode_trips)*100:.1f}%")
    
    print(f"\n" + "="*80)
    print("IMPLEMENTATION SQL TEMPLATE")
    print("="*80)
    
    print("""
-- Step 1: Auto-link high confidence change mode trips
UPDATE trip_data 
SET linked_trip_flag = 'TRANSFER',
    link_previous = 1,
    link_next = 1,
    processed_date = GETDATE()
WHERE dest_purpose LIKE '%Changed or transferred mode%'
  AND distance_miles <= 2.0 
  AND speed_mph <= 25.0
  AND mode_1 IN ('Bus (public transit)', 
                 'Rail (e.g., train, subway)', 
                 'Walk (or jog/wheelchair)')
  AND coordinate_continuous_flag = 1;
  
-- Step 2: Flag clear errors  
UPDATE trip_data
SET error_flag = 'DATA_QUALITY_ERROR',
    error_reason = CASE 
        WHEN distance_miles <= 0.01 THEN 'Near-zero distance'
        WHEN speed_mph > 100 THEN 'Impossible speed'
        ELSE 'Other error'
    END,
    processed_date = GETDATE()
WHERE dest_purpose LIKE '%Changed or transferred mode%'
  AND (distance_miles <= 0.01 OR speed_mph > 100);

-- Step 3: Mark remaining for manual review
UPDATE trip_data
SET review_flag = 'MANUAL_REVIEW_REQUIRED',
    processed_date = GETDATE()  
WHERE dest_purpose LIKE '%Changed or transferred mode%'
  AND linked_trip_flag IS NULL
  AND error_flag IS NULL;
""")
    
    print(f"=" * 80)
    print("END OF ANALYSIS")
    print(f"=" * 80)

if __name__ == "__main__":
    generate_final_report()
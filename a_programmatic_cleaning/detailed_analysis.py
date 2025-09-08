#!/usr/bin/env python3
"""
Detailed analysis of potential linking patterns and timing for change mode trips
"""

import csv
from collections import defaultdict
from datetime import datetime, timedelta

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

def parse_timestamp(ts_str):
    if not ts_str or ts_str == 'Missing Response':
        return None
    try:
        return datetime.strptime(ts_str, '%Y-%m-%d %H:%M:%S.%f')
    except:
        try:
            return datetime.strptime(ts_str, '%Y-%m-%d %H:%M:%S')
        except:
            return None

def analyze_linking_patterns():
    """Focus on timing and linking patterns"""
    
    print("DETAILED LINKING PATTERN ANALYSIS")
    print("=" * 50)
    
    # Read and organize data
    all_trips = []
    
    with open(r'persons_with_change_purpose_trips.csv', 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            trip = {
                'person_id': row['person_id'],
                'tripnum': safe_int(row['tripnum']),
                'dest_purpose': row['dest_purpose'],
                'depart_dt': parse_timestamp(row['depart_time_timestamp']),
                'arrival_dt': parse_timestamp(row['arrival_time_timestamp']),
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
    
    # Group by person and sort by trip number
    person_trips = defaultdict(list)
    for trip in sorted(all_trips, key=lambda x: (x['person_id'], x['tripnum'] or 0)):
        person_trips[trip['person_id']].append(trip)
    
    print("TIMING ANALYSIS FOR CHANGE MODE TRIPS")
    print("-" * 40)
    
    linking_scenarios = []
    time_gaps = []
    
    for person_id, trips in person_trips.items():
        for i, trip in enumerate(trips):
            if 'Changed or transferred mode' in trip['dest_purpose']:
                scenario = {
                    'person_id': person_id,
                    'trip_index': i,
                    'trip': trip,
                    'prev_trip': trips[i-1] if i > 0 else None,
                    'next_trip': trips[i+1] if i < len(trips)-1 else None
                }
                
                # Calculate time gaps
                if scenario['prev_trip'] and scenario['prev_trip']['arrival_dt'] and trip['depart_dt']:
                    scenario['gap_before_min'] = (trip['depart_dt'] - scenario['prev_trip']['arrival_dt']).total_seconds() / 60
                    time_gaps.append(scenario['gap_before_min'])
                else:
                    scenario['gap_before_min'] = None
                
                if scenario['next_trip'] and trip['arrival_dt'] and scenario['next_trip']['depart_dt']:
                    scenario['gap_after_min'] = (scenario['next_trip']['depart_dt'] - trip['arrival_dt']).total_seconds() / 60
                else:
                    scenario['gap_after_min'] = None
                
                # Check coordinate continuity
                scenario['coord_continuous_before'] = False
                scenario['coord_continuous_after'] = False
                
                if scenario['prev_trip']:
                    if (trip['origin_lat'] and scenario['prev_trip']['dest_lat'] and
                        abs(trip['origin_lat'] - scenario['prev_trip']['dest_lat']) < 0.001 and
                        abs(trip['origin_lng'] - scenario['prev_trip']['dest_lng']) < 0.001):
                        scenario['coord_continuous_before'] = True
                
                if scenario['next_trip']:
                    if (trip['dest_lat'] and scenario['next_trip']['origin_lat'] and
                        abs(trip['dest_lat'] - scenario['next_trip']['origin_lat']) < 0.001 and
                        abs(trip['dest_lng'] - scenario['next_trip']['origin_lng']) < 0.001):
                        scenario['coord_continuous_after'] = True
                
                linking_scenarios.append(scenario)
    
    # Analyze time gaps
    valid_gaps = [g for g in time_gaps if g is not None and -1440 < g < 1440]  # Within 24 hours
    if valid_gaps:
        valid_gaps.sort()
        n = len(valid_gaps)
        print(f"Time gap analysis (n={n} valid gaps):")
        print(f"  Min: {min(valid_gaps):.1f} minutes")
        print(f"  25th percentile: {valid_gaps[n//4]:.1f} minutes")  
        print(f"  Median: {valid_gaps[n//2]:.1f} minutes")
        print(f"  75th percentile: {valid_gaps[3*n//4]:.1f} minutes")
        print(f"  Max: {max(valid_gaps):.1f} minutes")
        
        # Time gap categories
        immediate = sum(1 for g in valid_gaps if -5 <= g <= 5)
        short = sum(1 for g in valid_gaps if 5 < g <= 30)
        medium = sum(1 for g in valid_gaps if 30 < g <= 120)
        long = sum(1 for g in valid_gaps if g > 120)
        
        print(f"  Immediate (-5 to +5 min): {immediate} ({immediate/n*100:.1f}%)")
        print(f"  Short (5-30 min): {short} ({short/n*100:.1f}%)")
        print(f"  Medium (30-120 min): {medium} ({medium/n*100:.1f}%)")
        print(f"  Long (>120 min): {long} ({long/n*100:.1f}%)")
    
    print("\nCONSERVATIVE LINKING CRITERIA ANALYSIS")
    print("-" * 40)
    
    # Define conservative linking criteria tiers
    tier1_candidates = []  # Very conservative
    tier2_candidates = []  # Moderately conservative  
    tier3_candidates = []  # Less conservative
    
    for scenario in linking_scenarios:
        trip = scenario['trip']
        
        # Tier 1: Very conservative (highest confidence transfers)
        if (scenario['coord_continuous_before'] and scenario['coord_continuous_after'] and
            scenario['gap_before_min'] is not None and scenario['gap_after_min'] is not None and
            0 <= scenario['gap_before_min'] <= 10 and 0 <= scenario['gap_after_min'] <= 10 and
            trip['distance_miles'] is not None and trip['distance_miles'] <= 1.0 and
            trip['speed_mph'] is not None and trip['speed_mph'] <= 15):
            tier1_candidates.append(scenario)
        
        # Tier 2: Moderate confidence 
        elif (scenario['coord_continuous_before'] and scenario['coord_continuous_after'] and
              scenario['gap_before_min'] is not None and scenario['gap_after_min'] is not None and
              0 <= scenario['gap_before_min'] <= 20 and 0 <= scenario['gap_after_min'] <= 20 and
              trip['distance_miles'] is not None and trip['distance_miles'] <= 2.5 and
              trip['speed_mph'] is not None and trip['speed_mph'] <= 25):
            tier2_candidates.append(scenario)
            
        # Tier 3: Lower confidence but still reasonable
        elif (scenario['coord_continuous_before'] and scenario['coord_continuous_after'] and
              scenario['gap_before_min'] is not None and scenario['gap_after_min'] is not None and
              0 <= scenario['gap_before_min'] <= 45 and 0 <= scenario['gap_after_min'] <= 45 and
              trip['distance_miles'] is not None and trip['distance_miles'] <= 5.0 and
              trip['speed_mph'] is not None and trip['speed_mph'] <= 40):
            tier3_candidates.append(scenario)
    
    print(f"Tier 1 (Very Conservative): {len(tier1_candidates)} candidates")
    print("  Criteria: Coordinates continuous both ends, gaps <=10min both, dist <=1mi, speed <=15mph")
    
    print(f"Tier 2 (Moderately Conservative): {len(tier2_candidates)} candidates")
    print("  Criteria: Coordinates continuous both ends, gaps <=20min both, dist <=2.5mi, speed <=25mph")
    
    print(f"Tier 3 (Less Conservative): {len(tier3_candidates)} candidates")
    print("  Criteria: Coordinates continuous both ends, gaps <=45min both, dist <=5mi, speed <=40mph")
    
    # Examples from each tier
    if tier1_candidates:
        print(f"\nTIER 1 EXAMPLES:")
        for scenario in tier1_candidates[:3]:
            trip = scenario['trip']
            print(f"  Person {scenario['person_id']}, Trip {trip['tripnum']}: "
                  f"dist={trip['distance_miles']:.2f}mi, speed={trip['speed_mph']:.1f}mph, "
                  f"gaps={scenario['gap_before_min']:.1f}/{scenario['gap_after_min']:.1f}min, mode={trip['mode_1']}")
    
    if tier2_candidates:
        print(f"\nTIER 2 EXAMPLES:")
        for scenario in tier2_candidates[:3]:
            trip = scenario['trip']
            print(f"  Person {scenario['person_id']}, Trip {trip['tripnum']}: "
                  f"dist={trip['distance_miles']:.2f}mi, speed={trip['speed_mph']:.1f}mph, "
                  f"gaps={scenario['gap_before_min']:.1f}/{scenario['gap_after_min']:.1f}min, mode={trip['mode_1']}")
    
    print("\nERROR DETECTION ANALYSIS")
    print("-" * 40)
    
    clear_errors = []
    suspicious_patterns = []
    
    for scenario in linking_scenarios:
        trip = scenario['trip']
        
        # Clear error indicators
        error_reasons = []
        
        if trip['distance_miles'] is not None and trip['distance_miles'] <= 0.005:
            error_reasons.append("near-zero distance")
        
        if trip['speed_mph'] is not None and trip['speed_mph'] > 150:
            error_reasons.append("impossible speed")
        
        if trip['distance_miles'] is not None and trip['distance_miles'] > 200:
            if trip['mode_1'] in ['Walk (or jog/wheelchair)', 'Bus (public transit)']:
                error_reasons.append("unrealistic distance for mode")
        
        # Suspicious patterns
        suspicious_reasons = []
        
        if (scenario['gap_before_min'] is not None and scenario['gap_after_min'] is not None and
            scenario['gap_before_min'] > 360 and scenario['gap_after_min'] > 360):
            suspicious_reasons.append("isolated trip (>6hr gaps)")
        
        if (not scenario['coord_continuous_before'] and not scenario['coord_continuous_after']):
            suspicious_reasons.append("no coordinate continuity")
        
        if scenario['prev_trip'] and scenario['next_trip']:
            if trip['mode_1'] == scenario['prev_trip']['mode_1'] == scenario['next_trip']['mode_1']:
                suspicious_reasons.append("same mode before/during/after")
        
        if error_reasons:
            clear_errors.append((scenario, error_reasons))
        elif len(suspicious_reasons) >= 2:
            suspicious_patterns.append((scenario, suspicious_reasons))
    
    print(f"Clear errors: {len(clear_errors)} ({len(clear_errors)/len(linking_scenarios)*100:.1f}%)")
    print(f"Suspicious patterns: {len(suspicious_patterns)} ({len(suspicious_patterns)/len(linking_scenarios)*100:.1f}%)")
    
    if clear_errors:
        print("\nCLEAR ERROR EXAMPLES:")
        for scenario, reasons in clear_errors[:3]:
            trip = scenario['trip']
            print(f"  Person {scenario['person_id']}, Trip {trip['tripnum']}: "
                  f"dist={trip['distance_miles']}, speed={trip['speed_mph']}, "
                  f"reasons: {', '.join(reasons)}")
    
    print("\nSUMMARY RECOMMENDATIONS")
    print("-" * 40)
    
    total_change_mode = len(linking_scenarios)
    
    print(f"Total change mode trips analyzed: {total_change_mode}")
    print(f"\nRecommended actions:")
    print(f"  AUTO-LINK (Tier 1): {len(tier1_candidates)} trips ({len(tier1_candidates)/total_change_mode*100:.1f}%)")
    print(f"  REVIEW FOR LINKING (Tier 2-3): {len(tier2_candidates) + len(tier3_candidates)} trips ({(len(tier2_candidates) + len(tier3_candidates))/total_change_mode*100:.1f}%)")
    print(f"  FLAG AS ERROR: {len(clear_errors)} trips ({len(clear_errors)/total_change_mode*100:.1f}%)")
    print(f"  MANUAL REVIEW: {len(suspicious_patterns)} trips ({len(suspicious_patterns)/total_change_mode*100:.1f}%)")
    
    remaining = total_change_mode - len(tier1_candidates) - len(tier2_candidates) - len(tier3_candidates) - len(clear_errors)
    print(f"  LEAVE AS-IS: {remaining} trips ({remaining/total_change_mode*100:.1f}%)")
    
    return {
        'total': total_change_mode,
        'tier1': len(tier1_candidates),
        'tier2': len(tier2_candidates), 
        'tier3': len(tier3_candidates),
        'errors': len(clear_errors),
        'suspicious': len(suspicious_patterns)
    }

if __name__ == "__main__":
    results = analyze_linking_patterns()
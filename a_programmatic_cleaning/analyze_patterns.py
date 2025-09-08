#!/usr/bin/env python3
"""
Comprehensive analysis of change mode trips using only standard library
"""

import csv
import math
from datetime import datetime
from collections import defaultdict, Counter

def parse_timestamp(ts_str):
    """Parse timestamp string to datetime object"""
    try:
        return datetime.strptime(ts_str, '%Y-%m-%d %H:%M:%S.%f')
    except:
        try:
            return datetime.strptime(ts_str, '%Y-%m-%d %H:%M:%S')
        except:
            return None

def calculate_distance(lat1, lng1, lat2, lng2):
    """Calculate distance between two points using haversine formula"""
    try:
        lat1, lng1, lat2, lng2 = map(math.radians, [float(lat1), float(lng1), float(lat2), float(lng2)])
        dlat = lat2 - lat1
        dlng = lng2 - lng1
        a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlng/2)**2
        return 2 * 3959 * math.asin(math.sqrt(a))  # Earth radius in miles
    except:
        return None

def analyze_data():
    """Main analysis function"""
    
    print("=" * 80)
    print("COMPREHENSIVE CHANGE MODE TRIP ANALYSIS")
    print("=" * 80)
    
    # Read and parse data
    trips = []
    change_mode_trips = []
    
    with open(r'C:\Users\mjensen\projects\hhts_cleaning\a_programmatic_cleaning\persons_with_change_purpose_trips.csv', 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            # Parse timestamps
            row['depart_dt'] = parse_timestamp(row['depart_time_timestamp'])
            row['arrival_dt'] = parse_timestamp(row['arrival_time_timestamp'])
            
            if row['depart_dt'] and row['arrival_dt']:
                row['duration_minutes'] = (row['arrival_dt'] - row['depart_dt']).total_seconds() / 60
            else:
                row['duration_minutes'] = None
                
            # Convert numeric fields
            try:
                row['distance_miles'] = float(row['distance_miles'])
                row['speed_mph'] = float(row['speed_mph'])
                row['tripnum'] = int(row['tripnum'])
                row['origin_lat'] = float(row['origin_lat'])
                row['origin_lng'] = float(row['origin_lng'])
                row['dest_lat'] = float(row['dest_lat'])
                row['dest_lng'] = float(row['dest_lng'])
            except:
                continue
                
            trips.append(row)
            
            if 'Changed or transferred mode' in row['dest_purpose']:
                change_mode_trips.append(row)
    
    print(f"\nDATASET OVERVIEW:")
    print(f"Total records: {len(trips):,}")
    print(f"Change mode trips: {len(change_mode_trips):,}")
    print(f"Other trips: {len(trips) - len(change_mode_trips):,}")
    
    # Sort trips by person and trip number
    trips_sorted = sorted(trips, key=lambda x: (x['person_id'], x['tripnum']))
    
    # Group by person for sequence analysis
    person_trips = defaultdict(list)
    for trip in trips_sorted:
        person_trips[trip['person_id']].append(trip)
    
    # TEMPORAL PATTERN ANALYSIS
    print("\n" + "="*50)
    print("1. TEMPORAL PATTERN ANALYSIS")
    print("="*50)
    
    time_gaps_before = []
    time_gaps_after = []
    
    for person_id, person_trip_list in person_trips.items():
        for i, trip in enumerate(person_trip_list):
            if 'Changed or transferred mode' in trip['dest_purpose']:
                # Time gap before
                if i > 0 and person_trip_list[i-1]['arrival_dt'] and trip['depart_dt']:
                    gap_before = (trip['depart_dt'] - person_trip_list[i-1]['arrival_dt']).total_seconds() / 60
                    time_gaps_before.append(gap_before)
                    trip['time_gap_before'] = gap_before
                
                # Time gap after  
                if i < len(person_trip_list)-1 and trip['arrival_dt'] and person_trip_list[i+1]['depart_dt']:
                    gap_after = (person_trip_list[i+1]['depart_dt'] - trip['arrival_dt']).total_seconds() / 60
                    time_gaps_after.append(gap_after)
                    trip['time_gap_after'] = gap_after
    
    if time_gaps_before:
        print(f"\nTime gaps before change mode trips (minutes):")
        print(f"  Count: {len(time_gaps_before)}")
        print(f"  Mean: {sum(time_gaps_before)/len(time_gaps_before):.1f}")
        print(f"  Min: {min(time_gaps_before):.1f}")
        print(f"  Max: {max(time_gaps_before):.1f}")
        
        short_before = sum(1 for x in time_gaps_before if x <= 30)
        print(f"  <=30 minutes: {short_before} ({short_before/len(time_gaps_before)*100:.1f}%)")
    
    if time_gaps_after:
        print(f"\nTime gaps after change mode trips (minutes):")
        print(f"  Count: {len(time_gaps_after)}")
        print(f"  Mean: {sum(time_gaps_after)/len(time_gaps_after):.1f}")
        print(f"  Min: {min(time_gaps_after):.1f}")
        print(f"  Max: {max(time_gaps_after):.1f}")
        
        short_after = sum(1 for x in time_gaps_after if x <= 30)
        print(f"  <=30 minutes: {short_after} ({short_after/len(time_gaps_after)*100:.1f}%)")
    
    # GEOGRAPHIC PATTERN ANALYSIS  
    print("\n" + "="*50)
    print("2. GEOGRAPHIC PATTERN ANALYSIS")
    print("="*50)
    
    distances = [trip['distance_miles'] for trip in change_mode_trips if trip['distance_miles'] is not None]
    speeds = [trip['speed_mph'] for trip in change_mode_trips if trip['speed_mph'] is not None]
    
    print(f"\nDistance analysis for change mode trips:")
    print(f"  Count: {len(distances)}")
    print(f"  Mean: {sum(distances)/len(distances):.2f} miles")
    print(f"  Min: {min(distances):.4f} miles")
    print(f"  Max: {max(distances):.2f} miles")
    
    very_short = sum(1 for x in distances if x <= 0.1)
    zero_distance = sum(1 for x in distances if x <= 0.01)
    
    print(f"  <=0.1 miles: {very_short} ({very_short/len(distances)*100:.1f}%)")
    print(f"  <=0.01 miles (near-zero): {zero_distance} ({zero_distance/len(distances)*100:.1f}%)")
    
    print(f"\nSpeed analysis:")
    print(f"  Count: {len(speeds)}")
    print(f"  Mean: {sum(speeds)/len(speeds):.1f} mph")
    print(f"  Min: {min(speeds):.1f} mph")
    print(f"  Max: {max(speeds):.1f} mph")
    
    high_speed = sum(1 for x in speeds if x > 60)
    very_high_speed = sum(1 for x in speeds if x > 100)
    
    print(f"  >60 mph: {high_speed} ({high_speed/len(speeds)*100:.1f}%)")
    print(f"  >100 mph: {very_high_speed} ({very_high_speed/len(speeds)*100:.1f}%)")
    
    # MODE CONSISTENCY ANALYSIS
    print("\n" + "="*50)
    print("3. MODE CONSISTENCY ANALYSIS")
    print("="*50)
    
    mode_patterns = Counter()
    mode_changes = 0
    mode_same_before = 0
    mode_same_after = 0
    mode_same_both = 0
    
    for person_id, person_trip_list in person_trips.items():
        for i, trip in enumerate(person_trip_list):
            if 'Changed or transferred mode' in trip['dest_purpose']:
                mode_patterns[trip['mode_1']] += 1
                
                prev_mode = person_trip_list[i-1]['mode_1'] if i > 0 else None
                next_mode = person_trip_list[i+1]['mode_1'] if i < len(person_trip_list)-1 else None
                
                if prev_mode == trip['mode_1']:
                    mode_same_before += 1
                if next_mode == trip['mode_1']:
                    mode_same_after += 1
                if prev_mode == trip['mode_1'] and next_mode == trip['mode_1']:
                    mode_same_both += 1
    
    print(f"\nMost common modes for change mode trips:")
    for mode, count in mode_patterns.most_common(5):
        print(f"  {mode}: {count}")
    
    total_with_context = len([t for t in change_mode_trips if hasattr(t, 'time_gap_before') or hasattr(t, 'time_gap_after')])
    if total_with_context > 0:
        print(f"\nMode consistency patterns:")
        print(f"  Same mode as previous trip: {mode_same_before} ({mode_same_before/total_with_context*100:.1f}%)")
        print(f"  Same mode as next trip: {mode_same_after} ({mode_same_after/total_with_context*100:.1f}%)")
        print(f"  Same mode as both adjacent trips: {mode_same_both} ({mode_same_both/total_with_context*100:.1f}%)")
    
    # JOURNEY CONTEXT ANALYSIS
    print("\n" + "="*50)
    print("4. JOURNEY CONTEXT ANALYSIS") 
    print("="*50)
    
    prev_purposes = Counter()
    next_purposes = Counter()
    home_work_patterns = 0
    
    for person_id, person_trip_list in person_trips.items():
        for i, trip in enumerate(person_trip_list):
            if 'Changed or transferred mode' in trip['dest_purpose']:
                if i > 0:
                    prev_purposes[person_trip_list[i-1]['dest_purpose']] += 1
                if i < len(person_trip_list)-1:
                    next_purposes[person_trip_list[i+1]['dest_purpose']] += 1
                    
                # Check for home-work patterns
                prev_purpose = person_trip_list[i-1]['dest_purpose'] if i > 0 else ""
                next_purpose = person_trip_list[i+1]['dest_purpose'] if i < len(person_trip_list)-1 else ""
                
                if (('home' in prev_purpose.lower() and 'work' in next_purpose.lower()) or
                    ('work' in prev_purpose.lower() and 'home' in next_purpose.lower())):
                    home_work_patterns += 1
    
    print(f"\nMost common purposes before change mode:")
    for purpose, count in prev_purposes.most_common(5):
        print(f"  {purpose}: {count}")
        
    print(f"\nMost common purposes after change mode:")
    for purpose, count in next_purposes.most_common(5):
        print(f"  {purpose}: {count}")
        
    print(f"\nHome-work or work-home patterns: {home_work_patterns}")
    
    # CONSERVATIVE RULE RECOMMENDATIONS
    print("\n" + "="*60)
    print("5. CONSERVATIVE RULE RECOMMENDATIONS")
    print("="*60)
    
    # Identify clear linking candidates
    linking_candidates = []
    error_candidates = []
    
    for person_id, person_trip_list in person_trips.items():
        for i, trip in enumerate(person_trip_list):
            if 'Changed or transferred mode' in trip['dest_purpose']:
                time_gap_before = getattr(trip, 'time_gap_before', 999)
                time_gap_after = getattr(trip, 'time_gap_after', 999)
                
                # Clear linking criteria
                if (time_gap_before <= 15 and time_gap_after <= 15 and 
                    trip['distance_miles'] <= 2.0 and 
                    trip['duration_minutes'] and trip['duration_minutes'] <= 30 and
                    trip['speed_mph'] <= 30):
                    linking_candidates.append(trip)
                
                # Clear error criteria
                elif (trip['distance_miles'] <= 0.01 or 
                      trip['speed_mph'] > 100 or
                      (time_gap_before > 240 and time_gap_after > 240)):
                    error_candidates.append(trip)
    
    print(f"\nCLEAR LINKING CANDIDATES:")
    print(f"Criteria: Time gap <=15 min (both sides) AND Distance <=2.0 miles AND Duration <=30 min AND Speed <=30 mph")
    print(f"Count: {len(linking_candidates)} ({len(linking_candidates)/len(change_mode_trips)*100:.1f}%)")
    
    print(f"\nCLEAR ERROR CANDIDATES:")
    print(f"Criteria: Near-zero distance (<=0.01 mi) OR Impossible speed (>100 mph) OR Long gaps (>4 hr both sides)")
    print(f"Count: {len(error_candidates)} ({len(error_candidates)/len(change_mode_trips)*100:.1f}%)")
    
    edge_cases = len(change_mode_trips) - len(linking_candidates) - len(error_candidates)
    print(f"\nEDGE CASES (manual review needed): {edge_cases} ({edge_cases/len(change_mode_trips)*100:.1f}%)")
    
    # COORDINATE CONTINUITY ANALYSIS
    print("\n" + "="*60)
    print("6. COORDINATE CONTINUITY ANALYSIS")
    print("="*60)
    
    origin_matches_prev = 0
    dest_matches_next = 0
    both_continuous = 0
    
    for person_id, person_trip_list in person_trips.items():
        for i, trip in enumerate(person_trip_list):
            if 'Changed or transferred mode' in trip['dest_purpose']:
                # Check origin matches previous destination
                if i > 0:
                    prev_trip = person_trip_list[i-1]
                    if (abs(trip['origin_lat'] - prev_trip['dest_lat']) < 0.001 and
                        abs(trip['origin_lng'] - prev_trip['dest_lng']) < 0.001):
                        origin_matches_prev += 1
                
                # Check destination matches next origin
                if i < len(person_trip_list)-1:
                    next_trip = person_trip_list[i+1]
                    if (abs(trip['dest_lat'] - next_trip['origin_lat']) < 0.001 and
                        abs(trip['dest_lng'] - next_trip['origin_lng']) < 0.001):
                        dest_matches_next += 1
                        
                        # Check if both conditions met
                        if (i > 0 and 
                            abs(trip['origin_lat'] - person_trip_list[i-1]['dest_lat']) < 0.001 and
                            abs(trip['origin_lng'] - person_trip_list[i-1]['dest_lng']) < 0.001):
                            both_continuous += 1
    
    print(f"Origin matches previous destination: {origin_matches_prev} ({origin_matches_prev/len(change_mode_trips)*100:.1f}%)")
    print(f"Destination matches next origin: {dest_matches_next} ({dest_matches_next/len(change_mode_trips)*100:.1f}%)")  
    print(f"Both coordinate continuities: {both_continuous} ({both_continuous/len(change_mode_trips)*100:.1f}%)")
    
    # SPECIFIC EXAMPLES
    print("\n" + "="*60)
    print("7. SPECIFIC EXAMPLES")
    print("="*60)
    
    if linking_candidates:
        print(f"\nLINKING CANDIDATE EXAMPLES:")
        for i, trip in enumerate(linking_candidates[:5]):
            gap_before = getattr(trip, 'time_gap_before', 'N/A')
            gap_after = getattr(trip, 'time_gap_after', 'N/A')
            print(f"  Person {trip['person_id']}, Trip {trip['tripnum']}: "
                  f"{trip['distance_miles']:.3f}mi, {trip['duration_minutes']:.0f}min, "
                  f"gaps: {gap_before:.0f}/{gap_after:.0f}min, {trip['speed_mph']:.1f}mph")
    
    if error_candidates:
        print(f"\nERROR CANDIDATE EXAMPLES:")
        for i, trip in enumerate(error_candidates[:5]):
            gap_before = getattr(trip, 'time_gap_before', 'N/A')
            gap_after = getattr(trip, 'time_gap_after', 'N/A')
            print(f"  Person {trip['person_id']}, Trip {trip['tripnum']}: "
                  f"{trip['distance_miles']:.3f}mi, {trip['duration_minutes']:.0f}min, "
                  f"gaps: {gap_before:.0f}/{gap_after:.0f}min, {trip['speed_mph']:.1f}mph")
    
    # Multi-day patterns
    person_change_counts = Counter()
    for trip in change_mode_trips:
        person_change_counts[trip['person_id']] += 1
    
    frequent_users = {k: v for k, v in person_change_counts.items() if v >= 5}
    print(f"\nMULTI-DAY PATTERNS:")
    print(f"Persons with >=5 change mode trips: {len(frequent_users)}")
    print(f"Max change mode trips by one person: {max(person_change_counts.values()) if person_change_counts else 0}")
    
    return {
        'total_change_mode': len(change_mode_trips),
        'linking_candidates': len(linking_candidates),
        'error_candidates': len(error_candidates),
        'coordinate_continuous': both_continuous
    }

if __name__ == "__main__":
    results = analyze_data()
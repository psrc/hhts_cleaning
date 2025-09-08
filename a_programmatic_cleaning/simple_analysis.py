#!/usr/bin/env python3
"""
Simple analysis of change mode patterns focusing on key metrics
"""

import csv
from collections import Counter, defaultdict
from datetime import datetime

def safe_float(value):
    """Safely convert to float"""
    try:
        return float(value)
    except (ValueError, TypeError):
        return None

def safe_int(value):
    """Safely convert to int"""
    try:
        return int(value)
    except (ValueError, TypeError):
        return None

def parse_timestamp(ts_str):
    """Parse timestamp string"""
    if not ts_str or ts_str == 'Missing Response':
        return None
    try:
        return datetime.strptime(ts_str, '%Y-%m-%d %H:%M:%S.%f')
    except:
        try:
            return datetime.strptime(ts_str, '%Y-%m-%d %H:%M:%S')
        except:
            return None

def analyze_change_mode_data():
    """Analyze change mode patterns"""
    
    print("CHANGE MODE TRIP ANALYSIS")
    print("=" * 50)
    
    # Read all data
    all_trips = []
    change_mode_trips = []
    
    with open(r'C:\Users\mjensen\projects\hhts_cleaning\a_programmatic_cleaning\persons_with_change_purpose_trips.csv', 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            # Clean and convert data
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
                if 'Changed or transferred mode' in trip['dest_purpose']:
                    change_mode_trips.append(trip)
    
    print(f"Total trips: {len(all_trips):,}")
    print(f"Change mode trips: {len(change_mode_trips):,}")
    print(f"Unique persons: {len(set(t['person_id'] for t in all_trips)):,}")
    
    # Group by person for sequence analysis
    person_trips = defaultdict(list)
    for trip in sorted(all_trips, key=lambda x: (x['person_id'], x['tripnum'] or 0)):
        person_trips[trip['person_id']].append(trip)
    
    print("\n1. DISTANCE AND SPEED PATTERNS")
    print("-" * 30)
    
    # Distance analysis
    distances = [t['distance_miles'] for t in change_mode_trips if t['distance_miles'] is not None]
    speeds = [t['speed_mph'] for t in change_mode_trips if t['speed_mph'] is not None]
    
    if distances:
        distances.sort()
        n = len(distances)
        print(f"Distance statistics (n={n}):")
        print(f"  Min: {min(distances):.4f} miles")
        print(f"  Median: {distances[n//2]:.2f} miles")
        print(f"  Max: {max(distances):.2f} miles")
        print(f"  Mean: {sum(distances)/n:.2f} miles")
        
        very_short = sum(1 for d in distances if d <= 0.1)
        short = sum(1 for d in distances if d <= 1.0)
        medium = sum(1 for d in distances if 1.0 < d <= 5.0)
        long_dist = sum(1 for d in distances if d > 5.0)
        
        print(f"  <=0.1 miles: {very_short} ({very_short/n*100:.1f}%)")
        print(f"  <=1.0 miles: {short} ({short/n*100:.1f}%)")
        print(f"  1-5 miles: {medium} ({medium/n*100:.1f}%)")
        print(f"  >5 miles: {long_dist} ({long_dist/n*100:.1f}%)")
    
    if speeds:
        speeds.sort()
        n = len(speeds)
        print(f"\nSpeed statistics (n={n}):")
        print(f"  Min: {min(speeds):.1f} mph")
        print(f"  Median: {speeds[n//2]:.1f} mph")
        print(f"  Max: {max(speeds):.1f} mph")
        print(f"  Mean: {sum(speeds)/n:.1f} mph")
        
        very_slow = sum(1 for s in speeds if s <= 5)
        normal = sum(1 for s in speeds if 5 < s <= 30)
        fast = sum(1 for s in speeds if 30 < s <= 60)
        very_fast = sum(1 for s in speeds if s > 60)
        
        print(f"  <=5 mph: {very_slow} ({very_slow/n*100:.1f}%)")
        print(f"  5-30 mph: {normal} ({normal/n*100:.1f}%)")
        print(f"  30-60 mph: {fast} ({fast/n*100:.1f}%)")
        print(f"  >60 mph: {very_fast} ({very_fast/n*100:.1f}%)")
    
    print("\n2. MODE PATTERNS")
    print("-" * 30)
    
    mode_counts = Counter()
    for trip in change_mode_trips:
        if trip['mode_1']:
            mode_counts[trip['mode_1']] += 1
    
    print("Most common modes in change mode trips:")
    for mode, count in mode_counts.most_common(10):
        print(f"  {mode}: {count}")
    
    print("\n3. SEQUENCE PATTERNS")
    print("-" * 30)
    
    # Analyze sequences around change mode trips
    sequential_change_modes = 0
    coordinate_continuous = 0
    mode_same_before_after = 0
    
    for person_id, trips in person_trips.items():
        for i, trip in enumerate(trips):
            if 'Changed or transferred mode' in trip['dest_purpose']:
                
                # Check for sequential change mode trips
                if (i > 0 and 'Changed or transferred mode' in trips[i-1]['dest_purpose']) or \
                   (i < len(trips)-1 and 'Changed or transferred mode' in trips[i+1]['dest_purpose']):
                    sequential_change_modes += 1
                
                # Check coordinate continuity
                prev_continuous = False
                next_continuous = False
                
                if i > 0:
                    prev_trip = trips[i-1]
                    if (trip['origin_lat'] and trip['origin_lng'] and 
                        prev_trip['dest_lat'] and prev_trip['dest_lng']):
                        if (abs(trip['origin_lat'] - prev_trip['dest_lat']) < 0.001 and
                            abs(trip['origin_lng'] - prev_trip['dest_lng']) < 0.001):
                            prev_continuous = True
                
                if i < len(trips)-1:
                    next_trip = trips[i+1]
                    if (trip['dest_lat'] and trip['dest_lng'] and 
                        next_trip['origin_lat'] and next_trip['origin_lng']):
                        if (abs(trip['dest_lat'] - next_trip['origin_lat']) < 0.001 and
                            abs(trip['dest_lng'] - next_trip['origin_lng']) < 0.001):
                            next_continuous = True
                
                if prev_continuous and next_continuous:
                    coordinate_continuous += 1
                
                # Check mode consistency
                if (i > 0 and i < len(trips)-1 and
                    trip['mode_1'] and trips[i-1]['mode_1'] and trips[i+1]['mode_1']):
                    if trips[i-1]['mode_1'] == trips[i+1]['mode_1']:
                        mode_same_before_after += 1
    
    print(f"Sequential change mode trips: {sequential_change_modes}")
    print(f"Coordinate continuous (both ends): {coordinate_continuous} ({coordinate_continuous/len(change_mode_trips)*100:.1f}%)")
    print(f"Same mode before/after change: {mode_same_before_after}")
    
    print("\n4. PURPOSE CONTEXT")
    print("-" * 30)
    
    prev_purposes = Counter()
    next_purposes = Counter()
    
    for person_id, trips in person_trips.items():
        for i, trip in enumerate(trips):
            if 'Changed or transferred mode' in trip['dest_purpose']:
                if i > 0:
                    prev_purposes[trips[i-1]['dest_purpose']] += 1
                if i < len(trips)-1:
                    next_purposes[trips[i+1]['dest_purpose']] += 1
    
    print("Most common purposes BEFORE change mode:")
    for purpose, count in prev_purposes.most_common(5):
        print(f"  {purpose}: {count}")
    
    print("\nMost common purposes AFTER change mode:")
    for purpose, count in next_purposes.most_common(5):
        print(f"  {purpose}: {count}")
    
    print("\n5. POTENTIAL LINKING CANDIDATES")
    print("-" * 30)
    
    # Conservative linking criteria
    linking_candidates = []
    for person_id, trips in person_trips.items():
        for i, trip in enumerate(trips):
            if 'Changed or transferred mode' in trip['dest_purpose']:
                # Must have coordinate continuity
                prev_continuous = False
                next_continuous = False
                
                if i > 0:
                    prev_trip = trips[i-1]
                    if (trip['origin_lat'] and prev_trip['dest_lat'] and
                        abs(trip['origin_lat'] - prev_trip['dest_lat']) < 0.001 and
                        abs(trip['origin_lng'] - prev_trip['dest_lng']) < 0.001):
                        prev_continuous = True
                
                if i < len(trips)-1:
                    next_trip = trips[i+1]
                    if (trip['dest_lat'] and next_trip['origin_lat'] and
                        abs(trip['dest_lat'] - next_trip['origin_lat']) < 0.001 and
                        abs(trip['dest_lng'] - next_trip['origin_lng']) < 0.001):
                        next_continuous = True
                
                # Additional criteria for linking
                if (prev_continuous and next_continuous and
                    trip['distance_miles'] and trip['distance_miles'] <= 3.0 and
                    trip['speed_mph'] and trip['speed_mph'] <= 50):
                    linking_candidates.append(trip)
    
    print(f"Conservative linking candidates: {len(linking_candidates)} ({len(linking_candidates)/len(change_mode_trips)*100:.1f}%)")
    
    print("\n6. POTENTIAL ERROR CASES") 
    print("-" * 30)
    
    error_cases = []
    for trip in change_mode_trips:
        is_error = False
        reasons = []
        
        # Near zero distance
        if trip['distance_miles'] is not None and trip['distance_miles'] <= 0.01:
            is_error = True
            reasons.append("near-zero distance")
        
        # Impossible speed
        if trip['speed_mph'] is not None and trip['speed_mph'] > 200:
            is_error = True  
            reasons.append("impossible speed")
        
        # Very high distance for local transit
        if (trip['distance_miles'] is not None and trip['distance_miles'] > 500 and
            trip['mode_1'] in ['Bus (public transit)', 'Walk (or jog/wheelchair)']):
            is_error = True
            reasons.append("unrealistic distance for mode")
        
        if is_error:
            error_cases.append((trip, reasons))
    
    print(f"Potential error cases: {len(error_cases)} ({len(error_cases)/len(change_mode_trips)*100:.1f}%)")
    
    if error_cases:
        print("\nError case examples:")
        for i, (trip, reasons) in enumerate(error_cases[:5]):
            dist = trip['distance_miles'] if trip['distance_miles'] is not None else "N/A"
            speed = trip['speed_mph'] if trip['speed_mph'] is not None else "N/A"
            print(f"  Person {trip['person_id']}, Trip {trip['tripnum']}: "
                  f"dist={dist}, speed={speed}, mode={trip['mode_1']}, reasons={', '.join(reasons)}")
    
    print("\n7. MULTI-USER PATTERNS")
    print("-" * 30)
    
    person_counts = Counter()
    for trip in change_mode_trips:
        person_counts[trip['person_id']] += 1
    
    frequent_users = [p for p, count in person_counts.items() if count >= 5]
    print(f"Persons with 5+ change mode trips: {len(frequent_users)}")
    print(f"Max change mode trips by one person: {max(person_counts.values())}")
    
    if frequent_users:
        print("Top heavy users:")
        for person_id, count in person_counts.most_common(10):
            print(f"  Person {person_id}: {count} trips")

if __name__ == "__main__":
    analyze_change_mode_data()
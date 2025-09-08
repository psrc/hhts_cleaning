#!/usr/bin/env python3
"""
Comprehensive analysis of change mode patterns with specific examples and recommendations
"""

import csv
from collections import defaultdict, Counter

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

def analyze_comprehensive():
    """Complete analysis with specific recommendations"""
    
    print("COMPREHENSIVE CHANGE MODE ANALYSIS")
    print("=" * 60)
    
    # Read all data
    all_trips = []
    change_mode_trips = []
    
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
                'dest_lng': safe_float(row['dest_lng']),
                'depart_time': row['depart_time_timestamp'],
                'arrival_time': row['arrival_time_timestamp']
            }
            
            if trip['tripnum'] is not None:
                all_trips.append(trip)
                if 'Changed or transferred mode' in trip['dest_purpose']:
                    change_mode_trips.append(trip)
    
    # Group by person
    person_trips = defaultdict(list)
    for trip in sorted(all_trips, key=lambda x: (x['person_id'], x['tripnum'] or 0)):
        person_trips[trip['person_id']].append(trip)
    
    print(f"Dataset: {len(all_trips)} total trips, {len(change_mode_trips)} change mode trips")
    print(f"Persons: {len(person_trips)} unique persons")
    
    print("\n1. GEOGRAPHIC COORDINATE ANALYSIS")
    print("-" * 50)
    
    linking_candidates_coord = []
    error_candidates_coord = []
    
    for person_id, trips in person_trips.items():
        for i, trip in enumerate(trips):
            if 'Changed or transferred mode' in trip['dest_purpose']:
                
                # Check coordinate continuity
                prev_continuous = False
                next_continuous = False
                
                if i > 0 and trips[i-1]['dest_lat'] and trip['origin_lat']:
                    lat_diff = abs(trip['origin_lat'] - trips[i-1]['dest_lat'])
                    lng_diff = abs(trip['origin_lng'] - trips[i-1]['dest_lng'])
                    if lat_diff < 0.001 and lng_diff < 0.001:
                        prev_continuous = True
                
                if (i < len(trips)-1 and trip['dest_lat'] and 
                    trips[i+1]['origin_lat']):
                    lat_diff = abs(trip['dest_lat'] - trips[i+1]['origin_lat'])
                    lng_diff = abs(trip['dest_lng'] - trips[i+1]['origin_lng'])
                    if lat_diff < 0.001 and lng_diff < 0.001:
                        next_continuous = True
                
                # Assess linking potential based on coordinates and distance/speed
                if (prev_continuous and next_continuous and 
                    trip['distance_miles'] is not None and trip['speed_mph'] is not None):
                    
                    if (trip['distance_miles'] <= 5.0 and trip['speed_mph'] <= 60):
                        linking_candidates_coord.append({
                            'person_id': person_id,
                            'tripnum': trip['tripnum'],
                            'distance': trip['distance_miles'],
                            'speed': trip['speed_mph'],
                            'mode': trip['mode_1'],
                            'trip_index': i,
                            'prev_trip': trips[i-1] if i > 0 else None,
                            'next_trip': trips[i+1] if i < len(trips)-1 else None
                        })
                
                # Check for clear errors
                if trip['distance_miles'] is not None and trip['speed_mph'] is not None:
                    if (trip['distance_miles'] <= 0.01 or trip['speed_mph'] > 100 or
                        (trip['distance_miles'] > 100 and trip['mode_1'] in 
                         ['Walk (or jog/wheelchair)', 'Bus (public transit)'])):
                        error_candidates_coord.append({
                            'person_id': person_id,
                            'tripnum': trip['tripnum'],
                            'distance': trip['distance_miles'],
                            'speed': trip['speed_mph'],
                            'mode': trip['mode_1'],
                            'error_type': 'distance/speed anomaly'
                        })
    
    print(f"Coordinate-continuous linking candidates: {len(linking_candidates_coord)}")
    print(f"Clear error candidates: {len(error_candidates_coord)}")
    
    print("\n2. DETAILED LINKING CANDIDATE ANALYSIS")
    print("-" * 50)
    
    # Categorize linking candidates by confidence
    high_confidence = []
    medium_confidence = []
    low_confidence = []
    
    for candidate in linking_candidates_coord:
        # High confidence: short distance, reasonable speed, transit modes
        if (candidate['distance'] <= 2.0 and candidate['speed'] <= 25 and
            candidate['mode'] in ['Bus (public transit)', 'Rail (e.g., train, subway)', 'Walk (or jog/wheelchair)']):
            high_confidence.append(candidate)
        # Medium confidence: moderate distance/speed
        elif candidate['distance'] <= 4.0 and candidate['speed'] <= 40:
            medium_confidence.append(candidate)
        else:
            low_confidence.append(candidate)
    
    print(f"High confidence (dist<=2mi, speed<=25mph, transit): {len(high_confidence)}")
    print(f"Medium confidence (dist<=4mi, speed<=40mph): {len(medium_confidence)}")
    print(f"Low confidence (other): {len(low_confidence)}")
    
    # Show examples
    if high_confidence:
        print(f"\nHIGH CONFIDENCE EXAMPLES:")
        for candidate in high_confidence[:5]:
            prev_purpose = candidate['prev_trip']['dest_purpose'][:40] if candidate['prev_trip'] else "N/A"
            next_purpose = candidate['next_trip']['dest_purpose'][:40] if candidate['next_trip'] else "N/A"
            print(f"  Person {candidate['person_id']}, Trip {candidate['tripnum']}: "
                  f"{candidate['distance']:.2f}mi, {candidate['speed']:.1f}mph, {candidate['mode']}")
            print(f"    Prev: {prev_purpose}")
            print(f"    Next: {next_purpose}")
    
    print("\n3. MODE AND PURPOSE PATTERN ANALYSIS")
    print("-" * 50)
    
    mode_transitions = Counter()
    purpose_sequences = Counter()
    
    for person_id, trips in person_trips.items():
        for i, trip in enumerate(trips):
            if 'Changed or transferred mode' in trip['dest_purpose']:
                # Mode transitions
                if i > 0 and i < len(trips)-1:
                    prev_mode = trips[i-1]['mode_1']
                    curr_mode = trip['mode_1'] 
                    next_mode = trips[i+1]['mode_1']
                    
                    if prev_mode != curr_mode:
                        mode_transitions[f"{prev_mode} -> {curr_mode}"] += 1
                    if curr_mode != next_mode:
                        mode_transitions[f"{curr_mode} -> {next_mode}"] += 1
                
                # Purpose sequences 
                if i > 0 and i < len(trips)-1:
                    prev_purpose = trips[i-1]['dest_purpose']
                    next_purpose = trips[i+1]['dest_purpose']
                    purpose_sequences[f"{prev_purpose} | {next_purpose}"] += 1
    
    print(f"Top mode transitions:")
    for transition, count in mode_transitions.most_common(5):
        print(f"  {transition}: {count}")
    
    print(f"\nTop purpose sequences (before | after):")
    for sequence, count in purpose_sequences.most_common(5):
        parts = sequence.split(' | ')
        if len(parts) == 2:
            print(f"  {parts[0][:30]}... | {parts[1][:30]}...: {count}")
    
    print("\n4. SPECIFIC PERSON ANALYSIS")
    print("-" * 50)
    
    # Examine some specific high-usage persons
    person_stats = Counter()
    for trip in change_mode_trips:
        person_stats[trip['person_id']] += 1
    
    high_users = [p for p, count in person_stats.items() if count >= 10]
    print(f"Persons with 10+ change mode trips: {len(high_users)}")
    
    if high_users:
        sample_person = high_users[0]
        sample_trips = person_trips[sample_person]
        change_trips = [t for t in sample_trips if 'Changed or transferred mode' in t['dest_purpose']]
        
        print(f"\nExample analysis - Person {sample_person} ({len(change_trips)} change mode trips):")
        for i, trip in enumerate(change_trips[:5]):
            print(f"  Trip {trip['tripnum']}: {trip['distance_miles']:.2f}mi, {trip['speed_mph']:.1f}mph, {trip['mode_1']}")
    
    print("\n5. CONSERVATIVE RULE RECOMMENDATIONS")
    print("-" * 50)
    
    print("RULE 1 - AUTO-LINK CRITERIA (High Confidence):")
    print("  • Origin coordinates match previous trip destination (within 0.001 degrees)")
    print("  • Destination coordinates match next trip origin (within 0.001 degrees)")  
    print("  • Distance <= 2.0 miles")
    print("  • Speed <= 25 mph")
    print("  • Mode is Bus, Rail, or Walk")
    print(f"  -> Applies to: {len(high_confidence)} trips ({len(high_confidence)/len(change_mode_trips)*100:.1f}%)")
    
    print(f"\nRULE 2 - REVIEW FOR LINKING (Medium Confidence):")
    print("  • Coordinate continuity (both ends)")
    print("  • Distance <= 4.0 miles")
    print("  • Speed <= 40 mph")
    print(f"  -> Applies to: {len(medium_confidence)} trips ({len(medium_confidence)/len(change_mode_trips)*100:.1f}%)")
    
    print(f"\nRULE 3 - FLAG AS ERROR:")
    print("  • Distance <= 0.01 miles OR")
    print("  • Speed > 100 mph OR")
    print("  • Distance > 100 miles AND mode is Walk/Bus")
    print(f"  -> Applies to: {len(error_candidates_coord)} trips ({len(error_candidates_coord)/len(change_mode_trips)*100:.1f}%)")
    
    remaining = len(change_mode_trips) - len(high_confidence) - len(medium_confidence) - len(error_candidates_coord)
    print(f"\nRULE 4 - LEAVE AS-IS (Manual trips or insufficient data):")
    print(f"  -> Applies to: {remaining} trips ({remaining/len(change_mode_trips)*100:.1f}%)")
    
    print("\n6. IMPLEMENTATION PRIORITY")
    print("-" * 50)
    
    print("Phase 1 (Immediate): Implement Rule 1 (auto-link high confidence)")
    print("Phase 2 (Review): Manually review Rule 2 candidates")
    print("Phase 3 (Cleanup): Flag/correct Rule 3 errors")
    print("Phase 4 (Manual): Address remaining cases as needed")
    
    # Generate specific SQL conditions
    print("\n7. SQL IMPLEMENTATION EXAMPLE")
    print("-" * 50)
    
    print("-- Auto-link high confidence change mode trips")
    print("UPDATE trips SET")
    print("  link_to_previous = 1,")
    print("  link_to_next = 1")
    print("WHERE dest_purpose LIKE '%Changed or transferred mode%'")
    print("  AND distance_miles <= 2.0")
    print("  AND speed_mph <= 25")
    print("  AND mode_1 IN ('Bus (public transit)', 'Rail (e.g., train, subway)', 'Walk (or jog/wheelchair)')")
    print("  AND coordinate_continuous_before = 1")  
    print("  AND coordinate_continuous_after = 1;")
    
    return {
        'total_change_mode': len(change_mode_trips),
        'high_confidence_linking': len(high_confidence),
        'medium_confidence_linking': len(medium_confidence),
        'error_candidates': len(error_candidates_coord),
        'coordinate_continuous': len(linking_candidates_coord),
        'high_users': len(high_users)
    }

if __name__ == "__main__":
    results = analyze_comprehensive()
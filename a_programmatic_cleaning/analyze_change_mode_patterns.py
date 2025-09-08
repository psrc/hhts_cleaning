#!/usr/bin/env python3
"""
Comprehensive analysis of change mode trips for conservative rule development
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from geopy.distance import geodesic
import warnings
warnings.filterwarnings('ignore')

def calculate_distance(row):
    """Calculate distance between origin and destination"""
    try:
        return geodesic((row['origin_lat'], row['origin_lng']), 
                       (row['dest_lat'], row['dest_lng'])).miles
    except:
        return np.nan

def analyze_change_mode_patterns():
    """Main analysis function"""
    
    # Load data
    df = pd.read_csv(r"C:\Users\mjensen\projects\hhts_cleaning\a_programmatic_cleaning\persons_with_change_purpose_trips.csv")
    
    # Convert timestamps
    df['depart_time_timestamp'] = pd.to_datetime(df['depart_time_timestamp'])
    df['arrival_time_timestamp'] = pd.to_datetime(df['arrival_time_timestamp'])
    df['trip_duration_minutes'] = (df['arrival_time_timestamp'] - df['depart_time_timestamp']).dt.total_seconds() / 60
    
    # Calculate actual geodesic distances for verification
    df['calculated_distance'] = df.apply(calculate_distance, axis=1)
    
    # Identify change mode trips
    change_mode_trips = df[df['dest_purpose'].str.contains('Changed or transferred mode', na=False)].copy()
    other_trips = df[~df['dest_purpose'].str.contains('Changed or transferred mode', na=False)].copy()
    
    print("=" * 80)
    print("COMPREHENSIVE CHANGE MODE TRIP ANALYSIS")
    print("=" * 80)
    
    print(f"\nDATASET OVERVIEW:")
    print(f"Total records: {len(df):,}")
    print(f"Unique persons: {df['person_id'].nunique():,}")
    print(f"Change mode trips: {len(change_mode_trips):,}")
    print(f"Other trips: {len(other_trips):,}")
    print(f"Date range: {df['depart_time_timestamp'].min()} to {df['depart_time_timestamp'].max()}")
    
    # TEMPORAL PATTERN ANALYSIS
    print("\n" + "="*50)
    print("1. TEMPORAL PATTERN ANALYSIS")
    print("="*50)
    
    # Sort by person and trip number for sequence analysis
    df_sorted = df.sort_values(['person_id', 'tripnum']).copy()
    
    # Calculate time gaps between consecutive trips
    df_sorted['prev_arrival'] = df_sorted.groupby('person_id')['arrival_time_timestamp'].shift(1)
    df_sorted['next_depart'] = df_sorted.groupby('person_id')['depart_time_timestamp'].shift(-1)
    df_sorted['time_gap_before_minutes'] = (df_sorted['depart_time_timestamp'] - df_sorted['prev_arrival']).dt.total_seconds() / 60
    df_sorted['time_gap_after_minutes'] = (df_sorted['next_depart'] - df_sorted['arrival_time_timestamp']).dt.total_seconds() / 60
    
    change_mode_sorted = df_sorted[df_sorted['dest_purpose'].str.contains('Changed or transferred mode', na=False)].copy()
    
    print(f"\nTime Gap Analysis for Change Mode Trips:")
    print(f"Time gap before change mode trip (minutes):")
    print(change_mode_sorted['time_gap_before_minutes'].describe())
    print(f"\nTime gap after change mode trip (minutes):")
    print(change_mode_sorted['time_gap_after_minutes'].describe())
    
    # Short time gaps (potential transfers)
    short_gap_before = change_mode_sorted['time_gap_before_minutes'] <= 30
    short_gap_after = change_mode_sorted['time_gap_after_minutes'] <= 30
    
    print(f"\nTrips with ≤30 min gap before: {short_gap_before.sum()} ({short_gap_before.mean()*100:.1f}%)")
    print(f"Trips with ≤30 min gap after: {short_gap_after.sum()} ({short_gap_after.mean()*100:.1f}%)")
    print(f"Trips with ≤30 min gap both before AND after: {(short_gap_before & short_gap_after).sum()}")
    
    # GEOGRAPHIC PATTERN ANALYSIS
    print("\n" + "="*50)
    print("2. GEOGRAPHIC PATTERN ANALYSIS")
    print("="*50)
    
    print(f"\nDistance Statistics for Change Mode Trips:")
    print(change_mode_trips['distance_miles'].describe())
    print(f"\nCalculated vs Reported Distance Comparison:")
    distance_diff = change_mode_trips['calculated_distance'] - change_mode_trips['distance_miles']
    print(f"Mean difference: {distance_diff.mean():.4f} miles")
    print(f"Std difference: {distance_diff.std():.4f} miles")
    
    # Very short distance change mode trips (potential errors)
    very_short = change_mode_trips['distance_miles'] <= 0.1
    print(f"\nVery short distance change mode trips (≤0.1 miles): {very_short.sum()} ({very_short.mean()*100:.1f}%)")
    
    # Zero distance trips (same location)
    zero_distance = change_mode_trips['distance_miles'] <= 0.01
    print(f"Near-zero distance trips (≤0.01 miles): {zero_distance.sum()}")
    
    if zero_distance.sum() > 0:
        print("\nNear-zero distance change mode examples:")
        print(change_mode_trips[zero_distance][['person_id', 'tripnum', 'distance_miles', 'trip_duration_minutes', 'mode_1']].head(10))
    
    # SPEED ANOMALY ANALYSIS
    print(f"\nSpeed Analysis:")
    print(change_mode_trips['speed_mph'].describe())
    
    # Unrealistic speeds
    high_speed = change_mode_trips['speed_mph'] > 60
    very_high_speed = change_mode_trips['speed_mph'] > 100
    print(f"\nHigh speed trips (>60 mph): {high_speed.sum()} ({high_speed.mean()*100:.1f}%)")
    print(f"Very high speed trips (>100 mph): {very_high_speed.sum()} ({very_high_speed.mean()*100:.1f}%)")
    
    if very_high_speed.sum() > 0:
        print("\nVery high speed examples:")
        print(change_mode_trips[very_high_speed][['person_id', 'tripnum', 'distance_miles', 'speed_mph', 'trip_duration_minutes']].head())
    
    # MODE CONSISTENCY ANALYSIS
    print("\n" + "="*50)
    print("3. MODE CONSISTENCY ANALYSIS")
    print("="*50)
    
    # Get mode patterns around change mode trips
    df_with_context = df_sorted.copy()
    df_with_context['prev_mode_1'] = df_with_context.groupby('person_id')['mode_1'].shift(1)
    df_with_context['next_mode_1'] = df_with_context.groupby('person_id')['mode_1'].shift(-1)
    
    change_mode_context = df_with_context[df_with_context['dest_purpose'].str.contains('Changed or transferred mode', na=False)].copy()
    
    print(f"\nMode patterns for change mode trips:")
    print(f"Most common current mode: {change_mode_context['mode_1'].value_counts().head()}")
    
    # Cases where mode doesn't actually change
    same_mode_before = change_mode_context['mode_1'] == change_mode_context['prev_mode_1']
    same_mode_after = change_mode_context['mode_1'] == change_mode_context['next_mode_1']
    same_mode_both = same_mode_before & same_mode_after
    
    print(f"\nTrips where mode same as previous: {same_mode_before.sum()} ({same_mode_before.mean()*100:.1f}%)")
    print(f"Trips where mode same as next: {same_mode_after.sum()} ({same_mode_after.mean()*100:.1f}%)")
    print(f"Trips where mode same as both previous AND next: {same_mode_both.sum()}")
    
    # JOURNEY CONTEXT ANALYSIS
    print("\n" + "="*50)
    print("4. JOURNEY CONTEXT ANALYSIS")
    print("="*50)
    
    # Get context of trips before and after
    df_with_purposes = df_sorted.copy()
    df_with_purposes['prev_purpose'] = df_with_purposes.groupby('person_id')['dest_purpose'].shift(1)
    df_with_purposes['next_purpose'] = df_with_purposes.groupby('person_id')['dest_purpose'].shift(-1)
    
    change_mode_purpose_context = df_with_purposes[df_with_purposes['dest_purpose'].str.contains('Changed or transferred mode', na=False)].copy()
    
    print(f"\nMost common trip purposes before change mode:")
    print(change_mode_purpose_context['prev_purpose'].value_counts().head(10))
    
    print(f"\nMost common trip purposes after change mode:")
    print(change_mode_purpose_context['next_purpose'].value_counts().head(10))
    
    # Home-work-home patterns
    home_work_patterns = (
        (change_mode_purpose_context['prev_purpose'].str.contains('home', case=False, na=False)) &
        (change_mode_purpose_context['next_purpose'].str.contains('work', case=False, na=False))
    ) | (
        (change_mode_purpose_context['prev_purpose'].str.contains('work', case=False, na=False)) &
        (change_mode_purpose_context['next_purpose'].str.contains('home', case=False, na=False))
    )
    
    print(f"\nHome-work or work-home patterns: {home_work_patterns.sum()} ({home_work_patterns.mean()*100:.1f}%)")
    
    # CONSERVATIVE RULE IDENTIFICATION
    print("\n" + "="*60)
    print("5. CONSERVATIVE RULE RECOMMENDATIONS")
    print("="*60)
    
    # Clear linking candidates
    print("\nCLEAR LINKING CANDIDATES:")
    print("Criteria for likely legitimate transfers:")
    
    linking_candidates = change_mode_sorted[
        (change_mode_sorted['time_gap_before_minutes'] <= 15) &
        (change_mode_sorted['time_gap_after_minutes'] <= 15) &
        (change_mode_sorted['distance_miles'] <= 2.0) &
        (change_mode_sorted['trip_duration_minutes'] <= 30) &
        (change_mode_sorted['speed_mph'] <= 30)
    ].copy()
    
    print(f"- Time gap ≤15 min before AND after")
    print(f"- Distance ≤2.0 miles")
    print(f"- Duration ≤30 minutes")
    print(f"- Speed ≤30 mph")
    print(f"Trips meeting all criteria: {len(linking_candidates)} ({len(linking_candidates)/len(change_mode_sorted)*100:.1f}%)")
    
    # Clear error cases
    print("\nCLEAR ERROR CASES:")
    print("Criteria for likely data entry errors:")
    
    error_candidates = change_mode_sorted[
        (
            (change_mode_sorted['distance_miles'] <= 0.01) |  # Zero distance
            (change_mode_sorted['speed_mph'] > 100) |  # Impossible speed
            (
                (change_mode_sorted['time_gap_before_minutes'] > 240) &  # Long gaps both sides
                (change_mode_sorted['time_gap_after_minutes'] > 240)
            )
        )
    ].copy()
    
    print(f"- Near-zero distance (≤0.01 miles) OR")
    print(f"- Impossible speed (>100 mph) OR") 
    print(f"- Long time gaps (>4 hours) both before and after")
    print(f"Trips meeting any criteria: {len(error_candidates)} ({len(error_candidates)/len(change_mode_sorted)*100:.1f}%)")
    
    # Multi-day patterns
    print("\nMULTI-DAY PATTERN ANALYSIS:")
    person_change_counts = change_mode_trips.groupby('person_id').size()
    frequent_users = person_change_counts[person_change_counts >= 5]
    print(f"Persons with ≥5 change mode trips: {len(frequent_users)}")
    print(f"Max change mode trips by one person: {person_change_counts.max()}")
    
    if len(frequent_users) > 0:
        print(f"\nTop frequent users:")
        print(frequent_users.sort_values(ascending=False).head(10))
    
    # SPECIFIC EXAMPLES
    print("\n" + "="*60)
    print("6. SPECIFIC EXAMPLES")
    print("="*60)
    
    if len(linking_candidates) > 0:
        print("\nEXAMPLE LINKING CANDIDATES:")
        print(linking_candidates[['person_id', 'tripnum', 'distance_miles', 'trip_duration_minutes', 
                                'time_gap_before_minutes', 'time_gap_after_minutes', 'speed_mph']].head(5))
    
    if len(error_candidates) > 0:
        print("\nEXAMPLE ERROR CANDIDATES:")
        print(error_candidates[['person_id', 'tripnum', 'distance_miles', 'trip_duration_minutes', 
                              'time_gap_before_minutes', 'time_gap_after_minutes', 'speed_mph']].head(5))
    
    # Edge cases
    edge_cases = change_mode_sorted[
        ~change_mode_sorted.index.isin(linking_candidates.index) &
        ~change_mode_sorted.index.isin(error_candidates.index)
    ].copy()
    
    print(f"\nEDGE CASES (need manual review): {len(edge_cases)} ({len(edge_cases)/len(change_mode_sorted)*100:.1f}%)")
    if len(edge_cases) > 0:
        print("Example edge cases:")
        print(edge_cases[['person_id', 'tripnum', 'distance_miles', 'trip_duration_minutes', 
                         'time_gap_before_minutes', 'time_gap_after_minutes', 'speed_mph']].head(5))
    
    # DETAILED COORDINATES ANALYSIS
    print("\n" + "="*60)
    print("7. COORDINATE PATTERN ANALYSIS")
    print("="*60)
    
    # Check for identical coordinates with adjacent trips
    df_coords = df_sorted.copy()
    df_coords['prev_dest_lat'] = df_coords.groupby('person_id')['dest_lat'].shift(1)
    df_coords['prev_dest_lng'] = df_coords.groupby('person_id')['dest_lng'].shift(1)
    df_coords['next_origin_lat'] = df_coords.groupby('person_id')['origin_lat'].shift(-1)
    df_coords['next_origin_lng'] = df_coords.groupby('person_id')['origin_lng'].shift(-1)
    
    change_mode_coords = df_coords[df_coords['dest_purpose'].str.contains('Changed or transferred mode', na=False)].copy()
    
    # Check if change mode origin matches previous trip destination
    origin_matches_prev = (
        (abs(change_mode_coords['origin_lat'] - change_mode_coords['prev_dest_lat']) < 0.001) &
        (abs(change_mode_coords['origin_lng'] - change_mode_coords['prev_dest_lng']) < 0.001)
    )
    
    # Check if change mode destination matches next trip origin  
    dest_matches_next = (
        (abs(change_mode_coords['dest_lat'] - change_mode_coords['next_origin_lat']) < 0.001) &
        (abs(change_mode_coords['dest_lng'] - change_mode_coords['next_origin_lng']) < 0.001)
    )
    
    print(f"Change mode trips where origin matches previous destination: {origin_matches_prev.sum()} ({origin_matches_prev.mean()*100:.1f}%)")
    print(f"Change mode trips where destination matches next origin: {dest_matches_next.sum()} ({dest_matches_next.mean()*100:.1f}%)")
    print(f"Change mode trips with both coordinate continuities: {(origin_matches_prev & dest_matches_next).sum()}")
    
    return {
        'total_change_mode': len(change_mode_trips),
        'linking_candidates': len(linking_candidates),
        'error_candidates': len(error_candidates),
        'edge_cases': len(edge_cases),
        'coordinate_continuous': (origin_matches_prev & dest_matches_next).sum()
    }

if __name__ == "__main__":
    results = analyze_change_mode_patterns()
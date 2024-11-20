#!/bin/bash

export TZ="America/Denver"

RECORDINGS_DIR="/recordings"
SORTED_DIR="/sorted_recordings"
START_AFTERNOON_HOUR=17
END_MORNING_HOUR=9

# Get current day of week (1-7, 1=Monday)
current_day=$(date +%u)

# Clean and recreate sorted directory
rm -rf "$SORTED_DIR"/*
mkdir -p "$SORTED_DIR"

# Function to get Unix timestamp for a specific time today
get_today_timestamp() {
    local hour=$1
    date -d "today $hour:00:00 MST" +%s
}

# Function to get Unix timestamp for a specific time on a specific date
get_date_timestamp() {
    local date=$1
    local hour=$2
    date -d "$date $hour:00:00 MST" +%s
}

if [ $current_day -le 5 ]; then
    # Weekday operation
    echo "Weekday operation detected ($current_day)"
    # For afternoon playlist (5 PM), get today's recordings from 9 AM to 5 PM
    current_hour=$(date +%-H)
    if [ $current_hour -ge $START_AFTERNOON_HOUR ]; then
        # If it's after 5 PM, get today's 9 AM to 5 PM recordings
        recording_start=$(get_today_timestamp $END_MORNING_HOUR)
        recording_end=$(get_today_timestamp $START_AFTERNOON_HOUR)
    else
        # If it's before 5 PM, get yesterday's 9 AM to 5 PM recordings
        recording_start=$(date -d "yesterday $END_MORNING_HOUR:00:00 MST" +%s)
        recording_end=$(date -d "yesterday $START_AFTERNOON_HOUR:00:00 MST" +%s)
    fi
else
    # Weekend operation remains the same
    echo "Weekend operation detected ($current_day)"
    last_monday=$(date -d "last monday" +%Y-%m-%d)
    recording_start=$(get_date_timestamp "$last_monday" $END_MORNING_HOUR)
    recording_end=$(date -d "$last_monday +4 days $START_AFTERNOON_HOUR:00:00 MST" +%s)
fi

echo "Creating sorted copies for recordings between:"
echo "Start: $(date -d @$recording_start) (Unix: $recording_start)"
echo "End: $(date -d @$recording_end) (Unix: $recording_end)"
echo "----------------------------------------"

# Rest of the script remains the same
counter=1
find "$RECORDINGS_DIR" -name "*.mp3" -type f | while read file; do
    timestamp=$(basename "$file" .mp3)
    if [[ $timestamp -ge $recording_start && $timestamp -le $recording_end ]]; then
        echo "$file $timestamp"
    fi
done | sort -k2 -n | while read file timestamp; do
    padded_num=$(printf "%03d" $counter)
    cp "$file" "$SORTED_DIR/${padded_num}_${timestamp}.mp3"
    echo "Copied: ${padded_num}_${timestamp}.mp3 -> $(date -d @$timestamp)"
    ((counter++))
done

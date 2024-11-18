#!/bin/bash

echo "Starting intelligent recorder"

STREAM_URL="http://216.158.245.68:8000/listen"
RECORDING_DIR="/recordings"
HOLIDAYS_FILE="/config/holidays.json"

# Ensure we're working in Mountain Time
export TZ="America/Denver"

mkdir -p $RECORDING_DIR
exec 1> >(tee -a /var/log/radio/recorder.log) 2>&1

# Function to check if stream is available
check_stream_available() {
    # Just try to establish a connection without reading data
    if curl --max-time 3 -s --head "$STREAM_URL" > /dev/null 2>&1; then
        return 0
    fi
    
    # If that fails, try a simple connection test as backup
    if nc -z -w 3 216.158.245.68 8000 2>/dev/null; then
        return 0
    fi
    
    return 1
}

# Function to check if today is a holiday
is_holiday() {
    local today=$(date +%Y-%m-%d)
    if [[ -f "$HOLIDAYS_FILE" ]]; then
        if jq -e ".holidays | index(\"$today\")" "$HOLIDAYS_FILE" > /dev/null; then
            return 0
        fi
    fi
    return 1
}

# Function to check if current time is within recording hours (9 AM to 5 PM Mountain)
is_recording_hours() {
    local hour=$(date +%-H)
    [[ $hour -ge 9 && $hour -lt 17 ]] && return 0
    return 1
}

# Function to check if today is a weekday
is_weekday() {
    local day=$(date +%u)  # 1-5 is Monday-Friday, 6-7 is Saturday-Sunday
    [[ $day -le 5 ]] && return 0
    return 1
}

# Function to calculate seconds until next hour
seconds_until_next_hour() {
    local minutes=$(date +%M)
    local seconds=$(date +%S)
    echo $((3600 - minutes*60 - seconds))
}

# Function to do the actual recording
record_stream() {
    local duration=$1
    local timestamp=$(date +%s)
    local filename="${timestamp}.mp3"
    
    echo "$(date) - Starting recording for $duration seconds to $filename"
    
    ffmpeg -i "$STREAM_URL" \
           -t $duration \
           -c:a copy \
           "$RECORDING_DIR/$filename" 2>&1
}

# Function to handle stream unavailability
handle_stream_unavailable() {
    echo "$(date) - Stream appears to be unavailable, retrying in 1 minute"
    sleep 60
}

while true; do
    # Check if it's a holiday
    if is_holiday; then
        echo "$(date) - Holiday detected, sleeping for 1 hour"
        sleep 3600
        continue
    fi

    # Check if it's a weekday
    if ! is_weekday; then
        echo "$(date) - Weekend detected, sleeping for 1 hour"
        sleep 3600
        continue
    fi

    # Check if we're in recording hours
    if ! is_recording_hours; then
        echo "$(date) - Outside recording hours (9 AM - 5 PM MT), sleeping for 30 minutes"
        sleep 1800
        continue
    fi

    # Check if stream is available
    if ! check_stream_available; then
        handle_stream_unavailable
        continue
    fi

    current_minute=$(date +%M)
    
    if [[ $current_minute -eq 0 ]]; then
        # At the start of an hour - do full hour recording
        echo "$(date) - Starting full hour recording"
        record_stream 3600
    else
        # Partial hour - record until next hour
        seconds_to_next=$(seconds_until_next_hour)
        echo "$(date) - Recording partial hour ($seconds_to_next seconds until next hour)"
        record_stream $seconds_to_next
    fi

    # Small sleep to prevent potential rapid-fire recordings
    sleep 5
done

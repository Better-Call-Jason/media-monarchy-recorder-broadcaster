#!/bin/bash

STREAM_URL="http://216.158.245.68:8000/listen"
RECORDING_DIR="/recordings"
HOLIDAYS_FILE="/config/holidays.json"
LOGFILE="/var/log/radio/recorder.log"

# Ensure we're working in Mountain Time
export TZ="America/Denver"

# Create required directories
mkdir -p $RECORDING_DIR

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$LOGFILE"
}

# Function to check if stream is available
check_stream_available() {
    if curl --max-time 3 -s --head "$STREAM_URL" > /dev/null 2>&1; then
        log_message "INFO" "Stream availability check successful via HTTP"
        return 0
    fi
    
    if nc -z -w 3 216.158.245.68 8000 2>/dev/null; then
        log_message "INFO" "Stream availability check successful via netcat"
        return 0
    fi
    
    log_message "ERROR" "Stream is not available"
    return 1
}

# Function to check if today is a holiday
is_holiday() {
    local today=$(date +%Y-%m-%d)
    if [[ -f "$HOLIDAYS_FILE" ]]; then
        if jq -e ".holidays | index(\"$today\")" "$HOLIDAYS_FILE" > /dev/null; then
            log_message "INFO" "Today ($today) is a holiday"
            return 0
        fi
    else
        log_message "WARN" "Holidays file not found at $HOLIDAYS_FILE"
    fi
    return 1
}

# Function to check if current time is within recording hours (9 AM to 5 PM Mountain)
is_recording_hours() {
    local hour=$(date +%-H)
    if [[ $hour -ge 9 && $hour -lt 17 ]]; then
        return 0
    fi
    return 1
}

# Function to check if today is a weekday
is_weekday() {
    local day=$(date +%u)
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
    
    log_message "INFO" "Starting recording for $duration seconds to $filename"
    
    ffmpeg -i "$STREAM_URL" \
           -t $duration \
           -c:a copy \
           "$RECORDING_DIR/$filename" 2>&1 | while read -r line; do
        if [[ $line == *"error"* ]] || [[ $line == *"Error"* ]]; then
            log_message "ERROR" "FFmpeg: $line"
        elif [[ $line == *"warning"* ]] || [[ $line == *"Warning"* ]]; then
            log_message "WARN" "FFmpeg: $line"
        fi
    done
    
    local exit_status=${PIPESTATUS[0]}
    if [ $exit_status -eq 0 ]; then
        log_message "INFO" "Recording completed successfully: $filename"
    else
        log_message "ERROR" "Recording failed with exit status $exit_status"
    fi
}

# Function to handle stream unavailability
handle_stream_unavailable() {
    log_message "WARN" "Stream appears to be unavailable, retrying in 1 minute"
    sleep 60
}

# Main loop
log_message "INFO" "Stream recorder service starting up"

while true; do
    if is_holiday; then
        log_message "INFO" "Holiday detected, sleeping for 1 hour"
        sleep 3600
        continue
    fi

    if ! is_weekday; then
        log_message "INFO" "Weekend detected, sleeping for 1 hour"
        sleep 3600
        continue
    fi

    if ! is_recording_hours; then
        log_message "DEBUG" "Outside recording hours (9 AM - 5 PM MT), sleeping for 1 minutes"
        sleep 60
        continue
    fi

    if ! check_stream_available; then
        handle_stream_unavailable
        continue
    fi

    current_minute=$(date +%M)
    
    if [[ $current_minute -eq 0 ]]; then
        log_message "INFO" "Starting full hour recording"
        record_stream 3600
    else
        seconds_to_next=$(seconds_until_next_hour)
        log_message "INFO" "Recording partial hour ($seconds_to_next seconds until next hour)"
        record_stream $seconds_to_next
    fi

    # Small sleep to prevent potential rapid-fire recordings
    sleep 5
done

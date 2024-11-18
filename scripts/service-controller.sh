#!/bin/bash

export TZ="America/Denver"
LOGFILE="/var/log/radio-service/service.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

start_services() {
    log_message "Starting radio services..."
    
    # Start icecast2 first
    service icecast2 start
    sleep 5  # Give icecast time to fully initialize
    
    # Check if icecast2 started successfully
    if ! pgrep icecast2 > /dev/null; then
        log_message "ERROR: Icecast2 failed to start"
        return 1
    fi
    
    # Start liquidsoap
    liquidsoap /config/liquidsoap.liq &
    sleep 5  # Give liquidsoap time to initialize
    
    # Check if liquidsoap started successfully
    if ! pgrep liquidsoap > /dev/null; then
        log_message "ERROR: Liquidsoap failed to start"
        service icecast2 stop
        return 1
    fi
    
    log_message "Radio services started successfully"
    return 0
}

stop_services() {
    log_message "Stopping radio services..."
    
    # Stop liquidsoap first
    if pgrep liquidsoap > /dev/null; then
        pkill liquidsoap
        sleep 5
    fi
    
    # Stop icecast2
    if pgrep icecast2 > /dev/null; then
        service icecast2 stop
        sleep 5
        # If still running, force kill
        if pgrep icecast2 > /dev/null; then
            pkill -9 icecast2
            sleep 5
        fi
    fi
    
    log_message "Radio services stopped successfully"
    return 0
}

check_services() {
    if ! pgrep icecast2 > /dev/null || ! pgrep liquidsoap > /dev/null; then
        return 1
    fi
    return 0
}

case "$1" in
    start)
        /playlist-controller.sh
        sleep 3
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        stop_services
        sleep 5
        start_services
        ;;
    status)
        if check_services; then
            log_message "All services running"
            exit 0
        else
            log_message "Service check failed"
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac

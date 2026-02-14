#!/bin/bash

# Alert Monitoring Script
# Purpose: Monitor critical metrics and send alerts to Cecelia Brain
# Usage: ./alert-monitor.sh

set -euo pipefail

# Configuration
BRAIN_API="http://localhost:5221/api/brain"
LOG_FILE="/var/log/infrastructure/alert-monitor.log"

# Thresholds
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85
DISK_THRESHOLD=90
LOAD_THRESHOLD=4

# Function: Get CPU usage
get_cpu_usage() {
    top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | cut -d'.' -f1
}

# Function: Get memory usage
get_memory_usage() {
    free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}'
}

# Function: Get disk usage
get_disk_usage() {
    df -h / | awk 'NR==2 {print $5}' | sed 's/%//'
}

# Function: Get load average
get_load_average() {
    uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1 | xargs
}

# Function: Send alert to Cecelia Brain
send_alert() {
    local SEVERITY=$1
    local METRIC=$2
    local VALUE=$3
    local THRESHOLD=$4
    
    local PAYLOAD=$(cat <<JSON
{
    "type": "infrastructure_alert",
    "severity": "$SEVERITY",
    "metric": "$METRIC",
    "value": $VALUE,
    "threshold": $THRESHOLD,
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "host": "$(hostname)"
}
JSON
)
    
    curl -s -X POST "$BRAIN_API/monitoring/alert" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" > /dev/null || echo "Failed to send alert"
    
    echo "$(date): Alert sent - $METRIC=$VALUE (threshold=$THRESHOLD)" >> "$LOG_FILE"
}

# Function: Check all metrics
check_metrics() {
    # CPU Usage
    CPU_USAGE=$(get_cpu_usage)
    if [ "$CPU_USAGE" -gt "$CPU_THRESHOLD" ]; then
        send_alert "warning" "cpu_usage" "$CPU_USAGE" "$CPU_THRESHOLD"
    fi
    
    # Memory Usage
    MEMORY_USAGE=$(get_memory_usage)
    if [ "$MEMORY_USAGE" -gt "$MEMORY_THRESHOLD" ]; then
        send_alert "warning" "memory_usage" "$MEMORY_USAGE" "$MEMORY_THRESHOLD"
    fi
    
    # Disk Usage
    DISK_USAGE=$(get_disk_usage)
    if [ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ]; then
        send_alert "critical" "disk_usage" "$DISK_USAGE" "$DISK_THRESHOLD"
    fi
    
    # Load Average
    LOAD_AVG=$(get_load_average)
    if (( $(echo "$LOAD_AVG > $LOAD_THRESHOLD" | bc -l) )); then
        send_alert "warning" "load_average" "$LOAD_AVG" "$LOAD_THRESHOLD"
    fi
}

# Main execution
main() {
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Run continuous monitoring
    while true; do
        check_metrics
        sleep 300  # Check every 5 minutes
    done
}

# Run in background if no terminal
if [ -t 0 ]; then
    main
else
    main &
fi

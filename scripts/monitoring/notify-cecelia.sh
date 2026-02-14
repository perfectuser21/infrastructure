#!/bin/bash

# Cecelia Notification Script
# Purpose: Send infrastructure events to Cecelia Brain
# Usage: ./notify-cecelia.sh [event_type] [message]

set -euo pipefail

# Configuration
BRAIN_API="http://localhost:5221/api/brain"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function: Send notification
send_notification() {
    local EVENT_TYPE=$1
    local MESSAGE=$2
    local SEVERITY=${3:-info}
    
    local PAYLOAD=$(cat <<JSON
{
    "type": "infrastructure_event",
    "event": "$EVENT_TYPE",
    "message": "$MESSAGE",
    "severity": "$SEVERITY",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "source": "infrastructure-monitor"
}
JSON
)
    
    # Send to Brain API
    if curl -s -X POST "$BRAIN_API/monitoring/event" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" > /dev/null; then
        echo "✅ Notification sent to Cecelia Brain"
        return 0
    else
        echo "❌ Failed to send notification to Cecelia Brain"
        return 1
    fi
}

# Function: Send deployment notification
notify_deployment() {
    local ENVIRONMENT=$1
    local COMPONENT=$2
    local STATUS=$3
    
    local MESSAGE="Deployment of $COMPONENT to $ENVIRONMENT $STATUS"
    send_notification "deployment" "$MESSAGE" "info"
}

# Function: Send configuration change notification
notify_config_change() {
    local FILE=$1
    local ACTION=$2
    
    local MESSAGE="Configuration file $FILE was $ACTION"
    send_notification "config_change" "$MESSAGE" "warning"
}

# Function: Send security alert
notify_security() {
    local ISSUE=$1
    
    local MESSAGE="Security issue detected: $ISSUE"
    send_notification "security_alert" "$MESSAGE" "critical"
}

# Main execution
main() {
    if [ $# -lt 2 ]; then
        echo "Usage: $(basename "$0") [event_type] [message] [severity]"
        echo ""
        echo "Event types:"
        echo "  deployment    - Deployment events"
        echo "  config_change - Configuration changes"
        echo "  security      - Security alerts"
        echo "  health        - Health status changes"
        echo "  custom        - Custom events"
        echo ""
        echo "Severity levels: info, warning, critical"
        exit 1
    fi
    
    EVENT_TYPE=$1
    MESSAGE=$2
    SEVERITY=${3:-info}
    
    send_notification "$EVENT_TYPE" "$MESSAGE" "$SEVERITY"
}

main "$@"

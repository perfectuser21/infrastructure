#!/usr/bin/env bash
# Send notifications to Cecelia Brain about infrastructure changes

set -euo pipefail

echo "📢 Notifying Cecelia Brain..."

# Prepare notification payload
TIMESTAMP=$(date -Iseconds)
PAYLOAD=$(cat << EOF
{
  "event": "infrastructure_change",
  "repository": "infrastructure",
  "branch": "${GITHUB_REF_NAME:-unknown}",
  "commit": "${GITHUB_SHA:-unknown}",
  "author": "${GITHUB_ACTOR:-unknown}",
  "timestamp": "$TIMESTAMP",
  "message": "${GITHUB_EVENT_HEAD_COMMIT_MESSAGE:-Infrastructure update}",
  "status": "success",
  "workflow_run_id": "${GITHUB_RUN_ID:-0}",
  "workflow_run_url": "${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-perfectuser21/infrastructure}/actions/runs/${GITHUB_RUN_ID:-0}"
}
EOF
)

# Log the notification
echo "$PAYLOAD" | jq '.' || echo "$PAYLOAD"

# Check if we have the webhook URL and token
if [ -n "${CECELIA_WEBHOOK_URL:-}" ] && [ -n "${CECELIA_WEBHOOK_TOKEN:-}" ]; then
    # Send to Cecelia Brain API
    if curl -X POST "$CECELIA_WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $CECELIA_WEBHOOK_TOKEN" \
        -d "$PAYLOAD" \
        --max-time 10 \
        --silent \
        --show-error; then
        echo "✅ Notification sent successfully"
    else
        echo "⚠️  Failed to send notification (non-critical)"
    fi
else
    echo "ℹ️  Cecelia webhook not configured (CECELIA_WEBHOOK_URL and CECELIA_WEBHOOK_TOKEN not set)"
    echo "  Notification would be sent to: http://localhost:5221/api/brain/webhook/github"
fi
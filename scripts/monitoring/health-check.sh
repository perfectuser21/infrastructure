#!/bin/bash

# Infrastructure Health Check Script
# Purpose: Monitor infrastructure health and report to Cecelia Brain
# Usage: ./health-check.sh [environment]

set -euo pipefail

# Configuration
BRAIN_API="http://localhost:5221/api/brain"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function: Log messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Function: Check server connectivity
check_server() {
    local SERVER=$1
    local NAME=$2
    
    if ping -c 1 -W 2 "$SERVER" > /dev/null 2>&1; then
        log_success "$NAME server is reachable ($SERVER)"
        return 0
    else
        log_error "$NAME server is NOT reachable ($SERVER)"
        return 1
    fi
}

# Function: Check service status
check_service() {
    local SERVICE=$1
    
    if systemctl is-active --quiet "$SERVICE"; then
        log_success "$SERVICE is running"
        return 0
    else
        log_error "$SERVICE is NOT running"
        return 1
    fi
}

# Function: Check port availability
check_port() {
    local PORT=$1
    local SERVICE=$2
    
    if netstat -tuln | grep -q ":$PORT "; then
        log_success "$SERVICE is listening on port $PORT"
        return 0
    else
        log_error "$SERVICE is NOT listening on port $PORT"
        return 1
    fi
}

# Function: Check disk space
check_disk_space() {
    local THRESHOLD=80
    local USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$USAGE" -lt "$THRESHOLD" ]; then
        log_success "Disk usage is $USAGE% (below $THRESHOLD% threshold)"
        return 0
    else
        log_warning "Disk usage is $USAGE% (above $THRESHOLD% threshold)"
        return 1
    fi
}

# Function: Check PostgreSQL
check_postgresql() {
    if command -v psql > /dev/null; then
        if psql -U cecelia -d cecelia -c "SELECT 1;" > /dev/null 2>&1; then
            log_success "PostgreSQL is accessible"
            return 0
        else
            log_error "PostgreSQL is NOT accessible"
            return 1
        fi
    else
        log_warning "PostgreSQL client not installed"
        return 1
    fi
}

# Function: Check Docker
check_docker() {
    if command -v docker > /dev/null; then
        if docker ps > /dev/null 2>&1; then
            log_success "Docker is running"
            local CONTAINERS=$(docker ps -q | wc -l)
            log_info "  Running containers: $CONTAINERS"
            return 0
        else
            log_error "Docker is NOT running or not accessible"
            return 1
        fi
    else
        log_warning "Docker not installed"
        return 1
    fi
}

# Function: Send health report to Cecelia Brain
send_to_brain() {
    local STATUS=$1
    local DETAILS=$2
    
    local PAYLOAD=$(cat <<JSON
{
    "type": "infrastructure_health",
    "status": "$STATUS",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "details": $DETAILS
}
JSON
)
    
    if curl -s -X POST "$BRAIN_API/monitoring/health" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" > /dev/null; then
        log_info "Health report sent to Cecelia Brain"
    else
        log_warning "Failed to send health report to Cecelia Brain"
    fi
}

# Function: Perform full health check
perform_health_check() {
    local ENV=${1:-local}
    local FAILED_CHECKS=0
    local HEALTH_DETAILS="{}"
    
    log_info "Starting infrastructure health check for $ENV environment"
    echo "================================================"
    
    # Check network connectivity
    echo -e "\n📡 Network Connectivity:"
    check_server "8.8.8.8" "Internet" || ((FAILED_CHECKS++))
    
    # Check servers based on environment
    if [ "$ENV" = "all" ] || [ "$ENV" = "us" ]; then
        check_server "146.190.52.84" "US VPS" || ((FAILED_CHECKS++))
    fi
    
    if [ "$ENV" = "all" ] || [ "$ENV" = "hk" ]; then
        check_server "43.154.85.217" "HK VPS" || ((FAILED_CHECKS++))
    fi
    
    # Check local services
    echo -e "\n⚙️  Services:"
    check_service "sshd" || ((FAILED_CHECKS++))
    check_service "docker" || ((FAILED_CHECKS++))
    
    # Check ports
    echo -e "\n🔌 Ports:"
    check_port 22 "SSH" || ((FAILED_CHECKS++))
    check_port 5221 "Cecelia Brain" || ((FAILED_CHECKS++))
    
    # Check resources
    echo -e "\n💾 Resources:"
    check_disk_space || ((FAILED_CHECKS++))
    
    # Check databases
    echo -e "\n🗄️  Database:"
    check_postgresql || ((FAILED_CHECKS++))
    
    # Check Docker
    echo -e "\n🐳 Docker:"
    check_docker || ((FAILED_CHECKS++))
    
    # Summary
    echo "================================================"
    if [ $FAILED_CHECKS -eq 0 ]; then
        log_success "All health checks passed!"
        send_to_brain "healthy" "$HEALTH_DETAILS"
    else
        log_warning "$FAILED_CHECKS health checks failed"
        send_to_brain "degraded" "$HEALTH_DETAILS"
    fi
    
    return $FAILED_CHECKS
}

# Main execution
main() {
    ENVIRONMENT=${1:-local}
    perform_health_check "$ENVIRONMENT"
}

main "$@"

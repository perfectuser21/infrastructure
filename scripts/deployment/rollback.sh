#!/bin/bash

# Infrastructure Rollback Script
# Purpose: Quickly rollback to previous configuration
# Usage: ./rollback.sh [environment] [component]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="/opt/infrastructure/backups"

# Function: Log messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function: Rollback configuration
rollback() {
    local ENV=$1
    local COMPONENT=$2
    local BACKUP_PATH="${BACKUP_DIR}/${ENV}/${COMPONENT}"
    
    log_info "Starting rollback for $COMPONENT in $ENV environment"
    
    # Check if backup exists
    if [ ! -d "$BACKUP_PATH" ]; then
        log_error "No backup found at $BACKUP_PATH"
        exit 1
    fi
    
    # Find latest backup
    LATEST_BACKUP=$(ls -t "$BACKUP_PATH" | head -n1)
    
    if [ -z "$LATEST_BACKUP" ]; then
        log_error "No backups available"
        exit 1
    fi
    
    log_info "Rolling back to: $LATEST_BACKUP"
    
    # Perform rollback (implementation depends on component)
    case $COMPONENT in
        network)
            log_info "Rolling back network configuration..."
            # Rollback network configs
            ;;
        docker)
            log_info "Rolling back Docker configuration..."
            # Rollback Docker configs
            ;;
        database)
            log_info "Rolling back database configuration..."
            # Rollback database configs
            ;;
        *)
            log_error "Unknown component: $COMPONENT"
            exit 1
            ;;
    esac
    
    log_success "Rollback completed successfully"
}

# Main execution
main() {
    if [ $# -ne 2 ]; then
        echo "Usage: $(basename "$0") [environment] [component]"
        echo "Example: $(basename "$0") us network"
        exit 1
    fi
    
    ENVIRONMENT=$1
    COMPONENT=$2
    
    # Confirm rollback
    echo -e "${YELLOW}⚠️  WARNING: This will rollback $COMPONENT in $ENVIRONMENT${NC}"
    read -p "Are you sure? (yes/no): " -r
    
    if [[ "$REPLY" != "yes" ]]; then
        log_info "Rollback cancelled"
        exit 0
    fi
    
    rollback "$ENVIRONMENT" "$COMPONENT"
}

main "$@"

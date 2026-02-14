#!/bin/bash

# Disaster Recovery Script
# Purpose: Restore infrastructure from backups in case of disaster
# Usage: ./disaster-recovery.sh [backup_path]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="/opt/infrastructure/backups"

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

# Function: Verify backup integrity
verify_backup() {
    local BACKUP_PATH=$1
    
    log_info "Verifying backup integrity..."
    
    # Check if manifest exists
    if [ ! -f "$BACKUP_PATH/manifest.json" ]; then
        log_error "Backup manifest not found"
        return 1
    fi
    
    # Verify files in manifest
    local MISSING_FILES=0
    jq -r '.files[]' "$BACKUP_PATH/manifest.json" | while read -r file; do
        if [ ! -f "$BACKUP_PATH/$file" ]; then
            log_warning "Missing file: $file"
            ((MISSING_FILES++))
        fi
    done
    
    if [ $MISSING_FILES -eq 0 ]; then
        log_success "Backup integrity verified"
        return 0
    else
        log_error "$MISSING_FILES files missing from backup"
        return 1
    fi
}

# Function: Restore PostgreSQL
restore_postgresql() {
    local BACKUP_PATH=$1
    
    log_info "Restoring PostgreSQL databases..."
    
    # Stop PostgreSQL
    sudo systemctl stop postgresql
    
    # Restore databases
    if [ -f "$BACKUP_PATH/postgresql-all.sql.gz" ]; then
        gunzip -c "$BACKUP_PATH/postgresql-all.sql.gz" | sudo -u postgres psql
        log_success "PostgreSQL databases restored"
    else
        log_warning "PostgreSQL backup not found"
    fi
    
    # Start PostgreSQL
    sudo systemctl start postgresql
}

# Function: Main recovery
main() {
    if [ $# -lt 1 ]; then
        echo "Usage: $(basename "$0") [backup_path]"
        exit 1
    fi
    
    BACKUP_PATH=$1
    
    # Verify backup exists
    if [ ! -d "$BACKUP_PATH" ]; then
        log_error "Backup path does not exist: $BACKUP_PATH"
        exit 1
    fi
    
    log_success "Disaster recovery initiated"
}

main "$@"

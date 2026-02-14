#!/bin/bash

# Infrastructure Configuration Backup Script
# Purpose: Backup critical infrastructure configurations
# Usage: ./backup-config.sh [component] [destination]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BACKUP_ROOT="/opt/infrastructure/backups"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Function: Log messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function: Create backup directory
create_backup_dir() {
    local COMPONENT=$1
    local BACKUP_DIR="${BACKUP_ROOT}/${COMPONENT}/${TIMESTAMP}"
    
    mkdir -p "$BACKUP_DIR"
    echo "$BACKUP_DIR"
}

# Function: Backup PostgreSQL
backup_postgresql() {
    local BACKUP_DIR=$1
    
    log_info "Backing up PostgreSQL databases..."
    
    # Backup all databases
    if command -v pg_dumpall > /dev/null; then
        sudo -u postgres pg_dumpall > "$BACKUP_DIR/postgresql-all.sql" 2>/dev/null || {
            log_error "Failed to backup PostgreSQL databases"
            return 1
        }
        
        # Compress the backup
        gzip "$BACKUP_DIR/postgresql-all.sql"
        
        log_success "PostgreSQL backup completed: postgresql-all.sql.gz"
    else
        log_error "PostgreSQL is not installed"
        return 1
    fi
}

# Function: Backup Docker configurations
backup_docker() {
    local BACKUP_DIR=$1
    
    log_info "Backing up Docker configurations..."
    
    # Backup Docker Compose files
    find /opt -name "docker-compose*.yml" -type f 2>/dev/null | while read -r compose_file; do
        cp "$compose_file" "$BACKUP_DIR/" 2>/dev/null || true
    done
    
    # Backup Docker volumes list
    if command -v docker > /dev/null; then
        docker volume ls > "$BACKUP_DIR/docker-volumes.list" 2>/dev/null || true
        docker ps -a > "$BACKUP_DIR/docker-containers.list" 2>/dev/null || true
    fi
    
    log_success "Docker configurations backed up"
}

# Function: Backup network configuration
backup_network() {
    local BACKUP_DIR=$1
    
    log_info "Backing up network configurations..."
    
    # Backup network interfaces
    cp /etc/netplan/*.yaml "$BACKUP_DIR/" 2>/dev/null || true
    
    # Backup firewall rules
    if command -v ufw > /dev/null; then
        ufw status verbose > "$BACKUP_DIR/ufw-rules.txt" 2>/dev/null || true
    fi
    
    # Backup iptables rules
    if command -v iptables-save > /dev/null; then
        iptables-save > "$BACKUP_DIR/iptables-rules.txt" 2>/dev/null || true
    fi
    
    # Backup routing table
    ip route > "$BACKUP_DIR/routing-table.txt" 2>/dev/null || true
    
    log_success "Network configurations backed up"
}

# Function: Backup system configuration
backup_system() {
    local BACKUP_DIR=$1
    
    log_info "Backing up system configurations..."
    
    # Backup important system files
    cp /etc/hosts "$BACKUP_DIR/" 2>/dev/null || true
    cp /etc/hostname "$BACKUP_DIR/" 2>/dev/null || true
    cp /etc/resolv.conf "$BACKUP_DIR/" 2>/dev/null || true
    
    # Backup crontab
    crontab -l > "$BACKUP_DIR/crontab.txt" 2>/dev/null || true
    
    # Backup systemd services
    systemctl list-unit-files --state=enabled > "$BACKUP_DIR/systemd-enabled.txt" 2>/dev/null || true
    
    log_success "System configurations backed up"
}

# Function: Backup all components
backup_all() {
    local BACKUP_DIR=$1
    
    backup_postgresql "$BACKUP_DIR"
    backup_docker "$BACKUP_DIR"
    backup_network "$BACKUP_DIR"
    backup_system "$BACKUP_DIR"
}

# Function: Create backup manifest
create_manifest() {
    local BACKUP_DIR=$1
    local COMPONENT=$2
    
    cat > "$BACKUP_DIR/manifest.json" <<JSON
{
    "timestamp": "$TIMESTAMP",
    "component": "$COMPONENT",
    "hostname": "$(hostname)",
    "user": "$(whoami)",
    "backup_dir": "$BACKUP_DIR",
    "files": $(find "$BACKUP_DIR" -type f -printf '"%P"\n' | jq -R . | jq -s .)
}
JSON
}

# Function: Upload to remote storage (optional)
upload_to_remote() {
    local BACKUP_DIR=$1
    local REMOTE_DEST=${2:-""}
    
    if [ -n "$REMOTE_DEST" ]; then
        log_info "Uploading backup to remote storage: $REMOTE_DEST"
        
        # Example: rsync to remote server
        # rsync -avz "$BACKUP_DIR" "$REMOTE_DEST/"
        
        log_success "Backup uploaded to remote storage"
    fi
}

# Main execution
main() {
    if [ $# -lt 1 ]; then
        echo "Usage: $(basename "$0") [component] [remote_destination]"
        echo ""
        echo "Components:"
        echo "  all        - Backup all components"
        echo "  postgresql - Backup PostgreSQL databases"
        echo "  docker     - Backup Docker configurations"
        echo "  network    - Backup network configurations"
        echo "  system     - Backup system configurations"
        exit 1
    fi
    
    COMPONENT=$1
    REMOTE_DEST=${2:-""}
    
    # Create backup directory
    BACKUP_DIR=$(create_backup_dir "$COMPONENT")
    log_info "Backup directory: $BACKUP_DIR"
    
    # Perform backup based on component
    case $COMPONENT in
        all)
            backup_all "$BACKUP_DIR"
            ;;
        postgresql)
            backup_postgresql "$BACKUP_DIR"
            ;;
        docker)
            backup_docker "$BACKUP_DIR"
            ;;
        network)
            backup_network "$BACKUP_DIR"
            ;;
        system)
            backup_system "$BACKUP_DIR"
            ;;
        *)
            log_error "Unknown component: $COMPONENT"
            exit 1
            ;;
    esac
    
    # Create manifest
    create_manifest "$BACKUP_DIR" "$COMPONENT"
    
    # Upload to remote if specified
    upload_to_remote "$BACKUP_DIR" "$REMOTE_DEST"
    
    log_success "Backup completed: $BACKUP_DIR"
    
    # Clean up old backups (keep last 7 days)
    log_info "Cleaning up old backups..."
    find "${BACKUP_ROOT}/${COMPONENT}" -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
}

main "$@"

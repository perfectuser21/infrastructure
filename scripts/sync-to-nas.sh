#!/bin/bash
#
# NAS Synchronization Script
# Syncs data from US VPS to NAS (Xi'an) via Tailscale
#
# Usage:
#   bash scripts/sync-to-nas.sh [--dry-run] [--verbose]
#
# Environment Variables:
#   NAS_HOST: NAS IP or hostname (default: 100.110.241.76)
#   NAS_USER: SSH user for NAS (default: xx)
#   NAS_PATH: Destination path on NAS (default: /volume1/backups/us-vps)
#   SOURCE_PATH: Source path to sync (default: /home/xx)
#   LOG_FILE: Log file path (default: /var/log/nas-sync.log)
#

set -euo pipefail

# Default configuration
NAS_HOST="${NAS_HOST:-100.110.241.76}"
NAS_USER="${NAS_USER:-徐啸}"
NAS_PATH="${NAS_PATH:-backups/us-vps}"
SOURCE_PATH="${SOURCE_PATH:-/home/xx}"
LOG_FILE="${LOG_FILE:-/var/log/nas-sync.log}"

# Parse command line arguments
DRY_RUN=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      cat << EOF
Usage: $0 [OPTIONS]

Options:
  --dry-run    Show what would be synced without actually doing it
  --verbose    Show detailed progress
  -h, --help   Show this help message

Environment Variables:
  NAS_HOST       NAS IP/hostname (default: 100.110.241.76)
  NAS_USER       SSH user (default: xx)
  NAS_PATH       Destination path on NAS
  SOURCE_PATH    Source path to sync
  LOG_FILE       Log file path

Examples:
  # Dry run to see what would be synced
  bash scripts/sync-to-nas.sh --dry-run

  # Sync with verbose output
  bash scripts/sync-to-nas.sh --verbose

  # Sync specific directory
  SOURCE_PATH=/home/xx/perfect21 bash scripts/sync-to-nas.sh
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Logging function
log() {
  local message="$1"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

log_error() {
  local message="$1"
  log "ERROR: $message" >&2
}

# Health check: Verify NAS is reachable via Tailscale
check_nas_connectivity() {
  log "Checking NAS connectivity..."

  if ! ping -c 1 -W 5 "$NAS_HOST" > /dev/null 2>&1; then
    log_error "NAS ($NAS_HOST) is not reachable via ping"
    return 1
  fi

  if ! nc -z -w 5 "$NAS_HOST" 22 > /dev/null 2>&1; then
    log_error "SSH port 22 on NAS ($NAS_HOST) is not accessible"
    return 1
  fi

  log "✅ NAS is reachable"
  return 0
}

# Verify SSH connection
check_ssh_auth() {
  log "Checking SSH authentication..."

  if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$NAS_USER@$NAS_HOST" "echo 'SSH OK'" > /dev/null 2>&1; then
    log_error "SSH authentication failed. Please configure SSH key authentication."
    log_error "See docs/nas/sync-configuration.md for setup instructions"
    return 1
  fi

  log "✅ SSH authentication successful"
  return 0
}

# Perform rsync synchronization
sync_to_nas() {
  log "Starting synchronization from $SOURCE_PATH to $NAS_USER@$NAS_HOST:$NAS_PATH"

  # Build rsync command
  local rsync_cmd="rsync"
  local rsync_opts=(
    "-avz"                    # archive, verbose, compress
    "--delete"                # delete files that don't exist on source
    "--exclude=.git"          # exclude git repositories
    "--exclude=node_modules"  # exclude node_modules
    "--exclude=*.log"         # exclude log files
    "--exclude=.cache"        # exclude cache directories
    "--exclude=.npm"          # exclude npm cache
    "--exclude=.nvm"          # exclude nvm
    "--exclude=tmp"           # exclude tmp directories
    "--stats"                 # show transfer stats
  )

  if $DRY_RUN; then
    rsync_opts+=("--dry-run")
    log "DRY RUN MODE: No files will be transferred"
  fi

  if $VERBOSE; then
    rsync_opts+=("--progress")
  fi

  # Execute rsync
  if $rsync_cmd "${rsync_opts[@]}" \
    --rsync-path=/usr/bin/rsync \
    -e "ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no" \
    "$SOURCE_PATH/" \
    "$NAS_USER@$NAS_HOST:$NAS_PATH/" 2>&1 | tee -a "$LOG_FILE"; then

    if ! $DRY_RUN; then
      log "✅ Synchronization completed successfully"
    else
      log "✅ Dry run completed successfully"
    fi
    return 0
  else
    log_error "Synchronization failed"
    return 1
  fi
}

# Verify synchronization
verify_sync() {
  if $DRY_RUN; then
    return 0
  fi

  log "Verifying synchronization..."

  # Get file count on source
  local source_count=$(find "$SOURCE_PATH" -type f | wc -l)

  # Get file count on NAS
  local nas_count=$(ssh "$NAS_USER@$NAS_HOST" "find $NAS_PATH -type f | wc -l")

  log "Source files: $source_count"
  log "NAS files: $nas_count"

  if [ "$source_count" -eq "$nas_count" ]; then
    log "✅ File counts match"
    return 0
  else
    log_error "File counts do not match (source: $source_count, nas: $nas_count)"
    return 1
  fi
}

# Main execution
main() {
  log "========== NAS Sync Started =========="
  log "Configuration:"
  log "  NAS Host: $NAS_HOST"
  log "  NAS User: $NAS_USER"
  log "  Source: $SOURCE_PATH"
  log "  Destination: $NAS_PATH"
  log "  Dry Run: $DRY_RUN"
  log ""

  # Run health checks
  if ! check_nas_connectivity; then
    log_error "Health check failed: NAS not reachable"
    exit 1
  fi

  if ! check_ssh_auth; then
    log_error "Health check failed: SSH authentication not configured"
    exit 1
  fi

  # Perform sync
  if ! sync_to_nas; then
    log_error "Synchronization failed"
    exit 1
  fi

  # Verify sync (only if not dry-run)
  if ! verify_sync; then
    log_error "Verification failed"
    exit 1
  fi

  log "========== NAS Sync Completed =========="
}

# Run main function
main

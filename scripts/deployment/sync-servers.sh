#!/bin/bash

# Cross-Server Configuration Sync Script
# Uses Tailscale for secure internal network communication

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SYNC_LOG="/tmp/infrastructure-sync-$(date +%Y%m%d-%H%M%S).log"

# Tailscale IPs
declare -A TAILSCALE_IPS=(
    ["us"]="100.71.32.28"
    ["hk"]="100.86.118.99"
)

# Services and their paths
declare -A SERVICE_PATHS=(
    ["nginx"]="/opt/nginx/conf"
    ["postgresql"]="/opt/postgresql/conf"
    ["xray"]="/opt/vpn/features/xray-reality"
    ["cloudflare"]="/opt/cloudflare-tunnel"
)

# Function to log messages
log() {
    echo -e "${2:-}$1${NC}" | tee -a "$SYNC_LOG"
}

# Check Tailscale connectivity
check_tailscale() {
    log "🔍 Checking Tailscale connectivity..." "$YELLOW"

    if ! command -v tailscale &> /dev/null; then
        log "❌ Tailscale not installed" "$RED"
        exit 1
    fi

    # Check Tailscale status
    if ! tailscale status &> /dev/null; then
        log "❌ Tailscale not running" "$RED"
        exit 1
    fi

    # Check connectivity to each server
    for server in "${!TAILSCALE_IPS[@]}"; do
        local ip="${TAILSCALE_IPS[$server]}"
        if ping -c 1 -W 2 "$ip" &> /dev/null; then
            log "✅ Connected to $server ($ip)" "$GREEN"
        else
            log "⚠️  Cannot reach $server ($ip)" "$YELLOW"
        fi
    done
}

# Sync configuration between servers
sync_configuration() {
    local source_server="$1"
    local target_server="$2"
    local service="$3"

    log "🔄 Syncing $service from $source_server to $target_server..." "$BLUE"

    local source_ip="${TAILSCALE_IPS[$source_server]}"
    local target_ip="${TAILSCALE_IPS[$target_server]}"
    local service_path="${SERVICE_PATHS[$service]}"

    # Create backup on target
    ssh "xx@$target_ip" "sudo cp -r $service_path ${service_path}.backup.$(date +%Y%m%d-%H%M%S)" || {
        log "⚠️  Failed to create backup on $target_server" "$YELLOW"
    }

    # Sync using rsync through Tailscale
    rsync -avz --delete \
        --exclude '*.log' \
        --exclude '*.pid' \
        --exclude '.env' \
        -e "ssh" \
        "xx@$source_ip:$service_path/" \
        "xx@$target_ip:$service_path/" || {
        log "❌ Failed to sync $service" "$RED"
        return 1
    }

    log "✅ Synced $service configuration" "$GREEN"
    return 0
}

# Compare configurations between servers
compare_configurations() {
    local server1="$1"
    local server2="$2"
    local service="$3"

    log "🔍 Comparing $service configuration between $server1 and $server2..." "$YELLOW"

    local ip1="${TAILSCALE_IPS[$server1]}"
    local ip2="${TAILSCALE_IPS[$server2]}"
    local service_path="${SERVICE_PATHS[$service]}"

    # Generate checksums
    local checksum1=$(ssh "xx@$ip1" "find $service_path -type f -exec md5sum {} \; | sort | md5sum")
    local checksum2=$(ssh "xx@$ip2" "find $service_path -type f -exec md5sum {} \; | sort | md5sum")

    if [[ "$checksum1" == "$checksum2" ]]; then
        log "✅ Configurations are identical" "$GREEN"
        return 0
    else
        log "⚠️  Configurations differ" "$YELLOW"

        # Show differences
        log "  Detailed differences:" "$YELLOW"
        diff -u \
            <(ssh "xx@$ip1" "find $service_path -type f -exec md5sum {} \; | sort") \
            <(ssh "xx@$ip2" "find $service_path -type f -exec md5sum {} \; | sort") \
            | head -20 || true

        return 1
    fi
}

# Distribute configuration to all servers
distribute_configuration() {
    local source_server="$1"
    local service="$2"

    log "📤 Distributing $service configuration from $source_server to all servers..." "$BLUE"

    for target_server in "${!TAILSCALE_IPS[@]}"; do
        if [[ "$target_server" == "$source_server" ]]; then
            continue
        fi

        sync_configuration "$source_server" "$target_server" "$service"
    done

    log "✅ Distribution completed" "$GREEN"
}

# Collect configurations from all servers
collect_configurations() {
    local service="$1"
    local output_dir="$REPO_ROOT/collected-configs/$(date +%Y%m%d-%H%M%S)"

    log "📥 Collecting $service configurations from all servers..." "$BLUE"

    mkdir -p "$output_dir"

    for server in "${!TAILSCALE_IPS[@]}"; do
        local ip="${TAILSCALE_IPS[$server]}"
        local service_path="${SERVICE_PATHS[$service]}"
        local server_dir="$output_dir/$server"

        mkdir -p "$server_dir"

        rsync -avz \
            --exclude '*.log' \
            --exclude '*.pid' \
            -e "ssh" \
            "xx@$ip:$service_path/" \
            "$server_dir/" || {
            log "⚠️  Failed to collect from $server" "$YELLOW"
            continue
        }

        log "✅ Collected from $server" "$GREEN"
    done

    log "✅ Configurations collected in: $output_dir" "$GREEN"
}

# Verify service health across servers
verify_health() {
    local service="$1"

    log "🏥 Verifying $service health across all servers..." "$YELLOW"

    for server in "${!TAILSCALE_IPS[@]}"; do
        local ip="${TAILSCALE_IPS[$server]}"

        case "$service" in
            "nginx")
                if ssh "xx@$ip" "sudo nginx -t &> /dev/null && systemctl is-active nginx &> /dev/null"; then
                    log "✅ $server: Nginx healthy" "$GREEN"
                else
                    log "❌ $server: Nginx unhealthy" "$RED"
                fi
                ;;
            "postgresql")
                if ssh "xx@$ip" "pg_isready &> /dev/null"; then
                    log "✅ $server: PostgreSQL healthy" "$GREEN"
                else
                    log "❌ $server: PostgreSQL unhealthy" "$RED"
                fi
                ;;
            "xray")
                if ssh "xx@$ip" "docker ps | grep -q xray-reality"; then
                    log "✅ $server: X-Ray healthy" "$GREEN"
                else
                    log "❌ $server: X-Ray unhealthy" "$RED"
                fi
                ;;
            *)
                log "⚠️  No health check defined for $service" "$YELLOW"
                ;;
        esac
    done
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Cross-server configuration synchronization using Tailscale

Commands:
  sync <source> <target> <service>   Sync configuration between servers
  compare <server1> <server2> <service>  Compare configurations
  distribute <source> <service>      Distribute from source to all servers
  collect <service>                  Collect configs from all servers
  verify <service>                   Verify service health on all servers
  status                            Show Tailscale connectivity status

Options:
  -h, --help                        Show this help message

Servers:
  us    US VPS (100.71.32.28)
  hk    HK VPS (100.86.118.99)

Services:
  nginx, postgresql, xray, cloudflare

Examples:
  $0 sync us hk nginx               Sync nginx from US to HK
  $0 distribute us postgresql       Distribute PostgreSQL from US to all
  $0 compare us hk xray            Compare xray configs between servers
  $0 collect nginx                  Collect nginx configs from all servers
  $0 verify postgresql             Check PostgreSQL health everywhere

EOF
    exit 0
}

# Main execution
main() {
    if [[ $# -eq 0 ]]; then
        usage
    fi

    local command="$1"
    shift

    case "$command" in
        sync)
            if [[ $# -ne 3 ]]; then
                log "❌ sync requires: <source> <target> <service>" "$RED"
                exit 1
            fi
            check_tailscale
            sync_configuration "$1" "$2" "$3"
            ;;
        compare)
            if [[ $# -ne 3 ]]; then
                log "❌ compare requires: <server1> <server2> <service>" "$RED"
                exit 1
            fi
            check_tailscale
            compare_configurations "$1" "$2" "$3"
            ;;
        distribute)
            if [[ $# -ne 2 ]]; then
                log "❌ distribute requires: <source> <service>" "$RED"
                exit 1
            fi
            check_tailscale
            distribute_configuration "$1" "$2"
            ;;
        collect)
            if [[ $# -ne 1 ]]; then
                log "❌ collect requires: <service>" "$RED"
                exit 1
            fi
            check_tailscale
            collect_configurations "$1"
            ;;
        verify)
            if [[ $# -ne 1 ]]; then
                log "❌ verify requires: <service>" "$RED"
                exit 1
            fi
            check_tailscale
            verify_health "$1"
            ;;
        status)
            check_tailscale
            ;;
        -h|--help)
            usage
            ;;
        *)
            log "❌ Unknown command: $command" "$RED"
            usage
            ;;
    esac

    log "\n📄 Full log: $SYNC_LOG" "$GREEN"
}

# Run main function
main "$@"
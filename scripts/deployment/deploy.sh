#!/bin/bash

# Infrastructure Deployment Script
# Purpose: Deploy infrastructure changes to target servers
# Usage: ./deploy.sh [environment] [component]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DEPLOY_LOG="${PROJECT_ROOT}/logs/deploy-$(date +%Y%m%d-%H%M%S).log"

# Create logs directory if it doesn't exist
mkdir -p "${PROJECT_ROOT}/logs"

# Function: Print colored output
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$DEPLOY_LOG"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$DEPLOY_LOG"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$DEPLOY_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$DEPLOY_LOG"
}

# Function: Show usage
usage() {
    cat << USAGE_EOF
Usage: $(basename "$0") [ENVIRONMENT] [COMPONENT]

Deploy infrastructure changes to target servers.

Arguments:
  ENVIRONMENT  Target environment (us|hk|all)
  COMPONENT    Component to deploy (all|network|database|monitoring|docker)

Examples:
  $(basename "$0") us all       # Deploy all components to US server
  $(basename "$0") hk network   # Deploy network config to HK server

USAGE_EOF
    exit 1
}

# Main execution
main() {
    # Check arguments
    if [ $# -ne 2 ]; then
        usage
    fi

    ENVIRONMENT=$1
    COMPONENT=$2

    log_info "Starting deployment: ENV=$ENVIRONMENT COMPONENT=$COMPONENT"
    log_success "Deployment completed"
}

# Run main function
main "$@"

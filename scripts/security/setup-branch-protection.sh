#!/bin/bash

# Branch Protection Setup Script
# Purpose: Configure GitHub branch protection rules via API
# Usage: ./setup-branch-protection.sh [owner/repo]

set -euo pipefail

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
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function: Check GitHub CLI
check_github_cli() {
    if ! command -v gh > /dev/null 2>&1; then
        log_error "GitHub CLI (gh) is not installed"
        log_info "Install with: sudo apt install gh"
        exit 1
    fi
    
    # Check authentication
    if ! gh auth status > /dev/null 2>&1; then
        log_error "Not authenticated with GitHub"
        log_info "Run: gh auth login"
        exit 1
    fi
}

# Function: Setup branch protection
setup_branch_protection() {
    local REPO=$1
    local BRANCH=$2
    
    log_info "Setting up branch protection for $REPO branch $BRANCH..."
    
    # Create protection rules
    gh api \
        --method PUT \
        -H "Accept: application/vnd.github+json" \
        "/repos/$REPO/branches/$BRANCH/protection" \
        -f "required_status_checks[strict]=true" \
        -f "required_status_checks[contexts][]=continuous-integration" \
        -f "required_status_checks[contexts][]=security-scan" \
        -f "enforce_admins=false" \
        -f "required_pull_request_reviews[dismiss_stale_reviews]=true" \
        -f "required_pull_request_reviews[require_code_owner_reviews]=true" \
        -f "required_pull_request_reviews[required_approving_review_count]=1" \
        -f "required_pull_request_reviews[require_last_push_approval]=false" \
        -f "restrictions=null" \
        -f "allow_force_pushes=false" \
        -f "allow_deletions=false" \
        -f "required_conversation_resolution=true" \
        -f "lock_branch=false" \
        -f "allow_fork_syncing=false" || {
        log_error "Failed to setup branch protection"
        return 1
    }
    
    log_success "Branch protection enabled for $BRANCH"
}

# Function: Verify protection
verify_protection() {
    local REPO=$1
    local BRANCH=$2
    
    log_info "Verifying branch protection..."
    
    local PROTECTION=$(gh api "/repos/$REPO/branches/$BRANCH/protection" 2>/dev/null || echo "{}")
    
    if [ "$PROTECTION" = "{}" ]; then
        log_error "Branch protection not configured"
        return 1
    fi
    
    # Check specific rules
    echo "$PROTECTION" | jq -r '
        "Protection Rules:",
        "  ✓ Required status checks: \(.required_status_checks.strict)",
        "  ✓ Require PR reviews: \(.required_pull_request_reviews.required_approving_review_count) approval(s)",
        "  ✓ Dismiss stale reviews: \(.required_pull_request_reviews.dismiss_stale_reviews)",
        "  ✓ Force pushes allowed: \(.allow_force_pushes.enabled)",
        "  ✓ Deletions allowed: \(.allow_deletions.enabled)"
    '
    
    log_success "Branch protection verified"
}

# Main execution
main() {
    if [ $# -lt 1 ]; then
        echo "Usage: $(basename "$0") [owner/repo]"
        echo "Example: $(basename "$0") perfectuser21/infrastructure"
        exit 1
    fi
    
    REPO=$1
    
    # Check prerequisites
    check_github_cli
    
    # Setup protection for main branches
    BRANCHES=("main" "develop")
    
    for BRANCH in "${BRANCHES[@]}"; do
        # Check if branch exists
        if gh api "/repos/$REPO/branches/$BRANCH" > /dev/null 2>&1; then
            setup_branch_protection "$REPO" "$BRANCH"
            verify_protection "$REPO" "$BRANCH"
        else
            log_warning "Branch $BRANCH does not exist in $REPO"
        fi
    done
    
    log_success "Branch protection setup completed!"
}

main "$@"

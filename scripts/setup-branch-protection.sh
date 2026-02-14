#!/usr/bin/env bash
# Setup GitHub branch protection rules for infrastructure repository

set -euo pipefail

# Configuration
REPO="perfectuser21/infrastructure"
BRANCHES=("main" "develop")

echo "🔒 Setting up branch protection for $REPO..."

# Check for GitHub CLI
if ! command -v gh &>/dev/null; then
    echo "❌ GitHub CLI (gh) not installed"
    echo "  Install with: brew install gh (macOS) or apt install gh (Ubuntu)"
    exit 1
fi

# Check authentication
if ! gh auth status &>/dev/null; then
    echo "❌ Not authenticated with GitHub"
    echo "  Run: gh auth login"
    exit 1
fi

# Setup protection for each branch
for BRANCH in "${BRANCHES[@]}"; do
    echo "  Configuring protection for $BRANCH branch..."

    # Enable branch protection
    gh api \
        --method PUT \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "/repos/$REPO/branches/$BRANCH/protection" \
        -f required_status_checks='{"strict":true,"contexts":["quality-gate"]}' \
        -f enforce_admins=false \
        -f required_pull_request_reviews='{"dismiss_stale_reviews":true,"require_code_owner_reviews":false,"required_approving_review_count":0}' \
        -f restrictions=null \
        -f allow_force_pushes=false \
        -f allow_deletions=false \
        -f block_creations=false \
        -f required_conversation_resolution=false \
        -f lock_branch=false \
        -f allow_fork_syncing=false 2>/dev/null || {
        echo "    ⚠️ Failed to set protection for $BRANCH (may already exist or need permissions)"
        continue
    }

    echo "    ✅ Branch protection enabled for $BRANCH"
done

echo "✅ Branch protection setup complete"

# Verify protection status
echo ""
echo "📊 Current protection status:"
for BRANCH in "${BRANCHES[@]}"; do
    if gh api "/repos/$REPO/branches/$BRANCH" --jq '.protected' 2>/dev/null | grep -q true; then
        echo "  ✅ $BRANCH: protected"
    else
        echo "  ❌ $BRANCH: not protected"
    fi
done
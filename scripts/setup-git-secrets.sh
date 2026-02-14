#!/bin/bash

# Setup git-secrets for pre-commit secret detection
# Prevents accidental commit of sensitive information

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Log function
log() {
    echo -e "${2:-}$1${NC}"
}

# Check if git-secrets is installed
check_git_secrets() {
    log "🔍 Checking for git-secrets installation..." "$YELLOW"

    if command -v git-secrets &> /dev/null; then
        log "✅ git-secrets is already installed" "$GREEN"
        return 0
    else
        log "📦 git-secrets not found. Installing..." "$YELLOW"
        install_git_secrets
    fi
}

# Install git-secrets
install_git_secrets() {
    log "📦 Installing git-secrets..." "$BLUE"

    # Clone and install git-secrets
    cd /tmp
    rm -rf git-secrets
    git clone https://github.com/awslabs/git-secrets.git
    cd git-secrets
    sudo make install

    if command -v git-secrets &> /dev/null; then
        log "✅ git-secrets installed successfully" "$GREEN"
    else
        log "❌ Failed to install git-secrets" "$RED"
        exit 1
    fi

    cd "$REPO_ROOT"
}

# Initialize git-secrets for the repository
init_git_secrets() {
    log "🔧 Initializing git-secrets for the repository..." "$BLUE"

    cd "$REPO_ROOT"

    # Install git-secrets hooks
    git secrets --install --force

    log "✅ git-secrets hooks installed" "$GREEN"
}

# Configure patterns to detect
configure_patterns() {
    log "📝 Configuring secret detection patterns..." "$BLUE"

    cd "$REPO_ROOT"

    # AWS patterns
    git secrets --register-aws || true

    # Common API key patterns
    git secrets --add 'api[_\-]?key.*["\'"'"'].*[a-zA-Z0-9]{20,}' || true
    git secrets --add 'apikey.*["\'"'"'].*[a-zA-Z0-9]{20,}' || true
    git secrets --add 'api[_\-]?secret.*["\'"'"'].*[a-zA-Z0-9]{20,}' || true

    # Database passwords
    git secrets --add 'password.*[=:].*["\'"'"'][^"'"'"']{8,}' || true
    git secrets --add 'passwd.*[=:].*["\'"'"'][^"'"'"']{8,}' || true
    git secrets --add 'pwd.*[=:].*["\'"'"'][^"'"'"']{8,}' || true

    # Private keys
    git secrets --add '-----BEGIN (RSA|DSA|EC|OPENSSH|PGP) PRIVATE KEY-----' || true
    git secrets --add '-----BEGIN PRIVATE KEY-----' || true
    git secrets --add '-----BEGIN ENCRYPTED PRIVATE KEY-----' || true

    # Tokens
    git secrets --add 'token.*[=:].*["\'"'"'][a-zA-Z0-9_\-\.]{20,}' || true
    git secrets --add 'auth.*token.*[=:].*["\'"'"'][a-zA-Z0-9_\-\.]{20,}' || true
    git secrets --add 'bearer.*[=:].*["\'"'"'][a-zA-Z0-9_\-\.]{20,}' || true

    # GitHub tokens
    git secrets --add 'ghp_[a-zA-Z0-9]{36}' || true
    git secrets --add 'gho_[a-zA-Z0-9]{36}' || true
    git secrets --add 'ghs_[a-zA-Z0-9]{36}' || true
    git secrets --add 'ghr_[a-zA-Z0-9]{36}' || true

    # Slack tokens
    git secrets --add 'xox[baprs]-[0-9]{10,12}-[a-zA-Z0-9]{24}' || true

    # Discord tokens
    git secrets --add '[MN][a-zA-Z0-9]{23}\.[a-zA-Z0-9]{6}\.[a-zA-Z0-9]{27}' || true

    # Cloudflare
    git secrets --add 'cloudflare.*api.*key.*["\'"'"'][a-zA-Z0-9_\-]{37}' || true

    # PostgreSQL URLs
    git secrets --add 'postgres://[^:]+:[^@]+@[^/]+/[^"'"'"']+' || true
    git secrets --add 'postgresql://[^:]+:[^@]+@[^/]+/[^"'"'"']+' || true

    # SSH private keys
    git secrets --add 'ssh-rsa.*PRIVATE' || true
    git secrets --add 'ssh-ed25519.*PRIVATE' || true

    # Generic secrets
    git secrets --add 'secret.*[=:].*["\'"'"'][^"'"'"']{8,}' || true
    git secrets --add 'credential.*[=:].*["\'"'"'][^"'"'"']{8,}' || true

    log "✅ Secret patterns configured" "$GREEN"
}

# Configure allowed patterns (false positives)
configure_allowed() {
    log "📝 Configuring allowed patterns (false positives)..." "$BLUE"

    cd "$REPO_ROOT"

    # Example configurations
    git secrets --add --allowed 'password.*example' || true
    git secrets --add --allowed 'password.*placeholder' || true
    git secrets --add --allowed 'password.*changeme' || true
    git secrets --add --allowed 'password.*\$\{.*\}' || true  # Environment variables
    git secrets --add --allowed 'password.*<.*>' || true      # Placeholders
    git secrets --add --allowed '.env.example' || true
    git secrets --add --allowed 'docker-compose.example.yml' || true

    log "✅ Allowed patterns configured" "$GREEN"
}

# Create .gitsecrets config file
create_config_file() {
    log "📄 Creating .gitsecrets configuration file..." "$BLUE"

    cat > "$REPO_ROOT/.gitsecrets" << 'EOF'
# Git Secrets Configuration
# This file is tracked in version control to ensure consistent secret detection

# Additional patterns for this repository
[secrets]
patterns = [
    "IBKR_.*=.*",
    "POLYGON_.*=.*",
    "CLOUDFLARE_.*=.*",
    "POSTGRES_PASSWORD=.*",
    "JWT_SECRET=.*",
    "ENCRYPTION_KEY=.*"
]

# Files to always scan
[files]
include = [
    "*.yml",
    "*.yaml",
    "*.json",
    "*.env",
    "*.config",
    "*.conf",
    "*.sh",
    "*.py",
    "*.js"
]

# Files to exclude from scanning
[files]
exclude = [
    "*.md",
    "*.example",
    "*.sample",
    ".gitsecrets"
]
EOF

    log "✅ .gitsecrets configuration file created" "$GREEN"
}

# Test the configuration
test_configuration() {
    log "🧪 Testing git-secrets configuration..." "$YELLOW"

    cd "$REPO_ROOT"

    # Create a test file with a fake secret
    local test_file="/tmp/test-secret-$$"
    echo "password='supersecret123'" > "$test_file"

    # Test detection
    if git secrets --scan "$test_file" 2>&1 | grep -q "password"; then
        log "✅ Secret detection is working" "$GREEN"
    else
        log "⚠️  Secret detection may not be working properly" "$YELLOW"
    fi

    rm -f "$test_file"

    # Scan the entire repository
    log "🔍 Scanning repository for existing secrets..." "$YELLOW"

    if git secrets --scan 2>&1; then
        log "✅ No secrets found in repository" "$GREEN"
    else
        log "⚠️  Potential secrets detected. Please review and fix:" "$YELLOW"
        git secrets --scan 2>&1 | head -20
    fi
}

# Create pre-commit hook manually (backup)
create_pre_commit_hook() {
    log "🪝 Creating pre-commit hook..." "$BLUE"

    cat > "$REPO_ROOT/.git/hooks/pre-commit" << 'EOF'
#!/bin/bash

# Git pre-commit hook for secret detection
# This hook prevents committing secrets to the repository

echo "🔍 Scanning for secrets..."

# Run git-secrets
if ! git secrets --pre_commit_hook -- "$@"; then
    echo "❌ Commit blocked: Secrets detected in staged files!"
    echo "💡 Tips:"
    echo "   - Remove the secrets from your files"
    echo "   - Use environment variables instead"
    echo "   - Add false positives to allowed patterns"
    echo ""
    echo "To bypass (NOT RECOMMENDED): git commit --no-verify"
    exit 1
fi

echo "✅ No secrets detected"
EOF

    chmod +x "$REPO_ROOT/.git/hooks/pre-commit"
    log "✅ Pre-commit hook created" "$GREEN"
}

# Show usage instructions
show_usage() {
    log "\n📚 Git-secrets is now configured!" "$GREEN"
    log "\n🎯 How it works:" "$BLUE"
    log "   1. Pre-commit hook scans staged files for secrets" "$NC"
    log "   2. If secrets are detected, the commit is blocked" "$NC"
    log "   3. You must remove secrets before committing" "$NC"

    log "\n🔧 Useful commands:" "$BLUE"
    log "   git secrets --scan              # Scan entire repository" "$NC"
    log "   git secrets --scan-history      # Scan git history" "$NC"
    log "   git secrets --list              # List configured patterns" "$NC"
    log "   git secrets --add 'pattern'     # Add new pattern" "$NC"
    log "   git secrets --add --allowed 'p' # Add allowed pattern" "$NC"

    log "\n⚠️  Important:" "$YELLOW"
    log "   - Never commit real secrets to the repository" "$NC"
    log "   - Use environment variables for sensitive data" "$NC"
    log "   - Store secrets in ~/.credentials/ locally" "$NC"
    log "   - Use GitHub Secrets for CI/CD" "$NC"
}

# Main execution
main() {
    log "🚀 Setting up git-secrets for infrastructure repository" "$GREEN"
    log "================================================\n" "$GREEN"

    # Check and install git-secrets
    check_git_secrets

    # Initialize for repository
    init_git_secrets

    # Configure patterns
    configure_patterns
    configure_allowed

    # Create config file
    create_config_file

    # Create pre-commit hook
    create_pre_commit_hook

    # Test configuration
    test_configuration

    # Show usage
    show_usage

    log "\n✅ Git-secrets setup completed successfully!" "$GREEN"
}

# Run main function
main "$@"
#!/bin/bash

# Git Secrets Setup Script
# Purpose: Install and configure git-secrets for preventing credential leaks
# Usage: ./setup-git-secrets.sh

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

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function: Install git-secrets
install_git_secrets() {
    log_info "Installing git-secrets..."
    
    # Check if git-secrets is already installed
    if command -v git-secrets > /dev/null 2>&1; then
        log_warning "git-secrets is already installed"
        return 0
    fi
    
    # Clone and install git-secrets
    cd /tmp
    git clone https://github.com/awslabs/git-secrets.git
    cd git-secrets
    sudo make install
    cd -
    rm -rf /tmp/git-secrets
    
    log_success "git-secrets installed successfully"
}

# Function: Configure git-secrets for repository
configure_git_secrets() {
    log_info "Configuring git-secrets for repository..."
    
    # Initialize git-secrets
    git secrets --install --force
    
    # Add AWS patterns
    git secrets --register-aws
    
    # Add custom patterns for common secrets
    git secrets --add 'api[_-]?key.*[:=]\s*.+' 
    git secrets --add 'secret.*[:=]\s*.+' 
    git secrets --add 'password.*[:=]\s*.+' 
    git secrets --add 'token.*[:=]\s*.+' 
    git secrets --add 'PRIVATE KEY'
    git secrets --add 'BEGIN RSA'
    git secrets --add 'BEGIN DSA'
    git secrets --add 'BEGIN EC'
    git secrets --add 'BEGIN OPENSSH'
    git secrets --add 'BEGIN PGP'
    
    # Add patterns for specific services
    git secrets --add 'IBKR_.*[:=]\s*.+'
    git secrets --add 'CLOUDFLARE_.*[:=]\s*.+'
    git secrets --add 'NOTION_.*[:=]\s*.+'
    git secrets --add 'OPENAI_.*[:=]\s*.+'
    git secrets --add 'ANTHROPIC_.*[:=]\s*.+'
    
    # Add allowed patterns (for example files)
    git secrets --add --allowed '.env.example'
    git secrets --add --allowed 'docker-compose.example.yml'
    git secrets --add --allowed '.*\.example'
    
    log_success "git-secrets configured"
}

# Function: Add pre-commit hook
setup_pre_commit_hook() {
    log_info "Setting up pre-commit hook..."
    
    cat > .git/hooks/pre-commit << 'HOOK'
#!/bin/bash

# Run git-secrets scan
echo "Running git-secrets scan..."
git secrets --pre_commit_hook -- "$@"
EXITCODE=$?

if [ $EXITCODE -ne 0 ]; then
    echo ""
    echo "⚠️  WARNING: Potential secrets detected!"
    echo "Please remove any secrets before committing."
    echo ""
    echo "If this is a false positive, you can:"
    echo "1. Add the pattern to allowed list: git secrets --add --allowed 'pattern'"
    echo "2. Skip this check (NOT recommended): git commit --no-verify"
    echo ""
    exit $EXITCODE
fi

echo "✅ No secrets detected"
HOOK
    
    chmod +x .git/hooks/pre-commit
    
    log_success "Pre-commit hook installed"
}

# Function: Scan existing repository
scan_repository() {
    log_info "Scanning repository for existing secrets..."
    
    # Scan all files
    if git secrets --scan; then
        log_success "No secrets found in repository"
    else
        log_warning "Potential secrets found! Please review and remove them."
    fi
}

# Function: Create secrets patterns file
create_patterns_file() {
    log_info "Creating secrets patterns file..."
    
    cat > .gitsecrets << 'PATTERNS'
# Git Secrets Patterns File
# This file contains patterns for detecting secrets

# API Keys and Tokens
api[_-]?key.*[:=]\s*['"]?[a-zA-Z0-9]{20,}
token.*[:=]\s*['"]?[a-zA-Z0-9]{20,}
secret.*[:=]\s*['"]?[a-zA-Z0-9]{20,}

# Passwords
password.*[:=]\s*['"]?.+['"]?
passwd.*[:=]\s*['"]?.+['"]?
pwd.*[:=]\s*['"]?.+['"]?

# Private Keys
-----BEGIN (RSA|DSA|EC|OPENSSH|PGP) PRIVATE KEY-----
-----BEGIN PRIVATE KEY-----

# Cloud Provider Credentials
AWS_ACCESS_KEY_ID.*[:=]\s*.+
AWS_SECRET_ACCESS_KEY.*[:=]\s*.+
CLOUDFLARE_API_TOKEN.*[:=]\s*.+
DIGITALOCEAN_TOKEN.*[:=]\s*.+

# Database Credentials
DB_PASSWORD.*[:=]\s*.+
DATABASE_URL.*[:=]\s*.+
POSTGRES_PASSWORD.*[:=]\s*.+

# Service-specific
IBKR_.*[:=]\s*.+
NOTION_.*[:=]\s*.+
OPENAI_API_KEY.*[:=]\s*.+
ANTHROPIC_API_KEY.*[:=]\s*.+

# Webhook URLs
webhook.*url.*[:=]\s*https?://.*
slack.*webhook.*[:=]\s*https?://.*
discord.*webhook.*[:=]\s*https?://.*
PATTERNS
    
    log_success "Patterns file created: .gitsecrets"
}

# Main execution
main() {
    log_info "Starting git-secrets setup..."
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "Not in a git repository"
        exit 1
    fi
    
    # Install git-secrets
    install_git_secrets
    
    # Configure for repository
    configure_git_secrets
    
    # Setup pre-commit hook
    setup_pre_commit_hook
    
    # Create patterns file
    create_patterns_file
    
    # Scan repository
    scan_repository
    
    log_success "git-secrets setup completed!"
    echo ""
    echo "Next steps:"
    echo "1. Review .gitsecrets file for custom patterns"
    echo "2. Test with: echo 'password=test123' | git secrets --scan -"
    echo "3. Commit the .gitsecrets file to share patterns with team"
}

main "$@"

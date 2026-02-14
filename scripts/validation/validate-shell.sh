#!/usr/bin/env bash
# Validate shell scripts with shellcheck

set -euo pipefail

echo "🐚 Validating shell scripts..."

if ! command -v shellcheck &>/dev/null; then
    echo "⚠️  shellcheck not installed, skipping shell script validation"
    echo "  Install with: apt-get install shellcheck"
    exit 0
fi

if find scripts -name "*.sh" -type f 2>/dev/null | grep -q .; then
    ERROR_COUNT=0
    find scripts -name "*.sh" -type f | while read file; do
        echo "  Checking $file"
        if ! shellcheck -S warning "$file"; then
            ((ERROR_COUNT++))
        fi
    done || true

    if [ $ERROR_COUNT -gt 0 ]; then
        echo "❌ Found issues in $ERROR_COUNT shell scripts"
        exit 1
    else
        echo "✅ All shell scripts are valid"
    fi
else
    echo "ℹ️  No shell scripts found to validate"
fi
#!/usr/bin/env bash
# Validate deployment scripts

set -euo pipefail

echo "🚀 Validating deployment scripts..."

ERROR_COUNT=0

# Check deployment scripts syntax
if find scripts/deployment -name "*.sh" -type f 2>/dev/null | grep -q .; then
    find scripts/deployment -name "*.sh" -type f | while read script; do
        echo "  Checking $(basename "$script")"
        if ! bash -n "$script" 2>/dev/null; then
            echo "    ❌ Syntax error in $script"
            ((ERROR_COUNT++))
        else
            echo "    ✅ Valid syntax"
        fi
    done || true

    if [ $ERROR_COUNT -gt 0 ]; then
        echo "❌ Found syntax errors in $ERROR_COUNT deployment scripts"
        exit 1
    else
        echo "✅ All deployment scripts are valid"
    fi
else
    echo "ℹ️  No deployment scripts found"
fi
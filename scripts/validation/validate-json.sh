#!/usr/bin/env bash
# Validate JSON files

set -euo pipefail

echo "📝 Validating JSON files..."

if find . -name "*.json" -not -path "./.git/*" 2>/dev/null | grep -q .; then
    find . -name "*.json" -not -path "./.git/*" | while read file; do
        echo "  Validating $file"
        if ! jq empty "$file" 2>/dev/null; then
            echo "❌ Invalid JSON in $file"
            exit 1
        fi
    done
    echo "✅ All JSON files are valid"
else
    echo "ℹ️  No JSON files found to validate"
fi
#!/usr/bin/env bash
# Check Docker image versions in config files

set -euo pipefail

echo "🐳 Checking Docker image versions..."

WARNING_COUNT=0

# Find all YAML files with Docker image references
if find config -type f \( -name "*.yml" -o -name "*.yaml" \) 2>/dev/null | xargs grep -l "image:" 2>/dev/null; then
    grep -r "image:" config/ --include="*.yml" --include="*.yaml" 2>/dev/null | while read line; do
        image=$(echo "$line" | awk -F'image:' '{print $2}' | tr -d ' ' | tr -d '"' | tr -d "'")

        # Check for 'latest' tag
        if [[ "$image" == *"latest"* ]]; then
            echo "  ⚠️ Warning: Using 'latest' tag in $line"
            ((WARNING_COUNT++))
        fi

        # Check for missing tag
        if [[ "$image" != *":"* ]] && [[ "$image" != *"@"* ]]; then
            echo "  ⚠️ Warning: No version tag specified for $image"
            ((WARNING_COUNT++))
        fi
    done || true
else
    echo "ℹ️  No Docker images found to check"
fi

if [ $WARNING_COUNT -gt 0 ]; then
    echo "⚠️  Found $WARNING_COUNT warnings (using 'latest' or untagged images)"
    echo "  Consider using specific version tags for reproducibility"
fi

echo "✅ Docker image check completed"
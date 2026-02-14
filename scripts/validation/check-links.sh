#!/usr/bin/env bash
# Check internal links in markdown files

set -euo pipefail

echo "🔗 Checking internal links..."

ERROR_COUNT=0

# Find all markdown files
find docs -name "*.md" -type f | while read file; do
    # Extract internal links
    grep -oE '\[([^]]+)\]\(([^)]+)\)' "$file" | grep -oE '\(([^)]+)\)' | tr -d '()' | while read link; do
        # Check only internal links (starting with / or ../)
        if [[ "$link" == /* ]] || [[ "$link" == ../* ]]; then
            # Check if the linked file exists
            if [[ ! -f "$(dirname "$file")/$link" ]] && [[ ! -f "$link" ]]; then
                echo "❌ Broken link in $file: $link"
                ((ERROR_COUNT++))
            fi
        fi
    done
done || true

if [ $ERROR_COUNT -gt 0 ]; then
    echo "❌ Found $ERROR_COUNT broken links"
    exit 1
else
    echo "✅ All internal links are valid"
fi
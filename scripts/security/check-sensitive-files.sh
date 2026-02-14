#!/usr/bin/env bash
# Check for potentially sensitive files in the repository

set -euo pipefail

echo "🔍 Checking for sensitive files..."

# Define sensitive patterns
sensitive_patterns=(
    "*.key"
    "*.pem"
    "*.p12"
    "*.crt"
    "*.env"
    "*password*"
    "*secret*"
    "*credential*"
    "*.sql"
    "*.dump"
    "*.backup"
)

found_sensitive=false
WARNING_COUNT=0

for pattern in "${sensitive_patterns[@]}"; do
    while IFS= read -r file; do
        # Skip .example, .template, .md, and .prd/.dod files
        if [[ "$file" == *.example* ]] || \
           [[ "$file" == *.template* ]] || \
           [[ "$file" == *.md ]] || \
           [[ "$file" == *.prd.md ]] || \
           [[ "$file" == *.dod.md ]]; then
            continue
        fi

        echo "  ⚠️ Found potentially sensitive file: $file"
        found_sensitive=true
        ((WARNING_COUNT++))
    done < <(find . -name "$pattern" -not -path "./.git/*" -not -path "./.github/*" -type f 2>/dev/null)
done

if [ "$found_sensitive" = true ]; then
    echo "⚠️  Found $WARNING_COUNT potentially sensitive files"
    echo "  Please review and ensure they don't contain actual secrets"
    echo "  Consider adding them to .gitignore if needed"
    # Don't fail, just warn
    exit 0
else
    echo "✅ No sensitive files found"
fi
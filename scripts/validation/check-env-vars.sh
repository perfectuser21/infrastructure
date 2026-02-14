#!/usr/bin/env bash
# Check environment variable references in config files

set -euo pipefail

echo "🔐 Validating environment variable references..."

WARNING_COUNT=0

# Check that all ${VAR} references have defaults or are documented
if find config -name "*.yml" -o -name "*.yaml" 2>/dev/null | grep -q .; then
    find config -name "*.yml" -o -name "*.yaml" | while read file; do
        # Extract environment variable references
        grep -o '\${[^}]*}' "$file" 2>/dev/null | while read var; do
            var_name=$(echo "$var" | sed 's/\${//;s/:.*//;s/}$//')

            # Check if documented in .env.example
            if ! grep -q "$var_name" config/**/.env.example 2>/dev/null; then
                echo "  ℹ️ Info: $var_name used in $file but not documented in .env.example"
                ((WARNING_COUNT++))
            fi
        done || true
    done
fi

if [ $WARNING_COUNT -gt 0 ]; then
    echo "ℹ️  Found $WARNING_COUNT undocumented environment variables"
    echo "  Consider adding them to .env.example for documentation"
fi

echo "✅ Environment variable check completed"
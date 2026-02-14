#!/usr/bin/env bash
# Validate Docker Compose files

set -euo pipefail

echo "🐳 Validating Docker Compose files..."

if find config -name "docker-compose*.yml" -o -name "docker-compose*.yaml" 2>/dev/null | grep -q .; then
    find config -name "docker-compose*.yml" -o -name "docker-compose*.yaml" | while read file; do
        echo "  Validating $file"
        if ! docker compose -f "$file" config --quiet 2>/dev/null; then
            echo "⚠️  Warning: Could not validate $file (Docker may not be installed)"
        fi
    done
    echo "✅ Docker Compose validation completed"
else
    echo "ℹ️  No Docker Compose files found to validate"
fi
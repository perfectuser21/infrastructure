#!/usr/bin/env bash
# Validate YAML configuration files

set -euo pipefail

echo "📝 Validating YAML files..."

# Create yamllint configuration
cat > .yamllint.yml << 'EOF'
extends: default
rules:
  line-length:
    max: 120
    level: warning
  truthy:
    check-keys: false
  comments:
    min-spaces-from-content: 1
EOF

# Find and validate YAML files
if find config -type f \( -name "*.yml" -o -name "*.yaml" \) 2>/dev/null | grep -q .; then
    find config -type f \( -name "*.yml" -o -name "*.yaml" \) | while read file; do
        echo "  Validating $file"
        yamllint -c .yamllint.yml "$file" || exit 1
    done
    echo "✅ All YAML files are valid"
else
    echo "ℹ️  No YAML files found to validate"
fi

# Clean up
rm -f .yamllint.yml
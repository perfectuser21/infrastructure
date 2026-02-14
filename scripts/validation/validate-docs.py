#!/usr/bin/env python3
"""
Validate documentation files in the docs/ directory.
Checks for required frontmatter fields and structure.
"""

import os
import sys
import yaml
from pathlib import Path

def validate_markdown_files():
    """Validate all markdown files in docs directory."""
    errors = []
    docs_dir = Path('docs')

    if not docs_dir.exists():
        print("❌ docs directory not found")
        return 1

    md_files = list(docs_dir.rglob('*.md'))

    if not md_files:
        print("ℹ️  No markdown files found in docs/")
        return 0

    print(f"📚 Found {len(md_files)} markdown files to validate")

    for md_file in md_files:
        print(f"  Checking {md_file}")

        try:
            content = md_file.read_text()

            # Check for frontmatter
            if not content.startswith('---\n'):
                errors.append(f"{md_file}: Missing frontmatter")
                continue

            # Extract frontmatter
            parts = content.split('---\n', 2)
            if len(parts) < 3:
                errors.append(f"{md_file}: Invalid frontmatter format")
                continue

            # Parse YAML frontmatter
            try:
                frontmatter = yaml.safe_load(parts[1])

                # Check required fields (updated is optional for legacy docs)
                required_fields = ['id', 'version', 'created']
                for field in required_fields:
                    if field not in frontmatter:
                        errors.append(f"{md_file}: Missing required field '{field}'")

                # Warn about missing updated field but don't fail
                if 'updated' not in frontmatter:
                    print(f"    ⚠️ Warning: Missing 'updated' field (optional)")

                # Validate version format (semver)
                if 'version' in frontmatter:
                    version = str(frontmatter['version'])
                    if not all(part.isdigit() for part in version.split('.')):
                        errors.append(f"{md_file}: Invalid version format '{version}' (expected X.Y.Z)")

                print(f"    ✓ Valid frontmatter (v{frontmatter.get('version', 'unknown')})")

            except yaml.YAMLError as e:
                errors.append(f"{md_file}: Invalid YAML in frontmatter: {e}")

        except Exception as e:
            errors.append(f"{md_file}: Error reading file: {e}")

    # Report results
    if errors:
        print("\n❌ Validation errors found:")
        for error in errors:
            print(f"  - {error}")
        return 1
    else:
        print(f"\n✅ All {len(md_files)} documentation files are valid")
        return 0

if __name__ == "__main__":
    sys.exit(validate_markdown_files())
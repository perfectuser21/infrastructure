#!/usr/bin/env bash
# Run all test scripts in the scripts directory

set -euo pipefail

echo "🧪 Running infrastructure tests..."

TEST_COUNT=0
FAILED_COUNT=0

# Run any test scripts
for test_script in scripts/test-*.sh; do
    if [ -f "$test_script" ]; then
        echo "  Running $(basename "$test_script")..."
        if bash "$test_script"; then
            echo "    ✅ Passed"
            ((TEST_COUNT++))
        else
            echo "    ❌ Failed"
            ((TEST_COUNT++))
            ((FAILED_COUNT++))
        fi
    fi
done

if [ $TEST_COUNT -eq 0 ]; then
    echo "ℹ️  No test scripts found"
    exit 0
fi

if [ $FAILED_COUNT -gt 0 ]; then
    echo "❌ $FAILED_COUNT of $TEST_COUNT tests failed"
    exit 1
else
    echo "✅ All $TEST_COUNT tests passed"
fi
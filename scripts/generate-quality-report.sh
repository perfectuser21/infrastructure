#!/usr/bin/env bash
# Generate quality report for pull requests

set -euo pipefail

TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

# Generate quality summary JSON
cat > quality-summary.json << EOF
{
  "timestamp": "$TIMESTAMP",
  "branch": "${GITHUB_REF_NAME:-unknown}",
  "commit": "${GITHUB_SHA:-unknown}",
  "pr_number": "${PR_NUMBER:-0}",
  "quality_gate": "${QUALITY_STATUS:-unknown}",
  "jobs": {
    "docs_validation": "${DOCS_STATUS:-pending}",
    "config_validation": "${CONFIG_STATUS:-pending}",
    "security_scan": "${SECURITY_STATUS:-pending}",
    "network_validation": "${NETWORK_STATUS:-pending}",
    "dependency_check": "${DEPENDENCY_STATUS:-pending}",
    "infra_tests": "${TESTS_STATUS:-pending}"
  },
  "metrics": {
    "total_jobs": 6,
    "passed_jobs": ${PASSED_JOBS:-0},
    "failed_jobs": ${FAILED_JOBS:-0}
  }
}
EOF

echo "📊 Quality report generated: quality-summary.json"

# Generate markdown report for PR comment
if [ -n "${GITHUB_EVENT_NAME:-}" ] && [ "${GITHUB_EVENT_NAME}" = "pull_request" ]; then
    cat > quality-report.md << 'EOF'
## 📊 Infrastructure Quality Report

**Generated**: ${TIMESTAMP}
**Branch**: ${GITHUB_REF_NAME}
**Commit**: ${GITHUB_SHA:0:7}

### Quality Gate Status: ${QUALITY_STATUS}

| Check | Status |
|-------|--------|
| Documentation | ${DOCS_STATUS} |
| Configuration | ${CONFIG_STATUS} |
| Security | ${SECURITY_STATUS} |
| Network | ${NETWORK_STATUS} |
| Dependencies | ${DEPENDENCY_STATUS} |
| Tests | ${TESTS_STATUS} |

### Summary
- Total checks: 6
- Passed: ${PASSED_JOBS}
- Failed: ${FAILED_JOBS}

---
*Infrastructure CI Enhanced v1.0*
EOF

    echo "📝 Markdown report generated: quality-report.md"
fi
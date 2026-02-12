#!/bin/bash
#
# NAS Synchronization Test Script
# Tests the sync-to-nas.sh script functionality
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_SCRIPT="$SCRIPT_DIR/sync-to-nas.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test result logging
log_test() {
  local test_name="$1"
  echo -e "${YELLOW}[TEST]${NC} $test_name"
  TESTS_RUN=$((TESTS_RUN + 1))
}

log_pass() {
  local message="$1"
  echo -e "${GREEN}[PASS]${NC} $message"
  TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_fail() {
  local message="$1"
  echo -e "${RED}[FAIL]${NC} $message"
  TESTS_FAILED=$((TESTS_FAILED + 1))
}

# Test 1: Script exists and is executable
test_script_exists() {
  log_test "Script existence and permissions"

  if [ -f "$SYNC_SCRIPT" ]; then
    log_pass "Script file exists"
  else
    log_fail "Script file not found: $SYNC_SCRIPT"
    return 1
  fi

  if [ -x "$SYNC_SCRIPT" ]; then
    log_pass "Script is executable"
  else
    log_fail "Script is not executable"
    return 1
  fi
}

# Test 2: Bash syntax check
test_syntax() {
  log_test "Bash syntax validation"

  if bash -n "$SYNC_SCRIPT" 2>/dev/null; then
    log_pass "Script syntax is valid"
  else
    log_fail "Script syntax error"
    bash -n "$SYNC_SCRIPT" 2>&1
    return 1
  fi
}

# Test 3: Default configuration
test_default_config() {
  log_test "Default configuration values"

  # Check NAS_USER default
  if grep -q 'NAS_USER="${NAS_USER:-徐啸}"' "$SYNC_SCRIPT"; then
    log_pass "NAS_USER default is correct (徐啸)"
  else
    log_fail "NAS_USER default is incorrect"
    grep 'NAS_USER=' "$SYNC_SCRIPT"
    return 1
  fi

  # Check NAS_PATH default
  if grep -q 'NAS_PATH="${NAS_PATH:-backups/us-vps}"' "$SYNC_SCRIPT"; then
    log_pass "NAS_PATH default is correct (backups/us-vps)"
  else
    log_fail "NAS_PATH default is incorrect"
    grep 'NAS_PATH=' "$SYNC_SCRIPT"
    return 1
  fi

  # Check rsync-path is present
  if grep -q '\-\-rsync-path=/usr/bin/rsync' "$SYNC_SCRIPT"; then
    log_pass "rsync-path parameter present"
  else
    log_fail "rsync-path parameter missing"
    return 1
  fi

  # Check StrictHostKeyChecking
  if grep -q 'StrictHostKeyChecking=no' "$SYNC_SCRIPT"; then
    log_pass "StrictHostKeyChecking parameter present"
  else
    log_fail "StrictHostKeyChecking parameter missing"
    return 1
  fi
}

# Test 4: NAS connectivity
test_nas_connectivity() {
  log_test "NAS connectivity (Tailscale)"

  local nas_host="100.110.241.76"

  if ping -c 1 -W 5 "$nas_host" > /dev/null 2>&1; then
    log_pass "NAS is reachable via ping"
  else
    log_fail "NAS is not reachable"
    return 1
  fi

  if nc -z -w 5 "$nas_host" 22 > /dev/null 2>&1; then
    log_pass "SSH port (22) is accessible"
  else
    log_fail "SSH port (22) is not accessible"
    return 1
  fi
}

# Test 5: SSH authentication
test_ssh_auth() {
  log_test "SSH authentication to NAS"

  local nas_user="徐啸"
  local nas_host="100.110.241.76"

  if ssh -o ConnectTimeout=10 -o BatchMode=yes "$nas_user@$nas_host" "echo 'SSH OK'" 2>/dev/null; then
    log_pass "SSH key authentication works"
  else
    log_fail "SSH key authentication failed"
    echo "  Please configure SSH keys: ssh-copy-id $nas_user@$nas_host"
    return 1
  fi
}

# Test 6: Dry-run sync test
test_dry_run() {
  log_test "Dry-run synchronization"

  # Create a small test directory
  local test_dir="/tmp/nas-sync-test-$$"
  mkdir -p "$test_dir"
  echo "test file" > "$test_dir/test.txt"

  # Run dry-run sync
  if DRY_RUN=true SOURCE_PATH="$test_dir" LOG_FILE="/tmp/nas-sync-test.log" \
     bash "$SYNC_SCRIPT" > /dev/null 2>&1; then
    log_pass "Dry-run completed successfully"
  else
    log_fail "Dry-run failed"
    cat "/tmp/nas-sync-test.log" 2>/dev/null || true
    rm -rf "$test_dir"
    return 1
  fi

  # Cleanup
  rm -rf "$test_dir"
  rm -f "/tmp/nas-sync-test.log"
}

# Test 7: Help message
test_help() {
  log_test "Help message display"

  if bash "$SYNC_SCRIPT" --help | grep -q "Usage:" 2>/dev/null; then
    log_pass "Help message displays correctly"
  else
    log_fail "Help message not working"
    return 1
  fi
}

# Main test execution
main() {
  echo "========================================="
  echo "  NAS Sync Script Test Suite"
  echo "========================================="
  echo ""

  # Run all tests (continue on failure)
  test_script_exists || true
  test_syntax || true
  test_default_config || true
  test_nas_connectivity || true
  test_ssh_auth || true
  test_dry_run || true
  test_help || true

  # Summary
  echo ""
  echo "========================================="
  echo "  Test Summary"
  echo "========================================="
  echo "Total:  $TESTS_RUN"
  echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
  echo -e "${RED}Failed: $TESTS_FAILED${NC}"
  echo ""

  if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
  else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
  fi
}

main

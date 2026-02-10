#!/bin/bash
# 测试 NAS 内容管理工具
# 用法: ./test-nas-content-manager.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANAGER="${SCRIPT_DIR}/nas-content-manager.sh"

# 颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# 测试计数
PASS=0
FAIL=0

test_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASS++))
}

test_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAIL++))
}

echo "=== 测试 NAS 内容管理工具 ==="
echo ""

# Test 1: Help 命令
echo "Test 1: help 命令"
if $MANAGER help | grep -q "NAS 内容管理工具"; then
    test_pass "help 命令输出正确"
else
    test_fail "help 命令输出不正确"
fi
echo ""

# Test 2: List 命令
echo "Test 2: list 命令"
if $MANAGER list | head -5 | grep -q "|"; then
    test_pass "list 命令输出格式正确"
else
    test_fail "list 命令输出格式不正确"
fi
echo ""

# Test 3: Stats 命令
echo "Test 3: stats 命令"
if $MANAGER stats | grep -q "总内容数"; then
    test_pass "stats 命令输出正确"
else
    test_fail "stats 命令输出不正确"
fi
echo ""

# Test 4: 不存在的 content_id
echo "Test 4: 不存在的 content_id"
if ! $MANAGER show non-existent-id 2>&1 | grep -q "内容不存在"; then
    test_fail "错误处理不正确"
else
    test_pass "错误处理正确"
fi
echo ""

# Test 5: Show 命令（使用已存在的 content_id）
echo "Test 5: show 命令"
FIRST_ID=$($MANAGER list | head -1 | cut -d'|' -f1 | tr -d ' ')
if [ -n "$FIRST_ID" ]; then
    if $MANAGER show "$FIRST_ID" | grep -q "Manifest"; then
        test_pass "show 命令输出正确"
    else
        test_fail "show 命令输出不正确"
    fi
else
    echo "  ⏭️  跳过（无内容可测试）"
fi
echo ""

# Test 6: Read 命令
echo "Test 6: read 命令"
if [ -n "$FIRST_ID" ]; then
    if $MANAGER read "$FIRST_ID" >/dev/null 2>&1; then
        test_pass "read 命令成功"
    else
        test_fail "read 命令失败"
    fi
else
    echo "  ⏭️  跳过（无内容可测试）"
fi
echo ""

# Test 7: Filter 命令
echo "Test 7: filter 命令"
if $MANAGER filter draft | grep -q "|" || $MANAGER filter draft | grep -q "筛选状态"; then
    test_pass "filter 命令执行成功"
else
    test_fail "filter 命令执行失败"
fi
echo ""

# Test 8: Search 命令
echo "Test 8: search 命令"
if $MANAGER search "AI" | grep -q "|" || $MANAGER search "AI" | grep -q "搜索关键词"; then
    test_pass "search 命令执行成功"
else
    test_fail "search 命令执行失败"
fi
echo ""

# Test 9: 无效参数
echo "Test 9: 无效参数处理"
if ! $MANAGER update-status 2>&1 | grep -q "用法"; then
    test_fail "无效参数处理不正确"
else
    test_pass "无效参数处理正确"
fi
echo ""

# Test 10: 未知命令
echo "Test 10: 未知命令处理"
if ! $MANAGER unknown-command 2>&1 | grep -q "未知命令"; then
    test_fail "未知命令处理不正确"
else
    test_pass "未知命令处理正确"
fi
echo ""

# 总结
echo "==========================="
echo "测试完成"
echo "通过: $PASS"
echo "失败: $FAIL"
echo "==========================="

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}所有测试通过！${NC}"
    exit 0
else
    echo -e "${RED}有测试失败${NC}"
    exit 1
fi

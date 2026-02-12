#!/bin/bash
# 验证 PR 导入脚本的执行结果

set -e

echo "🔍 验证 PR 导入结果"
echo ""

# 检查 PostgreSQL 连接
echo "1️⃣  检查 PostgreSQL 连接..."
if psql -U cecelia -d cecelia -c "SELECT 1;" >/dev/null 2>&1; then
    echo "   ✅ PostgreSQL 连接正常"
else
    echo "   ❌ PostgreSQL 连接失败"
    exit 1
fi
echo ""

# 检查 pgvector 扩展
echo "2️⃣  检查 pgvector 扩展..."
PGVECTOR_INSTALLED=$(psql -U cecelia -d cecelia -tAc "SELECT COUNT(*) FROM pg_extension WHERE extname = 'vector';" 2>/dev/null || echo "0")

if [[ "$PGVECTOR_INSTALLED" == "1" ]]; then
    echo "   ✅ pgvector 扩展已安装"
else
    echo "   ⚠️  pgvector 扩展未安装"
    echo "   运行: bash scripts/setup-embeddings.sh"
fi
echo ""

# 检查导入的 PR 数量
echo "3️⃣  检查导入的 PR 数量..."
PR_COUNT=$(psql -U cecelia -d cecelia -tAc "SELECT COUNT(*) FROM tasks WHERE metadata->>'source' = 'pr_import';" 2>/dev/null || echo "0")

echo "   导入的 PR 总数: $PR_COUNT"

if [[ "$PR_COUNT" -gt 0 ]]; then
    echo "   ✅ 已导入 PR"
else
    echo "   ⚠️  未导入 PR"
    echo "   运行: node scripts/import-all-prs.js"
fi
echo ""

# 按 repo 统计
echo "4️⃣  按 repo 统计导入的 PR..."
psql -U cecelia -d cecelia -c "
SELECT
    metadata->>'repo' AS repo,
    COUNT(*) AS pr_count
FROM tasks
WHERE metadata->>'source' = 'pr_import'
GROUP BY metadata->>'repo'
ORDER BY pr_count DESC;
" 2>/dev/null || echo "   ⚠️  查询失败"
echo ""

# 检查 project 表
echo "5️⃣  检查 project 表..."
PROJECT_COUNT=$(psql -U cecelia -d cecelia -tAc "SELECT COUNT(*) FROM projects WHERE repo_path IS NOT NULL;" 2>/dev/null || echo "0")

echo "   关联的 project 数量: $PROJECT_COUNT"

if [[ "$PROJECT_COUNT" -ge 13 ]]; then
    echo "   ✅ 所有 repos 都有对应的 project"
else
    echo "   ⚠️  project 数量少于预期（期望 13 个）"
fi
echo ""

# 检查 metadata 字段完整性
echo "6️⃣  检查 metadata 字段完整性..."
SAMPLE=$(psql -U cecelia -d cecelia -tAc "
SELECT
    COUNT(*) AS count,
    SUM(CASE WHEN metadata->>'pr_number' IS NOT NULL THEN 1 ELSE 0 END) AS has_pr_number,
    SUM(CASE WHEN metadata->>'pr_author' IS NOT NULL THEN 1 ELSE 0 END) AS has_pr_author,
    SUM(CASE WHEN metadata->>'repo' IS NOT NULL THEN 1 ELSE 0 END) AS has_repo
FROM tasks
WHERE metadata->>'source' = 'pr_import'
LIMIT 1;
" 2>/dev/null || echo "0|0|0|0")

IFS='|' read -r count has_pr_number has_pr_author has_repo <<< "$SAMPLE"

echo "   总数: $count"
echo "   有 pr_number: $has_pr_number ($(awk "BEGIN {printf \"%.1f\", $has_pr_number*100/$count}")%)"
echo "   有 pr_author: $has_pr_author ($(awk "BEGIN {printf \"%.1f\", $has_pr_author*100/$count}")%)"
echo "   有 repo: $has_repo ($(awk "BEGIN {printf \"%.1f\", $has_repo*100/$count}")%)"

if [[ "$has_pr_number" == "$count" ]] && [[ "$has_repo" == "$count" ]]; then
    echo "   ✅ metadata 字段完整"
else
    echo "   ⚠️  部分 metadata 字段缺失"
fi
echo ""

# 测试 Brain API 相似度搜索（如果 Brain 在运行）
echo "7️⃣  测试 Brain API 相似度搜索..."
if curl -s -f localhost:5221/api/brain/health >/dev/null 2>&1; then
    echo "   Brain API 在线，测试相似度搜索..."

    SEARCH_RESULT=$(curl -s localhost:5221/api/brain/search-similar \
        -H "Content-Type: application/json" \
        -d '{"query": "add user authentication", "type": "task"}' 2>/dev/null)

    if echo "$SEARCH_RESULT" | jq -e '.results' >/dev/null 2>&1; then
        RESULT_COUNT=$(echo "$SEARCH_RESULT" | jq '.results | length')
        echo "   ✅ 相似度搜索成功，返回 $RESULT_COUNT 个结果"
    else
        echo "   ⚠️  相似度搜索失败"
    fi
else
    echo "   ⚠️  Brain API 未运行（localhost:5221）"
    echo "   跳过相似度搜索测试"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 验证完成"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

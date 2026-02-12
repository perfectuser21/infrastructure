#!/bin/bash
set -e

echo "🔧 PostgreSQL pgvector 扩展安装"
echo ""

# 检测 PostgreSQL 版本
echo "📋 检测 PostgreSQL 版本..."
PG_VERSION=$(psql --version | grep -oE '[0-9]+\.[0-9]+' | head -1 | cut -d. -f1)

if [[ -z "$PG_VERSION" ]]; then
    echo "❌ 无法检测 PostgreSQL 版本"
    echo "   请确保 PostgreSQL 已安装且在 PATH 中"
    exit 1
fi

echo "✅ PostgreSQL $PG_VERSION.x detected"
echo ""

# 检查 pgvector 是否已安装
echo "📦 检查 pgvector 扩展..."
if dpkg -l | grep -q "postgresql-$PG_VERSION-pgvector"; then
    echo "✅ pgvector 已安装"
else
    echo "📥 安装 pgvector 扩展..."

    # 添加 APT 仓库（如果需要）
    if ! grep -q "apt.postgresql.org" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
        echo "   添加 PostgreSQL APT 仓库..."
        sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
        wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
        sudo apt-get update -qq
    fi

    # 安装 pgvector
    echo "   安装 postgresql-$PG_VERSION-pgvector..."
    sudo apt-get install -y -qq postgresql-$PG_VERSION-pgvector

    echo "✅ pgvector 安装完成"
fi
echo ""

# 启用扩展到 cecelia 数据库
echo "🔌 启用 pgvector 扩展到 cecelia 数据库..."

# 检查扩展是否已启用
EXTENSION_EXISTS=$(psql -U cecelia -d cecelia -tAc "SELECT COUNT(*) FROM pg_extension WHERE extname = 'vector';" 2>/dev/null || echo "0")

if [[ "$EXTENSION_EXISTS" == "1" ]]; then
    echo "✅ pgvector 扩展已在 cecelia 数据库中启用"
else
    echo "   创建扩展..."
    psql -U cecelia -d cecelia -c "CREATE EXTENSION IF NOT EXISTS vector;" >/dev/null
    echo "✅ pgvector 扩展已启用"
fi
echo ""

# 验证安装
echo "🧪 验证安装..."

# 测试向量类型
TEST_RESULT=$(psql -U cecelia -d cecelia -tAc "SELECT '[1,2,3]'::vector;" 2>&1)

if [[ "$TEST_RESULT" == "[1,2,3]" ]]; then
    echo "✅ 向量类型测试通过"
else
    echo "❌ 向量类型测试失败"
    echo "   输出: $TEST_RESULT"
    exit 1
fi

# 测试向量距离计算（余弦相似度）
TEST_DISTANCE=$(psql -U cecelia -d cecelia -tAc "SELECT '[1,2,3]'::vector <=> '[4,5,6]'::vector;" 2>&1)

if [[ -n "$TEST_DISTANCE" ]] && [[ "$TEST_DISTANCE" != *"ERROR"* ]]; then
    echo "✅ 向量距离计算测试通过"
else
    echo "❌ 向量距离计算测试失败"
    echo "   输出: $TEST_DISTANCE"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ pgvector 安装和验证完成"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 下一步："
echo "   1. 运行 import-all-prs.js 导入历史 PRs"
echo "   2. 在 Brain API 中使用相似度搜索"
echo ""

---
id: database-migrations
version: 1.1.0
created: 2026-02-10
updated: 2026-02-10
changelog:
  - 1.1.0: 添加数据库清理历史和 workspace migrations
  - 1.0.0: 初始版本 - 数据库 Migration 管理
---

# 数据库 Migration 管理

## 📋 概述

所有服务的数据库 Schema 由各自仓库的 migrations 管理。Infrastructure 仓库只负责 PostgreSQL 的安装和配置。

### 当前数据库状态 (2026-02-10)

| 数据库 | 表数 | 说明 |
|--------|------|------|
| `cecelia` | 57 张 | Cecelia 核心表（已清理 NocoDB） |
| `n8n_social_metrics` | - | N8N 社交媒体数据 |
| `timescaledb` | - | TimescaleDB 模板库 |

### 清理历史

- **2026-02-10**: 删除 85 张 NocoDB 遗留表 (nc_*)，总表数从 142 → 57
- **备份**: `/tmp/cecelia-backup-before-nocodb-cleanup-20260210.sql` (48MB)

---

## 🗂️ Migration 位置

### Cecelia Brain

**位置**: `cecelia/core/brain/migrations/`

**文件数**: 18 个 SQL 文件

**命名规范**:
```
NNN_description.sql
例如: 017_add_data_task_type.sql
```

**当前版本**: 017（见 `selfcheck.js`）

**版本跟踪表**:
```sql
SELECT * FROM schema_version ORDER BY version DESC LIMIT 5;
```

### Cecelia Workspace (OKR/TRD 前端)

**位置 1**: `cecelia/workspace/apps/core/migrations/`

**文件数**: 7 个 SQL 文件 (OKR/TRD 相关)

**文件列表**:
```
001_add_okr_hierarchy.sql
002_trd_tables.sql
003_decisions_table.sql
004_planner_tables.sql
005_project_state_machine.sql
006_areas_table.sql
007_okr_three_layer.sql
```

**位置 2**: `cecelia/workspace/apps/core/src/db/migrations/`

**文件数**: 3 个 SQL 文件 (OKR 相关)

**文件列表**:
```
001-create-key-results.sql
002-modify-goals-table.sql
003-modify-projects-table.sql
```

**管理方式**: 前端服务自己管理

---

## 🔧 执行 Migration

### Cecelia Brain

```bash
# 方法 1: 使用部署脚本（推荐）
cd /home/xx/perfect21/cecelia/core
bash scripts/brain-deploy.sh
# 部署脚本会自动执行未运行的 migrations

# 方法 2: 手动执行
cd /home/xx/perfect21/cecelia/core/brain
psql -h localhost -U cecelia -d cecelia -f migrations/018_new_migration.sql
```

### 手动执行所有 Migrations

```bash
cd /home/xx/perfect21/cecelia/core/brain/migrations

# 按顺序执行所有 SQL 文件
for file in $(ls -v *.sql); do
  echo "Executing $file..."
  psql -h localhost -U cecelia -d cecelia -f "$file"
done
```

---

## 📝 创建新 Migration

### 步骤

1. **确定版本号**
   ```bash
   # 查看当前最高版本
   ls -1 cecelia/core/brain/migrations/ | tail -1
   # 假设是 018_xxx.sql，下一个是 019
   ```

2. **创建 SQL 文件**
   ```bash
   cd cecelia/core/brain/migrations
   touch 019_add_new_feature.sql
   ```

3. **编写 SQL**
   ```sql
   -- 019_add_new_feature.sql
   
   -- 创建新表
   CREATE TABLE IF NOT EXISTS new_feature (
     id SERIAL PRIMARY KEY,
     name VARCHAR(255) NOT NULL,
     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
   );
   
   -- 更新 schema_version
   INSERT INTO schema_version (version, description)
   VALUES (19, '添加 new_feature 表');
   ```

4. **测试**
   ```bash
   # 在测试数据库测试
   psql -h localhost -U cecelia -d cecelia_test -f 019_add_new_feature.sql
   ```

5. **更新 selfcheck.js**
   ```javascript
   // cecelia/core/brain/src/selfcheck.js
   const EXPECTED_SCHEMA_VERSION = '019';  // 更新版本号
   ```

---

## 🔍 检查 Migration 状态

### 查看已执行的 Migrations

```bash
# 连接数据库
psql -h localhost -U cecelia -d cecelia

# 查看 schema_version 表
SELECT * FROM schema_version ORDER BY version;

# 查看当前版本
SELECT MAX(version) FROM schema_version;
```

### 检查未执行的 Migrations

```bash
cd /home/xx/perfect21/cecelia/core/brain

# 获取数据库中的最高版本
DB_VERSION=$(psql -h localhost -U cecelia -d cecelia -t -c "SELECT MAX(version) FROM schema_version;" | xargs)

# 列出未执行的 migrations
for file in migrations/*.sql; do
  FILE_VERSION=$(basename "$file" | cut -d'_' -f1 | sed 's/^0*//')
  if [ "$FILE_VERSION" -gt "$DB_VERSION" ]; then
    echo "未执行: $file"
  fi
done
```

---

## ⚠️ Migration 最佳实践

### DO ✅

1. **总是添加 `IF NOT EXISTS`**
   ```sql
   CREATE TABLE IF NOT EXISTS my_table (...);
   ALTER TABLE my_table ADD COLUMN IF NOT EXISTS new_col VARCHAR(255);
   ```

2. **更新 schema_version 表**
   ```sql
   INSERT INTO schema_version (version, description)
   VALUES (19, '描述这个 migration');
   ```

3. **按版本号顺序执行**
   - Migration 必须按顺序执行
   - 不要跳过版本号

4. **测试后再部署**
   - 先在测试数据库测试
   - 确认无误后再部署到生产

### DON'T ❌

1. **不要修改已执行的 Migration**
   - 已执行的 migration 是历史记录
   - 如需修改，创建新的 migration

2. **不要直接修改数据库**
   - 所有 schema 变更必须通过 migration
   - 直接修改会导致版本不一致

3. **不要删除 Migration 文件**
   - Migration 是数据库演进的历史
   - 删除会导致版本追踪混乱

---

## 🗄️ Migration 文件列表（Cecelia Brain）

```bash
000_base_schema.sql                    # 基础 schema
001_cecelia_architecture_upgrade.sql   # 架构升级
002_task_type_review_merge.sql         # 任务类型合并
003_feature_tick_system.sql            # Tick 系统
004_trigger_source.sql                 # 触发源
005_schema_version_and_config.sql      # 版本跟踪
006_exploratory_support.sql            # 探索性支持
007_pending_actions.sql                # 待办操作
008_publishing_system.sql              # 发布系统
009_fix_decisions_schema.sql           # 修复决策 schema
010_proposals.sql                      # 提案系统
011_trigger_source_values.sql          # 触发源值
012_learnings_table.sql                # 学习记录表
013_cortex_analyses.sql                # 皮层分析
015_cortex_quality_system.sql          # 质量系统
016_immune_system_connections.sql      # 免疫系统连接
017_add_data_task_type.sql             # 数据任务类型
018_add_feedback_and_status_history.sql # 反馈和状态历史
```

---

## 🔗 相关文档

- PostgreSQL 配置: [postgresql.md](./postgresql.md)
- Cecelia Brain: `cecelia/core/brain/migrations/`
- Schema 版本检查: `cecelia/core/brain/src/selfcheck.js`

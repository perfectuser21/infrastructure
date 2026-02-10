---
id: postgresql-configuration
version: 1.0.0
created: 2026-02-10
changelog:
  - 1.0.0: 初始版本 - PostgreSQL 配置文档
---

# PostgreSQL 配置

## 📋 基本信息

| 项目 | 信息 |
|------|------|
| **版本** | PostgreSQL 14+ |
| **端口** | 5432 |
| **主数据库** | `cecelia` |
| **用户** | `cecelia` |
| **密码** | 见 `.env.docker` |

## 🖥️ 部署位置

| 服务器 | 容器名 | 数据目录 |
|--------|--------|----------|
| 美国 VPS | `cecelia-core_postgres_1` | Docker volume |
| 香港 VPS | `social-metrics-postgres` | Docker volume |

---

## 🔧 安装配置

### Docker Compose 配置

**cecelia/core 的 PostgreSQL**:

```yaml
# docker-compose.yml
services:
  postgres:
    image: postgres:14-alpine
    container_name: cecelia-core_postgres_1
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: cecelia
      POSTGRES_USER: cecelia
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres-data:/var/lib/postgresql/data
    restart: unless-stopped

volumes:
  postgres-data:
```

### 环境变量

**文件位置**: `cecelia/core/.env.docker`

```bash
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=cecelia
POSTGRES_USER=cecelia
POSTGRES_PASSWORD=<strong-password>
```

---

## 📊 数据库列表

| 数据库 | 服务 | Schema 管理 |
|--------|------|-------------|
| `cecelia` | Cecelia Brain | `cecelia/core/brain/migrations/` |
| `zenithjoy` | ZenithJoy Workspace | `zenithjoy/workspace/migrations/` |
| `timescaledb` | 时序数据 | TimescaleDB extensions |

---

## 🔒 访问控制

### 本地访问

```bash
# 直接连接
psql -h localhost -p 5432 -U cecelia -d cecelia

# 通过 Docker
docker exec -it cecelia-core_postgres_1 psql -U cecelia -d cecelia
```

### 远程访问（通过 Tailscale）

```bash
# 从香港 VPS 访问美国 VPS 的 PostgreSQL
psql -h 100.71.32.28 -p 5432 -U cecelia -d cecelia
```

**安全配置** (`pg_hba.conf`):
```
# 只允许 Tailscale 网络访问
host    all             all             100.0.0.0/8            md5
```

---

## 💾 备份策略

### 手动备份

```bash
# 备份到文件
docker exec cecelia-core_postgres_1 pg_dump -U cecelia cecelia > /tmp/cecelia-backup-$(date +%Y%m%d).sql

# 恢复
docker exec -i cecelia-core_postgres_1 psql -U cecelia -d cecelia < /tmp/cecelia-backup-20260210.sql
```

### 自动备份（待配置）

**脚本位置**: `infrastructure/scripts/backup/postgres-backup.sh`

```bash
#!/bin/bash
# 每日凌晨 3 点备份
0 3 * * * /home/xx/perfect21/infrastructure/scripts/backup/postgres-backup.sh
```

---

## 🔍 Schema 版本管理

### Cecelia Brain

**Migrations 目录**: `cecelia/core/brain/migrations/`

**当前版本**: 017（见 `selfcheck.js`）

**命名规范**:
```
NNN_description.sql
例如: 017_add_quarantine_table.sql
```

**Schema 版本跟踪表**:
```sql
SELECT * FROM schema_version ORDER BY version DESC LIMIT 5;
```

### 执行 Migration

```bash
# 在 cecelia/core 仓库
cd /home/xx/perfect21/cecelia/core
bash scripts/run-migrations.sh  # 如有此脚本
```

---

## 📐 性能优化

### 连接池配置

**推荐设置**:
```javascript
// cecelia/core/brain/src/db-config.js
const pool = new Pool({
  max: 20,              // 最大连接数
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
```

### 索引建议

```sql
-- 示例：为常用查询添加索引
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_runs_created_at ON runs(created_at DESC);
```

---

## 🛠️ 维护任务

### 定期检查

```bash
# 检查数据库大小
docker exec cecelia-core_postgres_1 psql -U cecelia -c "\l+"

# 检查表大小
docker exec cecelia-core_postgres_1 psql -U cecelia -d cecelia -c "\dt+"

# 清理死元组
docker exec cecelia-core_postgres_1 psql -U cecelia -d cecelia -c "VACUUM ANALYZE;"
```

### 监控

```bash
# 查看活跃连接
docker exec cecelia-core_postgres_1 psql -U cecelia -d cecelia -c "SELECT * FROM pg_stat_activity;"

# 查看慢查询
docker exec cecelia-core_postgres_1 psql -U cecelia -d cecelia -c "SELECT * FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 10;"
```

---

## 🔗 相关文档

- TimescaleDB 配置: [timescaledb.md](./timescaledb.md) (待创建)
- Cecelia Brain Schema: `cecelia/core/brain/migrations/`
- ZenithJoy Schema: `zenithjoy/workspace/migrations/` (如有)

---
id: port-mapping
version: 1.0.0
created: 2026-02-10
changelog:
  - 1.0.0: 初始版本 - 从 ~/.claude/PORT_MAPPING.md 迁移
---

# 端口映射 - Perfect21 生态系统

## 🎯 端口分配原则

- **5200-5299**: 后端 API 服务
- **5300-5399**: 前端服务
- **5400-5499**: 数据库和存储
- **5500-5599**: 工具和监控
- **5600-5699**: N8N 和自动化

## 📊 完整端口映射表

| 端口 | 服务 | 仓库 | 说明 |
|------|------|------|------|
| **5211** | Cecelia Workspace | cecelia/workspace | Cecelia 前端（正式版） |
| **5212** | ZenithJoy Dashboard | zenithjoy/workspace | ZenithJoy 公司前端 |
| **5221** | Cecelia Brain API | cecelia/core | Brain 后端 API |
| **5432** | PostgreSQL | - | 主数据库 |
| **5433** | TimescaleDB | - | 时序数据库 |
| **5679** | N8N | cecelia/workflows | 自动化工作流 |
| **443** | X-Ray VPN | - | VPN 服务（禁止占用） |
| **8080** | VPN 订阅服务器 | - | X-Ray 订阅 |
| **80, 81** | Nginx Proxy Manager | - | 内部反向代理 |
| **3456** | Claude Monitor (Backend) | - | 监控后端 |
| **5173** | Claude Monitor (Frontend) | - | 监控前端 |

## 🖥️ 按服务器分组

### 美国 VPS (146.190.52.84)

| 端口 | 服务 | 状态 |
|------|------|------|
| 22 | SSH | ✅ 运行中 |
| 443 | X-Ray VPN | ✅ 运行中 |
| 5211 | Cecelia Workspace | ✅ 运行中 |
| 5221 | Cecelia Brain API | ✅ 运行中 |
| 5432 | PostgreSQL | ✅ 运行中 |
| 5679 | N8N | ✅ 运行中 |
| 8080 | VPN 订阅服务器 | ✅ 运行中 |

### 香港 VPS (43.154.85.217)

| 端口 | 服务 | 状态 |
|------|------|------|
| 22 | SSH | ✅ 运行中 |
| 443 | X-Ray VPN | ✅ 运行中 |
| 5212 | ZenithJoy Dashboard | ✅ 运行中 |
| 5432 | PostgreSQL | ✅ 运行中 |
| 8080 | VPN 订阅服务器 | ✅ 运行中 |

### 西安公司设备

| 设备 | 端口 | 服务 | 状态 |
|------|------|------|------|
| NAS | 445 | Samba | 待配置 |
| NAS | 2049 | NFS | 待配置 |
| Mac mini | - | - | - |
| Node PC | - | - | - |

## 🌐 公网域名映射

### 通过 Cloudflare Tunnel

| 域名 | 目标服务器 | 端口 | 说明 |
|------|-----------|------|------|
| autopilot.zenjoymedia.media | 香港 VPS | 5211 | ZenithJoy 生产环境 |
| zenjoymedia.media | 香港 VPS | 5211 | ZenithJoy 主域名 |
| dashboard.zenjoymedia.media | 香港 VPS | 5211 | ZenithJoy Dashboard |
| dev-autopilot.zenjoymedia.media | 香港开发 VPS | 5212 | ZenithJoy 开发环境 |
| n8n.zenjoymedia.media | 美国 VPS | 5679 | N8N 工作流 |

### 仅本地访问（无公网域名）

| 域名 | 目标服务器 | 端口 | 说明 |
|------|-----------|------|------|
| http://perfect21:5211 | 美国 VPS | 5211 | Cecelia Workspace (正式版) |
| http://perfect21:5212 | 美国 VPS | 5212 | Cecelia Workspace (研发版) |
| http://localhost:5221 | 美国 VPS | 5221 | Cecelia Brain API |

## 🚫 端口禁区（绝对不要占用）

| 端口 | 占用者 | 原因 |
|------|--------|------|
| **443** | X-Ray VPN | VPN 专用，占用会导致 VPN 断线 |
| **80, 81** | Nginx Proxy Manager | 内部管理，不对外 |
| **22** | SSH | 系统管理，不要改 |

## 📋 端口冲突排查

### 检查端口占用

```bash
# 检查某个端口是否被占用
sudo netstat -tulnp | grep :5221

# 检查某个端口被哪个进程占用
sudo lsof -i :5221
```

### 杀死占用端口的进程

```bash
# 找到进程 ID
sudo lsof -i :5221 | grep LISTEN

# 杀死进程
sudo kill -9 <PID>
```

## 🔧 Docker 端口映射

### Cecelia Brain (cecelia-core)

```yaml
# docker-compose.yml
services:
  brain:
    ports:
      - "5221:5221"
    environment:
      - PORT=5221
```

### PostgreSQL

```yaml
# docker-compose.yml (cecelia-core)
services:
  postgres:
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_PORT=5432
```

### N8N

```yaml
# docker-compose.yml (cecelia-workflows)
services:
  n8n:
    ports:
      - "5679:5678"  # 外部 5679，内部 5678
```

## 🔗 相关文档

- 网络拓扑: [topology.md](./topology.md)
- 服务器详情: [../servers/](../servers/)
- NAS 配置: [../nas/setup.md](../nas/setup.md)

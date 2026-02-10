---
id: hk-vps-server
version: 1.0.0
created: 2026-02-10
changelog:
  - 1.0.0: 初始版本 - 香港 VPS 服务器文档
---

# 香港 VPS (生产环境)

## 📋 基本信息

| 项目 | 信息 |
|------|------|
| **位置** | 腾讯云 香港 |
| **公网 IP** | 43.154.85.217 |
| **Tailscale IP** | 100.86.118.99 |
| **主机名** | vm-0-8-ubuntu |
| **系统** | Ubuntu 22.04 LTS |
| **CPU** | - |
| **内存** | - |
| **存储** | - |
| **用途** | 生产环境、ZenithJoy Autopilot |

---

## 🔌 SSH 连接

```bash
# 通过 Tailscale 连接（推荐）
ssh root@100.86.118.99

# 使用别名
ssh hk

# 直接公网 IP（如需要）
ssh root@43.154.85.217

# VSCode Remote SSH
# 在 VSCode 中选择 "Connect to Host" → hk
```

---

## 🌐 网络配置

### 公网访问

- **公网 IP**: 43.154.85.217
- **Cloudflare Tunnel**: ✅ 用于域名路由
- **防火墙**: 腾讯云安全组

### Tailscale 内网

- **Tailscale IP**: 100.86.118.99
- **Exit Node**: ❌ 未启用
- **内网设备**: 可访问美国 VPS、西安设备

---

## 📦 运行中的服务

| 服务 | 端口 | 状态 | 仓库 |
|------|------|------|------|
| **ZenithJoy Dashboard** | 5211 | ✅ 运行中 | zenithjoy/workspace |
| **PostgreSQL** | 5432 | ✅ 运行中 | - |
| **X-Ray VPN** | 443 | ✅ 运行中 | - |
| **VPN 订阅服务器** | 8080 | ✅ 运行中 | - |

---

## 🐳 Docker 容器

```bash
# 查看运行中的容器
docker ps

# 常驻容器:
# - autopilot-dashboard      (ZenithJoy 前端)
# - social-metrics-postgres  (PostgreSQL)
# - xray-reality             (VPN)
```

---

## 📂 重要目录

| 目录 | 用途 |
|------|------|
| `/opt/zenithjoy/` | ZenithJoy 生产部署 |
| `/opt/xray-reality/` | X-Ray VPN 配置 |
| `/home/xx/` | 用户目录 |

---

## 🔐 VPN 服务

### X-Ray Reality

- **端口**: 443
- **配置**: `/opt/xray-reality/config.json`
- **订阅地址**: `http://43.154.85.217:8080/clash/<uuid>`
- **账号数**: 5 个

---

## 💾 数据库

### PostgreSQL

- **端口**: 5432
- **数据库**: `zenithjoy`
- **用户**: 见配置
- **数据目录**: Docker volume

### 备份策略

```bash
# 手动备份
docker exec social-metrics-postgres pg_dump -U <user> zenithjoy > /tmp/zenithjoy-backup-$(date +%Y%m%d).sql

# 通过 Tailscale 从美国 VPS 备份
ssh hk "docker exec social-metrics-postgres pg_dump -U <user> zenithjoy" > /tmp/hk-backup-$(date +%Y%m%d).sql
```

---

## 🛠️ 常用操作

### 重启服务

```bash
# 重启 Dashboard
docker restart autopilot-dashboard

# 重启 PostgreSQL
docker restart social-metrics-postgres

# 重启 VPN
docker restart xray-reality
```

### 查看日志

```bash
# Dashboard 日志
docker logs -f autopilot-dashboard

# PostgreSQL 日志
docker logs -f social-metrics-postgres

# VPN 日志
docker logs -f xray-reality
```

### 健康检查

```bash
# Dashboard
curl -s http://localhost:5211/health | jq

# PostgreSQL
docker exec social-metrics-postgres pg_isready
```

---

## 🔒 防火墙规则

**腾讯云安全组规则**:
- 22 (SSH)
- 443 (VPN)
- 8080 (VPN 订阅)
- 其他服务通过 Cloudflare Tunnel 访问

---

## 📊 监控

### 系统资源

```bash
# CPU 使用率
top

# 内存使用
free -h

# 磁盘使用
df -h

# Docker 资源
docker stats
```

---

## 🔧 维护任务

### 定期维护

- [ ] 每周检查磁盘空间
- [ ] 每周检查 Docker 容器状态
- [ ] 每月更新系统包: `sudo apt update && sudo apt upgrade`
- [ ] 每月清理 Docker 垃圾: `docker system prune -a`

### 备份清单

- [ ] PostgreSQL 数据库
- [ ] ZenithJoy Dashboard 配置
- [ ] VPN 配置文件

---

## 🔗 相关文档

- 网络拓扑: [../network/topology.md](../network/topology.md)
- 端口映射: [../network/ports.md](../network/ports.md)
- PostgreSQL 配置: [../database/postgresql.md](../database/postgresql.md)
- 美国 VPS: [us-vps.md](./us-vps.md)

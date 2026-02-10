---
id: us-vps-server
version: 1.0.0
created: 2026-02-10
changelog:
  - 1.0.0: 初始版本 - 美国 VPS 服务器文档
---

# 美国 VPS (研发环境)

## 📋 基本信息

| 项目 | 信息 |
|------|------|
| **位置** | DigitalOcean NYC (纽约) |
| **公网 IP** | 146.190.52.84 |
| **Tailscale IP** | 100.71.32.28 |
| **主机名** | perfect21 |
| **系统** | Ubuntu 22.04 LTS |
| **CPU** | 8 core |
| **内存** | 16 GB |
| **存储** | 320 GB SSD |
| **用途** | 研发环境、Claude Code (有头) |

## 🔌 SSH 连接

```bash
# 直接连接（需要 WARP）
ssh root@146.190.52.84

# 使用别名
ssh us

# VSCode Remote SSH
# 在 VSCode 中选择 "Connect to Host" → us
```

## 🌐 网络配置

### 公网访问

- **公网 IP**: 146.190.52.84
- **WARP 加速**: ✅ 已配置（Include 模式）
- **Cloudflare WARP**: 只代理此 IP

### Tailscale 内网

- **Tailscale IP**: 100.71.32.28
- **Exit Node**: ✅ 提供（可作为其他设备的出口）
- **内网设备**: 可访问香港 VPS、西安设备

## 📦 运行中的服务

| 服务 | 端口 | 状态 | 仓库 |
|------|------|------|------|
| **Cecelia Brain API** | 5221 | ✅ 运行中 | cecelia/core |
| **Cecelia Workspace** | 5211 | ✅ 运行中 | cecelia/workspace |
| **PostgreSQL** | 5432 | ✅ 运行中 | - |
| **N8N** | 5679 | ✅ 运行中 | cecelia/workflows |
| **X-Ray VPN** | 443 | ✅ 运行中 | - |
| **VPN 订阅服务器** | 8080 | ✅ 运行中 | - |
| **Nginx Proxy Manager** | 80, 81 | ✅ 运行中 | - |
| **Cloudflare Tunnel** | - | ✅ 运行中 | - |

## 🐳 Docker 容器

```bash
# 查看运行中的容器
docker ps

# 常驻容器:
# - cecelia-core_brain_1        (Brain API)
# - cecelia-core_postgres_1     (PostgreSQL)
# - n8n-self-hosted             (N8N)
# - cloudflared-tunnel          (Cloudflare Tunnel)
# - xray-reality                (VPN)
```

## 📂 重要目录

| 目录 | 用途 |
|------|------|
| `/home/xx/perfect21/` | 所有项目根目录 |
| `/home/xx/perfect21/cecelia/core/` | Cecelia Brain 后端 |
| `/home/xx/perfect21/cecelia/workspace/` | Cecelia 前端 |
| `/home/xx/perfect21/zenithjoy/workspace/` | ZenithJoy 前端 |
| `/home/xx/perfect21/infrastructure/` | 基础设施配置 |
| `/home/xx/.claude/` | Claude Code 全局配置 |
| `/home/xx/.credentials/` | 凭据存储 |
| `/opt/vpn/` | VPN 配置 |

## 🔐 VPN 服务

### X-Ray Reality

- **端口**: 443
- **配置**: `/opt/vpn/features/xray-reality/config/xray-server.json`
- **订阅地址**: `http://146.190.52.84:8080/clash/<uuid>`
- **账号数**: 10 个

### Cloudflare Tunnel

- **容器**: `cloudflared-tunnel`
- **配置**: `/root/.cloudflared/config.yml`
- **路由域名**: n8n.zenjoymedia.media

## 💾 数据库

### PostgreSQL

- **端口**: 5432
- **数据库**: `cecelia`
- **用户**: `cecelia`
- **密码**: 见 `.env.docker`
- **数据目录**: `/var/lib/postgresql/data` (Docker volume)

### 备份策略

```bash
# 手动备份
docker exec cecelia-core_postgres_1 pg_dump -U cecelia cecelia > /tmp/cecelia-backup-$(date +%Y%m%d).sql

# 自动备份（待配置）
# 见 infrastructure/scripts/backup/
```

## 🛠️ 常用操作

### 重启服务

```bash
# 重启 Brain
cd /home/xx/perfect21/cecelia/core
docker-compose restart brain

# 重启 PostgreSQL
docker-compose restart postgres

# 重启 N8N
docker restart n8n-self-hosted

# 重启 VPN
docker restart xray-reality
```

### 查看日志

```bash
# Brain 日志
cd /home/xx/perfect21/cecelia/core
docker-compose logs -f brain

# PostgreSQL 日志
docker-compose logs -f postgres

# N8N 日志
docker logs -f n8n-self-hosted
```

### 健康检查

```bash
# Brain API
curl -s http://localhost:5221/api/brain/health | jq

# PostgreSQL
docker exec cecelia-core_postgres_1 pg_isready

# N8N
curl -s http://localhost:5679/healthz
```

## 🔒 防火墙规则

```bash
# 查看防火墙状态
sudo ufw status

# 开放端口 (已配置):
# - 22 (SSH)
# - 443 (VPN)
# - 8080 (VPN 订阅)
# - 其他服务通过 Docker 内网访问
```

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

### Cecelia Watchdog

```bash
# 查看 Watchdog 状态
curl -s http://localhost:5221/api/brain/watchdog | jq

# 查看 RSS/CPU 实时监控
curl -s http://localhost:5221/api/brain/watchdog | jq '.processes'
```

## 🔧 维护任务

### 定期维护

- [ ] 每周检查磁盘空间
- [ ] 每周检查 Docker 容器状态
- [ ] 每月更新系统包: `sudo apt update && sudo apt upgrade`
- [ ] 每月清理 Docker 垃圾: `docker system prune -a`

### 备份清单

- [ ] PostgreSQL 数据库
- [ ] N8N 工作流配置
- [ ] VPN 配置文件
- [ ] Cloudflare Tunnel 配置

## 🔗 相关文档

- 网络拓扑: [../network/topology.md](../network/topology.md)
- 端口映射: [../network/ports.md](../network/ports.md)
- PostgreSQL 配置: [../database/postgresql.md](../database/postgresql.md)

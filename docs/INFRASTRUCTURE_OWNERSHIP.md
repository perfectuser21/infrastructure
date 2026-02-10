---
id: infrastructure-ownership
version: 1.0.0
created: 2026-02-10
changelog:
  - 1.0.0: 初始版本 - 统一基础设施职责划分
---

# Infrastructure Ownership - 基础设施职责划分

## 🎯 目标

解决职责混乱问题，明确 Database、NAS、Skills、设备管理的归属。

---

## 📦 仓库职责矩阵

| 层级 | 组件 | 职责 | 归属仓库 | 配置位置 |
|------|------|------|----------|----------|
| **L0: 硬件层** | VPS (美国/香港) | 服务器管理 | `perfect21/infrastructure` | `/docs/servers/` |
| | NAS (西安) | 存储设备 | `perfect21/infrastructure` | `/docs/nas/` |
| | Mac mini (西安) | 开发设备 | `perfect21/infrastructure` | `/docs/devices/` |
| | Node PC (西安) | 计算设备 | `perfect21/infrastructure` | `/docs/devices/` |
| **L1: 网络层** | Tailscale | VPN 配置 | `perfect21/infrastructure` | `/config/tailscale/` |
| | X-Ray Reality | 翻墙 VPN | `perfect21/infrastructure` | `/config/xray/` |
| | Cloudflare Tunnel | 域名路由 | `perfect21/infrastructure` | `/config/cloudflare/` |
| | Nginx | 反向代理 | `perfect21/infrastructure` | `/config/nginx/` |
| **L2: 存储层** | PostgreSQL | 数据库服务 | `perfect21/infrastructure` (安装)<br>`cecelia/core` (schema) | Infrastructure: `/config/postgresql/`<br>Core: `/brain/migrations/` |
| | NAS (Samba/NFS) | 文件共享 | `perfect21/infrastructure` | `/config/nas/` |
| | TimescaleDB | 时序数据库 | `perfect21/infrastructure` (安装)<br>各服务 (schema) | Infrastructure: `/config/timescaledb/` |
| **L3: 服务层** | Cecelia Brain | 调度决策 API | `cecelia/core` | `/brain/` |
| | Cecelia Workspace | 前端界面 | `cecelia/workspace` | `/apps/core/` |
| | ZenithJoy Workspace | 公司前端 | `zenithjoy/workspace` | `/apps/dashboard/` |
| | N8N Workflows | 自动化工作流 | `cecelia/workflows` | `/workflows/` |
| **L4: 工具层** | Skills | 开发工具 | `~/.claude/skills/` (全局)<br>`cecelia/engine` (部署脚本) | `~/.claude/skills/*/` |
| | Engine (Hooks/CI) | 开发工具链 | `cecelia/engine` | `/hooks/`, `/ci/` |
| | QA | 质量工具 | `cecelia/quality` | `/qa/` |

---

## 🗂️ 新建仓库：perfect21/infrastructure

### 目的

**统一管理所有基础设施配置（L0/L1/L2 层）**

### 目录结构

```
perfect21/infrastructure/
├── README.md                        # 架构总览
├── docs/
│   ├── servers/                     # 服务器文档
│   │   ├── us-vps.md               # 美国 VPS (146.190.52.84)
│   │   ├── hk-vps.md               # 香港 VPS (43.154.85.217)
│   │   └── hk-dev-vps.md           # 香港开发 VPS (100.86.118.99)
│   ├── nas/                         # NAS 文档
│   │   ├── setup.md                # NAS 初始配置
│   │   ├── tailscale.md            # Tailscale 配置
│   │   ├── samba.md                # Samba 配置
│   │   └── troubleshooting.md      # 故障排查（你昨天的问题）
│   ├── devices/                     # 设备文档
│   │   ├── mac-mini.md             # Mac mini 配置
│   │   └── node-pc.md              # Node PC 配置
│   └── network/                     # 网络架构
│       ├── topology.md             # 网络拓扑图
│       └── vpn.md                  # VPN 配置总览
├── config/                          # 配置文件
│   ├── tailscale/                  # Tailscale 配置
│   ├── xray/                       # X-Ray Reality 配置
│   ├── cloudflare/                 # Cloudflare Tunnel 配置
│   ├── nginx/                      # Nginx 配置
│   ├── postgresql/                 # PostgreSQL 安装配置
│   │   ├── install.sh              # 安装脚本
│   │   └── pg_hba.conf             # 访问控制
│   ├── nas/                        # NAS 配置
│   │   ├── smb.conf                # Samba 配置
│   │   └── exports                 # NFS 配置
│   └── timescaledb/                # TimescaleDB 配置
├── scripts/                         # 自动化脚本
│   ├── backup/                     # 备份脚本
│   ├── monitoring/                 # 监控脚本
│   └── deployment/                 # 部署脚本
└── ansible/                         # Ansible playbooks (可选)
    └── playbooks/
```

---

## 🔑 核心原则

### 1. Database 职责分离

| 职责 | 归属 | 文件位置 |
|------|------|----------|
| **安装和配置** | `perfect21/infrastructure` | `/config/postgresql/install.sh` |
| **Schema 和 Migrations** | 各服务仓库 | `cecelia/core/brain/migrations/` |
| **备份脚本** | `perfect21/infrastructure` | `/scripts/backup/` |
| **连接配置** | 各服务仓库 | `cecelia/core/brain/src/db-config.js` |

**规则**：
- Infrastructure 只管**装好数据库**
- 各服务自己管**表结构和数据**

### 2. NAS 职责分离

| 职责 | 归属 | 文件位置 |
|------|------|----------|
| **硬件和网络配置** | `perfect21/infrastructure` | `/docs/nas/setup.md` |
| **Samba/NFS 配置** | `perfect21/infrastructure` | `/config/nas/` |
| **挂载脚本** | `perfect21/infrastructure` | `/scripts/mount-nas.sh` |
| **应用层使用** | 各服务仓库 | 服务自己的代码 |

**你昨天的问题**：
- NAS 配置坏了 → 应该记录在 `infrastructure/docs/nas/troubleshooting.md`
- 在家连不上 → 可能是 Tailscale 配置问题，查 `infrastructure/config/tailscale/`

### 3. Skills 职责分离

| 职责 | 归属 | 文件位置 |
|------|------|----------|
| **Skill 源代码** | `~/.claude/skills/` | 用户本地 |
| **部署脚本** | `cecelia/engine` | `/skills/deploy.sh` |
| **CI/CD** | `cecelia/engine` | `/ci/`, `/hooks/` |

**规则**：
- Skills 是**全局工具**，不属于任何仓库
- Engine 负责**部署和管理** Skills

### 4. 设备管理

| 设备 | 配置管理 | 监控 | 备份 |
|------|----------|------|------|
| 美国 VPS | `infrastructure/docs/servers/us-vps.md` | Cecelia Watchdog | Infrastructure scripts |
| 香港 VPS | `infrastructure/docs/servers/hk-vps.md` | Cecelia Watchdog | Infrastructure scripts |
| NAS | `infrastructure/docs/nas/setup.md` | 手动检查 | NAS 自己的备份 |
| Mac mini | `infrastructure/docs/devices/mac-mini.md` | - | Time Machine |
| Node PC | `infrastructure/docs/devices/node-pc.md` | - | 手动 |

---

## 📋 数据流图

### 当前混乱流程

```
Mac mini → ??? → 美国 VPS → ??? → Node PC
          (不清楚)          (不清楚)
```

### 期望清晰流程（通过 NAS）

```
Mac mini ─────┐
              │
              ↓
            NAS (西安局域网 + Tailscale)
              ↑
              │
Node PC ──────┘
              │
              ↓ (Tailscale)
        美国/香港 VPS
```

**配置文件位置**：
- Tailscale 配置：`infrastructure/config/tailscale/nas.json`
- NAS 挂载脚本：`infrastructure/scripts/mount-nas.sh`

---

## ✅ 下一步行动

### 1. 创建 Infrastructure 仓库

```bash
cd /home/xx/perfect21
mkdir infrastructure
cd infrastructure
git init
git remote add origin <github-url>
```

### 2. 修复 NAS 配置

**问题**：昨天配置坏了，在家连不上

**排查步骤**：
1. 检查 Tailscale 是否连接：`tailscale status`
2. 检查 NAS 是否在 Tailscale 网络：`ping <nas-tailscale-ip>`
3. 检查 Samba 配置：`sudo cat /etc/samba/smb.conf`
4. 记录到 `infrastructure/docs/nas/troubleshooting.md`

### 3. 迁移现有配置

**从全局 CLAUDE.md 迁移到 Infrastructure**：
- `~/.claude/CLAUDE.md` 中的网络架构 → `infrastructure/docs/network/topology.md`
- `~/.claude/PORT_MAPPING.md` → `infrastructure/docs/network/ports.md`

### 4. 统一文档

**更新全局 CLAUDE.md**：
- 删除重复的网络架构描述
- 添加引用：`详细配置参考：perfect21/infrastructure`

---

## 🚫 反模式（不要做）

| ❌ 错误做法 | ✅ 正确做法 |
|------------|------------|
| 在 cecelia/core 里放 NAS 配置 | 放 infrastructure |
| 在 zenithjoy/workspace 里配置数据库 | Schema 在各服务，安装在 infrastructure |
| 在多个地方记录网络拓扑 | 只在 infrastructure/docs/network/topology.md |
| Skills 放在某个仓库里 | Skills 在 ~/.claude/skills/，部署脚本在 engine |

---

## 📚 参考资料

- 全局架构：`~/.claude/CLAUDE.md`
- Cecelia 定义：`cecelia/core/DEFINITION.md`
- 端口映射：`~/.claude/PORT_MAPPING.md`（将迁移到 infrastructure）

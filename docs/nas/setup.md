---
id: nas-setup
version: 1.0.0
created: 2026-02-10
changelog:
  - 1.0.0: 初始版本 - NAS 完整配置指南
---

# NAS 配置指南

## 📋 基本信息

| 项目 | 信息 | 备注 |
|------|------|------|
| **位置** | 西安公司 | - |
| **型号** | TBD (待确认) | - |
| **局域网 IP** | 192.168.x.x (待确认) | - |
| **Tailscale IP** | TBD (待配置) | - |
| **用途** | 文件存储、数据库备份、设备间文件共享 | - |

## 🎯 配置目标

### 期望数据流

```
Mac mini (西安) ──┐
                  │
                  ↓
                NAS (西安局域网 + Tailscale)
                  ↑
                  │
Node PC (西安) ───┘
                  │
                  ↓ (Tailscale)
            美国/香港 VPS
```

**好处**：
- ✅ Mac mini 和 Node PC 在同一局域网，速度快
- ✅ 通过 Tailscale，远程 VPS 也能访问
- ✅ NAS 作为中心存储，统一管理

## 🔧 配置步骤

### 第 1 步：确认 NAS 型号和访问方式

**待确认信息**：
- [ ] NAS 型号（群晖/威联通/其他）
- [ ] 管理界面 URL（如 http://192.168.1.100:5000）
- [ ] 管理员账号密码

**当前问题**：
- ⚠️ 昨天配置后，在家无法连接
- ✅ 在公司可以连接

### 第 2 步：安装 Tailscale（推荐）

#### 方案 A：NAS 原生支持 Tailscale

**群晖 (Synology)**：
```bash
# 1. 登录 DSM 管理界面
# 2. 打开 Package Center
# 3. 搜索 "Tailscale"
# 4. 安装并启动
# 5. 授权加入 Tailscale 网络
```

**威联通 (QNAP)**：
```bash
# 1. 登录 QTS 管理界面
# 2. 打开 App Center
# 3. 搜索 "Tailscale"
# 4. 安装并启动
# 5. 授权加入 Tailscale 网络
```

#### 方案 B：通过 Docker 安装 Tailscale

如果 NAS 不原生支持，可以用 Docker：

```bash
# 1. 在 NAS 上启用 Docker
# 2. 运行 Tailscale 容器
docker run -d \
  --name=tailscale \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE \
  -v /var/lib/tailscale:/var/lib/tailscale \
  -v /dev/net/tun:/dev/net/tun \
  --restart=unless-stopped \
  tailscale/tailscale:latest
```

#### 方案 C：通过 Mac mini 中转（临时方案）

如果 NAS 无法安装 Tailscale，可以通过 Mac mini 中转：

```
美国 VPS → (Tailscale) → Mac mini → (局域网) → NAS
```

在 Mac mini 上配置 SSH 端口转发：
```bash
# Mac mini 上运行
ssh -L 445:192.168.x.x:445 localhost -N
```

### 第 3 步：配置 Samba 文件共享

#### 在 NAS 上启用 Samba

**群晖**：
```
控制面板 → 文件服务 → SMB/CIFS → 启用 SMB 服务
```

**威联通**：
```
控制台 → 网络服务 → Win/Mac/NFS → 启用 Microsoft 网络
```

#### 创建共享文件夹

```
文件夹名: shared
路径: /volume1/shared (群晖) 或 /share/shared (威联通)
权限: 允许所有用户读写（或按需设置）
```

#### 创建访问用户

```
用户名: perfect21
密码: <设置强密码>
权限: 读写 /shared 文件夹
```

### 第 4 步：测试本地连接

#### 从 Mac mini 测试

```bash
# 挂载 NAS
mkdir -p ~/nas
mount -t smbfs //perfect21@192.168.x.x/shared ~/nas

# 测试读写
echo "test" > ~/nas/test.txt
cat ~/nas/test.txt
rm ~/nas/test.txt

# 卸载
umount ~/nas
```

#### 从 Node PC 测试

```powershell
# Windows 资源管理器
# 地址栏输入: \\192.168.x.x\shared
# 输入用户名密码: perfect21 / <密码>
```

### 第 5 步：配置 Tailscale 访问

#### 获取 NAS 的 Tailscale IP

```bash
# 在 NAS 上运行（SSH 或 Docker）
tailscale ip -4
# 输出示例: 100.100.100.100
```

#### 从美国 VPS 测试

```bash
# 在美国 VPS 上运行
ping 100.100.100.100

# 挂载 NAS（通过 Tailscale IP）
mkdir -p /mnt/nas
mount -t cifs //100.100.100.100/shared /mnt/nas -o username=perfect21,password=<密码>

# 测试读写
echo "test from us-vps" > /mnt/nas/test.txt
cat /mnt/nas/test.txt
```

### 第 6 步：持久化挂载

#### Linux (美国/香港 VPS)

创建凭据文件：
```bash
# /root/.nascredentials
username=perfect21
password=<密码>
```

修改 `/etc/fstab`：
```bash
//100.100.100.100/shared  /mnt/nas  cifs  credentials=/root/.nascredentials,uid=1000,gid=1000  0  0
```

测试挂载：
```bash
mount -a
df -h | grep nas
```

#### macOS (Mac mini)

创建自动挂载脚本 `~/mount-nas.sh`：
```bash
#!/bin/bash
mkdir -p ~/nas
mount -t smbfs //perfect21:<密码>@100.100.100.100/shared ~/nas
```

添加到启动项：
```bash
# 系统偏好设置 → 用户与群组 → 登录项 → 添加 mount-nas.sh
```

## 🔍 故障排查

### 问题 1：在家无法连接

**症状**：昨天配置后，在家连不上 NAS，到公司能连上

**可能原因**：
1. Tailscale 服务未启动
2. NAS 防火墙阻止 Tailscale
3. Tailscale 配置错误

**排查步骤**：

```bash
# 1. 检查 Tailscale 是否运行
tailscale status | grep nas

# 2. 如果没有 NAS，说明 Tailscale 未启动或未加入网络
# 需要到公司后检查 NAS 的 Tailscale 服务

# 3. 检查 Tailscale 日志
# 群晖: /var/log/tailscaled.log
# QNAP: /var/log/tailscale.log
```

**临时解决方案**：
- 在公司：直接用局域网 IP (192.168.x.x)
- 在家/远程：等 Tailscale 修复，或用 Mac mini 中转

### 问题 2：挂载失败

**症状**：`mount` 命令报错

**排查步骤**：

```bash
# 1. 检查 Samba 服务是否运行
# 在 NAS 上运行
netstat -tulnp | grep 445

# 2. 检查防火墙
# 确保 445 端口开放

# 3. 检查用户名密码
# 尝试用浏览器访问 \\192.168.x.x\shared
```

### 问题 3：Tailscale IP 变化

**症状**：挂载点失效

**原因**：Tailscale IP 可能会变（很少见）

**解决**：
```bash
# 使用 Tailscale MagicDNS（稳定的域名）
# 在 Tailscale 管理界面启用 MagicDNS
# 然后用域名代替 IP: nas.tail-xxxxx.ts.net
mount -t cifs //nas.tail-xxxxx.ts.net/shared /mnt/nas
```

## 📋 待办事项

- [ ] 确认 NAS 型号
- [ ] 获取 NAS 管理界面 URL
- [ ] 在 NAS 上安装 Tailscale
- [ ] 配置 Samba 共享
- [ ] 测试本地连接（Mac mini/Node PC）
- [ ] 测试远程连接（美国/香港 VPS）
- [ ] 配置持久化挂载
- [ ] 记录 NAS 的 Tailscale IP
- [ ] 更新网络拓扑图

## 📚 参考资料

- Tailscale 官方文档: https://tailscale.com/kb/
- 群晖 Samba 配置: https://kb.synology.com/
- 威联通 Samba 配置: https://www.qnap.com/

---
id: node-pc-device
version: 1.0.0
created: 2026-02-10
changelog:
  - 1.0.0: 初始版本 - Node PC 设备文档
---

# Node PC (西安公司)

## 📋 基本信息

| 项目 | 信息 |
|------|------|
| **位置** | 西安公司 |
| **系统** | Windows |
| **Tailscale IP** | 100.97.242.124 |
| **局域网 IP** | 192.168.1.3 (待确认) |
| **主机名** | node |
| **用途** | 计算设备、后台任务 |

---

## 🔌 连接方式

### 通过 Tailscale

```bash
# SSH 连接（需要在 Windows 上启用 SSH）
ssh <user>@100.97.242.124

# 或使用别名
ssh zenithjoy-pc

# PowerShell 远程
# 需要先配置 WinRM
```

### 通过局域网（在公司）

```bash
# 直接连接
ssh <user>@192.168.1.3
```

### 远程桌面

```bash
# 从 Mac
# Microsoft Remote Desktop → 添加 PC
# 地址: 100.97.242.124 (Tailscale)

# 从 Windows
mstsc /v:100.97.242.124
```

---

## 🌐 网络配置

### Tailscale

- **Tailscale IP**: 100.97.242.124
- **状态**: ✅ 在线（active; relay "nue"）
- **Exit Node**: 未启用
- **连接方式**: relay（中转）

**注意**: 使用 relay 连接，性能可能不如 direct。

---

## 💻 用途

### 1. 计算任务

- 数据处理
- 后台任务
- 批量操作

### 2. 文件处理

- 与 NAS 共享文件
- 与 Mac mini 共享文件
- 文件格式转换

### 3. 网络扫描

- 局域网设备发现
- NAS IP 查找
- 网络诊断

---

## 📂 常用目录

| 目录 | 用途 |
|------|------|
| `C:\Users\<user>\` | 用户目录 |
| `C:\Projects\` | 项目目录（如有） |
| `Z:\` | NAS 挂载点（待配置） |

---

## 🔧 NAS 挂载配置

### 挂载 NAS

**方法 1: 使用资源管理器**

1. 打开 Windows 资源管理器
2. 地址栏输入: `\\<nas-ip>\shared`
3. 输入用户名密码: `perfect21` / `<密码>`
4. 右键 → 映射网络驱动器 → 选择盘符（如 Z:）

**方法 2: 使用命令行**

```powershell
# 临时挂载
net use Z: \\<nas-ip>\shared /user:perfect21 <密码>

# 持久化挂载
net use Z: \\<nas-ip>\shared /user:perfect21 <密码> /persistent:yes

# 断开挂载
net use Z: /delete
```

### 通过 Tailscale IP 挂载

```powershell
# 使用 NAS 的 Tailscale IP
net use Z: \\<nas-tailscale-ip>\shared /user:perfect21 <密码>
```

---

## 🛠️ 常用操作

### 系统信息

```powershell
# 查看系统版本
systeminfo

# 查看网络配置
ipconfig /all

# 查看磁盘空间
Get-PSDrive

# 查看进程
Get-Process
```

### 网络诊断

```powershell
# 查看 Tailscale 状态
tailscale status

# 测试网络连通性
ping 100.71.32.28  # 美国 VPS

# 测试 NAS 连接
ping <nas-ip>

# 查看 ARP 表（找设备）
arp -a
```

### 网络扫描

```powershell
# 扫描局域网设备
1..254 | ForEach-Object {
  $ip = "192.168.1.$_"
  if (Test-Connection -ComputerName $ip -Count 1 -Quiet) {
    Write-Host "$ip is alive"
  }
}
```

---

## ⚠️ 已知问题

### 问题 1: Tailscale 使用 Relay 连接

**症状**: Tailscale 显示 "relay nue"，不是 direct 连接

**影响**: 性能可能较差

**待优化**:
- [ ] 检查防火墙配置
- [ ] 尝试启用 UPnP
- [ ] 配置端口转发

---

## 🔗 相关文档

- 网络拓扑: [../network/topology.md](../network/topology.md)
- NAS 配置: [../nas/setup.md](../nas/setup.md)
- Mac mini: [mac-mini.md](./mac-mini.md)
- VPN 配置: [../network/vpn.md](../network/vpn.md)

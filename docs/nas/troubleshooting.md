---
id: nas-troubleshooting
version: 1.0.0
created: 2026-02-10
changelog:
  - 1.0.0: 初始版本 - NAS 故障排查手册
---

# NAS 故障排查手册

## 🚨 当前问题记录

### 问题 #1: 昨天配置后，在家无法连接 NAS

**时间**: 2026-02-09

**症状**:
- ❌ 在家（远程）无法连接 NAS
- ✅ 在公司（局域网）可以连接 NAS

**状态**: 🔍 待排查

**可能原因**:
1. Tailscale 服务未启动或未正确配置
2. NAS 防火墙阻止 Tailscale 流量
3. NAS 的 Tailscale 配置损坏
4. NAS 未加入 Tailscale 网络

**下一步行动**:
- [ ] 到公司后检查 NAS 的 Tailscale 服务状态
- [ ] 确认 NAS 是否出现在 `tailscale status` 输出中
- [ ] 检查 NAS 的 Tailscale 日志
- [ ] 记录 NAS 型号和系统版本

---

## 📋 常见问题排查流程

### 问题类型 1: 无法连接 NAS（远程）

#### 排查步骤

**Step 1: 检查 Tailscale 网络**

```bash
# 在任意 Tailscale 设备上运行
tailscale status

# 检查是否有 NAS 设备
# 应该看到类似: 100.x.x.x  nas  user@  linux/synology  active
```

**结果判断**:
- ✅ 看到 NAS → 进入 Step 2
- ❌ 没看到 NAS → NAS 的 Tailscale 未启动，跳到「修复方案 A」

**Step 2: 测试网络连通性**

```bash
# Ping NAS 的 Tailscale IP
ping 100.x.x.x  # 替换为实际 IP

# 测试 Samba 端口
nc -zv 100.x.x.x 445
```

**结果判断**:
- ✅ Ping 通 + 端口开放 → 进入 Step 3
- ❌ Ping 不通 → Tailscale 配置问题，跳到「修复方案 B」
- ❌ Ping 通但端口不开 → Samba 服务问题，跳到「修复方案 C」

**Step 3: 测试挂载**

```bash
# Linux
mkdir -p /tmp/nas-test
mount -t cifs //100.x.x.x/shared /tmp/nas-test -o username=perfect21,password=<密码>

# macOS
mkdir -p ~/nas-test
mount -t smbfs //perfect21:<密码>@100.x.x.x/shared ~/nas-test
```

**结果判断**:
- ✅ 挂载成功 → 问题解决
- ❌ 认证失败 → 跳到「修复方案 D」
- ❌ 其他错误 → 记录错误信息，咨询专家

---

### 修复方案 A: NAS 的 Tailscale 未启动

**适用症状**: `tailscale status` 看不到 NAS

**操作步骤（需要在 NAS 上操作）**:

#### 群晖 (Synology)

```bash
# 1. 登录 DSM 管理界面
# 2. 打开 Package Center
# 3. 找到 Tailscale，查看状态
# 4. 如果未运行，点击"运行"
# 5. 如果未安装，点击"安装"
```

#### 威联通 (QNAP)

```bash
# 1. 登录 QTS 管理界面
# 2. 打开 App Center
# 3. 找到 Tailscale，查看状态
# 4. 如果未运行，点击"启动"
# 5. 如果未安装，点击"安装"
```

#### 通用 (SSH 登录 NAS)

```bash
# 检查 Tailscale 服务
sudo systemctl status tailscaled

# 如果未运行，启动服务
sudo systemctl start tailscaled

# 如果未安装，参考 setup.md 安装 Tailscale
```

---

### 修复方案 B: Tailscale 配置问题

**适用症状**: `tailscale status` 看到 NAS，但 ping 不通

**操作步骤**:

```bash
# 1. 在 NAS 上重启 Tailscale
sudo systemctl restart tailscaled

# 2. 检查 Tailscale 日志
sudo journalctl -u tailscaled -f

# 3. 尝试重新加入网络
tailscale down
tailscale up --accept-routes

# 4. 检查防火墙规则
# 群晖: 控制面板 → 安全性 → 防火墙
# 威联通: 控制台 → 系统 → 安全 → 防火墙
# 确保允许 Tailscale 流量（UDP 41641）
```

---

### 修复方案 C: Samba 服务问题

**适用症状**: Ping 通，但端口 445 不通

**操作步骤**:

```bash
# 1. 检查 Samba 服务状态
sudo systemctl status smbd

# 2. 如果未运行，启动服务
sudo systemctl start smbd

# 3. 检查 Samba 配置
sudo cat /etc/samba/smb.conf

# 4. 检查共享文件夹
# 群晖: 控制面板 → 共享文件夹
# 威联通: 控制台 → 共享文件夹
# 确保有 "shared" 文件夹，且启用了 SMB
```

---

### 修复方案 D: 认证失败

**适用症状**: 挂载时提示用户名或密码错误

**操作步骤**:

```bash
# 1. 确认用户名密码正确
# 在 NAS 管理界面检查用户 "perfect21" 是否存在

# 2. 重置密码
# 群晖: 控制面板 → 用户 → 选择用户 → 重设密码
# 威联通: 控制台 → 用户 → 选择用户 → 重设密码

# 3. 检查用户权限
# 确保用户对 "shared" 文件夹有读写权限

# 4. 重新测试挂载
```

---

## 🔍 问题类型 2: 挂载点突然失效

**症状**: 之前能用，现在突然不能用

**可能原因**:
1. NAS 重启导致 Tailscale IP 变化（罕见）
2. NAS 断电或网络中断
3. Tailscale 服务崩溃

**排查步骤**:

```bash
# 1. 检查挂载点状态
df -h | grep nas
mount | grep nas

# 2. 卸载失效的挂载点
sudo umount /mnt/nas

# 3. 检查 NAS 是否在线
tailscale status | grep nas

# 4. 重新挂载
sudo mount -a  # 如果在 /etc/fstab 中配置了
# 或手动挂载
```

---

## 🔍 问题类型 3: 性能问题（读写慢）

**症状**: 文件传输速度很慢

**可能原因**:
1. 走了 Tailscale Relay（中转）而非直连
2. 网络拥堵
3. NAS 硬盘性能瓶颈

**排查步骤**:

```bash
# 1. 检查 Tailscale 连接方式
tailscale status | grep nas

# 看到 "relay" → 走了中转，性能差
# 看到 "direct" → 直连，性能好

# 2. 如果是 relay，尝试强制直连
# 在 Tailscale 管理界面禁用 "Use DERP servers as a fallback"

# 3. 测试传输速度
# 创建 100MB 测试文件
dd if=/dev/zero of=/tmp/test100mb bs=1M count=100

# 上传到 NAS
time cp /tmp/test100mb /mnt/nas/

# 从 NAS 下载
time cp /mnt/nas/test100mb /tmp/test100mb.download

# 记录耗时，计算速度
```

---

## 📋 日志位置

### Tailscale 日志

| 系统 | 日志路径 |
|------|----------|
| 群晖 | `/var/log/tailscaled.log` |
| 威联通 | `/var/log/tailscale.log` |
| Linux | `sudo journalctl -u tailscaled` |

### Samba 日志

| 系统 | 日志路径 |
|------|----------|
| 群晖 | `/var/log/samba/` |
| 威联通 | `/var/log/samba/` |
| Linux | `/var/log/samba/` |

---

## 🔧 常用诊断命令

```bash
# 检查 Tailscale 网络
tailscale status
tailscale ping <device>
tailscale netcheck

# 检查 Samba 服务
sudo systemctl status smbd
sudo netstat -tulnp | grep 445
sudo smbstatus

# 检查挂载点
df -h
mount | grep nas
findmnt /mnt/nas

# 测试网络连通性
ping <nas-ip>
nc -zv <nas-ip> 445
telnet <nas-ip> 445

# 查看 Samba 配置
sudo cat /etc/samba/smb.conf
sudo testparm  # 验证配置正确性
```

---

## 📞 升级路径

如果以上方案都无法解决：

1. **记录详细信息**:
   - NAS 型号和系统版本
   - 错误信息截图
   - `tailscale status` 输出
   - 日志文件

2. **联系支持**:
   - Tailscale 官方支持: https://tailscale.com/contact/support
   - NAS 厂商支持:
     - 群晖: https://account.synology.com/support
     - 威联通: https://service.qnap.com/

3. **临时替代方案**:
   - 通过 Mac mini 中转访问 NAS（见 setup.md）
   - 使用局域网直连（仅在公司可用）

---

## 🔗 相关文档

- NAS 配置指南: [setup.md](./setup.md)
- 网络拓扑: [../network/topology.md](../network/topology.md)
- Tailscale 配置: [tailscale.md](./tailscale.md)

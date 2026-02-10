---
id: tailscale-detailed-solution
version: 1.0.0
created: 2026-02-10
source: ~/.claude/TAILSCALE_VPN_SOLUTION.md
changelog:
  - 1.0.0: 从全局配置迁移 Tailscale 详细方案
---

# Tailscale Exit Node 详细配置方案

## 🎯 问题描述

在中国使用 Tailscale 作为 exit node 翻墙时遇到的问题：

### 症状
1. **启用 Tailscale exit node 后网络完全断开**
   - Ping 任何 IP 都超时（100% packet loss）
   - DNS 无法解析域名
   - 浏览器无法访问任何网站

2. **Tailscale 显示 DNS 警告**
   ```
   Health check:
   - Tailscale can't reach the configured DNS servers. 
     Internet connectivity may be affected.
   ```

3. **WARP + Tailscale 冲突**
   - 同时开启两者会导致网络完全死掉
   - 单独用 WARP 无法翻墙（warp=off）
   - 单独用 Tailscale exit node 网络断开

---

## 🔍 根本原因

**Tailscale 的 DNS 配置有问题**

- Tailscale 默认会接管系统 DNS（accept-dns=true）
- 当作为 exit node 使用时，会将 DNS 设置为 127.0.2.2 和 127.0.2.3
- 如果 VPS 的 Tailscale DNS 服务无法访问，会导致所有网络请求失败
- 即使 IP 路由正常，DNS 解析失败也会让网络完全不可用

---

## ✅ 完整解决方案

### 步骤 1：修复 VPS 端的 Tailscale DNS

```bash
# 在 VPS 上执行
sudo tailscale set --accept-dns=false

# 重启 Tailscale 服务（可选）
sudo systemctl restart tailscaled

# 验证警告消失
tailscale status
# 应该没有 "Health check" 警告了
```

### 步骤 2：配置客户端（Mac/Linux/Windows）

```bash
# 在客户端机器上执行

# 1. 禁用 Tailscale DNS
tailscale set --accept-dns=false
# 或 Mac 上：
/Applications/Tailscale.app/Contents/MacOS/Tailscale set --accept-dns=false

# 2. 启用 exit node
tailscale set --exit-node=<VPS_IP>
# 例如：
tailscale set --exit-node=100.71.32.28

# 3. 验证配置
tailscale status | grep exit
# 应该显示：active; exit node

# 4. 测试翻墙
curl https://www.cloudflare.com/cdn-cgi/trace
# 应该显示：
# - ip=<VPS的公网IP>
# - loc=<VPS所在国家>（如 US）
```

### 步骤 3：验证网络正常

```bash
# 1. DNS 解析测试
nslookup google.com
# 应该返回 Google 的 IP

# 2. HTTP 访问测试
curl -I https://google.com
curl -I https://chatgpt.com
# 应该返回 HTTP 响应（不是超时）

# 3. Cloudflare trace
curl https://www.cloudflare.com/cdn-cgi/trace
# 验证：
# - ip 是 VPS IP
# - loc 是 VPS 国家
```

---

## 📋 配置检查清单

### VPS 端
```bash
# 检查 Tailscale 状态
tailscale status

# 应该显示：
# - 没有 "Health check" 警告
# - "offers exit node"（提供 exit node）
```

### 客户端
```bash
# 检查配置
tailscale status | grep exit

# 应该显示：
# <VPS_IP>  <hostname>  ...  active; exit node; relay/direct ...

# 检查 DNS（Mac）
cat /etc/resolv.conf
# 不应该有 127.0.2.2 或 127.0.2.3

# 检查 IP
curl https://www.cloudflare.com/cdn-cgi/trace | grep ip=
# 应该显示 VPS 的公网 IP
```

---

## ❓ 常见问题

### Q1: Ping 8.8.8.8 不通但网站能访问？
**A:** 正常。ICMP 可能被 VPS 或中间节点阻止，但 TCP/UDP（HTTP/HTTPS）能正常工作。

### Q2: curl 访问 ChatGPT 返回 403？
**A:** 正常。Cloudflare 识别 curl 为机器人。浏览器访问应该没问题。

### Q3: 关闭 exit node 后无法访问外网？
**A:** 在中国境内，如果本地网络被 GFW 限制，必须使用 VPN（如 Tailscale exit node）才能访问被墙网站。

### Q4: WARP 和 Tailscale 能同时用吗？
**A:** 不推荐。两者都是 VPN，会产生路由冲突。选择其中一个使用即可。

---

## 🏗️ 架构说明

### 使用 Tailscale Exit Node（推荐）

```
客户端 → Tailscale → VPS (exit node) → 外网
```

**优点：**
- 内网互联 + 翻墙一体化
- 稳定可靠
- 配置简单

**配置：**
- VPS: `sudo tailscale set --accept-dns=false`
- 客户端: `tailscale set --accept-dns=false && tailscale set --exit-node=<VPS_IP>`

### 使用其他 VPN（如 WARP）

```
客户端 → WARP → 外网
客户端 → Tailscale → VPS（内网互联）
```

**问题：**
- 两个 VPN 同时运行会冲突
- WARP 可能在某些地区不工作（warp=off）

---

## 🔧 故障排查

### 网络完全断开

```bash
# 1. 检查 exit node 状态
tailscale status | grep exit

# 2. 检查 DNS 配置
cat /etc/resolv.conf
# 如果看到 127.0.2.2，说明 Tailscale DNS 没有禁用

# 3. 禁用 Tailscale DNS
tailscale set --accept-dns=false

# 4. 重新连接
tailscale set --exit-node=<VPS_IP>
```

### DNS 无法解析

```bash
# 1. 检查系统 DNS
scutil --dns  # Mac
cat /etc/resolv.conf  # Linux

# 2. 手动设置 DNS（临时）
# Mac: 系统设置 → 网络 → WiFi → DNS → 添加 8.8.8.8

# 3. 禁用 Tailscale DNS
tailscale set --accept-dns=false
```

### VPS 端 Tailscale 重启

```bash
sudo systemctl restart tailscaled
# 等待几秒
tailscale status
```

---

## 📝 相关命令速查

```bash
# === Tailscale 常用命令 ===

# 查看状态
tailscale status

# 启用 exit node
tailscale set --exit-node=<IP>

# 关闭 exit node
tailscale set --exit-node=

# 禁用 DNS
tailscale set --accept-dns=false

# 启用 DNS
tailscale set --accept-dns=true

# 重启服务（VPS）
sudo systemctl restart tailscaled

# 停止 Tailscale
sudo tailscale down

# 启动 Tailscale
sudo tailscale up

# === 网络诊断 ===

# 测试 IP
curl https://www.cloudflare.com/cdn-cgi/trace

# 测试 DNS
nslookup google.com

# 测试连通性
ping -c 3 8.8.8.8

# 测试 HTTP
curl -I https://google.com

# 查看路由
netstat -rn | grep default  # Mac/Linux
route print  # Windows

# 查看 DNS
scutil --dns  # Mac
cat /etc/resolv.conf  # Linux
```

---

## 🎯 最终配置

### VPS (146.190.52.84)
```bash
# Tailscale 状态
tailscale status
# 应显示：
# - 没有 Health check 警告
# - offers exit node

# DNS 配置
# accept-dns=false（已设置）
```

### Mac Mini (100.86.57.69)
```bash
# 用途：开发机器
# Tailscale：内网互联
# VPN：通过 exit node 或 WARP
```

### MacBook Air (100.93.121.82)
```bash
# Tailscale 配置
tailscale set --accept-dns=false
tailscale set --exit-node=100.71.32.28

# 验证
tailscale status | grep exit
# 应显示：active; exit node

curl https://www.cloudflare.com/cdn-cgi/trace
# 应显示：ip=146.190.52.84, loc=US
```

---

## 🔗 参考链接

- [Tailscale Exit Nodes](https://tailscale.com/kb/1103/exit-nodes/)
- [Tailscale DNS](https://tailscale.com/kb/1054/dns/)

---

**记录于：** 2026-02-03  
**解决者：** Claude Code  
**验证：** ✅ MacBook Air 翻墙成功

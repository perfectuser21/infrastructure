---
id: vpn-configuration
version: 1.0.0
created: 2026-02-10
source: ~/.claude/VPN_CONFIG.md
changelog:
  - 1.0.0: 从全局配置迁移 VPN 文档
---

# VPN 翻墙配置

## 🎯 推荐配置：Tailscale Exit Node

**原因**:
- ✅ Tailscale 浏览速度比 WARP 快（实测）
- ✅ WARP 被 OpenAI 屏蔽（ChatGPT 403）
- ✅ 配置简单不冲突

**MacBook Air 配置**:
```bash
# 关闭 WARP 网页流量
warp-cli disconnect

# 启用 Tailscale exit node
/Applications/Tailscale.app/Contents/MacOS/Tailscale set --exit-node=100.71.32.28
```

**效果**:
- ✅ 所有外网通过 VPS 翻墙（快速）
- ✅ ChatGPT、Google、YouTube 都能访问
- ✅ 本地网络、飞书正常

---

## 🛡️ Cloudflare WARP 配置（备用）

如果需要 WARP（如 VSCode 连接），已通过 API 配置：

**Profile ID**: 2f9c5edf-17bf-47df-818c-ae60c988870b
**Mode**: Exclude（排除模式）
**Protocol**: MASQUE

**排除列表（这些不走 WARP）**:
- 本地 IP: 192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12
- 中国服务: douyin.com, qq.com, kuaishou.com, xiaohongshu.com, feishu.cn, dingtalk.com, taobao.com, alipay.com, baidu.com, zhihu.com, bilibili.com, weibo.com, jd.com
- ChatGPT: openai.com, chatgpt.com, oaiusercontent.com, oaistatic.com, auth0.com

**管理后台**: https://one.dash.cloudflare.com/zenithjoy/settings/devices

**API 管理**:
```bash
# 凭据位置
source ~/.credentials/cloudflare.env

# 查看配置
curl -s "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/devices/policy" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"

# 修改 Exclude 列表
curl -s -X PATCH "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/devices/policy" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"exclude": [...]}'
```

---

## 🌐 Tailscale 配置

### VPS (Exit Node)

```bash
# DNS 配置
sudo tailscale set --accept-dns=false

# Exit node 已启用
# 客户端连接：tailscale set --exit-node=100.71.32.28
```

### 设备 IP

| 设备 | Tailscale IP | 状态 |
|------|--------------|------|
| 美国 VPS | 100.71.32.28 | ✅ Exit Node |
| 香港 VPS | 100.86.118.99 | ✅ 在线 |
| Mac mini | 100.86.57.69 | ✅ 在线 |
| Node PC | 100.97.242.124 | ✅ 在线 |
| MacBook Air | 100.93.121.82 | ✅ 在线 |
| NAS | TBD | ⚠️ 待配置 |

---

## ⚠️ Mac Mini 问题

**现象**: 使用 Tailscale exit node 时很卡，direct 连接丢包 50%

**临时方案**:
- 在 Mac Mini 上装 WARP，用 WARP 翻墙
- 或接受慢速度（如不常用）

**待排查**:
- [ ] 检查 Mac Mini 网络配置
- [ ] 测试 Mac Mini → VPS 的网络质量
- [ ] 考虑换用 WARP 或其他 VPN

---

## 🔐 X-Ray Reality VPN

### 服务器端

| 服务器 | 端口 | 配置文件 | 订阅地址 |
|--------|------|----------|----------|
| 美国 VPS | 443 | `/opt/vpn/features/xray-reality/config/xray-server.json` | `http://146.190.52.84:8080/clash/<uuid>` |
| 香港 VPS | 443 | `/opt/xray-reality/config.json` | `http://43.154.85.217:8080/clash/<uuid>` |

### 客户端

**订阅方式**:
- Clash: 添加订阅地址（见上表）
- V2Ray: 扫描二维码或导入配置

**账号数**:
- 美国 VPS: 10 个
- 香港 VPS: 5 个

---

## 📋 凭据管理

所有 VPN 相关凭据存储在：

```
~/.credentials/cloudflare.env
~/.credentials/xray-accounts.json (如有)
```

**Cloudflare API Token**:
```bash
CLOUDFLARE_ACCOUNT_ID=1e06934c7e8134910ffcc5b7761fbc68
CLOUDFLARE_API_TOKEN=<见 ~/.credentials/cloudflare.env>
```

**权限**: Account → Zero Trust → Edit

---

## 🔗 相关文档

- 网络拓扑: [topology.md](./topology.md)
- Tailscale 详细方案: `~/.claude/TAILSCALE_VPN_SOLUTION.md` (待迁移)
- X-Ray 客户端配置: `~/.claude/XRAY_CLIENT_CONFIG.md` (待迁移)
- VPN 测试结果: `~/.claude/VPN_TEST_RESULTS.md` (待迁移)

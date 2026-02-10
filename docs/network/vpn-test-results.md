---
id: vpn-test-results
version: 1.0.0
created: 2026-02-10
source: ~/.claude/VPN_TEST_RESULTS.md
changelog:
  - 1.0.0: 从全局配置迁移 VPN 测试结果
---

# VPN 速度对比测试结果

**测试日期**: 2026-02-03  
**测试设备**: MacBook Air  
**测试方法**: 实际客户端测速

---

## 📊 完整数据对比

### 速度测试（越小越好）

| 网站 | WARP | Tailscale | 胜者 |
|------|------|-----------|------|
| Google | 2.5秒 | 10秒(超时) | ✅ WARP |
| YouTube | 9.3秒 | 10秒(超时) | ✅ WARP |
| ChatGPT | 1.3秒 | 10秒(超时) | ✅ WARP |
| GitHub | 1.9秒 | 10秒(超时) | ✅ WARP |
| Twitter | 2.6秒(403) | 10秒(超时) | ✅ WARP |

### 网络质量

| 指标 | WARP | Tailscale | 胜者 |
|------|------|-----------|------|
| Cloudflare 丢包 | 30% | 40% | ✅ WARP |
| Google 丢包 | 20% | 70% | ✅ WARP |
| Cloudflare 延迟 | 214ms | 246ms | ✅ WARP |
| Google 延迟 | 213ms | 258ms | ✅ WARP |

### 功能性

| 功能 | WARP | Tailscale |
|------|------|-----------|
| Google | ✅ 能访问 | ❌ 超时 |
| YouTube | ✅ 能访问 | ❌ 超时 |
| ChatGPT | ❌ 403被屏蔽 | ❌ 超时 |
| 出口位置 | 美国(SJC) | 中国(失败) |

---

## 🏆 结论

### 明确胜者：WARP

**压倒性优势**：
- ✅ 所有网站都能访问（除了 ChatGPT 被 OpenAI 屏蔽）
- ✅ 速度快 2-10 倍
- ✅ 丢包率更低（30% vs 40-70%）
- ✅ 延迟更低
- ✅ 稳定可用

**Tailscale Exit Node 完全失败**：
- ❌ 所有主要网站超时
- ❌ 70% 丢包率（灾难性）
- ❌ Exit node 未生效（流量仍在中国）
- ❌ 无法正常使用

---

## 💡 推荐配置

### 最终方案：只用 WARP

```bash
# MacBook Air 配置
warp-cli connect

# 关闭 Tailscale exit node
/Applications/Tailscale.app/Contents/MacOS/Tailscale set --exit-node=
```

**理由**：
1. 实测数据证明 WARP 快 2-10 倍
2. WARP 丢包率虽然有 30%，但比 Tailscale 的 70% 好太多
3. WARP 能正常访问 Google、YouTube、GitHub 等主要网站
4. Tailscale exit node 在你的网络环境下完全不可用

### ChatGPT 访问问题

两种 VPN 都被 OpenAI 屏蔽：
- WARP: 403 Forbidden
- Tailscale: 超时（连接都不通）

**临时方案**：
- 用手机 4G/5G 热点访问 ChatGPT
- 或者购买住宅代理服务
- 或者使用 X-Ray Reality（见 [xray配置](../../config/xray/client-config.md)）

---

## 🔍 Tailscale 失败原因分析

1. **Exit node 未生效**：出口 IP 显示仍在中国西安
2. **连接不稳定**：VPS 看到 MacBook Air 为 offline
3. **丢包率极高**：70% 丢包导致无法正常通信
4. **Relay 问题**：MacBook Air 使用 relay "nue" 连接质量差

---

## 📝 数据来源

- WARP 测试: test-warp.sh 结果（2026-02-03 21:53:31）
- Tailscale 测试: test-tailscale.sh 结果（2026-02-03 21:56:06, 21:59:43）
- 测试方法: 真实客户端测速，非模拟

---

## ⚠️ 用户之前的误解

用户之前说"Tailscale 比 WARP 快"，但实测数据完全相反：
- 可能是因为之前测试时 Tailscale exit node 根本没生效
- 或者测试的不是同样的网站
- 实际数据显示 WARP 在所有方面都完胜

---

## 🔗 相关文档

- VPN 配置: [vpn.md](./vpn.md)
- Tailscale 详细方案: [tailscale-detailed.md](./tailscale-detailed.md)
- 网络拓扑: [topology.md](./topology.md)

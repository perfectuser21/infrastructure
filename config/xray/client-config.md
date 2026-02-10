---
id: xray-client-config
version: 1.0.0
created: 2026-02-10
source: ~/.claude/XRAY_CLIENT_CONFIG.md
changelog:
  - 1.0.0: 从全局配置迁移 X-Ray 客户端配置
---

# X-Ray Reality 客户端配置

## 📋 服务器信息

| 参数 | 值 |
|------|-----|
| **协议** | VLESS + Reality |
| **地址** | 146.190.52.84 |
| **端口** | 443 |
| **UUID** | 53d920b2-7ff2-479e-b613-5ce43b2c21f9 |
| **Flow** | xtls-rprx-vision |
| **ServerName** | www.microsoft.com |
| **ShortId** | cff6b61f1b36c5a6 |
| **PrivateKey** | kKZZPsn5tkK11T8U0WXF5q6pcQuFOUww_dr0ohVAzno |

---

## 🎯 推荐配置方案：WARP + X-Ray

### 用途分配
- **WARP**: 日常上网（Google、YouTube、GitHub 等）- 快速
- **X-Ray**: 专门访问 ChatGPT - 不易被屏蔽

---

## 💻 MacOS 客户端推荐

### V2rayU (免费, 图形界面)
1. 下载: https://github.com/yanue/V2rayU/releases
2. 添加服务器配置
3. 设置为 PAC 模式或规则模式
4. 只路由 ChatGPT 流量通过 X-Ray

### Clash Verge (推荐)
1. 下载: https://github.com/clash-verge-rev/clash-verge-rev/releases
2. 导入下面的配置

---

## ⚙️ Clash 配置示例

```yaml
proxies:
  - name: "VPS-Xray"
    type: vless
    server: 146.190.52.84
    port: 443
    uuid: 53d920b2-7ff2-479e-b613-5ce43b2c21f9
    network: tcp
    tls: true
    udp: true
    flow: xtls-rprx-vision
    servername: www.microsoft.com
    reality-opts:
      public-key: [需要从 PrivateKey 生成]
      short-id: cff6b61f1b36c5a6

rules:
  - DOMAIN-SUFFIX,openai.com,VPS-Xray
  - DOMAIN-SUFFIX,chatgpt.com,VPS-Xray
  - DOMAIN-SUFFIX,oaiusercontent.com,VPS-Xray
  - DOMAIN-SUFFIX,oaistatic.com,VPS-Xray
  - MATCH,DIRECT
```

---

## 🔑 PublicKey 生成方法

因为配置中只有 PrivateKey，需要生成对应的 PublicKey：

### 方法 1: 在线工具
访问: https://v2ray.com/awesome/tools.html
使用 X25519 工具，输入 PrivateKey 生成 PublicKey

### 方法 2: 命令行
```bash
# 在 VPS 上运行
xray x25519 -i kKZZPsn5tkK11T8U0WXF5q6pcQuFOUww_dr0ohVAzno
```

---

## 🚀 最简单方案（不用配置客户端）

如果你已经有 X-Ray 客户端配置（之前可能设置过），直接：

1. **打开 X-Ray 客户端**（V2rayU 或 Clash）
2. **启用代理**
3. **设置规则**：只让 ChatGPT 走 X-Ray
4. **WARP 继续处理其他流量**

---

## ✅ 验证

连接成功后测试：
```bash
# 通过 X-Ray 代理访问 ChatGPT
curl --proxy socks5://127.0.0.1:1080 https://chatgpt.com
```

应该返回 200 而不是 403。

---

## 🔧 故障排除

| 问题 | 解决方案 |
|------|----------|
| **连接不上** | 检查 VPS 防火墙是否开放 443 端口 |
| **ChatGPT 还是 403** | X-Ray 可能也被屏蔽了，考虑换端口或协议 |
| **速度慢** | Reality 协议理论上应该很快，检查路由 |

---

## 📝 备注

- X-Ray Reality 是目前最难被检测的翻墙协议
- 伪装成访问 Microsoft 官网，几乎无法被识别
- 比 WARP 更不容易被 OpenAI 屏蔽

---

## 🔗 相关文档

- VPN 配置总览: [../docs/network/vpn.md](../docs/network/vpn.md)
- 服务器端配置: `/opt/vpn/features/xray-reality/config/xray-server.json`

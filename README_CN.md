# Xray Easy (VLESS REALITY + XHTTP)

**Language:** [Русский](./README.md) | [English](./README_ENG.md) | [Chinese](./README_CN.md)

---

# 🇨🇳 中文版

一个通用且完全自动化的 bash 脚本，用于部署基于 **Xray-core** 的专业 VPN 服务器。旨在使用先进的 **VLESS-REALITY** 和 **XHTTP** 协议绕过深度包检测 (DPI) 系统和现代防火墙。

## 为什么使用此脚本？

手动配置安全的代理服务器需要了解 Xray 配置、密钥生成、SSL 证书设置、复杂的路由设置和基本的服务器安全防护。此脚本在几分钟内**自动完成所有工作**，并为您提供方便的交互式管理菜单。

## 主要特点

* **现代协议：** 使用 **VLESS-TCP-XTLS-Vision** 和全新的 **XHTTP** 协议（取代了现在容易被阻断的旧版 WebSocket）。
* **三种安装模式：**
    1. **手动 REALITY：** 无需自有域名的快速安装（伪装成第三方网站）。
    2. **RealiTLScanner：** 脚本将自动扫描网络并找到完美的 SNI 伪装网站，以隐藏您的 IP。
    3. **自定义域名 + Web 面板：** 安装 Nginx，获取 Let's Encrypt 证书，并创建一个隐藏的 Web 面板。面板包含每个用户的订阅链接 (Base64) 和二维码。伪装网站（博客或作品集）将放置在主页上。
* **流量统计：** 内置 Xray API，用于监控每个独立用户的下载和上传流量（MB/GB）。
* **集成 Cloudflare WARP：** 解决 VPS IP 被禁用的问题！一键安装 WARP，并通过 Cloudflare 将流量路由到 *Apple, Meta, Google 或 OpenAI (ChatGPT)*。包含自动重连 (cron) 功能。
* **终端内的二维码：** 该脚本能够直接在 SSH 控制台中生成并输出巨大的、可扫描的配置二维码！
* **服务器安全：** 自动配置 UFW（防火墙）、Fail2ban（防止 SSH 暴力破解）、TCP BBR（网络加速），并安全地更改默认 SSH 端口。
* **灵活配置：** 支持即时更改连接端口（443，8443）、uTLS 指纹（chrome，ios，randomized）以及重命名用户。脚本还会自动进行配置备份！

## 要求

* 运行 **Debian 11/12** 或 **Ubuntu 20.04/22.04/24.04** 的干净服务器。
* `root` 权限。
* *（可选）* 如果您想使用 Web 面板订阅功能，需要一个已注册的域名。

## 安装

在您的服务器上以 `root` 身份运行此命令：

```bash
wget -qO xray_easy.sh https://raw.githubusercontent.com/FlexEbat/xray_easy_install/main/xray_easy.sh && chmod +x xray_easy.sh && ./xray_easy.sh
```

## 使用方法和主菜单

初始安装后，再次运行 `./xray_easy.sh` 命令将打开**管理面板**：

```text
=== Xray Pro Admin Panel ===
1) 用户管理
2) WARP 路由管理
3) 安装/卸载 Cloudflare WARP
4) 配置设置 (端口 / FP)
5) 更新 Xray-core
6) 测试 (Speedtest / Bench...)
7) 服务状态
8) 系统备份 (Backup)
9) 流量统计 (Traffic)
10) 卸载 xray
0) 退出
```

### 实用场景

* **绕过 IP 封锁（ChatGPT / Instagram 等）：** 许多 VPS 的 IP 地址被各种服务屏蔽或加载内容缓慢。使用 WARP 可能会解决这个问题（但不能保证 100% 有效）。进入菜单 3 安装 WARP。然后在菜单 2 中添加所需的路由（例如 geosite:openai 和 geosite:meta）。现在 Xray 将通过 Cloudflare 路由这些流量。
* **更改指纹（伪装）：** 如果您的服务商正在对您进行限速，请进入菜单 `4` 并将 uTLS 指纹从 `chrome` 更改为 `firefox` 或 `randomized`。
* **便捷的订阅功能：** 如果您为朋友或家人设置服务器，请在安装时选择“模式 3”。脚本将生成类似 `https://your-domain:2053/secret-hash_sub` 的链接。只需将此链接粘贴到客户端应用程序 (V2rayNG, Nekobox, Streisand, FoXray) 中，配置就会自动更新！

---

### ⚠️ 免责声明

本项目仅供教育和研究目的开发，用于研究最小化数字足迹和确保在线用户隐私的方法。本脚本旨在测试绕过地理屏蔽和深度包检测 (DPI) 系统的方法，并按“原样” (AS IS) 提供。作者对任何滥用此工具、可能导致的资源屏蔽或违反当地法律的行为不承担任何责任。您在使用此代码时需自行承担风险，并对其使用的所有后果承担全部责任。

*作者不鼓励也不支持任何非法活动。*

---

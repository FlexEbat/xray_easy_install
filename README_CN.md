## 重要提示

**注意：** 本项目及文档的原始语言为俄语。该分支（Fork）专门针对**俄语用户群体**进行优化和适配，部分内置资源或默认配置可能更符合俄罗斯网络环境。

-----

# Xray Easy (VLESS REALITY + XHTTP)

 **语言:** [Русский](./README.md) | [English](./README_ENG.md) | [Chinese](./README_CN.md)

-----

# 🇨🇳 中文版本

这是一个通用且高度自动化的 Bash 脚本，用于部署基于 **Xray-core** 的专业级 VPN 服务器。该脚本专为绕过深度数据包检测系统（如俄罗斯的 DPI ТСПУ）和现代防火墙而设计，采用了先进的 **VLESS-REALITY** 和 **XHTTP** 协议。

## 为什么选择这个脚本？

手动配置安全的代理需要具备 Xray 配置、密钥生成、SSL 证书设置、复杂路由（以确保 ChatGPT 正常工作）以及服务器基础安全防护等知识。该脚本可以在几分钟内**全自动完成所有工作**，并为您提供一个方便的交互式菜单进行管理。

## 主要特性

* **现代协议：** 支持 **VLESS-TCP-XTLS-Vision** 和全新的 **XHTTP**（用于替代已开始被封锁的旧版 WebSocket）。
* **三种安装模式：**
    1. **手动 REALITY：** 无需自有域名即可快速安装（伪装成其他网站）。
    2. **RealiTLScanner：** 脚本会自动扫描网络，为您寻找最理想的“目标网站”来掩盖您的 IP。
    3. **自有域名 + Web 面板：** 脚本将安装 Nginx，获取 Let's Encrypt 证书并启动隐藏的 Web 面板。面板包含每个用户的订阅链接（Base64）和二维码。域名主页将显示一个伪装页面（如博客或作品集）。
* **流量统计：** 内置 Xray API，用于监控每个用户的上传和下载流量（MB/GB）。
* **Cloudflare WARP 集成：** 解决主机 IP 被封锁的问题！一键安装 WARP，并允许将指向 *Apple, Meta, Google 或 OpenAI (ChatGPT)* 的流量通过 Cloudflare 转发。包含自动重连功能 (cron)。
* **终端二维码：** 脚本支持在 SSH 终端窗口直接生成并显示大尺寸、可扫描的二维码。
* **服务器安全：** 自动配置 UFW（防火墙）、Fail2ban（防止 SSH 暴力破解）、启用 TCP BBR（网络加速）以及安全地更改默认 SSH 端口。
* **灵活配置：** 支持随时更改连接端口（443, 8443）、uTLS 指纹（chrome, ios, randomized）和重命名用户。脚本会自动备份配置文件！

## 要求

* 全新的 **Debian 11/12** 或 **Ubuntu 20.04/22.04/24.04** 系统。
* 拥有 `root` 权限。
* *(可选)* 如果要使用订阅 Web 面板功能，需要一个已注册的域名。

## 安装

在您的服务器上以 `root` 身份运行以下命令：

```bash
wget -qO test.sh https://raw.githubusercontent.com/FlexEbat/xray_easy_install/main/xray_easy.sh && chmod +x xray_easy.sh && sudo ./xray_easy.sh
```

## 使用方法与主菜单

完成首次安装后，再次运行 `./xray_easy.sh` 即可打开**控制面板**：

```text
=== Xray Easy ===
1) 用户管理 (添加、删除、重命名、显示二维码)
2) WARP 路由管理 (为特定网站配置分流)
3) 安装/卸载 Cloudflare WARP
4) 配置设置 (更改端口和 uTLS 指纹)
5) 更新 Xray-core
6) 测试 (Speedtest, Bench, IP 封锁检查)
7) 服务状态
8) 卸载服务器
9) 流量统计
0) 退出
```

### 实用场景

* **解锁 ChatGPT / Instagram：** 许多 VPS 的 IP 地址被 OpenAI 屏蔽或加载图片缓慢。进入菜单 `3` 安装 WARP，然后在菜单 `2` 中添加 `geosite:openai` 和 `geosite:meta` 路由。现在 Xray 将通过 Cloudflare 发送这些流量，一切都将恢复正常！
* **更改指纹（伪装）：** 如果运营商对流量进行限速（Shaping），进入菜单 `4` 将 uTLS Fingerprint 从 `chrome` 更改为 `randomized` 或 `ios`。
* **便捷订阅：** 如果您是为朋友/家人设置服务器，请在安装时选择“模式 3”。脚本会生成类似 `https://your-domain:2053/secret-hash_sub` 的链接。只需将此链接粘贴到客户端软件（V2rayNG, Nekobox, Streisand, FoXray）中，配置即可自动更新！

-----

### 免责声明

本项目仅用于教育和网络测试目的。作者不对任何滥用此脚本的行为负责。

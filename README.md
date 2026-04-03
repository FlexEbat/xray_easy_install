# 🚀 Xray Easy (VLESS REALITY + XHTTP)

🌍 **Language:** [English](#english-version) | [Русский](#русская-версия)

---

# 🇬🇧 English Version

An all-in-one, highly automated bash script for deploying and managing a professional-grade **Xray-core** VPN server. Designed to bypass deep packet inspection (DPI) and modern firewalls using the latest **VLESS-REALITY** and **XHTTP** protocols.

## 🎯 Why this script?
Setting up a secure proxy from scratch requires configuring Xray, generating keys, dealing with SSL certificates, setting up routing for AI tools (like ChatGPT), and securing the server. This script does **all of that automatically** in a few minutes while providing an interactive, user-friendly terminal menu for future management.

## ✨ Key Features
*   **Next-Gen Protocols:** Uses **VLESS-TCP-XTLS-Vision** and the brand-new **XHTTP** (which replaces the deprecated WebSocket).
*   **Three Installation Modes:**
    1.  **Manual REALITY:** Setup without a domain (stealth SNI spoofing).
    2.  **RealiTLScanner:** Automatically scans and finds the best camouflage domain for your server's IP.
    3.  **Custom Domain + Web Panel:** Installs Nginx, generates Let's Encrypt SSL, and hosts a hidden Web Panel where users can get their subscription links (Base64) and QR codes.
*   **Traffic Statistics:** Built-in Xray API integration to monitor download/upload traffic (in MB/GB) per user.
*   **Cloudflare WARP Integration:** Automatically installs WARP and lets you route specific traffic (e.g., OpenAI/ChatGPT, Meta, Google) through Cloudflare to bypass localized bans on datacenter IPs. Includes auto-reconnect cron jobs.
*   **Terminal QR Codes:** Generate and display large, scannable QR codes for user configs directly in your SSH terminal!
*   **Server Security:** Automatically configures UFW (Firewall), Fail2ban (SSH brute-force protection), BBR (TCP optimization), and safely changes your SSH port.
*   **Dynamic Configuration:** Easily change incoming ports, uTLS fingerprints (e.g., chrome, ios, randomized), and rename users on the fly. 

## 📋 Prerequisites
*   A server running **Debian 11/12** or **Ubuntu 20.04/22.04/24.04**.
*   Root privileges.
*   *(Optional)* A registered domain name if you want to use the Web Panel feature.

## 🚀 Installation

Run the following command as `root` on your server:

```bash
wget -qO test.sh https://raw.githubusercontent.com/YOUR_GITHUB_NAME/YOUR_REPO/main/test.sh && chmod +x test.sh && sudo ./test.sh
```
*(Note: Replace the URL with the actual raw link to your script on GitHub).*

## 🛠 Usage & Main Menu
After the initial installation, running `./test.sh` again will open the **Admin Panel**:

```text
=== Xray Pro Admin Panel ===
1) Manage Users (Add, Remove, Rename, Show QR/Links)
2) Manage WARP Routing (Route specific sites via WARP)
3) Install/Uninstall Cloudflare WARP
4) Configure Configs (Change Ports, uTLS Fingerprint)
5) Update Xray-core
6) Server Tests (Speedtest, Ping, Geoblock check)
7) Check Services Status
8) Uninstall Server completely
9) Traffic Statistics
0) Exit
```

### 💡 Use Cases
*   **Unblocking ChatGPT/OpenAI:** Datacenter IPs are often blocked by AI services. Go to Menu `3` to install WARP, then Menu `2` to route `geosite:openai` through WARP. ChatGPT will work flawlessly!
*   **Changing Fingerprint:** If your ISP is throttling your connection, go to Menu `4` and change the uTLS fingerprint from `chrome` to `randomized` or `ios`.
*   **Auto-Subscriptions:** If you choose Mode 3 during setup, the script creates a unique `.html` page for every user. You can send this link to your friends, and they can paste the Base64 Sub-URL directly into apps like v2rayNG, Nekobox, or Vultr.

---

### ⚠️ Disclaimer
This project is for educational and network testing purposes only. The author is not responsible for any misuse of this script. / Данный проект создан исключительно в образовательных целях и для тестирования сетей. Автор не несет ответственности за ненадлежащее использование данного скрипта.

# Xray Easy (VLESS REALITY + XHTTP)

**Language:** [Русский](./README.md) | [English](./README_ENG.md) | [Chinese](./README_CN.md)

---

# 🇬🇧 English Version

A universal and fully automated bash script for deploying a professional VPN server based on **Xray-core**. Designed to bypass Deep Packet Inspection (DPI) systems and modern firewalls using the advanced **VLESS-REALITY** and **XHTTP** protocols.

## Why use this script?

Manually configuring a secure proxy requires knowledge of Xray configuration, key generation, SSL certificate setup, complex routing, and basic server security. This script does **absolutely everything automatically** in a couple of minutes, providing you with a convenient interactive menu for management.

## Key Features

* **Modern Protocols:** Uses **VLESS-TCP-XTLS-Vision** and the brand new **XHTTP** (which replaces the deprecated WebSocket that is now easily blocked).
* **Three Installation Modes:**
    1. **Manual REALITY:** Quick setup without your own domain (masks as a third-party site).
    2. **RealiTLScanner:** The script will automatically scan the network and find the perfect SNI donor site to mask your IP.
    3. **Custom Domain + Web Panel:** Installs Nginx, obtains Let's Encrypt certificates, and creates a hidden Web Panel. It includes subscription links (Base64) and QR codes for each user. A fake site (blog or portfolio) will be placed on the main page to hide your proxy.
* **Traffic Statistics:** Built-in Xray API to monitor how many Megabytes/Gigabytes each individual user has downloaded and uploaded.
* **Cloudflare WARP Integration:** Solves the problem of hosting IP bans! Installs WARP and allows you to route traffic to *Apple, Meta, Google, or OpenAI (ChatGPT)* through Cloudflare in a couple of clicks. Includes auto-reconnect (cron).
* **QR codes right in the terminal:** The script can generate and output huge, scannable QR codes for setup directly in the SSH console!
* **Server Security:** Automated configuration of UFW (Firewall), Fail2ban (SSH brute-force protection), TCP BBR (network acceleration), and safely changes the default SSH port.
* **Flexible Configuration:** Ability to change connection ports (443, 8443), uTLS fingerprints (chrome, ios, randomized) on the fly, and rename users. The script also handles configuration backups automatically!

## Requirements

* A clean server running **Debian 11/12** or **Ubuntu 20.04/22.04/24.04**.
* `root` privileges.
* *(Optional)* A registered domain if you want to use the Web Panel subscription feature.

## Installation

Run this command as `root` on your server:

```bash
wget -qO xray_easy.sh https://raw.githubusercontent.com/FlexEbat/xray_easy_install/main/xray_easy.sh && chmod +x xray_easy.sh && ./xray_easy.sh
Usage and Main Menu

After the initial installation, running the ./xray_easy.sh command again will open the Admin Panel:

code
Text
download
content_copy
expand_less
=== Xray Easy Admin Panel ===
1) Manage users
2) Manage WARP routes
3) Install/Uninstall Cloudflare WARP
4) Config settings (Ports / FP)
5) Update Xray-core
6) Tests (Speedtest / Bench...)
7) Service status
8) Backup system
9) Traffic statistics
10) Uninstall xray
0) Exit
Useful Scenarios

Unblocking ChatGPT / Instagram: Many VPS IP addresses are blocked by OpenAI or load images slowly. Go to menu 3 and install WARP. Then in menu 2, add the geosite:openai and geosite:meta routes. Now Xray will route this traffic through Cloudflare — everything will fly!

Changing the Fingerprint (Masking): If your provider is throttling your speed, go to menu 4 and change the uTLS Fingerprint from chrome to firefox or randomized.

Easy Subscriptions: If you're setting up a server for friends/family, choose "Mode 3" during installation. The script will generate links like https://your-domain:2053/secret-hash_sub. Just paste this link into the client app (V2rayNG, Nekobox, Streisand, FoXray), and the configs will update automatically!

⚠️ Disclaimer

This project is developed solely for educational and research purposes to study methods of minimizing digital footprints and ensuring user privacy online. The script is intended for testing ways to bypass geo-blocking and Deep Packet Inspection (DPI) systems, and is provided "AS IS". The author is not responsible for any misuse of this tool, possible blocking of your resources, or violation of local laws. You use this code at your own risk, assuming full responsibility for all consequences of its use.

The author does not encourage or endorse any illegal activity.

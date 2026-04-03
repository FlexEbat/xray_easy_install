#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

CONF_FILE="/etc/xray_admin.conf"
USERS_FILE="/etc/xray_users.conf"

if [[ "$EUID" -ne 0 ]]; then
  echo -e "${RED}[ОШИБКА] Скрипт должен быть запущен от имени root!${NC}"
  exit 1
fi

generate_xray_config() {
    WARP_JSON_ARRAY=""
    WARP_RULE=""
    if [[ -n "$WARP_DOMAINS" ]]; then
        WARP_JSON_ARRAY=$(echo "$WARP_DOMAINS" | sed 's/,/","/g')
        WARP_RULE="{ \"type\": \"field\", \"domain\":[\"$WARP_JSON_ARRAY\"], \"outboundTag\": \"warp\" },"
    fi

    VISION_CLIENTS=""
    WS_CLIENTS=""
    SHORT_IDS=""

    while IFS=":" read -r U_NAME U_UUID U_SHORT U_SECRET || [[ -n "$U_NAME" ]]; do
        if [[ -z "$U_NAME" ]]; then continue; fi
        # Добавлен параметр "email" для сбора статистики трафика
        VISION_CLIENTS+="$(printf '{"id":"%s","flow":"xtls-rprx-vision","email":"%s"},' "$U_UUID" "$U_NAME")"
        WS_CLIENTS+="$(printf '{"id":"%s","email":"%s"},' "$U_UUID" "$U_NAME")"
        SHORT_IDS+="$(printf '"%s",' "$U_SHORT")"
    done < "$USERS_FILE"

    VISION_CLIENTS="${VISION_CLIENTS%,}"
    WS_CLIENTS="${WS_CLIENTS%,}"
    SHORT_IDS="${SHORT_IDS%,}"

    if [[ "$HAS_DOMAIN" == "true" ]]; then
        SOCKET_INBOUND=",
        {
            \"listen\": \"/dev/shm/xray.sock\",
            \"protocol\": \"vless\",
            \"settings\": { \"clients\": [$WS_CLIENTS], \"decryption\": \"none\" },
            \"streamSettings\": {
                \"network\": \"xhttp\",
                \"xhttpSettings\": { \"path\": \"$NGINX_WS_PATH\" }
            }
        }"
    else
        SOCKET_INBOUND=""
    fi

    # Бэкап старого конфига перед перезаписью
    if [[ -f /usr/local/etc/xray/config.json ]]; then
        cp /usr/local/etc/xray/config.json /usr/local/etc/xray/config.json.bak
    fi

    cat <<EOF > /usr/local/etc/xray/config.json
{
    "log": { "loglevel": "warning" },
    "stats": {},
    "api": {
        "tag": "api",
        "services": ["StatsService"]
    },
    "policy": {
        "levels": { "0": { "statsUserUplink": true, "statsUserDownlink": true } },
        "system": { "statsInboundUplink": true, "statsInboundDownlink": true, "statsOutboundUplink": true, "statsOutboundDownlink": true }
    },
    "inbounds":[
        {
            "listen": "127.0.0.1",
            "port": 10085,
            "protocol": "dokodemo-door",
            "settings": { "address": "127.0.0.1" },
            "tag": "api"
        },
        {
            "listen": "0.0.0.0",
            "port": $VISION_PORT,
            "protocol": "vless",
            "settings": { "clients": [$VISION_CLIENTS], "decryption": "none" },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "target": "$REALITY_DEST:443",
                    "serverNames":["$REALITY_DEST"],
                    "privateKey": "$PRIVATE_KEY",
                    "shortIds":[$SHORT_IDS]
                }
            },
            "sniffing": { "enabled": true, "destOverride":["http", "tls", "quic"], "routeOnly": true }
        },
        {
            "listen": "0.0.0.0",
            "port": $XHTTP_PORT,
            "protocol": "vless",
            "settings": { "clients": [$WS_CLIENTS], "decryption": "none" },
            "streamSettings": {
                "network": "xhttp",
                "xhttpSettings": { "path": "$XHTTP_PATH" },
                "security": "reality",
                "realitySettings": {
                    "target": "$REALITY_DEST:443",
                    "serverNames": ["$REALITY_DEST"],
                    "privateKey": "$PRIVATE_KEY",
                    "shortIds": [$SHORT_IDS]
                }
            },
            "sniffing": { "enabled": true, "destOverride":["http", "tls", "quic"] }
        }$SOCKET_INBOUND
    ],
    "outbounds":[
        { "protocol": "freedom", "tag": "direct" },
        { "protocol": "socks", "tag": "warp", "settings": { "servers":[{"address": "127.0.0.1", "port": 40000}] } },
        { "protocol": "blackhole", "tag": "block" }
    ],
    "routing": {
        "domainStrategy": "AsIs",
        "rules":[
            { "type": "field", "inboundTag": ["api"], "outboundTag": "api" },
            { "type": "field", "protocol": ["bittorrent"], "outboundTag": "block" },
            { "type": "field", "domain":["geosite:category-ads-all"], "outboundTag": "block" },
            $WARP_RULE
            { "type": "field", "outboundTag": "direct", "network": "tcp,udp" }
        ]
    }
}
EOF

    echo -e "  [+] Проверка синтаксиса конфигурации Xray..."
    if ! /usr/local/bin/xray run -test -config /usr/local/etc/xray/config.json; then
        echo -e "${RED}[ОШИБКА] Неверный формат config.json! Xray указал на ошибку выше.${NC}"
        echo -e "${YELLOW}[!] Восстанавливаем резервную копию...${NC}"
        cp /usr/local/etc/xray/config.json.bak /usr/local/etc/xray/config.json 2>/dev/null
    else
        echo -e "  [+] Перезапуск Xray..."
        systemctl restart xray
        if ! systemctl is-active --quiet xray; then
            echo -e "${RED}  [!] Ошибка запуска Xray! Проверьте логи: journalctl -u xray -e --no-pager${NC}"
        fi
    fi
}

generate_user_pages() {
    echo -e "  [+] Генерация данных для пользователей..."
    if [[ "$HAS_DOMAIN" == "true" ]]; then
        rm -f /var/www/html/*.html /var/www/html/*_sub
        echo "$FAKE_SITE_HTML" > /var/www/html/index.html
    fi

    while IFS=":" read -r U_NAME U_UUID U_SHORT U_SECRET || [[ -n "$U_NAME" ]]; do
        if [[ -z "$U_NAME" ]]; then continue; fi
        LINK_VISION="vless://${U_UUID}@${SERVER_IP}:${VISION_PORT}?type=tcp&security=reality&pbk=${PUBLIC_KEY}&fp=${FINGERPRINT}&sni=${REALITY_DEST}&sid=${U_SHORT}&spx=%2F&flow=xtls-rprx-vision#${U_NAME}-Vision"
        LINK_XHTTP="vless://${U_UUID}@${SERVER_IP}:${XHTTP_PORT}?type=xhttp&security=reality&pbk=${PUBLIC_KEY}&fp=${FINGERPRINT}&sni=${REALITY_DEST}&sid=${U_SHORT}&path=${XHTTP_PATH}#${U_NAME}-XHTTP"

        if [[ "$HAS_DOMAIN" == "true" ]]; then
            LINK_WS="vless://${U_UUID}@${DOMAIN}:2053?type=xhttp&security=tls&fp=${FINGERPRINT}&path=${NGINX_WS_PATH}#${U_NAME}-XHTTP-CDN"
            RAW_SUB="${LINK_VISION}\n${LINK_XHTTP}\n${LINK_WS}"
            echo -e "$RAW_SUB" | base64 -w 0 > "/var/www/html/${U_SECRET}_sub"
            SUB_URL="https://${DOMAIN}:2053/${U_SECRET}_sub"

            cat <<EOF > "/var/www/html/${U_SECRET}.html"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><meta name="robots" content="noindex, nofollow">
    <title>Config for $U_NAME</title>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js"></script>
    <style>
        body { background: #121212; color: #fff; font-family: sans-serif; padding: 20px; max-width: 600px; margin: auto; }
        .card { background: #1e1e1e; padding: 20px; border-radius: 12px; margin-bottom: 20px; text-align:center;}
        .btn { background: #bb86fc; color: #000; border: none; padding: 10px; border-radius: 8px; cursor: pointer; font-weight: bold; width: 100%; margin-top: 10px; display: inline-block; text-decoration: none; box-sizing: border-box;}
        .btn-sub { background: #03dac6; }
        input.copy-input { width: 100%; padding: 10px; background: #2c2c2c; border: 1px solid #444; color: #fff; border-radius: 6px; box-sizing: border-box;}
        .qr-container { display: none; margin-top: 15px; text-align: center; background: #fff; padding: 15px; border-radius: 10px; width: fit-content; margin-inline: auto; }
        .qr-container.active { display: block; }
    </style>
</head>
<body>
    <h2>User: $U_NAME</h2>
    <div class="card">
        <h3>🔄 Auto-Subscription (Base64)</h3>
        <input type="text" class="copy-input" value="$SUB_URL" readonly onclick="this.select(); document.execCommand('copy'); alert('Copied!');">
        <button class="btn btn-sub" onclick="navigator.clipboard.writeText('$SUB_URL'); alert('Подписка скопирована!');">📋 Copy Base64 URL</button>
    </div>
    <script>function toggleQR(id, text) { let el = document.getElementById(id); if(el.innerHTML === "") { new QRCode(el, { text: text, width: 200, height: 200 }); } el.classList.toggle("active"); }</script>
    <div class="card"><h3>1. VLESS Vision REALITY</h3><button class="btn" onclick="navigator.clipboard.writeText('$LINK_VISION'); alert('Copied!');">📋 Copy</button><button class="btn" onclick="toggleQR('qr1', '$LINK_VISION')">📱 Show QR</button><div id="qr1" class="qr-container"></div></div>
    <div class="card"><h3>2. VLESS XHTTP REALITY</h3><button class="btn" onclick="navigator.clipboard.writeText('$LINK_XHTTP'); alert('Copied!');">📋 Copy</button><button class="btn" onclick="toggleQR('qr2', '$LINK_XHTTP')">📱 Show QR</button><div id="qr2" class="qr-container"></div></div>
    <div class="card"><h3>3. VLESS XHTTP + Nginx</h3><button class="btn" onclick="navigator.clipboard.writeText('$LINK_WS'); alert('Copied!');">📋 Copy</button><button class="btn" onclick="toggleQR('qr3', '$LINK_WS')">📱 Show QR</button><div id="qr3" class="qr-container"></div></div>
</body>
</html>
EOF
        fi
    done

    if [[ "$HAS_DOMAIN" == "true" ]]; then
        chown -R www-data:www-data /var/www/html
    fi
}

install_core() {
    export DEBIAN_FRONTEND=noninteractive
    apt update -y -q && apt install -y -q curl wget

    SERVER_IP=$(curl -s https://api.ipify.org | tr -d '\r\n')

    echo -e "${CYAN}=== Выбор типа установки ===${NC}"
    echo "1. Ручной ввод домена-маскировки (Только REALITY, без Nginx и веб-панели)"
    echo "2. RealiTLScanner (Авто-поиск доменов маскировки, только REALITY)"
    echo "3. Свой домен (Полная установка: Веб-панель, Nginx, SSL Let's Encrypt)"
    read -p "Выбор (1-3): " SETUP_MODE

    if [[ "$SETUP_MODE" == "1" ]]; then
        HAS_DOMAIN=false
        read -p "Введите сайт для маскировки (например, www.apple.com): " REAL_INPUT
        REALITY_DEST=$(echo "$REAL_INPUT" | tr -d '\r\n')
    elif [[ "$SETUP_MODE" == "2" ]]; then
        HAS_DOMAIN=false
        echo -e "${CYAN}Скачивание и запуск сканера... Нажмите Ctrl+C, когда найдете хороший сайт.${NC}"
        wget -qO RealiTLScanner https://github.com/XTLS/RealiTLScanner/releases/latest/download/RealiTLScanner-linux-64
        chmod +x RealiTLScanner
        ./RealiTLScanner -addr $SERVER_IP
        read -p "Скопируйте и введите выбранный сайт из списка выше: " REAL_INPUT
        REALITY_DEST=$(echo "$REAL_INPUT" | tr -d '\r\n')
        rm -f RealiTLScanner
    elif [[ "$SETUP_MODE" == "3" ]]; then
        HAS_DOMAIN=true
        echo -e "\n${YELLOW}Для работы панели необходим ваш личный домен.${NC}"
        read -p "Введите ВАШ домен (например, vpn.example.com): " DOMAIN_INPUT
        DOMAIN=$(echo "$DOMAIN_INPUT" | tr -d '\r\n')
        read -p "Введите ваш Email (для Let's Encrypt): " EMAIL_INPUT
        EMAIL=$(echo "$EMAIL_INPUT" | tr -d '\r\n')

        echo -e "\n${YELLOW}Настройка маскировки REALITY:${NC}"
        echo "1. Внешний сайт (Сайт чужой компании)"
        echo "2. Селфхост (Ваш домен $DOMAIN будет использоваться для REALITY)"
        read -p "Выбор (1-2): " REAL_TYPE

        if [[ "$REAL_TYPE" == "1" ]]; then
            read -p "Введите внешний сайт для REALITY (например, www.samsung.com): " REAL_INPUT
            REALITY_DEST=$(echo "$REAL_INPUT" | tr -d '\r\n')
        else
            REALITY_DEST="$DOMAIN"
            echo -e "\n${YELLOW}Какой сайт-заглушку установить на ваш домен?${NC}"
            echo "1. Сайт-визитка фотографа"
            echo "2. Личный IT Блог"
            read -p "Выбор (1-2): " FAKE_SITE_CHOICE
            if [[ "$FAKE_SITE_CHOICE" == "1" ]]; then
                export FAKE_SITE_HTML="<!DOCTYPE html><html><head><title>John Doe - Photographer</title><style>body{margin:0;font-family:sans-serif;background:#111;color:#fff}header{text-align:center;padding:50px} .gallery{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:10px;padding:20px} img{width:100%;height:300px;object-fit:cover;border-radius:5px;}</style></head><body><header><h1>John Doe Portfolio</h1><p>Capturing the moments</p></header><div class='gallery'><img src='https://picsum.photos/400/300?random=1'><img src='https://picsum.photos/400/300?random=2'><img src='https://picsum.photos/400/300?random=3'></div></body></html>"
            else
                export FAKE_SITE_HTML="<!DOCTYPE html><html><head><title>Dev Blog</title><style>body{max-width:800px;margin:auto;font-family:serif;padding:20px;line-height:1.6;color:#333} article{margin-bottom:40px;border-bottom:1px solid #ccc;padding-bottom:20px} h1{text-align:center;color:#2c3e50}</style></head><body><h1>My Dev Journey</h1><article><h2>Understanding Systems</h2><p>Today I learned about proxy structures and web servers...</p></article><article><h2>Optimization</h2><p>TCP BBR dramatically improves throughput over high latency links...</p></article></body></html>"
            fi
        fi
    else
        echo -e "${RED}Неверный выбор. Отмена.${NC}"
        exit 1
    fi

    echo -e "\n${YELLOW}Защита SSH и Anti-Bruteforce${NC}"
    read -p "Введите НОВЫЙ порт для SSH (от 1000 до 65000, оставьте пустым чтобы оставить 22): " NEW_SSH_PORT
    if [[ -n "$NEW_SSH_PORT" ]]; then
        mkdir -p /etc/ssh/sshd_config.d
        echo "Port $NEW_SSH_PORT" > /etc/ssh/sshd_config.d/99-custom-port.conf
        sed -i 's/^Port /#Port /g' /etc/ssh/sshd_config
        SSH_PORT=$NEW_SSH_PORT
    else
        SSH_PORT=22
    fi

    VISION_PORT="443"
    XHTTP_PORT="8443"
    FINGERPRINT="chrome"

    echo -e "\n${CYAN}Установка системных пакетов...${NC}"
    if [[ "$HAS_DOMAIN" == "true" ]]; then
        apt install -y -q jq nginx certbot qrencode uuid-runtime gnupg coreutils fail2ban ufw cron
    else
        apt install -y -q jq qrencode uuid-runtime gnupg coreutils fail2ban ufw cron
    fi

    ufw allow $VISION_PORT/tcp >/dev/null 2>&1
    ufw allow $XHTTP_PORT/tcp >/dev/null 2>&1
    ufw allow $SSH_PORT/tcp >/dev/null 2>&1
    if [[ "$HAS_DOMAIN" == "true" ]]; then
        ufw allow 80/tcp >/dev/null 2>&1
        ufw allow 2053/tcp >/dev/null 2>&1
    fi
    ufw --force enable >/dev/null 2>&1

    cat <<EOF > /etc/fail2ban/jail.local
[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF
    systemctl enable fail2ban >/dev/null 2>&1 && systemctl restart fail2ban

    sed -i '/net.core.default_qdisc=fq/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control=bbr/d' /etc/sysctl.conf
    sed -i '/fs.file-max=65535/d' /etc/sysctl.conf
    cat <<EOF >> /etc/sysctl.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
fs.file-max=65535
EOF
    sysctl -p >/dev/null 2>&1

    cat <<EOF > /etc/security/limits.d/xray.conf
* soft nofile 65535
* hard nofile 65535
root soft nofile 65535
root hard nofile 65535
EOF

    echo -e "\n${CYAN}Установка Xray Core...${NC}"
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

    echo -e "\n${YELLOW}Настройка автообновления баз GeoIP и GeoSite...${NC}"
    cat << 'EOF' > /usr/local/bin/update_geo.sh
#!/bin/bash
wget -q -O /usr/local/share/xray/geoip.dat https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
wget -q -O /usr/local/share/xray/geosite.dat https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
if systemctl is-active --quiet xray; then systemctl restart xray; fi
EOF
    chmod +x /usr/local/bin/update_geo.sh
    echo "0 4 * * 1 root /usr/local/bin/update_geo.sh" > /etc/cron.d/update_geo_xray

    echo -e "\n${CYAN}Генерация ключей шифрования Xray...${NC}"
    KEYS=$(/usr/local/bin/xray x25519)
    PRIVATE_KEY=$(echo "$KEYS" | grep -i "Private" | awk '{print $NF}' | tr -d '\r\n')
    PUBLIC_KEY=$(echo "$KEYS" | grep -i "Public" | awk '{print $NF}' | tr -d '\r\n')

    echo -e "\n${CYAN}Генерация путей и пользователей...${NC}"
    XHTTP_PATH="/$(openssl rand -hex 3 | tr -d '\r\n')"
    NGINX_WS_PATH="/$(openssl rand -hex 3 | tr -d '\r\n')"
    WARP_DOMAINS=""

    cat <<EOF > "$CONF_FILE"
HAS_DOMAIN="$HAS_DOMAIN"
DOMAIN="$DOMAIN"
EMAIL="$EMAIL"
SERVER_IP="$SERVER_IP"
REALITY_DEST="$REALITY_DEST"
PRIVATE_KEY="$PRIVATE_KEY"
PUBLIC_KEY="$PUBLIC_KEY"
XHTTP_PATH="$XHTTP_PATH"
NGINX_WS_PATH="$NGINX_WS_PATH"
WARP_DOMAINS="$WARP_DOMAINS"
FAKE_SITE_HTML="$FAKE_SITE_HTML"
VISION_PORT="$VISION_PORT"
XHTTP_PORT="$XHTTP_PORT"
FINGERPRINT="$FINGERPRINT"
EOF

    A_UUID=$(/usr/local/bin/xray uuid | tr -d '\r\n')
    A_SHORT=$(openssl rand -hex 4 | tr -d '\r\n')
    A_SECRET=$(openssl rand -hex 6 | tr -d '\r\n')
    echo "admin:$A_UUID:$A_SHORT:$A_SECRET" > "$USERS_FILE"

    if [[ "$HAS_DOMAIN" == "true" ]]; then
        echo -e "\n${CYAN}Настройка Nginx...${NC}"
        systemctl stop nginx
        if ! certbot certonly --standalone --non-interactive --agree-tos --email "$EMAIL" -d "$DOMAIN"; then
            echo -e "${RED}[ОШИБКА] Не удалось получить SSL сертификат! Убедитесь, что домен $DOMAIN привязан к IP-адресу сервера.${NC}"
            exit 1
        fi

        cat <<EOF > /etc/nginx/sites-available/default
server { listen 80 default_server; listen 443 ssl default_server; ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem; ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem; return 444; }
server { listen 80; server_name $DOMAIN; return 301 https://\$host\$request_uri; }
server {
    listen 2053 ssl http2; server_name $DOMAIN;
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem; ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    root /var/www/html; index index.html;
    location $NGINX_WS_PATH { if (\$http_upgrade != "websocket") { return 404; } proxy_pass http://unix:/dev/shm/xray.sock; proxy_redirect off; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
}
EOF
        systemctl start nginx && systemctl enable nginx
    fi

    echo -e "\n${CYAN}Применение конфигураций...${NC}"
    generate_xray_config
    generate_user_pages

    echo -e "\n${GREEN}=======================================${NC}"
    echo -e "${GREEN}Установка успешно завершена!${NC}"
    echo -e "${GREEN}=======================================${NC}"

    echo -e "\n${CYAN}Ваши данные для подключения (Пользователь admin):${NC}"
    while IFS=":" read -r U_NAME U_UUID U_SHORT U_SECRET || [[ -n "$U_NAME" ]]; do
        if [[ -z "$U_NAME" ]]; then continue; fi
        if [[ "$HAS_DOMAIN" == "true" ]]; then
            echo -e "👤 ${YELLOW}$U_NAME${NC} -> ВЕБ-ПАНЕЛЬ С QR: https://${DOMAIN}:2053/${U_SECRET}.html"
        else
            LINK_VISION="vless://${U_UUID}@${SERVER_IP}:${VISION_PORT}?type=tcp&security=reality&pbk=${PUBLIC_KEY}&fp=${FINGERPRINT}&sni=${REALITY_DEST}&sid=${U_SHORT}&spx=%2F&flow=xtls-rprx-vision#${U_NAME}-Vision"
            LINK_XHTTP="vless://${U_UUID}@${SERVER_IP}:${XHTTP_PORT}?type=xhttp&security=reality&pbk=${PUBLIC_KEY}&fp=${FINGERPRINT}&sni=${REALITY_DEST}&sid=${U_SHORT}&path=${XHTTP_PATH}#${U_NAME}-XHTTP"
            echo -e "\n👤 ${YELLOW}$U_NAME${NC}:"
            echo -e "Vision (Порт ${VISION_PORT}): ${CYAN}$LINK_VISION${NC}"
            echo -e "XHTTP (Порт ${XHTTP_PORT}): ${CYAN}$LINK_XHTTP${NC}"
        fi
    done < "$USERS_FILE"

    if [[ -n "$NEW_SSH_PORT" ]]; then
        echo -e "\n${RED}ВНИМАНИЕ: Ваш SSH порт изменен на $NEW_SSH_PORT !${NC}"
        systemctl restart sshd || systemctl restart ssh
    fi

    echo -e "\n${YELLOW}Возврат в главное меню через 5 секунд... Скопируйте ссылки!${NC}"
    sleep 5
}

manage_users() {
    while true; do
        echo -e "\n${CYAN}=== Управление Пользователями ===${NC}"
        echo "1) Добавить пользователя"
        echo "2) Удалить пользователя"
        echo "3) Список пользователей и их ссылок"
        echo "4) Показать QR-коды пользователя в терминале"
        echo "5) Изменить никнейм пользователя"
        echo "0) Назад"
        read -p "Выбор: " U_CHOICE

        case $U_CHOICE in
            1)
                read -p "Введите никнейм (оставьте пустым для рандомного): " NICKNAME
                if [[ -z "$NICKNAME" ]]; then NICKNAME="user_$(openssl rand -hex 2)"; fi
                if grep -q "^${NICKNAME}:" "$USERS_FILE"; then echo -e "${RED}Пользователь уже существует!${NC}"; continue; fi

                N_UUID=$(/usr/local/bin/xray uuid | tr -d '\r\n')
                N_SHORT=$(openssl rand -hex 4 | tr -d '\r\n')
                N_SECRET=$(openssl rand -hex 6 | tr -d '\r\n')

                echo "${NICKNAME}:${N_UUID}:${N_SHORT}:${N_SECRET}" >> "$USERS_FILE"
                generate_xray_config
                generate_user_pages
                echo -e "${GREEN}Пользователь $NICKNAME добавлен!${NC}"
                ;;
            2)
                read -p "Введите никнейм для удаления: " DEL_NAME
                if [[ "$DEL_NAME" == "admin" ]]; then echo -e "${RED}Нельзя удалить admin!${NC}"; continue; fi
                if grep -q "^${DEL_NAME}:" "$USERS_FILE"; then
                    # Получаем секрет для удаления HTML файла
                    DEL_SECRET=$(grep "^${DEL_NAME}:" "$USERS_FILE" | cut -d':' -f4)
                    sed -i "/^${DEL_NAME}:/d" "$USERS_FILE"
                    if [[ -n "$DEL_SECRET" ]]; then
                        rm -f /var/www/html/${DEL_SECRET}*
                    fi
                    generate_xray_config
                    generate_user_pages
                    echo -e "${GREEN}Пользователь $DEL_NAME удален!${NC}"
                else
                    echo -e "${RED}Пользователь не найден.${NC}"
                fi
                ;;
            3)
                echo "-----------------------------------"
                while IFS=":" read -r U_NAME U_UUID U_SHORT U_SECRET || [[ -n "$U_NAME" ]]; do
                    if [[ -z "$U_NAME" ]]; then continue; fi
                    if [[ "$HAS_DOMAIN" == "true" ]]; then
                        echo -e "👤 ${YELLOW}$U_NAME${NC} -> Панель: https://${DOMAIN}:2053/${U_SECRET}.html"
                    else
                        LINK_VISION="vless://${U_UUID}@${SERVER_IP}:${VISION_PORT}?type=tcp&security=reality&pbk=${PUBLIC_KEY}&fp=${FINGERPRINT}&sni=${REALITY_DEST}&sid=${U_SHORT}&spx=%2F&flow=xtls-rprx-vision#${U_NAME}-Vision"
                        LINK_XHTTP="vless://${U_UUID}@${SERVER_IP}:${XHTTP_PORT}?type=xhttp&security=reality&pbk=${PUBLIC_KEY}&fp=${FINGERPRINT}&sni=${REALITY_DEST}&sid=${U_SHORT}&path=${XHTTP_PATH}#${U_NAME}-XHTTP"
                        echo -e "\n👤 ${YELLOW}$U_NAME${NC}:"
                        echo -e "Vision (Порт ${VISION_PORT}): ${CYAN}$LINK_VISION${NC}"
                        echo -e "XHTTP (Порт ${XHTTP_PORT}): ${CYAN}$LINK_XHTTP${NC}"
                    fi
                done < "$USERS_FILE"
                echo "-----------------------------------"
                ;;
            4)
                read -p "Введите никнейм пользователя: " QR_NICK
                if ! grep -q "^${QR_NICK}:" "$USERS_FILE"; then
                    echo -e "${RED}Пользователь $QR_NICK не найден!${NC}"
                    continue
                fi
                IFS=":" read -r U_NAME U_UUID U_SHORT U_SECRET <<< "$(grep "^${QR_NICK}:" "$USERS_FILE")"
                
                LINK_VISION="vless://${U_UUID}@${SERVER_IP}:${VISION_PORT}?type=tcp&security=reality&pbk=${PUBLIC_KEY}&fp=${FINGERPRINT}&sni=${REALITY_DEST}&sid=${U_SHORT}&spx=%2F&flow=xtls-rprx-vision#${U_NAME}-Vision"
                echo -e "\n${CYAN}=== QR-код для Vision (Порт ${VISION_PORT}) ===${NC}"
                qrencode -t ANSIUTF8 "$LINK_VISION"
                
                LINK_XHTTP="vless://${U_UUID}@${SERVER_IP}:${XHTTP_PORT}?type=xhttp&security=reality&pbk=${PUBLIC_KEY}&fp=${FINGERPRINT}&sni=${REALITY_DEST}&sid=${U_SHORT}&path=${XHTTP_PATH}#${U_NAME}-XHTTP"
                echo -e "\n${CYAN}=== QR-код для XHTTP (Порт ${XHTTP_PORT}) ===${NC}"
                qrencode -t ANSIUTF8 "$LINK_XHTTP"
                ;;
            5)
                read -p "Введите текущий никнейм: " OLD_NICK
                if ! grep -q "^${OLD_NICK}:" "$USERS_FILE"; then
                    echo -e "${RED}Пользователь $OLD_NICK не найден!${NC}"
                    continue
                fi
                read -p "Введите новый никнейм: " NEW_NICK
                if [[ -z "$NEW_NICK" ]] || grep -q "^${NEW_NICK}:" "$USERS_FILE"; then
                    echo -e "${RED}Недопустимое имя или пользователь уже существует!${NC}"
                    continue
                fi
                sed -i "s/^${OLD_NICK}:/${NEW_NICK}:/" "$USERS_FILE"
                generate_xray_config
                generate_user_pages
                echo -e "${GREEN}Пользователь $OLD_NICK переименован в $NEW_NICK!${NC}"
                ;;
            0) break ;;
            *) echo "Неверный выбор" ;;
        esac
    done
}

manage_configs() {
    while true; do
        echo -e "\n${CYAN}=== Настройка конфигов ===${NC}"
        echo "1) Изменение портов подключения (Входящие)"
        echo "2) Изменение фингерпринта (fp)"
        echo "3) Пересоздать конфиги (Применить изменения)"
        echo "0) Назад"
        read -p "Выбор: " C_CHOICE

        case $C_CHOICE in
            1)
                echo -e "\n${YELLOW}Текущие порты:${NC}"
                echo "1) Vision (Сейчас: $VISION_PORT)"
                echo "2) XHTTP (Сейчас: $XHTTP_PORT)"
                read -p "Какой порт изменить? (1-2, 0-Отмена): " P_CHOICE
                if [[ "$P_CHOICE" == "1" ]]; then
                    read -p "Введите новый порт для Vision: " NEW_P
                    if [[ -n "$NEW_P" && "$NEW_P" =~ ^[0-9]+$ ]]; then
                        ufw delete allow $VISION_PORT/tcp >/dev/null 2>&1
                        VISION_PORT=$NEW_P
                        ufw allow $VISION_PORT/tcp >/dev/null 2>&1
                        sed -i "s/^VISION_PORT=.*/VISION_PORT=\"$VISION_PORT\"/" "$CONF_FILE"
                        echo -e "${GREEN}Порт Vision изменен на $VISION_PORT! Нажмите 'Пересоздать конфиги'.${NC}"
                    fi
                elif [[ "$P_CHOICE" == "2" ]]; then
                    read -p "Введите новый порт для XHTTP: " NEW_P
                    if [[ -n "$NEW_P" && "$NEW_P" =~ ^[0-9]+$ ]]; then
                        ufw delete allow $XHTTP_PORT/tcp >/dev/null 2>&1
                        XHTTP_PORT=$NEW_P
                        ufw allow $XHTTP_PORT/tcp >/dev/null 2>&1
                        sed -i "s/^XHTTP_PORT=.*/XHTTP_PORT=\"$XHTTP_PORT\"/" "$CONF_FILE"
                        echo -e "${GREEN}Порт XHTTP изменен на $XHTTP_PORT! Нажмите 'Пересоздать конфиги'.${NC}"
                    fi
                fi
                ;;
            2)
                echo -e "\n${YELLOW}Текущий фингерпринт: $FINGERPRINT${NC}"
                echo "Примеры: chrome, firefox, safari, ios, android, edge, randomized"
                read -p "Введите новый фингерпринт: " NEW_FP
                if [[ -n "$NEW_FP" ]]; then
                    FINGERPRINT=$NEW_FP
                    sed -i "s/^FINGERPRINT=.*/FINGERPRINT=\"$FINGERPRINT\"/" "$CONF_FILE"
                    echo -e "${GREEN}Фингерпринт изменен на $FINGERPRINT! Нажмите 'Пересоздать конфиги'.${NC}"
                fi
                ;;
            3)
                generate_xray_config
                generate_user_pages
                echo -e "${GREEN}Конфиги успешно пересозданы!${NC}"
                ;;
            0) break ;;
            *) echo "Неверный выбор" ;;
        esac
    done
}

toggle_warp() {
    if command -v warp-cli &> /dev/null; then
        echo -e "${YELLOW}WARP уже установлен. Удалить его? (y/n)${NC}"
        read -p "Выбор: " DEL_W
        if [[ "$DEL_W" == "y" ]]; then
            warp-cli --accept-tos disconnect >/dev/null 2>&1 || true
            apt purge -y -q cloudflare-warp
            rm -f /etc/apt/sources.list.d/cloudflare-client.list
            rm -f /usr/local/bin/warp_check.sh /etc/cron.d/warp_reconnect
            echo -e "${GREEN}WARP успешно удален!${NC}"
        fi
    else
        echo -e "${CYAN}Установка Cloudflare WARP...${NC}"
        curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
        echo "deb[signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflare-client.list >/dev/null
        apt update -y -q && apt install -y -q cloudflare-warp

        systemctl enable --now warp-svc >/dev/null 2>&1
        echo -e "${YELLOW}Ожидание демона WARP (3 сек)...${NC}"
        sleep 3

        warp-cli --accept-tos registration new >/dev/null 2>&1 || true
        warp-cli --accept-tos mode proxy >/dev/null 2>&1 || true
        warp-cli --accept-tos proxy port 40000 >/dev/null 2>&1 || true
        warp-cli --accept-tos connect >/dev/null 2>&1 || true
        echo -e "${GREEN}WARP установлен и запущен на порту 40000!${NC}"

        # Создаем авто-реконнект для WARP
        cat << 'EOF' > /usr/local/bin/warp_check.sh
#!/bin/bash
if ! warp-cli --accept-tos status | grep -q "Connected"; then
    warp-cli --accept-tos connect >/dev/null 2>&1
fi
EOF
        chmod +x /usr/local/bin/warp_check.sh
        echo "*/5 * * * * root /usr/local/bin/warp_check.sh" > /etc/cron.d/warp_reconnect
        echo -e "${GREEN}Авто-реконнект WARP (каждые 5 минут) успешно настроен!${NC}"
    fi
}

manage_warp() {
    echo -e "\n${CYAN}=== Управление WARP ===${NC}"
    echo "Текущие домены:[ ${WARP_DOMAINS:-"Нет"} ]"
    echo "1) Добавить Apple (geosite:apple)"
    echo "2) Добавить Meta/Facebook/Insta (geosite:meta)"
    echo "3) Добавить Google (geosite:google)"
    echo "4) Добавить OpenAI/ChatGPT (geosite:openai)"
    echo "5) Свой домен (например: domain:example.com)"
    echo "0) Очистить все правила WARP"
    read -p "Выбор: " W_CHOICE

    NEW_RULE=""
    case $W_CHOICE in
        1) NEW_RULE="geosite:apple" ;;
        2) NEW_RULE="geosite:meta" ;;
        3) NEW_RULE="geosite:google" ;;
        4) NEW_RULE="geosite:openai" ;;
        5) read -p "Введите правило: " NEW_RULE ;;
        0) WARP_DOMAINS="" ;;
    esac

    if [[ -n "$NEW_RULE" ]]; then
        if [[ -z "$WARP_DOMAINS" ]]; then WARP_DOMAINS="$NEW_RULE"; else WARP_DOMAINS="$WARP_DOMAINS,$NEW_RULE"; fi
    fi

    sed -i "s/^WARP_DOMAINS=.*/WARP_DOMAINS=\"$WARP_DOMAINS\"/" "$CONF_FILE"
    generate_xray_config
    echo -e "${GREEN}Маршрутизация WARP обновлена!${NC}"
}

show_stats() {
    echo -e "\n${CYAN}=== Статистика трафика пользователей ===${NC}"
    if ! systemctl is-active --quiet xray; then
        echo -e "${RED}Ошибка: Xray не запущен!${NC}"
        return
    fi
    
    STATS=$(/usr/local/bin/xray api statsquery -server=127.0.0.1:10085 2>/dev/null)
    if [[ -z "$STATS" ]]; then
        echo -e "${YELLOW}Нет данных. Если вы только что установили скрипт, трафика еще нет.${NC}"
        return
    fi

    echo -e "${YELLOW}Пользователь       | Скачано (MB) | Отправлено (MB)${NC}"
    echo "---------------------------------------------------"
    
    while IFS=":" read -r U_NAME _ || [[ -n "$U_NAME" ]]; do
        if [[ -z "$U_NAME" ]]; then continue; fi
        
        DOWN_B=$(echo "$STATS" | jq -r ".stat[] | select(.name == \"user>>>${U_NAME}>>>traffic>>>downlink\") | .value" 2>/dev/null)
        UP_B=$(echo "$STATS" | jq -r ".stat[] | select(.name == \"user>>>${U_NAME}>>>traffic>>>uplink\") | .value" 2>/dev/null)
        
        if [[ -z "$DOWN_B" || "$DOWN_B" == "null" ]]; then DOWN_B=0; fi
        if [[ -z "$UP_B" || "$UP_B" == "null" ]]; then UP_B=0; fi
        
        DOWN_MB=$(awk "BEGIN {printf \"%.2f\", $DOWN_B/1048576}")
        UP_MB=$(awk "BEGIN {printf \"%.2f\", $UP_B/1048576}")
        
        printf "%-18s | %-12s | %-15s\n" "${U_NAME}" "${DOWN_MB}" "${UP_MB}"
    done < "$USERS_FILE"
    echo "---------------------------------------------------"
    read -p "Нажмите Enter для продолжения..."
}

run_tests() {
    while true; do
        echo -e "\n${CYAN}=== Тесты ===${NC}"
        echo "1) IP region"
        echo "2) Censorcheck (geoblock)"
        echo "3) Censorcheck (dpi РФ)"
        echo "4) iPerf3 Россия"
        echo "5) YABS"
        echo "6) IP.Check.Place (блокировки)"
        echo "7) Bench.sh"
        echo "8) IPQuality"
        echo "9) Sysbench CPU"
        echo "0) Назад"
        read -p "Выбор: " T_C

        case $T_C in
            1) bash <(wget -qO- https://ipregion.vrnt.xyz); echo ""; read -p "Нажмите Enter..." ;;
            2) bash <(wget -qO- https://github.com/vernette/censorcheck/raw/master/censorcheck.sh) --mode geoblock; echo ""; read -p "Нажмите Enter..." ;;
            3) bash <(wget -qO- https://github.com/vernette/censorcheck/raw/master/censorcheck.sh) --mode dpi; echo ""; read -p "Нажмите Enter..." ;;
            4) bash <(wget -qO- https://itdog.app/rsps/); echo ""; read -p "Нажмите Enter..." ;;
            5) curl -sL yabs.sh | bash -s -- -4; echo ""; read -p "Нажмите Enter..." ;;
            6) bash <(curl -Ls IP.Check.Place) -l en; echo ""; read -p "Нажмите Enter..." ;;
            7) wget -qO- bench.sh | bash; echo ""; read -p "Нажмите Enter..." ;;
            8) bash <(curl -Ls https://Check.Place) -EI; echo ""; read -p "Нажмите Enter..." ;;
            9) apt install -y sysbench && sysbench cpu run --threads=1; echo ""; read -p "Нажмите Enter..." ;;
            0) break ;;
            *) echo "Неверный выбор" ; sleep 1 ;;
        esac
    done
}

check_services() {
    echo -e "\n${CYAN}=== Статус служб ===${NC}"
    for svc in ufw sshd ssh xray fail2ban warp-svc nginx; do
        if systemctl list-unit-files | grep -q "^${svc}.service"; then
            if systemctl is-active --quiet $svc; then
                echo -e "$svc: ${GREEN}Active${NC}"
            else
                echo -e "$svc: ${RED}Inactive${NC}"
            fi
        fi
    done
    echo ""
    read -p "Нажмите Enter для продолжения..."
}

uninstall_xray() {
    read -p "Удалить Xray и все настройки? (y/n): " CONFIRM
    if [[ "$CONFIRM" == "y" ]]; then
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove
        rm -f "$CONF_FILE" "$USERS_FILE" /usr/local/bin/update_geo.sh /etc/cron.d/update_geo_xray
        rm -f /var/www/html/*.html /var/www/html/*_sub
        if command -v warp-cli &> /dev/null; then 
            warp-cli --accept-tos disconnect 2>/dev/null || true
            apt purge -y -q cloudflare-warp
            rm -f /etc/apt/sources.list.d/cloudflare-client.list
            rm -f /usr/local/bin/warp_check.sh /etc/cron.d/warp_reconnect
        fi
        echo -e "${GREEN}Удаление завершено.${NC}"
        exit 0
    fi
}

while true; do
    if [[ -f "$CONF_FILE" ]]; then 
        source "$CONF_FILE"
        if [[ -z "$VISION_PORT" ]]; then VISION_PORT="443"; echo 'VISION_PORT="443"' >> "$CONF_FILE"; fi
        if [[ -z "$XHTTP_PORT" ]]; then XHTTP_PORT="8443"; echo 'XHTTP_PORT="8443"' >> "$CONF_FILE"; fi
        if [[ -z "$FINGERPRINT" ]]; then FINGERPRINT="chrome"; echo 'FINGERPRINT="chrome"' >> "$CONF_FILE"; fi
    fi

    echo -e "\n${YELLOW}=== Xray Pro Admin Panel ===${NC}"
    if [[ ! -f "$CONF_FILE" ]]; then
        echo "1) Установить сервер"
        echo "0) Выход"
        read -p "Выбор: " MENU_CHOICE
        case $MENU_CHOICE in
            1) install_core ;;
            0) exit 0 ;;
            *) echo "Неверный выбор" ; sleep 1 ;;
        esac
    else
        echo "-----------------------------------"
        echo "1) Управление пользователями"
        echo "2) Управление маршрутами WARP"
        echo "3) Установка/Удаление Cloudflare WARP"
        echo "4) Настройка конфигов"
        echo "5) Обновить Xray-core"
        echo "6) Тесты (Speedtest / Bench...)"
        echo "7) Статус служб"
        echo "8) Удалить сервер"
        echo "9) Статистика трафика (Traffic)"
        echo "0) Выход"
        read -p "Выбор: " MENU_CHOICE

        case $MENU_CHOICE in
            1) manage_users ;;
            2) manage_warp ;;
            3) toggle_warp ;;
            4) manage_configs ;;
            5) bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install; systemctl restart xray; echo -e "${GREEN}Обновлено!${NC}"; sleep 1;;
            6) run_tests ;;
            7) check_services ;;
            8) uninstall_xray ;;
            9) show_stats ;;
            0) exit 0 ;;
            *) echo "Неверный выбор" ; sleep 1 ;;
        esac
    fi
done

#!/bin/sh
set -e

# --- PERCORSI E VARIABILI ---
FLUIDD_DIR="/usr/data/fluidd"
NGINX_DATA="/usr/data/nginx"
SITES_AVAIL="$NGINX_DATA/sites-available"
SITES_ENAB="$NGINX_DATA/sites-enabled"
CONF_FILE="$SITES_AVAIL/fluidd"

NGINX_BIN="/usr/prog/nginx/sbin/nginx"
NGINX_PREFIX="/usr/prog/nginx"
NGINX_CONF="/usr/prog/nginx/conf/nginx.conf"

FLUIDD_URL="https://github.com/fluidd-core/fluidd/releases/download/v1.37.3/fluidd.zip"

echo "=========================================="
echo "   INSTALLAZIONE FLUIDD & NGINX (PORTA 81)"
echo "=========================================="

# 1. VERIFICA DIPENDENZE / OPKG
if command -v opkg >/dev/null 2>&1; then
    echo "===> Aggiornamento package manager opkg..."
    opkg update || true
    # Installa curl e unzip se non presenti
    command -v curl >/dev/null 2>&1 || opkg install curl
    command -v unzip >/dev/null 2>&1 || opkg install unzip
fi

# 2. DOWNLOAD E ESTRAZIONE FLUIDD
echo "===> Preparazione directory $FLUIDD_DIR..."
mkdir -p "$FLUIDD_DIR"
cd "$FLUIDD_DIR"

echo "===> Download di Fluidd v1.37.3..."
# -k / --insecure evita errori sui certificati SSL tipici dei sistemi MIPS/embedded
curl -k -OL "$FLUIDD_URL"

echo "===> Estrazione archivio..."
unzip -o fluidd.zip
rm -f fluidd.zip

# 3. CREAZIONE CONFIGURAZIONE NGINX
echo "===> Creazione file di configurazione Nginx..."
mkdir -p "$SITES_AVAIL"
mkdir -p "$SITES_ENAB"

cat << 'EOF' > "$CONF_FILE"
server {
    listen 81;

    #access_log /var/log/nginx/fluidd-access.log;
    #error_log /var/log/nginx/fluidd-error.log;

    # disable this section on smaller hardware like a pi zero
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_proxied expired no-cache no-store private auth;
    gzip_comp_level 4;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/x-javascript application/json application/xml;

    # web_path from fluidd static files
    root /usr/data/fluidd;

    index index.html;
    server_name _;

    # disable max upload size checks
    client_max_body_size 0;

    # disable proxy request buffering
    #proxy_request_buffering off;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location = /index.html {
        add_header Cache-Control "no-store, no-cache, must-revalidate";
    }

    location /websocket {
        proxy_pass http://apiserver/websocket;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 86400;
    }

    location ~ ^/(printer|api|access|machine|server)/ {
        proxy_pass http://apiserver$request_uri;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Scheme $scheme;
        proxy_read_timeout 600;
    }

    location /webcam/ {
        postpone_output 0;
        proxy_buffering off;
        proxy_ignore_headers X-Accel-Buffering;
        access_log off;
        error_log off;
        proxy_pass http://mjpgstreamer1/;
    }

    location /webcam2/ {
        postpone_output 0;
        proxy_buffering off;
        proxy_ignore_headers X-Accel-Buffering;
        access_log off;
        error_log off;
        proxy_pass http://mjpgstreamer2/;
    }

    location /webcam3/ {
        postpone_output 0;
        proxy_buffering off;
        proxy_ignore_headers X-Accel-Buffering;
        access_log off;
        error_log off;
        proxy_pass http://mjpgstreamer3/;
    }

    location /webcam4/ {
        postpone_output 0;
        proxy_buffering off;
        proxy_ignore_headers X-Accel-Buffering;
        access_log off;
        error_log off;
        proxy_pass http://mjpgstreamer4/;
    }
}
EOF

# 4. CREAZIONE SYMLINK
echo "===> Creazione Symlink in sites-enabled..."
ln -sf "$CONF_FILE" "$SITES_ENAB/fluidd"

# 5. CONTROLLO INCLUDE SU NGINX.CONF
# Verifica che nginx.conf carichi effettivamente la cartella sites-enabled
if [ -f "$NGINX_CONF" ]; then
    if ! grep -q "sites-enabled" "$NGINX_CONF"; then
        echo "===> NOTA: Aggiungo include per sites-enabled in $NGINX_CONF..."
        # Inserisce l'include dentro il blocco http
        sed -i '/http {/a \    include /usr/data/nginx/sites-enabled/*;' "$NGINX_CONF"
    fi
fi

# 6. TEST E RELOAD DI NGINX
echo "===> Verifica sintassi Nginx..."
"$NGINX_BIN" -p "$NGINX_PREFIX" -c "$NGINX_CONF" -t

echo "===> Reload di Nginx..."
"$NGINX_BIN" -p "$NGINX_PREFIX" -c "$NGINX_CONF" -s reload

echo "=========================================="
echo "   COMPLETATO CON SUCCESSO!"
echo "   Fluidd è attivo su http://<IP>:81"
echo "=========================================="
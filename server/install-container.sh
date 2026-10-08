#!/usr/bin/env bash
set -Eeuo pipefail

# Install the application and an ACME-only HTTP virtual host in the existing Debian CT.
# This script does not request a certificate, open ports, or remove existing Nginx sites.
DOMAIN="${1:-api.dl-home.de}"
APP_DIR=/opt/solarit-api
STATE_DIR=/var/lib/solarit-api
SERVICE_USER=solarit-api
ENV_FILE=/etc/solarit-api.env
SITE=/etc/nginx/sites-available/solarit-api-http

fail() { echo "ABBRUCH: $*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || fail "Als root im CT 111 ausführen, nicht auf dem PVE-Host."
[[ -f "$(dirname "$0")/solarit_api.py" && -f "$(dirname "$0")/nginx-api.conf.template" ]] || fail "solarit_api.py und nginx-api.conf.template müssen neben diesem Skript liegen."
[[ "$DOMAIN" =~ ^[A-Za-z0-9.-]+$ ]] || fail "Ungültiger Domainname."
[[ ! -e "$ENV_FILE" && ! -e "$SITE" ]] || fail "Eine frühere SOLARIT-Installation ist bereits vorhanden. Nichts überschrieben; zuerst bestehenden Zustand sichern und prüfen."

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y python3 nginx openssl curl ca-certificates
id "$SERVICE_USER" >/dev/null 2>&1 || useradd --system --home "$STATE_DIR" --shell /usr/sbin/nologin "$SERVICE_USER"
install -d -o root -g root -m 0755 "$APP_DIR"
install -d -o "$SERVICE_USER" -g "$SERVICE_USER" -m 0750 "$STATE_DIR"
install -d -o www-data -g www-data -m 0755 /var/www/letsencrypt
install -d -o www-data -g www-data -m 0755 /var/www/letsencrypt/.well-known/acme-challenge
install -o root -g root -m 0644 "$(dirname "$0")/solarit_api.py" "$APP_DIR/solarit_api.py"

ADMIN_TOKEN="$(openssl rand -hex 32)"
printf 'SOLARIT_DB=%s/solarit.sqlite3\nSOLARIT_ADMIN_TOKEN=%s\nSOLARIT_BIND=127.0.0.1\nSOLARIT_PORT=8765\nSOLARIT_ALLOWED_GAMES=solarit-randsektor-07\n' "$STATE_DIR" "$ADMIN_TOKEN" > "$ENV_FILE"
chmod 0600 "$ENV_FILE"

cat > /etc/systemd/system/solarit-api.service <<EOF
[Unit]
Description=Multi-game player presence and leaderboard API
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
EnvironmentFile=$ENV_FILE
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/python3 $APP_DIR/solarit_api.py
Restart=on-failure
RestartSec=3
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$STATE_DIR
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6

[Install]
WantedBy=multi-user.target
EOF

install -o root -g root -m 0644 "$(dirname "$0")/nginx-api.conf.template" "$SITE"
sed -i "s/api\\.dl-home\\.de/$DOMAIN/g" "$SITE"
ln -s "$SITE" /etc/nginx/sites-enabled/solarit-api-http
nginx -t
systemctl daemon-reload
systemctl enable --now solarit-api
systemctl enable --now nginx
systemctl reload nginx
sleep 1
curl --fail --silent http://127.0.0.1:8765/health >/dev/null || fail "Interner API-Healthcheck fehlgeschlagen."

echo
echo "Grundinstallation abgeschlossen; es wurde KEIN Zertifikat beantragt."
echo "CT-interner Test: curl http://127.0.0.1/health -H 'Host: $DOMAIN'"
echo "Vor HTTPS: öffentliche DNS-Auflösung und FRITZ!Box-/PVE-Freigaben TCP 80/443 extern prüfen."
echo "Danach getrennt ausführen: bash $(dirname "$0")/enable-https.sh $DOMAIN DEINE-E-MAIL"

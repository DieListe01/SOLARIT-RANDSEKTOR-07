#!/usr/bin/env bash
set -Eeuo pipefail

DOMAIN="${1:-api.dl-home.de}"
ADMIN_EMAIL="${2:-}"
SITE=/etc/nginx/sites-available/solarit-api-http
TEMPLATE="$(dirname "$0")/nginx-api-https.conf.template"

fail() { echo "ABBRUCH: $*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || fail "Als root im CT 111 ausführen, nicht auf dem PVE-Host."
[[ -f /etc/solarit-api.env && -f "$SITE" && -f "$TEMPLATE" ]] || fail "Zuerst install-container.sh ausführen."
[[ "$DOMAIN" =~ ^[A-Za-z0-9.-]+$ ]] || fail "Ungültiger Domainname."
[[ -n "$ADMIN_EMAIL" && "$ADMIN_EMAIL" == *@* ]] || fail "Aufruf: bash enable-https.sh api.dl-home.de E-MAIL"
grep -Fq "server_name $DOMAIN;" "$SITE" || fail "Domain stimmt nicht mit der HTTP-Grundinstallation überein."
getent ahosts "$DOMAIN" >/dev/null || fail "$DOMAIN löst auf diesem CT nicht auf. DNS zuerst prüfen."

echo "Dieses Skript fordert ein öffentliches Zertifikat an. Voraussetzung: DNS zeigt öffentlich auf diesen Anschluss,"
echo "TCP 80 erreicht den ACME-Endpunkt von außen und die TCP-443-Freigabe in FRITZ!Box/PVE zeigt auf CT 111."
echo "Port 443 lässt sich nach Aktivierung von HTTPS vollständig testen."
read -r -p "Bestätige diese Prüfung mit JA: " confirmation
[[ "$confirmation" == "JA" ]] || fail "Keine Änderung vorgenommen."

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y certbot curl ca-certificates
certbot certonly --webroot --webroot-path /var/www/letsencrypt --preferred-challenges http \
  --non-interactive --agree-tos --email "$ADMIN_EMAIL" -d "$DOMAIN"

HTTPS_TEMPLATE="$(mktemp /etc/nginx/solarit-api-https.XXXXXX)"
sed "s/api\\.dl-home\\.de/$DOMAIN/g" "$TEMPLATE" > "$HTTPS_TEMPLATE"
BACKUP="$SITE.pre-https.$(date +%Y%m%d%H%M%S)"
cp -a "$SITE" "$BACKUP"
install -o root -g root -m 0644 "$HTTPS_TEMPLATE" "$SITE"
rm -f "$HTTPS_TEMPLATE"
if ! nginx -t; then
  cp -a "$BACKUP" "$SITE"
  nginx -t || true
  fail "Nginx-Prüfung fehlgeschlagen; HTTP-Grundkonfiguration wurde wiederhergestellt."
fi
systemctl reload nginx
install -d -o root -g root -m 0755 /etc/letsencrypt/renewal-hooks/deploy
cat > /etc/letsencrypt/renewal-hooks/deploy/reload-nginx <<'HOOK'
#!/bin/sh
systemctl reload nginx
HOOK
chmod 0755 /etc/letsencrypt/renewal-hooks/deploy/reload-nginx
systemctl enable --now certbot.timer
curl --fail --silent --show-error --resolve "$DOMAIN:443:127.0.0.1" "https://$DOMAIN/health"
echo
echo "HTTPS ist lokal im CT geprüft. Zusätzlich von außen https://$DOMAIN/health testen."

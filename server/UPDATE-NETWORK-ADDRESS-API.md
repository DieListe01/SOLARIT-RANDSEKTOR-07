# Externe IP-Abfrage auf CT 111 aktivieren

Dieses Update ergänzt `GET /api/v1/network/address`. Die API gibt die öffentliche IPv4 des anfragenden Spielers zurück, ohne sie in die API-Datenbank zu schreiben. Bei einem Aufruf aus dem Heimnetz über NAT-Loopback wird die A-Adresse von `api.dl-home.de` verwendet. Diese muss durch FRITZ!Box-DynDNS aktuell gehalten werden. Andere Nginx-, Apache- und FRITZ!Box-Einstellungen bleiben unverändert. Das Spiel benötigt Version 0.36.10 oder neuer.

Lade `SOLARIT-Network-Address-API-Update-<VERSION>.zip` aus dem zugehörigen GitHub-Release herunter und lege es auf dem PVE-Knoten unter `/root/SOLARIT-Network-Address-API-Update.zip` ab. Dann in der Proxmox-Shell als root ausführen:

```bash
mkdir -p /root/solarit-network-address-api-update
unzip -o /root/SOLARIT-Network-Address-API-Update.zip -d /root/solarit-network-address-api-update
python3 -m py_compile /root/solarit-network-address-api-update/solarit_api.py
pct exec 111 -- cp -a /opt/solarit-api/solarit_api.py /root/solarit_api.py.before-network-address
pct push 111 /root/solarit-network-address-api-update/solarit_api.py /opt/solarit-api/solarit_api.py
pct exec 111 -- chown root:root /opt/solarit-api/solarit_api.py
pct exec 111 -- chmod 0644 /opt/solarit-api/solarit_api.py
pct exec 111 -- python3 -m py_compile /opt/solarit-api/solarit_api.py
pct exec 111 -- systemctl restart solarit-api
pct exec 111 -- curl -fsS http://127.0.0.1:8765/health
pct exec 111 -- curl -fsS http://127.0.0.1:8765/api/v1/network/address
```

Das Update speichert die Spielversion jeder öffentlichen Lobby und gibt sie in der Lobby-Liste zurück. Die Datenbank wird beim Dienststart automatisch um die neue Spalte erweitert. Die `health`-Antwort bestätigt den Neustart. Auf dem Spiele-PC anschließend in PowerShell testen:

```powershell
curl.exe -fsS https://api.dl-home.de/api/v1/network/address
```

Erwartet werden die Health-JSON-Antwort und – über HTTPS von einem Spiele-PC aus – eine IP-Antwort wie `{"ok":true,"address":"79.240.71.178"}`. Danach zeigt das Multiplayer-Menü die lokale und externe IPv4 mit Kopier-Schaltflächen. Lobbys melden ihre Spielversion; Clients können Lobbys mit abweichender Version nicht betreten.

Rollback bei Bedarf in der Proxmox-Shell:

```bash
pct exec 111 -- cp -a /root/solarit_api.py.before-network-address /opt/solarit-api/solarit_api.py
pct exec 111 -- systemctl restart solarit-api
```

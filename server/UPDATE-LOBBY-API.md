# Lobby-API auf dem vorhandenen CT 111 aktualisieren

Dieses Update ersetzt nur die Python-API. Es ändert keine Domain-, Apache-, Nginx- oder Zertifikatseinstellungen und migriert keine Bestenlisten. Die aktuelle Version legt die Lobby-Tabelle bei Bedarf beim Start an. Die vertrauenswürdige Apache/Nginx-Kante ist standardmäßig `192.168.178.148`; wenn sich diese CT-Adresse ändert, setze `SOLARIT_PROXY_EDGE` in `/etc/solarit-api.env` auf die neue IP.

ZIP auf den PVE-Knoten kopieren und dort entpacken. Dann in der Proxmox-Shell als root:

```bash
mkdir -p /root/solarit-api-update
unzip -o /root/SOLARIT-Online-Lobby-API-Update.zip -d /root/solarit-api-update
python3 -m py_compile /root/solarit-api-update/solarit_api.py
pct exec 111 -- cp -a /opt/solarit-api/solarit_api.py /root/solarit_api.py.before-lobby
pct push 111 /root/solarit-api-update/solarit_api.py /opt/solarit-api/solarit_api.py
pct exec 111 -- chown root:root /opt/solarit-api/solarit_api.py
pct exec 111 -- chmod 0644 /opt/solarit-api/solarit_api.py
pct exec 111 -- python3 -m py_compile /opt/solarit-api/solarit_api.py
pct exec 111 -- systemctl restart solarit-api
pct exec 111 -- curl -fsS http://127.0.0.1:8765/health
pct exec 111 -- curl -fsS http://127.0.0.1:8765/api/v1/games/solarit-randsektor-07/lobbies
```

Der letzte Aufruf muss `{"game_id":"solarit-randsektor-07","lobbies":[]}` oder eine Liste aktiver Lobbys zurückgeben. Rollback bei Bedarf:

```bash
pct exec 111 -- cp -a /root/solarit_api.py.before-lobby /opt/solarit-api/solarit_api.py
pct exec 111 -- systemctl restart solarit-api
```

UDP 2456 gehört zum Host-PC des Spiels. Dafür wird keine zusätzliche Portfreigabe zum API-Container eingerichtet.

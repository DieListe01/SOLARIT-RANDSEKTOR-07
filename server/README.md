# Mehrspiel-Online-Dienst (erste Version)

Der Dienst zählt aktive Spielsitzungen, speichert Einzelspieler-Siege je `profile_id` und liefert eine gemeinsame Top 10 pro Einsatz. Python-Standardbibliothek + SQLite genügen; keine PostgreSQL- oder Docker-Installation nötig.

## API

- `GET /health`: Bereitschaftstest.
- `GET /api/v1/network/address`: öffentliche IPv4 des anfragenden Spielers ermitteln. Die Adresse wird nur an den Anfragenden zurückgegeben und nicht gespeichert.
- `POST /api/v1/games/{game_id}/heartbeat`: Profil, zufällige Installations-ID, Nickname, Spielversion und `playing` aktualisieren. Aktive Profile laufen nach 120 Sekunden ohne Heartbeat aus.
- `POST /api/v1/games/{game_id}/results`: einen Sieg pro `run_id` und Spiel dedupliziert speichern.
- `GET /api/v1/games/{game_id}/highscores?mission=veyra-01`: gemeinsame Top 10 des Einsatzes und Spiels.
- `GET /api/v1/games/{game_id}/me/results?profile_id=...`: letzte persönliche Ergebnisse dieses Spiels.
- `GET` und `POST /api/v1/games/{game_id}/lobbies`: öffentliche, kurzlebige Direkt-Lobbys auflisten und nach ausdrücklicher Host-Einwilligung veröffentlichen; ergänzend `POST .../lobbies/heartbeat` und `POST .../lobbies/close`.
- Legacy-Endpunkte ohne `/games/{game_id}` bleiben für ältere SOLARIT-Versionen aktiv und verwenden ausschließlich `solarit-randsektor-07`.
- `GET /api/v1/admin/players` und `/api/v1/admin/summary`: Admin-Token erforderlich.

Bei normaler Online-Statistik speichert die API keine Client-IP-Adresse. `GET /api/v1/network/address` gibt die öffentliche IPv4 nur an den Anfragenden zurück; bei NAT-Loopback im Heimnetz wird die aktuelle A-Adresse des API-Hostnamens verwendet. Die Abfrage legt keinen Datensatz in der API-Datenbank an. Nur wenn ein Host seine Lobby ausdrücklich veröffentlicht, speichert die API die öffentliche Adresse. Sie ist höchstens 75 Sekunden nach dem letzten Lobby-Heartbeat öffentlich sichtbar; abgelaufene Datensätze werden bei der nächsten Lobby-Abfrage gelöscht. Bei einem Beitritt löscht das Spiel die Listung. Das zum Ändern/Löschen nötige Token liegt nur gehasht in der Datenbank und wird nie an andere Spieler ausgegeben. Nginx-Access-Logs sind ausgeschaltet. Gespeichert werden außerdem zufällige Profil-/Installationskennungen, Nickname, Spielversion, letzte Aktivität und übermittelte Siege. Sämtliche Spieltabellen sind nach `game_id` getrennt. SOLARIT verwendet `solarit-randsektor-07`; weitere erlaubte Spiele lassen sich über `SOLARIT_ALLOWED_GAMES` eintragen. Die Online-Statistik lässt sich im Spiel unter Optionen → Profil abschalten. Sie ist in der ersten Version standardmäßig eingeschaltet. Die Highscores sind nicht manipulationssicher: Ein Client kann Werte fälschen. Für eine private Spielrunde ist das akzeptabel; kompetitive Ranglisten bräuchten serverseitige Replay-/Simulationsvalidierung.

Hosts brauchen eine UDP-2456-Portweiterleitung zum Spiele-PC und müssen im Multiplayer-Menü **Öffentliche Lobby veröffentlichen** aktivieren. Erst dadurch wird ihre Adresse anderen Spielern angezeigt. Die Spielverbindung läuft direkt zwischen den PCs; der API-Server ist nur Lobby-Verzeichnis.

## Bereitstellung

Alle Serverdateien aus diesem Ordner müssen gemeinsam liegen. Beide Befehle als root im vorhandenen CT 111 ausführen, nicht auf dem PVE-Host. Zuerst:

```bash
bash install-container.sh api.dl-home.de
```

Dieser Schritt installiert den Dienst und einen HTTP-Grundhost, beantragt aber kein Zertifikat und löscht keine vorhandene Nginx-Site. Nach bestätigter DNS-Auflösung, extern erreichbarem TCP 80 und eingerichteter TCP-443-Freigabe separat ausführen:

```bash
bash enable-https.sh api.dl-home.de admin@dl-home.de
```

Das zweite Skript verlangt vor der Zertifikatsanforderung eine ausdrückliche Erreichbarkeitsbestätigung. Die Anwendung lauscht nur auf `127.0.0.1:8765`.

Admin-Auskunft direkt im Container:

```bash
set -a; . /etc/solarit-api.env; set +a
curl -H "Authorization: Bearer $SOLARIT_ADMIN_TOKEN" http://127.0.0.1:8765/api/v1/admin/players
```

## Tests

```bash
python3 -m unittest discover -s server -p 'test_*.py' -v
```

Im bereitgestellten Paket liegen Test und API im selben Ordner; dort lautet der Befehl `python3 -m unittest -v test_solarit_api`.

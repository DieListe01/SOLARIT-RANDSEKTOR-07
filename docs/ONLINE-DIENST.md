# Online-Spieler und gemeinsame Bestenliste

## Erste Version

Das Spiel verwendet an jedem Standort dieselbe Adresse: `https://api.dl-home.de`. Es gibt keine LAN-Sonderadresse und keinen zweiten lokalen Clientpfad. Dadurch sind LAN- und externe Clients protokollgleich; sie müssen die Domain jeweils per DNS erreichen können.

Die API trennt Spieler, Sitzungen, Ergebnisse und Ranglisten per `game_id`. SOLARIT verwendet `solarit-randsektor-07`; ein weiteres Spiel bekommt eine eigene ID und darf dieselbe Profil-ID oder Lauf-ID verwenden, ohne Daten mit SOLARIT zu teilen. Neue IDs werden kontrolliert über `SOLARIT_ALLOWED_GAMES` in `/etc/solarit-api.env` freigeschaltet. Die bisherigen Endpunkte ohne Spielpfad bleiben als SOLARIT-Kompatibilitätsalias erhalten. Vorhandene v1-SQLite-Daten werden beim Start der neuen Version automatisch in den SOLARIT-Namespace migriert.

Während einer Partie sendet das Spiel alle 45 Sekunden einen Heartbeat mit der bestehenden zufälligen `profile_id`, dem Nickname, einer zufälligen Installations-ID, Spielversion und dem Status „Partie läuft“. Am Partieende wird der Status auf inaktiv gesetzt. Ohne Heartbeat gilt der Spieler nach 120 Sekunden als offline. Ausschalten der Online-Statistik unter **Optionen → Profil** stoppt die Übertragung.

Nur siegreiche Einzelspieler-Läufe gehen in die gemeinsame Rangliste ein. Lauf-IDs verhindern doppelte Einträge; Resultate bleiben auch bei Serverausfall in einer lokalen Warteschlange und werden bei einer späteren Partie erneut versucht. Die lokale Bestenliste bleibt zusätzlich bestehen. Über **Online Top 10 laden** lässt sich die gemeinsame Rangliste in die Einsatzliste übernehmen.

Der Server verwendet Python-Standardbibliothek und SQLite. Er bindet die API nur auf Loopback-Port 8765; Nginx bedient HTTPS auf 443. Das Admin-Token liegt nur auf dem Server. Aktive Spieler und Summen sind über Admin-Endpunkte abrufbar. Die API speichert bei normaler Online-Statistik keine Client-IP-Adresse. `GET /api/v1/network/address` gibt die öffentliche IPv4 nur an den anfragenden Client zurück und legt dafür keinen Datenbankeintrag an. Bei NAT-Loopback im Heimnetz verwendet die API die aktuelle A-Adresse von `api.dl-home.de`; sie sollte über die FRITZ!Box-DynDNS aktuell gehalten werden. Eine veröffentlichte Lobby ist eine bewusste Ausnahme: Ihre öffentliche IP ist höchstens 75 Sekunden nach dem letzten Host-Heartbeat in der Liste sichtbar. Abgelaufene Einträge werden bei der nächsten Lobby-Abfrage aus der Datenbank entfernt. Der Host kann die Listung beenden; sobald ein Mitspieler beitritt, nimmt das Spiel sie zurück. Das Spiel sendet alle 20 Sekunden einen Lobby-Heartbeat. Das API-Token zum Verwalten der eigenen Lobby wird nur gehasht gespeichert und nie in der Lobby-Liste ausgegeben. Nginx-Access-Logs der API sind ausgeschaltet.

## Öffentliche Direkt-Lobbys

Im geöffneten Multiplayer-Menü aktualisiert sich die Lobby-Liste alle 15 Sekunden; **LOBBYS AKTUALISIEREN** startet zusätzlich eine sofortige Suche. Jede Lobby zeigt, wann der Host zuletzt gemeldet hat und wie lange der Eintrag noch gültig ist. Nach 75 Sekunden ohne Heartbeat wird er als veraltet markiert und kann nicht mehr ausgewählt werden. Beitreten funktioniert direkt per ENet/UDP; der Online-Dienst leitet keine Spielpakete weiter. Hosts veröffentlichen nur mit dem nicht vorausgewählten Häkchen **Öffentliche Lobby veröffentlichen**. Dadurch wird die öffentliche IP in der Lobby-Liste für andere Spieler sichtbar. Der Router muss UDP 2456 an den Host-PC weiterleiten und die lokale Firewall muss den Port erlauben. Ohne Häkchen bleiben manuelles Beitreten und private LAN-Spiele möglich.

Lobby-Einträge enthalten Nickname, Modus, Einsatzname, öffentliche Adresse und UDP-Port. Die externe IP im Spiel wird über die per HTTPS-Proxy erkannte öffentliche Client-IP ermittelt; bei NAT-Loopback im Heimnetz nutzt die API die öffentliche A-Adresse des eigenen Hostnamens. Spieler im selben LAN können alternativ die lokale IP kopieren und manuell eintragen.

Die Lobby-Endpunkte sind `GET` und `POST /api/v1/games/{game_id}/lobbies`, dazu `POST .../lobbies/heartbeat` und `POST .../lobbies/close`. Für Veröffentlichung muss die vertrauenswürdige Apache/Nginx-Proxy-Kette die echte Client-Adresse in `X-Forwarded-For` weiterreichen; die API vertraut nur der konfigurierten Proxy-Kette.

Highscores sind in dieser ersten Version nicht fälschungssicher, weil Clients ihre Ergebnisse melden. Außerdem sind Nickname und Profilkennung personenbezogene bzw. dauerhaft verknüpfbare Daten. Die Option kann abgeschaltet werden. Eine wettbewerbliche Rangliste bräuchte später serverseitige Matchvalidierung und einen ausdrücklichen Einwilligungsdialog.

## DNS und FRITZ!Box

Die Domain der Website selbst bleibt unverändert. Nur das neue Subdomain `api.dl-home.de` wird zum Heimanschluss geleitet.

1. In INWX einen DynDNS-Zugang für `api.dl-home.de` einrichten. INWX führt für die FRITZ!Box eine benutzerdefinierte DynDNS-Konfiguration auf.
2. In der FRITZ!Box unter **Internet → Freigaben → DynDNS** „Benutzerdefiniert“ wählen:
   - Update-URL: `https://dyndns.inwx.com/nic/update?myip=<ipaddr>&myipv6=<ip6addr>`
   - Domainname: `api.dl-home.de`
   - Benutzername/Kennwort: INWX-DynDNS-Zugang
3. Der CT 111 muss in der FRITZ!Box eine feste DHCP-Zuordnung erhalten (aktuell `192.168.178.155`).
4. Für dieses Gerät TCP 80 und TCP 443 freigeben. Falls die Proxmox-Firewall aktiv ist, diese Ports zusätzlich für CT 111 eingehend erlauben. Die API selbst bleibt auf Port 8765 nur intern im Container erreichbar.
5. Zuerst `install-container.sh` im CT ausführen. Es richtet nur den Dienst und die HTTP-ACME-Vorabkonfiguration ein, beantragt aber kein Zertifikat und lässt die Spiel-API über unverschlüsseltes HTTP gesperrt. DNS und Port 80 müssen von außen geprüft sowie die Port-443-Freigabe gesetzt sein. Erst danach `enable-https.sh` ausführen; es verlangt vor Certbot eine ausdrückliche Bestätigung.
6. Vom PC im LAN und zusätzlich über Mobilfunk `https://api.dl-home.de/health` testen. Beide Clients verwenden dieselbe URL. Falls der Router im LAN keine Rückleitung über die öffentliche Adresse unterstützt, benötigt das LAN einen DNS-Eintrag `api.dl-home.de → 192.168.178.155`; URL, HTTPS-Zertifikat und Spielclient bleiben gleich.

Falls der Internetanschluss keine eingehenden IPv4-Verbindungen zulässt (z. B. DS-Lite/CGNAT), reicht eine IPv4-Portfreigabe allein nicht. Dann IPv6-Erreichbarkeit/Freigabe prüfen oder einen ausgehenden Tunnel einsetzen. Die Hauptwebsite `dl-home.de` und `www.dl-home.de` dürfen nicht auf den PVE-Server umgestellt werden.

## Admin-Abfrage

Die API-Endpunkte sind unter `/api/v1/games/{game_id}/...` nach Spiel getrennt. Alte SOLARIT-Endpunkte ohne Spielpfad bleiben als Alias erhalten. Im Container:

```bash
set -a; . /etc/solarit-api.env; set +a
curl -H "Authorization: Bearer $SOLARIT_ADMIN_TOKEN" http://127.0.0.1:8765/api/v1/admin/players
curl -H "Authorization: Bearer $SOLARIT_ADMIN_TOKEN" http://127.0.0.1:8765/api/v1/admin/summary
```

Online bedeutet: mindestens ein Client hat in den letzten zwei Minuten gemeldet, dass eine Partie läuft.

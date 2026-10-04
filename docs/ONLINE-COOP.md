# Historischer Koop-Synchronisierungsstand

Der aktuelle Stand mit 1:1-Duell, Lobby und Chat steht in [MULTIPLAYER.md](MULTIPLAYER.md). Die folgenden Notizen dokumentieren den vorherigen Koop-Schritt mit Protokollversion 2.

# Online-Koop: Synchronisierung

Stand: 4. Oktober 2026. Der vorhandene Entwicklungsstand enthält eine ENet-Lobby für einen Host und einen Mitspieler. Beide steuern gemeinsam Spieler 0 gegen die KI. Der Host berechnet die Simulation, der Client übernimmt vollständige Snapshots und interpoliert die Darstellung.

## Snapshot-Übertragung

Lobbyangebot, Missionsstart und Snapshots verwenden denselben zuverlässigen Kanal 2. Der Client bestätigt den Missionsstart erst nach der synchronen Initialisierung seiner Simulation. Erst danach sendet der Host Spielstände.

Die Übertragungsrate beträgt höchstens vier Snapshots pro Sekunde. Es bleibt höchstens ein Snapshot unbestätigt. Der Host simuliert währenddessen weiter; nach der Bestätigung überträgt er beim nächsten fälligen Update seinen aktuellen Zustand. Dadurch wächst bei langsamen Verbindungen keine Warteschlange alter Spielstände.

Sitzungskennung, Missionsnummer und Snapshot-Sequenz verhindern die Übernahme veralteter Spielstände. Die Wiederverbindung zu einer laufenden Mission sendet deren Konfiguration erneut und setzt die Übertragung fort. Beim Missionsneustart wird die Übertragung erst nach erneuter Startbestätigung freigegeben. Befehle tragen ebenfalls die Missionsnummer und beginnen je Mission mit einer neuen Sequenz; bereits unterwegs befindliche Befehle einer alten Mission werden verworfen. Das geänderte RPC-Format verwendet Protokollversion 2.

## Verifikation

Aufruf aus dem Projektverzeichnis:

    .\Test-Multiplayer.ps1

Optional kann ein anderer lokaler UDP-Port gewählt werden:

    .\Test-Multiplayer.ps1 -Port 24652

Der Test startet zwei unsichtbare, headless Godot-Prozesse. Er vergleicht zwölf empfangene und wiederhergestellte Snapshots mit den gespeicherten Host-Fingerprints. Die Testwelt enthält zusätzliche Fahrzeuge und erzeugt Spielstände von etwa 149 KB, deutlich oberhalb der Netzwerk-MTU. Geprüft werden Hold, Move mit tatsächlicher Positionsänderung und Stop, Wiederverbindung sowie Missionsneustart und weitere Befehle danach. Zusätzlich pausiert der Client die Netzwerkverarbeitung für 0,9 Sekunden; der Test prüft, dass die Sendewarteschlange begrenzt bleibt und die Synchronisierung wieder fortgesetzt wird. Ausstehende lokale Pfadberechnungen werden beim Fingerprint normalisiert: Restore verwirft diese bewusst, und der Client berechnet keine Simulationsticks.

Die Logs stehen unter test-output/network-host.log und test-output/network-client.log, Fehler separat in den entsprechenden .err-Dateien. Der Test ist auch in Test-Solarit.ps1 eingebunden.

Der alte Test konnte aufgrund eines bereits durch die Simulation gesetzten Stop-Auftrags einen Host-Erfolg melden, bevor ein Mitspielerzustand bestätigt war. Der neue Test beendet den Host erst nach bestätigter Zustandsübereinstimmung und einer Abschlussbestätigung des Clients.

## Grenzen

Verifiziert wurde die lokale ENet-Verbindung. Internetbetrieb unter Paketverlust, Router-Portweiterleitung und verschiedene reale PCs wurden nicht geprüft. Der Koop-Modus teilt eine Fraktion; separate menschliche Teams, Hostmigration und authentifizierte öffentliche Lobbys sind nicht implementiert. Visuelle Effekte bleiben lokal und sind kein Bestandteil der Spielstand-Fingerprints.

# ASHLINE-Multiplayer: technische Grundlage

ASHLINE läuft derzeit lokal. Die `Simulation` nimmt Befehle zentral über `submit_command(packet, issuer)` an, schreitet in festen 30-Hz-Ticks fort und kann ihren Zustand als JSON sichern und wiederherstellen. Das ist eine brauchbare Trennlinie für Multiplayer, aber noch kein Netzcode: Transport, Lobby, Identität, Host-Autorität und Synchronisationsprüfungen fehlen.

## Empfohlener erster Mehrspielermodus

Zuerst sollte ein kooperativer Modus für zwei Spieler entstehen. Ein Spieler hostet, der zweite verbindet sich. Der Host besitzt den maßgeblichen Simulationszustand, führt KI, Wirtschaft, Produktion und Kampf aus und entscheidet, welche Befehle gültig sind. Clients senden nur Befehlsabsichten, zum Beispiel Einheitenauswahl plus Bewegungsziel. Sie dürfen weder Solarit, Trefferpunkte noch Einheiten direkt setzen.

Jeder Befehl erhält eine Sitzungskennung, Spielerkennung, laufende Befehlsnummer, gewünschte Simulations-Ticknummer, Aktion und Parameter. Der Host prüft Eigentum, Sichtbarkeit, Reichweite, Kosten, Voraussetzungen und Befehlsnummer, ordnet den Befehl einem Tick zu und verteilt das bestätigte Ergebnis an alle Teilnehmer. Lokale Vorhersage bleibt für Mausfeedback möglich; die Host-Bestätigung korrigiert den Zustand.

Die erste Codegrundlage liegt in `scripts/network_protocol.gd`: Protokollversion, Sitzungsprüfung, Spieler-/Eigentümerabgleich, fortlaufende Sequenzen, ein begrenztes Tickfenster, erlaubte Befehlsnamen und maximale Paketgröße werden vor Weitergabe geprüft. `state_hash()` erzeugt einen SHA-256-Fingerprint aus kanonisch sortierten Snapshot-Dictionaries. Das Modul stellt nur Prüf- und Serialisierungshelfer bereit; Simulationsticks werden noch nicht übers Netzwerk gesteuert.

## Synchronisation und Wiederverbindung

Die 30-Hz-Simulation wird zunächst auf einen deterministischen Host festgelegt. Ein normalisierter Hash über eine kanonisch sortierte Zustandsdarstellung wird in festen Abständen verglichen. Der Host sendet regelmäßig kompakte Zustandskorrekturen und vollständige Snapshots bei Missionsstart, späteren Kampagnenübergängen und Wiederverbindung. RNG-Seeds und RNG-Fortschritt gehören in jeden Snapshot. Abweichungen werden protokolliert und mit dem nächsten Host-Snapshot korrigiert.

Später kann Lockstep-Berechnung getestet werden. Dafür müssten Physik, Pfadsuche, Rundungen und Zufallszahlen auf allen unterstützten Rechnern reproduzierbar sein. Erst wenn ein Mehrgeräte-Test nach mehreren Minuten denselben Zustands-Hash liefert, sollte ein Client eigenständig Simulationsticks ausführen.

## Netzwerk und Sicherheit

Für eine erste private Testversion eignet sich ein Host-Client-Transport mit UDP und zuverlässigem, geordnetem Kanal für Spielbefehle sowie unzuverlässigem Kanal für häufige Statusupdates. Eine Lobby oder Relay kann NAT-Verbindungen vereinfachen; sie ersetzt keine Host-Prüfungen. Beitrittscodes sollten kurzlebig sein, und Sitzungsdaten dürfen keine lokalen Spielstände oder Update-Zugangsdaten offenlegen.

ASHLINE verwendet aktuell einen lokalen Gegner und eine einzelne Mission. Der kleinste sinnvolle Mehrspielertest ist daher: zwei lokale Spielinstanzen, gemeinsamer Missionsstart, gleichzeitig bestätigte Bau- und Bewegungsbefehle, Host-Neustart/Wiederverbindung, absichtliche ungültige Befehle und mindestens zehn Minuten identische Resultate. Erst danach lohnt sich öffentlicher Matchmaking- oder Dedicated-Server-Betrieb.

## Nächste umsetzbare Arbeitsschritte

1. Befehle als versionierte, serialisierbare Protokolltypen definieren und Spielerbesitz vom lokalen Spielerindex trennen.
2. Godot-ENet-Host und Client-Lobby mit Versions- und Missionsdatenabgleich ergänzen.
3. Hostvalidierung und Ticksequenz in `Simulation.submit_command` integrieren.
4. Snapshot, kanonischen Hash, Abweichungsprotokoll und Wiederverbindung testen.
5. Erst danach Koop-Spielregeln, Sieg/Niederlage und Lobbyqualität erweitern.

Der Release-Workflow kann diese Multiplayer-Schritte später ohne Änderung an der Updateverteilung ausliefern. Client und Host müssen vor einem öffentlichen Netzwerkbetrieb dieselbe Protokollversion und kompatible Missionsdaten melden.

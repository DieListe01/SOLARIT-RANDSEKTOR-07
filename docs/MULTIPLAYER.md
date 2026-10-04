# Multiplayer: 1:1-Duell und Koop

Stand: 4. Oktober 2026. Implementiert im Quellprojekt, Protokollversion 5. Beide PCs benötigen diesen Projektstand.

## Start und Bedienung

Spiel über SOLARIT-RANDSEKTOR-07.cmd oder Start-Solarit.ps1 starten. Im Hauptmenü MULTIPLAYER öffnen (auch im Einsatzmenü verfügbar); die Multiplayer-Lobby bietet 1:1-DUELL und KOOP GEGEN DIE KI.

1. Der Host wählt den Modus und erstellt ein Spiel.
2. Der Mitspieler trägt die IP-Adresse des Hosts ein und tritt bei. Auf demselben PC: 127.0.0.1.
3. Jeder wählt seine Fraktion und Farbe. Gleiche Farben werden getrennt. Der Host wählt eine der drei Karten und gemeinsame Startressourcen.
4. Beide bestätigen BEREIT. Änderungen an der Konfiguration setzen beide Bestätigungen zurück.
5. Der Host startet. Im Duell steuert er Spieler 0, der Mitspieler Spieler 1. Im Koop steuern beide Spieler 0 gegen die KI.

Der Duellstart enthält pro Spieler einen Baukern und einen Späher, identische Startressourcen und sämtliche Technologie-Freigaben. Kampagnen-KI und Missionswellen sind abgeschaltet. Zerstörung des gegnerischen Baukerns entscheidet das Duell. Statistik und Sieg/Niederlage werden aus der jeweiligen Spielerperspektive angezeigt. Jede beendete Partie wird lokal in der Kommandantenakte archiviert; der Host sendet beim Spielende den vollständigen Vergleichsbericht an den Client, damit beide die gegnerischen Gebäude, Fahrzeuge und Ressourcenverläufe sehen können. REVANCHE führt beide in die Lobby zurück; beide müssen erneut BEREIT bestätigen. Duelle verändern keine Kampagnenfortschritte oder lokalen Bestenlisten.

## Spielerzahl und Server

Aktuell genau zwei menschliche Spieler: Host und ein Mitspieler, im Duell gegeneinander oder im Koop gemeinsam. Es gibt keine automatische Serversuche oder öffentliche Serverliste. Der Mitspieler benötigt die IP des Hosts. Im selben lokalen Netzwerk die LAN-IP des Host-PCs verwenden; auf einem PC 127.0.0.1. Der Standardport ist UDP 2456.

Ein eigenständiger dedizierter Server ist noch nicht implementiert. Der aktuelle Host ist selbst Spieler und führt die Simulation aus. Ein ThinClient wäre grundsätzlich als künftiger Server denkbar, abhängig von CPU, RAM und Betriebssystem. Dafür fehlen ein automatischer Serverstart ohne Menü und die Trennung von Server und beiden entfernten Spielern; nur --headless oder das Erhöhen der Clientgrenze reicht nicht. Zunächst lokal/LAN per IP testen.

## Spielernamen und Systemmeldungen

Der lokale Kommandantenname wird automatisch in die Lobby übertragen und vom Host angezeigt. Lobby- und Chatnamen werden auf 20 Zeichen und Buchstaben, Zahlen, Leerzeichen, Bindestrich und Unterstrich begrenzt. Chatbeiträge werden als Klartext dargestellt. Systemmeldungen nennen Lobbyeröffnung, Beitritt, Bereitschaft, relevante Fraktions-/Kartenwechsel und Einsatzstart. Die Lobby zeigt reale Pingwerte erst nach einer Messung.

## Chat

Der Chat ist in der Lobby geöffnet. Während des Spiels: CHAT / ENTER anklicken oder Enter drücken. Enter im Eingabefeld oder SENDEN versendet die Nachricht; Escape schließt das Eingabefeld und im Spiel den Chat. Bei eingehenden Nachrichten öffnet sich die Anzeige.

Nachrichten sind reiner Text, maximal 300 Zeichen. Steuerzeichen werden entfernt; pro Absender ist höchstens eine Nachricht je 500 ms erlaubt. Der Host weist den Absender anhand des verbundenen Peers zu. Die letzten 50 Nachrichten bleiben auf dem Host und werden bei Wiederbeitritt übertragen. Ein neuer Verbindungsaufbau auf dem Host beginnt einen neuen Verlauf. Chat und Spielstände verwenden getrennte Netzwerkkanäle.

## Verbindung und Synchronisierung

Der Host führt die Simulation aus. Der Client berechnet keine eigenen Simulationsticks. Zuverlässige Snapshots werden höchstens viermal pro Sekunde gesendet; es gibt höchstens einen unbestätigten Spielstand. Sitzungskennung, Missionsnummer, Sequenzen und eine Startbestätigung verhindern veraltete Übernahmen.

Im Duell erhält der Client vollständige eigene Objekte und aktuell sichtbare Gegner. Versteckte Gegner werden auf dem Host aus dem Snapshot entfernt. Gegnerische Queues, Pfade, Ziele, Ressourcen, RNG-Zustand und Aufklärung werden nicht übertragen. Legitime zuletzt gesehene Gegner bleiben im eigenen Aufklärungswissen. Kamera, Auswahl, Bauvorschau, HUD, Minimap und Musik verwenden den lokalen Spielerindex.

Befehle werden auf Spielerbesitz, Mission, Sequenz, Größe und die Spielregeln geprüft. Abgewiesene, korrekt sequenzierte Pakete blockieren nachfolgende Befehle nicht.

Ping und Synchronisierungsstatus werden im Spiel angezeigt. Bei einem Verbindungsabbruch wartet das Duell; der Host simuliert erst nach Wiederbeitritt weiter. Der Mitspieler kann über die Wiederbeitritts-Lobby zum laufenden Host zurückkehren. Lokales Speichern/Laden und einseitiger Neustart sind in der Online-Pause nicht verfügbar; das Menü pausiert die laufende Online-Partie nicht.

## Tests

    .\Test-Multiplayer.ps1

Der Aufruf prüft Duellregeln headless, Koop zwischen zwei Prozessen sowie Duell, Lobby, Chat und Revanche in zwei vollständigen Spielinstanzen mit OpenGL. Die Fenster starten unsichtbar. Für Rechner ohne Grafiktreiber:

    .\Test-Multiplayer.ps1 -SkipUI

Mit -OnlyUI lässt sich nur der Test der vollständigen Spielinstanzen ausführen. Optional -Port 24671 verwenden; der Duell-Test nutzt dann den Folgeport.

- tests/versus.gd: faire Starts auf allen Karten, deaktivierte KI/Wellen, serverseitiger Kriegsnebel, private Gegnerdaten, Sichtwechsel, gefiltertes Restore, Eigentumsprüfung, Statistik und Siegbedingungen.
- tests/network_roundtrip.gd: große Koop-Snapshots, Host-Fingerprints, Hold/Move/Stop, verzögerte Netzwerkverarbeitung, Wiederbeitritt und Missionswechsel.
- tests/network_game.gd: beide Spieloberflächen, Lobbywahl und Bereitschaft, Chat in beide Richtungen, abgewiesener Besitz-Spoof gefolgt von gültigem Befehl, Gebäudebau des Mitspielers, Wiederbeitritt mit Chatverlauf, Ping, gefilterte Snapshots, beide Ergebnisse und Revanche.

Logs: test-output/network-*.log und .err. UI-Bilder: test-output/network-duel-chat.png und network-duel-victory.png. Der Aufruf ist in Test-Solarit.ps1 eingebunden.

## Noch offen

Internetbetrieb unter realem Paketverlust und mit verschiedenen PCs ist nicht verifiziert. Der Host ist selbst Teilnehmer; aktuell können ein Host und ein Mitspieler teilnehmen. UDP-Port 2456 muss bei Internetbetrieb am Router und in der Firewall zugänglich sein. Keine Hostmigration, öffentlichen Konten, Matchmaking, Zuschauer oder Replays. Der Host bleibt als Besitzer der autoritativen Simulation technisch vertrauenswürdig; die Filterung schützt den Mitspieler vor verborgenem Gegnerzustand. Die Karten bieten gleiche Startausstattung, aber noch kein geprüftes Turnier-Balancing. Visuelle Effekte bleiben lokal.

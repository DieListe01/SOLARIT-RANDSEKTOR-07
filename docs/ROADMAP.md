# Entwicklungsstand

## Phase 1 — spielbare Einzelmission

Umgesetzt: Start bis Debriefing, Basisbau, echte Ressourcenwirtschaft, Produktion, Kamerasteuerung, Auswahl, Kampf, wirtschaftende Gegner-KI, Sichtsystem, Radar, beide Renderpfade, Originalaudio und versionierte Spielstände. Windows-Release mit eingebettetem Datenpaket.

Die drei Fraktionsprofile dienen als Vorbereitung. Eigenständige Techbäume, exklusive Spezialfähigkeiten und individuelle Gebäudearchitektur sind noch keine abgeschlossene Fraktionsausarbeitung.

## Phase 2 — Kernspiel vertiefen

Interaktives Tutorial, Infanterie und Ingenieure; weitere Gegenwaffen; gezieltes Rückzugs-/Reparaturverhalten und Expansion der KI; zusätzliche Missionsziele und zwei weitere Karten. Aktuelle Gruppenseparation durch Tests kreuzender Armeen und dichter Engstellen vertiefen. Gebäudesilhouetten und Animationen ausarbeiten; eigene lesbare Bitmap-Schrift für Classic Retro ergänzen.

## Phase 3 — Fraktionen

Kobalt: schwere Industrie und defensive Stellung. Wanderpakt: schnelle Expansion und Überfälle. Prisma: Sensoren, Drohnen und elektronische Waffen. Getrennte Technologien, eigene Gebäudeformen und vollständige Musikstücke über die vorhandenen synchronen Motive hinaus.

## Phase 4 — Kampagne und Werkzeuge

Eigene strategische Planetenübersicht, verzweigte Missionsfolgen, datengetriebene Trigger und Karteneditor. Savegame-Migration und zusätzliche Plattform-Exports prüfen.

## Phase 5 — Veröffentlichung

Langzeit-Balancing, menschliche Spieltests aller Fraktionen und Schwierigkeiten, Barrierefreiheit, vollständige Hotkey-Konfliktprüfung, Audio- und Grafikpolish, Leistungstests auf Zielhardware und Steam-Deck-Bedienung. Multiplayer bleibt nachrangig.

## Visual Polish Pass 2 / 0.8

Ereignisgesteuerte lokale Kampf-/Treffer-/Zerstörungseffekte, begrenzte Partikel und Trümmer, Bildversatz für Kamerastoß mit drei Stufen, Effektprofile, neue Originalsounds und Motor-Ambience, stärkere Fahrzeuge, zusätzliche Industrie- und Bauanimationen, Hologrammvorschau, Produktions-/Baustellenfortschritt, Radar-Pings und aktive Tabs umgesetzt. Dies ergänzt den Singleplayer-Kern; vollständige Mehrspieler-Authority und Command-Architektur bleiben separate offene Arbeit.

## Style Consolidation / 0.10

Lokale serialisierbare Commands und explizite Entity-Identität umgesetzt, einschließlich Eigentümer-/Sichtprüfung und Migration alter Spielstände. Frühere Aussage „Command-Architektur vollständig offen“ wird dadurch präzisiert: Transport, authentifizierter Host/Server, Tick-Scheduling, Replay und mehr als zwei aktive Teilnehmer bleiben offen. Stil und Quality Gates werden vor weiterer Inhaltsausweitung priorisiert. Rollenformen, lebendige Konstruktion, kräftigere Teamflächen, Makrodetails, typeigene Wracks und Gebäuderuinen sowie Auswahl-/Produktionsfeedback konsolidiert. Neue Einheiten, Infanterie und Techbäume bleiben spätere Arbeit.


## Readability & Persistent Destruction / 0.11

Umgesetzt: missionslange kosmetische Schlachtspuren mit priorisiertem Recycling, typisierte Fahrzeug-/Gebäudereste, abgestufte Feuer-/Rauchphasen, getrennte validierte Save-Persistenz, FOW- und Kamera-Culling, World-Status über VFX, formabhängige Schatten und regionale Makrodetails. Bestehende Balance und Command-/Authority-Grenze erhalten. Details und Budgets in PERSISTENT_DESTRUCTION_IMPLEMENTATION.md. Menschliche Lesbarkeitsprüfung und GPU-/Zielhardware-Tests bleiben Teil Phase 5.


## Modelle und Updateinfo / 0.12

Umgesetzt: integrierte, datierte Versionshistorie mit zwölf Releases im Haupt- und Pausenmenü, zentrale Menü-Versionsanzeige, metallische Kantenbevels und stärker modellierte Tanks/Geschütztürme, feinere Auswahlmarkierungen, kompakte Energie-Treffer und unregelmäßigere Kristallformen. Keine neue Gameplay-Funktion, kein Balanceeingriff. Weitere menschliche Art-/Lesbarkeitsprüfung bleibt Teil des kontinuierlichen Polish.

## 0.13 — 02.10.2026
Umgesetzt: Objektinfo für Einheiten/Gebäude; sichtbare Reparaturbefehle; erreichbare Hangarziele; Sammler warten auf volle Reparatur; detailliertere Industrie- und Wrackgrafik; geschichtete Flammen; kompakte Auswahlwinkel; entzerrte Lebensbalken; Updateinfo.


## 0.14 — 02.10.2026
Umgesetzt: vier Bauausrichtungen, gedrehte Rechteckflächen, Ausgänge und Save-Kompatibilität; weitere Modellhardware; 60 Stereo-Effekte, Varianten und begrenzte Mischung; robuste Musik-Taktwechsel; Updateinfo mit 14 Versionen.



## 0.15 — 02.10.2026
Umgesetzt: eigenständige Missionsvorbereitung und verfeinerte Karten; facettierte Solarit-Textur; Crowd-/Zoom-Darstellungsstufen für Fahrzeuge und Bodendetails. Reproduzierbarer Rendervergleich (40 Fahrzeuge, pausierte Simulation, RTX 3060): 4,6 auf etwa 29 FPS. Höhere Bildraten auf weiteren Zielsystemen sowie große Langzeitgefechte bleiben weiter zu prüfen.


## 0.16 — 02.10.2026
Behoben: Kristallatlas-Kacheln wurden beim Generieren nicht an ihre Rasterposition versetzt. Die Solaritfelder waren in der Welt unsichtbar, obwohl die Vorkommen existierten. Alle Form- und Dichtevarianten sind neu erzeugt und sichtbar geprüft; automatischer Ernteablauf bleibt verfügbar.


## 0.17 — 02.10.2026
Fahrzeuggrafiken gecacht, Zählstands-LOD entfernt, Bewegung interpoliert, dynamische Ketten ergänzt, statische Bodendetails in sichtbare 16×16-Kacheln gebündelt und Fahrspuren zusammengefasst. 40 pausierte Fahrzeuge erreichen auf der RTX 3060 rund 51 FPS (vorher 5,9); 60 FPS und große bewegte Gefechte mit VFX bleiben offene Performanceziele. Gebäudegeometrie wird noch live gezeichnet.

## 0.18 — 02.10.2026
Laufende FPS-Anzeige ergänzt und automatisches CSV-Protokoll für anhaltende Einbrüche unter 45 FPS. Protokolliert werden Einsatzzeit, Einbruchdauer, mittlere/minimale FPS, alle sowie sichtbare Fahrzeuge und Gebäude (eigene/feindliche), VFX, Zeichenaufrufe, Primitives und Prozesszeiten. Erholung ab 50 FPS schließt den Eintrag.

## 0.19 — 02.10.2026
Nach einem Sieg wird eine missionseigene Top 10 mit Punktzahl, Zeit, Schwierigkeitsgrad, Fraktion und Datum gespeichert. Punktzahl und Rang stehen im Abschlussbildschirm; das Hauptmenü bietet die vollständige Bestenliste. Einsatzkennungen in Spielständen verhindern doppelte Siegesrekorde. Es gibt derzeit ein spielbares Level: Das Veyra-Becken.

## Stand 0.20 – Veyra-Front

Umgesetzt:
- Mission 02 „Die trockene Ader“ mit kombinierten Wirtschafts-/Expansionszielen.
- Mission 03 „Engpass Khepri“ mit 15-Minuten-Verteidigung und datengetriebenen Angriffswellen.
- Missionswahl in der Einsatzvorbereitung und Übergang zum nächsten Einsatz nach Sieg.
- Zieltypen `harvest_amount`, `build_structure`, `survive`, `destroy_all` zusätzlich zu `destroy_target` und `protect`.
- Missionsspezifische Start-Ruinen und Krater als kostengünstige Welt-Details.

Nächster sinnvoller Content-Schritt:
- Mission 04 „Staubstraße“ (mobiler Konvoi ohne klassischen Basisbau).
- Mission 05 „Schwarzes Signal“ (Radar-/Erkundungsziele und Signalstationen).
- Objective-Typen `reach_location`, `capture` und `escort` ergänzen.

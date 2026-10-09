# SOLARIT: RANDSEKTOR 07

Ein eigenständiges RTS mit Basisbau, Solarit-Wirtschaft und drei vollständig spielbaren Missionen. Stand: **0.36.31 / Eigenständige Fraktionsfahrzeuge und weichere Geländekanten**, 9. Oktober 2026.

Fahrzeuge und Gebäude werden im Einsatz als beleuchtete 3D-Modelle gerendert und passend zur RTS-Kamera in die Schlacht eingebettet. Alle acht Fahrzeug- und Gebäudetypen übernehmen Teamfarbe, Ausrichtung und sichtbare Zustände; Kobalt-Konsortium, Wanderpakt und Prisma-Konklave haben eigene Fahrwerksformen. Das Classic-Design behält seine bisherige Darstellung. Die bestehende SubViewport-Cache-Pipeline kann optionale, in Blender erstellte GLB-Modelle aufnehmen; die Qualitätsgrenzen und Modellkonventionen stehen in [docs/3D_ASSET_PIPELINE.md](docs/3D_ASSET_PIPELINE.md).

## Grafikarbeit v0.37 (in Arbeit)

Der erste Blender-Vertikalschnitt ergänzt den Solarit-Sammler H09 als editierbare `.blend`-Quelle und importiertes `.glb`. Schneidwalze, Arbeitshub, Fahrpose und Entladeklappe sind animiert und werden passend zum Simulationszustand über die bestehende 3D-SubViewport- und 2D-Cache-Pipeline gerendert. Der Cache zeigt 32 Fahrzeugrichtungen und tastet Fahr-, Abbau- und Entladeanimationen jeweils in acht Phasen ab. Eine reproduzierbare Übersicht mit allen 32 Richtungen und den 24 Animationsphasen liegt unter `test-output/harvester_turntable_animation_sheet.png`; Erstellungs- und Prüfpfad stehen in [docs/3D_ASSET_PIPELINE.md](docs/3D_ASSET_PIPELINE.md). Der Meilenstein ist noch in Arbeit: Raffinerie, Solaritfeld, Abbau- und Schadensdarstellung sowie Vergleichsaufnahmen bleiben offen.

## Intro und Startmenü

Beim Start läuft ein 15-sekündiges Intro: Die Landschaft von Veyra wird aufgedeckt, ein Landeschiff nähert sich der beleuchteten Kolonie, kurze Texte führen in die Welt ein und der Spieltitel erscheint. Escape, Enter, Leertaste, Linksklick oder „Überspringen“ führen jederzeit ins Menü. Nach 15 Sekunden öffnet sich das Menü automatisch. „Intro ansehen“ spielt die Sequenz erneut.

Das Startmenü verwendet eine durchgehende animierte Landschaft mit langsamem Parallax, Sternen, Orbitalstation, Solarit, Kolonielichtern, Rauch und Staub. Die Menüpunkte blenden kurz ein, bleiben sofort bedienbar und sind per Tastatur erreichbar. Ohne Spielstand ist „Spielstand laden“ deaktiviert. Die Hauptnavigation nutzt jetzt kompaktere, halbtransparente Kommandzeilen; Intro, Updateinfo und Bestenliste sind als sekundäre Aktionen gestaltet.

Die Systemoptionen sind in **Bild**, **Audio**, **Steuerung** und **Gameplay** gegliedert. Das dezente, mittig platzierte Systempanel lässt die Menüszenen am Rand sichtbar. Auflösung, Fensterart, Classic-Retro-Modus, CRT-Filter, Effektqualität, Kamerastoß, Lebensbalken, Lautstärke und Randscrollen bleiben erhalten. Audiopegel zeigen Prozentwerte; Tastenbelegungen sind als Aktionsliste anklickbar, auf Standard zurücksetzbar und Änderungen werden sofort gespeichert.

Das eigene Titelstück **First Signal** läuft bereits beim ersten Programmstart und setzt sich im Menü fort. Es besteht aus einem 32-sekündigen Synthesemotiv bei 120 BPM. Musiklautstärke und Stummschaltung gelten auch dafür. Beim Missionsstart übernimmt das dynamische Spielarrangement; bei Rückkehr zum Menü startet wieder das Titelstück. Intro und Menü verwenden auch den echten Classic-Retro-Renderpfad.

## Starten

**Windows-Spiel:** `build/SOLARIT-RANDSEKTOR-07.exe` doppelklicken. Die ausführbare Datei enthält Engine, Spieldaten, Grafik und Audio; eine Godot-Installation ist dafür nicht erforderlich.

**Quellprojekt:** `SOLARIT-RANDSEKTOR-07.cmd` startet mit der lokal mitgelieferten Engine. Alternativ `project.godot` mit **Godot 4.7.2 stable, Standard/GDScript** öffnen und F6/F5 drücken. Die Version wurde über die [offizielle Downloadseite](https://godotengine.org/download/windows/) geprüft. Keine Plugins, Python oder zusätzlichen Bibliotheken werden zum Spielen benötigt.

Der portable Quellprojekt-Starter speichert unter `.local/Godot/app_userdata/SOLARIT RANDSEKTOR 07/`. Der exportierte Direktstart verwendet Godots üblichen Benutzerordner unter `%APPDATA%/Godot/app_userdata/`.

## Erste Partie

1. „Einsatz wählen“ öffnen, einen der drei Einsätze, Fraktionsprofil und Gegnerverhalten wählen, Landung freigeben. Zum Einstieg Mission 01 auf „Ruhig“ verwenden.
2. Ein **Impulswerk** neben dem Baukern platzieren. Grün bedeutet gültig, Rot erklärt den Ablehnungsgrund.
3. Eine **Solarit-Raffinerie** errichten. Ein Sammler ist im Kaufpreis enthalten und beginnt automatisch mit dem Abbau.
4. Eine **Fahrzeugwerft** errichten. Ein zweites Impulswerk und eine zweite Raffinerie verbessern Versorgung und Einkommen.
5. Panzer produzieren, mit einem Wachtgeschütz die Basis sichern und die Armee aktiv gegen Angreifer einsetzen.
6. Mit dem Späher die zentrale Engstelle und den östlichen Kessel aufklären. Angriffsmarsch führt die Armee durch den Pass.
7. Den gegnerischen Baukern zerstören. Der eigene Baukern ist ein geschütztes Missionsziel; sein Verlust bedeutet Niederlage.

Im Produktionstab zeigt jede Werft ihre eigene Auftragsliste. Anklicken setzt sie als Ziel für neue Aufträge; im Fahrzeugtab wird das Ziel angezeigt. „Automatik“ verteilt neue Aufträge wieder an die Werft mit der kürzesten Warteschlange. Aufträge lassen sich einzeln abbrechen oder hinter dem laufenden Fahrzeug vorziehen.

Die Kampagne schaltet den Ausbau schrittweise frei: Nach Einsatz 01 werden Einsatz 02 und die Rüstungswerkstatt freigegeben. Deren erste Stufe produziert den schnellen Doppelsalven-Flanker **Dorn**. Der Sieg in Einsatz 02 gibt Einsatz 03 und die zweite Werkstattstufe frei; sie erschließt den langsamen Präzisions-Lanzierer **Prisma**. Die Ausbauten dauern, verbrauchen Solarit und werden bei Strommangel langsamer. Fortschritt wird separat vom Schnellspielstand lokal gespeichert.

Gebäude stehen während ihrer Bauzeit bereits auf der Karte. Sie werden erst nach Fertigstellung aktiv. Bei Energiemangel läuft Produktion mit 40 % Geschwindigkeit; Radar und Geschütze benötigen ausreichende Energie. Umstellte Fabriken warten mit fertigen Aufträgen auf einen freien Ausgang.

## Steuerung

| Eingabe | Aktion |
|---|---|
| Linksklick / Rahmen ziehen | Eigene Einheit, Gebäude oder mehrere Fahrzeuge auswählen |
| Shift + Auswahl | Auswahl ergänzen |
| Strg + Klick / Doppelklick | Sichtbare Einheiten gleichen Typs auswählen |
| Rechtsklick | Bewegen, Gegner angreifen oder Sammler auf Solarit ansetzen |
| A, danach Linksklick | Angriffsmarsch |
| S / H / G | Stopp / Position halten / aktuellen Standort bewachen |
| R bei ausgewähltem Gebäude | Bezahlte Reparatur umschalten |
| Strg + 1–9 / 1–9 | Gruppe speichern / auswählen |
| Gruppentaste doppelt | Kamera zur Gruppe |
| Pfeiltasten, W/J/K/L, Rand / mittlere Maustaste | Kamera bewegen |
| WASD ohne Auswahl | Kamera bewegen; bei Auswahl haben A/S Befehlspriorität |
| Mausrad | Zoom: 75 %, 100 %, 125 %, 150 % |
| Home / Leertaste | Baukern / letztes gemeldetes Ereignis |
| Shift + F1/F2/F4; F1/F2/F4 | Kameraposition speichern; abrufen |
| F3 | Diagnose: Pfade, Bauradien, KI, Energie, FPS, Musik |
| F5 / F9 | Schnell speichern / laden |
| Escape | Platzierung abbrechen oder Pause / Fortsetzen |
| Produktionsbutton: Klick / Shift + Klick / Rechtsklick | +1 / +5 / −1 Auftrag, 75 % Erstattung |
| Ausgewählte Werft + Rechtsklick | Sammelpunkt setzen |
| Klick auf Minimap | Kamera versetzen |

Die wichtigsten Befehls-Hotkeys lassen sich in den Optionen neu belegen. Gruppen entfernen zerstörte Einheiten automatisch und werden gespeichert. Der Sammler arbeitet autonom, sucht bei Erschöpfung ein anderes bekanntes Feld und weicht bei Beschuss zur Raffinerie zurück.

## Darstellung und Klang

Modern Retro arbeitet mit einem 1920×1080-Layout. Unterstützte Fenstergrößen: 1280×720, 1600×900, 1920×1080, 2560×1440 und 3840×2160. Ein Betriebssystem kann ein zu großes normales Fenster auf den Arbeitsbereich begrenzen; Vollbild oder Randlos verwenden dann die verfügbare Bildschirmfläche.

Classic Retro rendert **das gesamte Spiel mit 640×360**, einschließlich UI, und skaliert mit Nearest Neighbor und Integer Scaling. Bei 1600×900 wird beispielsweise ein 1280×720-Bild mit schwarzen Rändern gezeigt. Die Spielwelt besitzt zusätzlich einen entsprechend verkleinerten SubViewport. Umschalten verändert keinerlei Simulationsdaten. CRT: aus / leicht / stark.

Die eigene 120-BPM-Musik besteht pro Fraktionsprofil aus vier synchronen 16-Sekunden-Spuren. Ruhe, Feindkontakt, Gefechte und Basisalarm verändern das Arrangement mit geglätteter Intensität, Mindestdauer und taktgebundenem Wechsel. Eigene Sieg- und Niederlagen-Jingles sowie Synthese-SFX sind enthalten. Musik und Effekte sind getrennt regelbar; das Credits-Menü bietet einen Soundtest. `tools/generate_audio.py` enthält die reproduzierbare Originalkomposition und Synthese.

## Umgesetzter Umfang

- Drei datengetriebene 64×64-Missionen mit eigenem Briefing, Terrain, Ressourcenlage und Missionsmechanik.
- Erweiterte Zieltypen: Zerstören, Schützen, Solarit liefern, Strukturen errichten und Zeit überleben; mehrere Primärziele können kombiniert werden.
- Zeitgesteuerte, datengetriebene Angriffswellen mit schwierigkeitsabhängiger Zusammenstellung in Engpass Khepri.
- Baukern, Impulswerk, Raffinerie, Werft, Geschütz, Signalstation und Servicehangar.
- Rüstungswerkstatt mit zwei kampagnengebundenen Ausbaustufen und lokal gespeichertem Einsatzfortschritt.
- Sammler, Späher, Panzer, Belagerungsfahrzeug, schneller Doppelsalven-Flanker und schwerer Präzisions-Lanzierer; getrennte Waffen-, Reichweiten-, Lade- und Panzerungsdaten sowie eigene VFX-/Soundfamilien.
- Drei wählbare **Fraktionsprofile** mit unterschiedlichen Kosten, Integrität, Tempo, Waffenleistung, Fahrzeugsilhouetten und Musikvarianten. Sie teilen in dieser Version den Technologiebaum.
- A*-Grid mit Terrainkosten, Gebäude-Belegung, verteilter Anfrageverarbeitung, Gruppenversatz und lokaler Separation.
- Drei Fog-Zustände, gespeicherte Gebäudesichtungen und Radar-Minimap ohne durch Nebel sichtbare Feinde.
- Wirtschaftende KI mit begrenztem Aufklärungswissen, bezahltem Bau und Produktion, Verteidigung, Gruppenangriffen und Rückzug beschädigter Angreifer.
- Drei KI-Verhaltensstufen ohne zusätzliche Lebenspunkte, Gratisgeld oder Produktions-Cheats.
- Pause, Neustart, Quick Save/Load, Start- und Zweiminuten-Autosaves, versionierte JSON-Spielstände, Optionen und Statistik-Debriefing.

**Noch nicht umgesetzt:** die vollständige geplante Kampagne über die ersten drei Einsätze hinaus, interaktives Tutorial, Infanterie, fraktionsspezifische Technologie und Spezialfähigkeiten, Map Editor, Gamepad, öffentliche Modding-Schnittstelle. Neue Fahrzeuge und Gebäudetechnik werden in den drei vorhandenen Einsätzen schrittweise freigeschaltet.

## Architektur und Prüfung

`Catalog` lädt und validiert JSON-Daten. `WorldGrid` verwaltet Terrain und A*. `Simulation` besitzt den renderunabhängigen 30-Hz-Spielzustand. `WorldRenderer` und `TacticalMap` zeichnen ausschließlich daraus. `MusicDirector` interpretiert Sichtkontakte und Kampfereignisse. `main.gd` verbindet Eingaben, Menüs, Anzeige und Dateipersistenz.

Tests aus dem Projektverzeichnis starten:

```powershell
.\Test-Solarit.ps1
```

Die Tests prüfen Wirtschaft, Technik, Produktionsabbrüche, Wege durch die Engstelle, Spielstände, Sichtwissen, Zielverlust bei Projektilen, Sieg/Niederlage und Produktionsausgänge. Die UI-Prüfung rendert echte Godot-Fenster, speist Mausereignisse ein und erstellt Bilder unter `test-output/`. Zusätzlich prüft `tests/frontend.gd` Intro-Start, automatisches Ende, Überspringen, Wiederholung, Classic-Darstellung und den Wechsel zwischen Menü-, Soundtest- und Spielmusik. Ein automatischer Spieldurchlauf demonstriert einen Sieg ohne zusätzliche Einheiten oder Solarit. Der Leistungstest misst 200 Fahrzeuge; seine Messung ist kein pauschaler FPS-Nachweis für andere Hardware.

Weitere Ergebnisse und Grenzen: `docs/QA.md`. Entwicklungsphasen: `docs/ROADMAP.md`.

## Windows-Build

```powershell
python tools/fetch_windows_template.py
.\tools\Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Windows Desktop" build/SOLARIT-RANDSEKTOR-07.exe
```

Das Build-Werkzeug lädt ausschließlich das Windows-Release-Template aus dem offiziellen Godot-Archiv per HTTP-Range. Alternativ das Template-Paket über Godots Exportdialog installieren und den benutzerdefinierten Templatepfad im Preset entfernen. Linux und Steam Deck wurden noch nicht getestet; die Laufzeit enthält keine Windows-spezifischen Gameplay-Abhängigkeiten.

Für einen vollständigen lokalen Release-Build mit Regressionstests, Spiel-Export, Inno-Setup-Installer und SHA-256-Prüfsumme `.\Build-Release.ps1` starten. Godot 4.7.2 samt Windows-Exportvorlage und Inno Setup 6 müssen installiert sein; eine fehlende Godot-Vorlage wird vom Skript geladen. Die Dateien landen unter `build/`. Das Skript lädt nichts zu GitHub hoch und committet keine Dateien.

## Installer, GitHub-Releases und Updates

Der private Quellcode liegt in `DieListe01/SOLARIT-RANDSEKTOR-07`. Der Workflow `.github/workflows/release-windows.yml` prüft Tests und Versionsnummer und baut einen Windows-Installer. Öffentlich erscheinen ausschließlich Installer, Prüfsumme und Update-Manifest im separaten Repository `DieListe01/ASHLINE-Releases`; der Updater prüft diesen Feed einmal pro Start. Ein Installer wird erst nach SHA-256-Prüfung gestartet und nur nach ausdrücklicher Bestätigung geöffnet. Details und Einrichtung stehen in `docs/RELEASING.md`.

Ein lokales Kommandantenprofil mit Nickname, Statistik und Einsatzhistorie wird beim ersten Start angelegt; erreichbar im Hauptmenü und unter Optionen. Für jede nicht abgebrochene Partie gibt es außerdem einen versionierten Bericht mit Zeitreihen und Diagrammen zu Ressourcen, Fahrzeugen, Gebäuden, Produktion und Verlusten beider Seiten. Die erste Online-Version meldet laufende Spielsitzungen und überträgt gewonnene Einzelspieler-Highscores an `https://api.dl-home.de`; die gemeinsame Top 10 kann im Spiel geladen werden. Details: [Kommandantenakte](docs/KOMMANDANTENAKTE.md) und [Online-Dienst](docs/ONLINE-DIENST.md).

Im Entwicklungsstand sind **1:1-Duell und Online-Koop mit Chat** vorhanden. Das Multiplayer-Menü enthält jetzt außerdem ein öffentliches Lobby-Verzeichnis für Direktverbindungen. Die Veröffentlichung ist freiwillig und zeigt die öffentliche IPv4-Adresse bis zum Ende der Lobby; für Internetbeitritt muss UDP 2456 zum Host-PC weitergeleitet sein. Start über „MULTIPLAYER“ im Hauptmenü (auch im Einsatzmenü): Modus wählen, verbinden oder Lobby auswählen, Fraktion/Farbe festlegen, beide „Bereit“ bestätigen. Das Duell bietet eigene Basen und Ressourcen, serverseitigen Kriegsnebel, geprüfte Befehle, Ping, Wiederbeitritt, Sieg/Niederlage und Revanche. Chat in Lobby und Spiel, im Spiel über Enter. Die Lobby-API ist lokal getestet; Internetbetrieb der ENet-Partie bleibt noch zu prüfen. Anleitung und Tests: [Multiplayer](docs/MULTIPLAYER.md) und [Online-Dienst](docs/ONLINE-DIENST.md).

## Rechte

Welt, Namen, Karten, Zeichnungen, musikalische Motive und SFX dieses Projekts wurden eigenständig erstellt. Projektcode und eigene Assets: MIT, siehe `LICENSE`. Godot und seine eingebetteten Drittbibliotheken behalten ihre jeweiligen Lizenzen; siehe `THIRD_PARTY_NOTICES.md`.

## Grafik und Befehle in 0.4

Der normale Modus verwendet eigene industrielle Zeichnungen mit Höhenwirkung, Metalloberflächen, Ketten/Rädern/Schwebepods, Turm und Rohr, Lüftern, Rohrleitungen, Silos, Toren und Antennen. Die Bauliste zeigt eigene Vorschaubilder. Organische Geländegrenzen, Materialshader, Mündungsblitze, Leuchtspuren, Funken, Rauch und Fahrstaub ergänzen die Darstellung. Moderne Nahansicht bis 2,5×, Classic bleibt bei echter 640×360-Auflösung.

**Rechte Maustaste:** kurz klicken für einen Kontextbefehl, gedrückt halten und ziehen zum Verschieben der Karte. Ziehen erzeugt keinen Fahrbefehl und endet auch beim Loslassen über der Seitenleiste.

**Sammler:** mit Linksklick auswählen, dann Rechtsklick auf ein bekanntes Solaritfeld. Alternativ „SAMMELN“ in der Seitenleiste und anschließend Linksklick auf das Feld. „ABLADEN“ oder Rechtsklick auf eine eigene Raffinerie schickt ihn zurück. Der gewählte Bereich bleibt nach dem Abladen bevorzugt, bis das Feld leer ist. Neue Befehle ersetzen auch noch ausstehende Pfadanfragen; Stopp hält den Sammler an. Status und Ladung stehen in der Seitenleiste.

## Automatik in 0.5

Sammler beginnen selbstständig, suchen bekannte Solaritvorkommen, sammeln, fahren mit voller Ladung zur eigenen Raffinerie, laden automatisch ab und sammeln erneut. Nach einem manuellen Fahrbefehl wird dieser Kreislauf am Ziel automatisch wieder aufgenommen. „FELD WÄHLEN“ und „ABLADEN“ sind optionale Eingriffe; Stopp und Halten unterbrechen bewusst die Arbeit. Kampffahrzeuge und Geschütze erfassen sichtbare Feinde automatisch. Auch fahrende Kampffahrzeuge verteidigen sich jetzt, ohne ihren Fahrbefehl aufzugeben. Bewaffnete Bedrohungen haben bei der automatischen Zielwahl Vorrang vor Wirtschaftsobjekten. Verdeckte Gegner werden nicht erfasst.

## Grafikstand 0.6

Gemeinsame industrielle Gebäude- und Fahrzeugdarstellung in beiden Modi; Classic reduziert die Auflösung auf 640×360. Neues geschichtetes Gelände mit organischen Übergängen, Rissen, Geröll und Sandrippen, variierende Solaritkristalle mit sichtbarer Abnahme, Fahrspuren, zusätzliche Bauphasen mit Schweißfunken, kritische Gebäudebrände und Fertigstellungspulse.

Die umfangreiche Art-Direction ist damit noch nicht vollständig umgesetzt. Weitere UI- und Effektpolitur sowie die angeforderte Spieler-/Command-Architektur bleiben offen; diese Version hat keinen Multiplayer.

## Farbwelt und Kennung 0.7

Warme Ocker-/Kupferpalette für Sand, Fels, Metalle, Geröll, Schatten, Nebel, Intro und UI. Solarit bleibt kühl. Leichter Hitzeschimmer läuft nur im Welt-Viewport. Eigene Objekte sind kräftig cyan, feindliche rot: größere Panzerplatten und Gebäudepanels, Auswahlringe, separate Team-Unterstriche an Grün/Gelb/Rot-Healthbars, Icons, Minimap und Inspektionsanzeige verwenden die Spielerfarbe. Farbe ist von Fraktionsboni getrennt; acht gespeicherte Farbslots sind vorbereitet. Das Szenario hat weiterhin zwei aktive Spieler und keinen Multiplayer.

Weitere Details: Metallfugen, Nieten, Abrieb, Rost, Sockelstaub, warme Auslässe, zusätzliche Fraktionsformen (Kettenindustrie / schräge mobile Panzerung / glatte Hovermodule), Embleme, Turmrückstoß, Fahrzeugschadensrauch sowie Förderstrahl und Staub am arbeitenden Sammler. Gegner sind per Linksklick inspizierbar, bleiben außerhalb der eigenen Befehlsauswahl und werden bei Sichtverlust nicht weiter angezeigt.

## Visual Polish Pass 2 / 0.8

Neuer lokaler Präsentationskanal für Schuss, Impact, Treffer und Zerstörung. Energie, Kanone und Belagerung haben unterschiedliche Mündungsfeuer, Trails und eigene Sounds. Treffer erzeugen kurze Zielblitze, Funken und Staub; Zerstörung erzeugt gestaffelte Feuerimpulse, Rauch, Splitter, Druckring und zeitlich begrenzte Trümmer. Der Kamerastoß verändert nur den Bildversatz, bleibt auf die Welt begrenzt und hat AUS/LEICHT/NORMAL. Partikelvariation, Trümmer und Kamerastoß verändern weder Simulation noch deren RNG. Neue Partikel und Ruinen werden lokal verwaltet und mengenmäßig begrenzt.

Größere Panzer und Sammler, bewegte Ketten, Karosseriebewegung, Bremsstaub und Motor-Ambience. Bauvorschau als transparentes Hologramm, zusätzliche Montageprojektoren und Fundamentstaub. Baukern mit erhöhten Kommandomodulen, Energiekomponenten, bewegtes Raffinerieband mit Dampf, Werkkran, Scannerimpulse und bewegter Wartungsarm.

Minimap mit Rahmen, Radarscan und Warn-/Fertigstellungspings. Aktiver Bau-/Fahrzeugtab, sichtbarer Produktions- und Baustellenfortschritt, eindeutige Bauphasen, wertigere Tooltips sowie Energie- und Verlustmeldungen. Optionen: Effektqualität NIEDRIG/MITTEL/HOCH (wichtige Effekte bleiben erhalten) und Kamerastoß. Dieselben Systeme laufen in Modern und Classic. Keine neuen Waffengattungen, keine Networking-Implementierung; die bestehende Zwei-Spieler-Simulation ist damit weiterhin kein fertiger Mehrspielermodus.


## Combat VFX 0.9

Acht kosmetische Waffenprofile mit eigenen synthetisierten Schuss-/Trefferklängen, lokalen Mündungsvarianten, Energie-Arcs, schweren Staubstößen, Splittern, visuellen Kratern, Rückstoß und Trefferrütteln. Die aktiven Waffen verwenden ENERGY (pulse), BALLISTIC_HEAVY (cannon) und SIEGE (mortar); die übrigen fünf Profile sind eine Bibliothek für künftige Waffen und keine neuen Spielmechaniken. Belagerungsgeschosse erhalten eine rein gezeichnete Flugkurve mit Schatten; reale Geschwindigkeit, Treffer und Schaden bleiben unverändert.

Gebäudeschäden: gesund bis 70 %, beschädigt unter 70 %, kritisch unter 40 %, schwer beschädigt unter 15 %. Fahrzeuge unter 35 % zeigen Flammen und Funken. Zerstörungen hinterlassen begrenzte lokale Ruinen; Baukerne zeigen Überladung, zeitversetzte Detonationen, einen stärkeren Impuls und längeren Rauch. Terrain, UI, Teamfarben und gesunde Modelle bleiben erhalten. Modern und Classic verwenden dieselbe Bibliothek. Lokale Effekte verbrauchen keinen Simulationszufall und beeinflussen keine Navigation.

Der übergebene Combat-Auftrag endet nach der Überschrift „21. RANDOMISIERUNG“ mit „Explosion“. Die vollständigen Abschnitte 1–20 und lokale Varianten sind umgesetzt; kein fehlender Folgetext wurde angenommen.


## Style Consolidation 0.10

Stärkere warme Lichtkanten und Kontaktschatten, größere dynamische Teamflächen, markante Gebäudeaufbauten und klarere Scout-, Sammler- und Belagerungssilhouetten. Terrain ergänzt um alte Förderwege, Schrottgruppen, trockene Becken und Dünenzüge; Randfarben organisch gemischt. Die Oberflächendetails ändern weder Navigation noch Bauflächen. Bauprojektion und Montage zeigen einen bewegten Scan, vor der Aktivierung erscheinen die typischen Gebäudesysteme.

Nach realen Zerstörungsereignissen bleiben 120 Sekunden lang kosmetische Gebäuderuinen und Fahrzeugchassis sichtbar. Raffinerieruinen besitzen offene Tankringe, Hallen verbogene Träger, Baukern-/Radarreste einen gebrochenen Mast. Scout, Panzer, Sammler und Belagerer haben getrennte Explosionsgrößen. Schaden, Feuer, Funken und Rauch bleiben in Modern und echtem 640×360-Classic gleichwertig. Lokale FX werden beim Pausieren eingefroren.

HUD: Auswahlporträt, bis zu sechs Icons bei Gruppenauswahl, kompakte Angaben zu HP/Panzerung/Befehl/Waffe, sichtbare Bauzeit, rote Kennzeichnung fehlender Anforderungen, Solaritkosten, Werftwarteschlangen und gerahmte Meldungen. Die Energieanzeige nennt Verbrauch, Erzeugung und freien Überschuss.

Alle Gameplay-Eingaben aus der UI laufen nun durch `Simulation.submit_command(packet, issuer)`. Unterstützt: Move, Attack, AttackMove, Build, Produce/Cancel, Harvest/Return, Stop/Hold/Guard, Rally und Repair. JSON-kompatible Pakete werden auf Format, Eigentum, Sichtbarkeit und bestehende Bau-/Produktionsregeln geprüft. Entities besitzen `owner_id`, `team_id`, `faction_id`; alte Spielstände werden migriert, inkonsistente Metadaten vor Mutation verworfen. Dies ist eine lokale Command-Grenze: Netzwerktransport, Host-Authentifizierung, Tick-Scheduling, weitere aktive Teams und vollständige Multiplayer-Authority bleiben offen.

260 Funktionsprüfungen bestanden. Native Bilder: `test-output/style_battle_modern.png`, `style_battle_classic.png`, `style_aftermath_modern.png`, `style_group_selection.png`. Diese sind isolierte Prüfszenen über dem echten Renderer. Keine neuen Raketen-/Spezialeinheiten in diesem Pass.


## Readability & Persistent Destruction 0.11

Formabhängige Gebäude-, Turm- und Kristallschatten, schwere Fahrzeugfronten, ausgefallene Lüfter/Scanner bei kritischem Schaden und zusätzliche regionale Industrielandmarken. Palette, Layout und Spielbalance bleiben erhalten. Auswahlringe und Lebensbalken liegen über Rauch und Explosionen.

Die bisherige 120-Sekunden-Grenze aus 0.10 entfällt: Wracks, typisierte Ruinen und schwere Krater bleiben missionslang innerhalb fester Budgets (128 Reste, 80 Krater). Beim Recycling werden Fahrzeuge vor gewöhnlichen Gebäuden und Baukernen ersetzt. Rauch/Feuer klingen nach 60 beziehungsweise 90 Sekunden aus; bei dichten Gefechten wird Rauch begrenzt und abgeschwächt.

Spielstände speichern die lokalen Spuren separat vom Simulationszustand. Alte Saves bleiben lesbar; ihre bereits verschwundenen Spuren können nicht rückwirkend rekonstruiert werden. Classic zeigt dieselben Reste in echter 640×360-Auflösung. Details: [Persistenz und Budgets](docs/PERSISTENT_DESTRUCTION_IMPLEMENTATION.md).


## Modelle und Updateinfo 0.12

Im Hauptmenü neben „Intro ansehen“ und im Pausenmenü öffnet **UPDATEINFO** die komplette Versionshistorie. Links eine Version auswählen, rechts Datum und Änderungen lesen; lange Texte sind scrollbar. Maus und Pfeiltasten werden unterstützt. Die Versionseinträge stehen in `data/update_history.json`; neue Releases werden oben ergänzt. Die aktuelle Versionsnummer im Menü kommt aus derselben Datei. Historische Datumsangaben beruhen auf den vorhandenen Release-Archiven vom 01.10.2026.

Modelle haben abgeschrägte Metallkanten, stärker modellierte Tankoberflächen, zusätzliche Kommandokern-Ebenen und plastischere Geschütztürme. Gebäudeecken und flache unterbrochene Fahrzeugbögen ersetzen dicke Auswahlkreise. Energie-Treffer sind kompakter, Funken kürzer. Kristalle variieren in Anordnung, Höhe, Breite und Neigung; die Variation ist rein visuell und verbraucht keinen Simulationszufall. Beide Grafikmodi, Palette, Spiellogik und Persistenz bleiben erhalten.

310 Funktionsprüfungen bestanden. Native Vorschaubilder: `test-output/updateinfo_modern.png`, `updateinfo_classic.png`, `style_battle_modern.png` und `style_battle_classic.png`.

## Objektinfos, Reparatur und Gefechtsdetails 0.13 — 02.10.2026

Fahrzeug oder Gebäude auswählen und oben OBJEKTINFO anklicken; alternativ die kurze Objektinfo rechts anklicken. Das pausierte Detailfenster zeigt Beschreibung, HP, Panzerung, Sichtweite, Waffendaten, Tempo beziehungsweise Energie, Ladung und Reparaturkosten.

REPARIEREN oder R schaltet bei fertigen eigenen Gebäuden die Reparatur ein/aus. Sie kostet 0,3 Solarit pro tatsächlich repariertem HP, maximal 26 HP/s. Bei Fahrzeugen führt der Befehl zum nächstgelegenen erreichbaren und versorgten Servicehangar. Dort werden eigene Fahrzeuge im Umkreis von 100 automatisch gegen Solarit repariert. Fehlende Energie stoppt die Hangarreparatur; ohne Solarit gibt es keine Heilung. Sammler warten nach einem Serviceauftrag bis zur vollständigen Reparatur und nehmen anschließend ihre autonome Arbeit wieder auf. Kampffahrzeuge bleiben für weitere Befehle am Hangar. Manuelle neue Befehle ersetzen den Serviceauftrag. Baustellen zuerst fertigstellen; feindliche Objekte können nicht repariert werden. Gebäudereparatur benötigt Solarit, aber keinen Hangar.

Mehr Details: unterteilte Panzerplatten, Kabel, Verschlüsse, Zugösen, Auspuffmanschetten, Wartungsluken, Klemmen und Schweißfunken. Bewegte mehrschichtige Flammen, kleinere Brandspuren, unregelmäßige Trümmer, gebrochene Fundamente und erkennbare Räder/Motoren in Wracks. Kompakte Auswahlwinkel und versetzte Lebensbalken reduzieren Überlagerungen. Updateinfo enthält nun 13 datierte Versionen.

## Drehbare Gebäude und Stereo-Sound 0.14 — 02.10.2026

Beim Bauen drehen R oder E das gewählte Gebäude um 90 Grad; Q dreht zurück. Oben erscheint während der Bauplatzwahl der Knopf DREHEN. Vorschau und Bauprüfung nutzen die gedrehte Fläche; die Raffinerie belegt je nach Drehung 3×2 oder 2×3 Felder. Ausrichtung, Kollision und Erinnerungen an sichtbare Feindgebäude bleiben beim Speichern erhalten. Gedrehte Werften bevorzugen den Ausgang auf der Vorderseite und richten den anfänglichen Sammelpunkt entsprechend aus. Bestehende Gebäude werden dadurch nicht nachträglich gedreht. Alte Spielstände bleiben kompatibel.

Weitere sichtbare Details: Instrumente, Schalter, Wartungsstufen, Manometer, Ventilrohre, Schienen, Haltebänder, Kanister und feine Lüftungslamellen. Fahrzeuge haben weichere breite Schatten und einen klaren Kontaktschatten. Modern bleibt in voller Auflösung; Classic verwendet weiterhin 640×360.

60 neu erzeugte Stereo-Effekte (44,1 kHz): 54 Waffen-/Trefferdateien für neun Familien mit jeweils drei Varianten plus sechs Bau-/Aktionsklänge. Anschlag, Druck, Metallresonanzen und kurze Nachhalllagen geben schweren Waffen mehr Gewicht; Energiewaffen klingen elektrisch. Drehung und Reparatur bekommen Rückmeldung. 24 begrenzte Stimmen, getrennte Abstände pro Waffenklang, entfernungsabhängige Lautstärke und SFX-Limiter verhindern gegenseitiges Unterdrücken und zu laute Summen. Musikwechsel erkennen das Überschreiten einer Taktgrenze, auch wenn eine Audioabfrage verspätet eintrifft.



## Flüssigere Gefechte und neue Einsatzvorbereitung 0.15 — 02.10.2026

Die Fraktions- und Missionsauswahl erscheint als eigene, aufgeräumte Vorbereitungsseite statt als überlagerndes Fenster über dem Startmenü. Fraktion, Gegnerstärke, Missionsziel und Startaktion sind getrennt angeordnet. Menükarten erhalten feinere Rahmen, abgerundete Ecken und dezente Schatten.

Solaritkristalle werden aus einer facettierten Textur mit mehreren Formvarianten gezeichnet. Bei großen Gefechten vereinfacht die Darstellung nicht ausgewählte Fahrzeuge und Bodendetails; einzelne ausgewählte Einheiten behalten ihre vollen Modelle. Im reproduzierbaren Messlauf mit 40 Fahrzeugen stieg die Bildrate auf der RTX 3060 von 4,6 auf rund 29 FPS. Die Szene wurde mit angehaltener Simulation gemessen, um ausschließlich die Darstellung zu vergleichen.

## Rendering-Optimierung 0.17 — 02.10.2026

Fahrzeuge werden aus hochauflösenden Grafiken wiederverwendet, ohne bei vielen Einheiten auf vereinfachte Modelle umzuschalten. Bewegung und Turmausrichtung werden zwischen Simulationsticks interpoliert; Ketten, Spuren und Kampfeffekte bleiben dynamisch. Statische Bodendetails werden in 16×16-Kacheln gebündelt, Fahrspuren in einem Zeichenlauf ausgegeben.

Auf der RTX 3060 stieg die pausierte 40-Fahrzeuge-Messung von 5,9 auf rund 54 FPS; die Zeichenaufrufe fielen von 21.580 auf rund 4.600. Der Zielwert von 60 FPS ist noch nicht erreicht; 40 bewegte Fahrzeuge mit Kampfeffekten bleiben mit rund 23 FPS ein offener Engpass. Messaufbau und Grenzen stehen in [docs/QA.md](docs/QA.md).

## FPS-Anzeige und Einbruchprotokoll 0.18 — 02.10.2026

Während eines Einsatzes zeigt die obere Statusleiste laufend die Bildrate: Mint ab 50 FPS, Gold ab 30 FPS und Rot darunter. Sinkt das gleitende 0,4-Sekunden-Mittel unter 45 FPS und bleibt dort mindestens eine Sekunde, wird ein Einbruch protokolliert; ein Erholungseintrag entsteht ab 50 FPS. Die CSV-Datei `performance_events.csv` liegt im Godot-Appdatenordner (`user://performance_events.csv`) und enthält Zeitstempel, Einsatzzeit, Dauer, mittlere/minimale FPS, Gesamt- und sichtbare Objektzahlen (eigene und feindliche Einheiten/Gebäude), VFX, Draw Calls, Primitives, Prozesszeiten und Fahrzeug-Cache-Zähler. F3 zeigt weiterhin die ausführlichere Diagnose im Spiel.

## Einsatzrekorde 0.19 — 02.10.2026

Nach einem gewonnenen Einsatz zeigt die Auswertung die Punktzahl, deinen Rang und eine Vorschau der drei besten Ergebnisse. Im Hauptmenü öffnet **BESTENLISTE** die persönliche Top 10 des Levels. Gewertet werden 1.000 Basispunkte, +250 je Abschuss, Solarit ×0,5, +120 je produziertem Fahrzeug, +100 je errichtetem Gebäude, ein Zeitbonus von max. 0 bis 3.600 Punkten sowie −200 je verlorenem Fahrzeug und −500 je verlorenem Gebäude. Bei Punktgleichheit gewinnt die schnellere Zeit. Die Rekorde liegen dauerhaft in `user://highscores.json`; Niederlagen werden nicht eingetragen. Derzeit gibt es **ein spielbares Level: Das Veyra-Becken**.


## Veyra-Front 0.20 — 02.10.2026

Die Einsatzvorbereitung bietet jetzt drei Missionen. **Die trockene Ader** verbindet Expansion, zwei Raffinerien, 8.000 geliefertes Solarit und einen gezielten Schlag gegen die feindliche Raffinerie. **Engpass Khepri** startet mit ausgebautem Außenposten und verlangt 15 Minuten Verteidigung gegen sechs datengetriebene Angriffswellen; die Zusammenstellung unterscheidet sich zwischen Ruhig, Ausgewogen und Entschlossen.

Das Missionssystem wertet mehrere Primärziele gemeinsam aus und unterstützt jetzt `destroy_target`, `destroy_all`, `protect`, `survive`, `harvest_amount` und `build_structure`. Erfüllte Ziele bleiben erfüllt, auch wenn sich der Weltzustand danach wieder ändert. Wellenfortschritt und Zielstatus werden im Spielstand mitgeführt. Neue Karten können außerdem bereits vorhandene Ruinen und Krater als rein visuelle, nicht blockierende Welt-Details definieren.

## Gebäudecache 0.22 — 02.10.2026

Fertige und intakte Gebäude werden in hochauflösenden Texturen zwischengespeichert. Sie bleiben dadurch detailliert, müssen ihre vielen einzelnen Vektorformen aber nicht in jedem Bild erneut zeichnen. Baustellen, Reparaturen und stärker beschädigte Gebäude behalten ihre Live-Effekte. F3 zeigt Cache-Treffer und -Fehler.

Der Stresstest prüft vier und 50 zusätzliche Gebäude im selben sichtbaren Bereich. Produktionszustand, Fraktion, Drehung und Schadensstufe werden berücksichtigt; animierte Maschinendetails werden regelmäßig aktualisiert.

## Kampagnenausbau 0.26 — 03.10.2026

Nach Einsatz 01 können Fahrzeugwerft, Raffinerie und Radar ausgebaut werden. Die Werft schaltet den Flammenwerfer Glut frei und verkürzt Montagezeiten, die Raffinerie zahlt 20% mehr Solarit aus. Nach Einsatz 02 erweitert ein Radar-Ausbau die Sicht; Werkstatt Stufe 2 öffnet Lanzierer Prisma und den schwer gepanzerten Durchbruchpanzer Wall. Glut verursacht Flächenschaden auf kurze Distanz, Wall ist langsam, widerstandsfähig und besonders wirksam gegen Gebäude. Ausbaukosten, Freigaben und Effekte stehen in der Objektinfo und bleiben in Spielständen erhalten.

## Kampagnenausbau 0.25 — 03.10.2026

Kampagnensiege öffnen den nächsten Einsatz und seine Technikstufe. Die Rüstungswerkstatt wird nach Einsatz 01 verfügbar; Stufe 1 schaltet Dorn frei, Stufe 2 nach Einsatz 02 den Lanzierer Prisma. Ausbauzeit, Solarit und Energie bremsen die Forschung nachvollziehbar. Die zwei Fahrzeuge nutzen eigene gezeichnete Silhouetten, Werte, Geschosse und bestehende gebündelte Effekt- und Soundfamilien. Die Einsatzvorbereitung beschreibt nun direkt, was Ruhig, Ausgewogen und Entschlossen im Gefecht bedeuten.

## Adaptive Gefechts-VFX 0.23 — 03.10.2026

Bei mehr als zehn gleichzeitig sichtbaren Zerstörungen reduziert der Renderer Details an einem Teil der Explosionen und Ruinen. Die großen Impulse und Kernexplosionen bleiben detailliert; Feuer, Rauch, Staub und Trümmer werden in der dichten Szene gezielt ausgedünnt. Der Test mit 36 gleichzeitigen Zerstörungen fiel von 50,7 auf 21,4 ms pro Renderpass. 50 zusätzliche Gebäude bleiben bei rund 104 FPS auf einer RTX 3060 im isolierten Basistest.

## Renderprofil 0.21 — 02.10.2026

F3 schlüsselt die Zeichenzeit jetzt in Terrain, Ruinen/Trümmer, Gebäude, Fahrzeuge und Kampfeffekte auf. Dazu kommen Zähler für Solaritfelder, Wracks, Schüsse, Treffer und Partikel. Das Profiling läuft nur, wenn F3 eingeschaltet ist.

Der RTX-3060-Stresstest ergab rund 59 ms pro Bild bei 36 Wracks mit Rauch und rund 71 ms bei 25 sichtbaren Gebäuden. Damit sind die teuren Bereiche messbar; diese Version enthält noch keine FPS-Optimierung.

## Gefechts-Rendering 0.24 — 03.10.2026

Der Desktop nutzt Godots Forward+-Renderer. In derselben bewegten 20-gegen-20-Schlacht stieg die Bildrate auf einer RTX 3060 von rund 46 FPS mit GL Compatibility auf rund 78 FPS. Gebündelte Zeichenaufrufe senken zusätzlich die Kosten für Kampfeffekte und Fahrspuren; Fahrzeugdetails bleiben erhalten.

Der reproduzierbare A–G-Renderbenchmark trennt Bewegung, Geschosse, Treffer, Zerstörung, Gefecht und angesammelte Trümmer. Der Fünf-Minuten-Test hält ein Gefecht mit 40 Einheiten aktiv und protokolliert FPS nach 30 Sekunden, 2 Minuten und 5 Minuten. Die CSV-Messungen stehen in `test-output/`; detaillierte Ergebnisse und der weiterhin langsame Extremfall mit vielen Wracks stehen in [docs/QA.md](docs/QA.md).

# Readability & Persistent Destruction — 0.11

Dieser Pass baut auf 0.10 auf. Palette, HUD-Layout, Missionsdaten, Waffenwerte, Navigation, KI und Simulation bleiben erhalten. Die einzige Ergänzung im Simulationscode ist die Entity-ID im bestehenden kosmetischen Todesereignis, damit eine zerstörte Auswahl unmittelbar verschwindet.

Gebäude werfen jetzt achteckige Fundament- und aufbautenabhängige Schatten: getrennte Kühltürme beim Impulswerk, Mast und Schüssel beim Radar, unterschiedliche Höhen der anderen Klassen. Kristalle haben gerichtete scharfe Schatten; schwere Fahrzeugfronten zusätzliche Panzerflächen und Geschütztürme eigene Schatten. Kritische Gebäude stoppen Lüfter und Radarscanner, während Schaden und Warnsignale weiterlaufen. Die vorhandenen unterschiedlichen Kommandokronen, Tankgruppen, Hallen, Wartungsarme und Scanner bleiben erhalten.

Der Terrain-Cache ergänzt ein verlassenes Industriegelände und große Plateaukonturen. Die bestehenden strategischen Rasterregionen bleiben unverändert; dekorative Flächen erzeugen keine zusätzlichen Hindernisse oder Kleinststein-Mengen.

## Zerstörung und Budget

Jedes sichtbare bestätigte Todesereignis hinterlässt einen typisierten stationären Rest. Tanks und Belagerer besitzen Chassis, Ketten, versetzten Turm und gebogenes Rohr; Sammler Ladekastenrippen und gebrochenen Förderarm. Gebäuderuinen zeigen Fundamente, gebrochene Platten, Wände, Leitungen und klassenspezifische Module: offene Raffinerietanks, gefallene Energiekühler, eingestürzte Hallenträger, gebrochener Scanner und massiver ausgebrannter Kommandokern.

Ruinen und schwere Einschlagskrater besitzen keine zeitliche Ablaufgrenze. Es gelten 128 Reste, 80 Krater und weiterhin 220 kurzlebige Effektinstanzen. Bei vollem Restebudget wird zuerst das älteste Fahrzeug, dann das älteste gewöhnliche Gebäude und zuletzt ein Baukern ersetzt. Krater verwenden FIFO. Missionsstart setzt alle Spuren zurück. „Missionslang“ gilt somit innerhalb dieser bewusst begrenzten Speicherbudgets.

Fahrzeuge: 0–5 s Feuer/Rauch/Glut, 5–20 s Rauch/Glut, 20–60 s auslaufender leichter Rauch, danach kaltes statisches Wrack. Gebäude: entsprechende Grenzen 10/30/90 s. Rauchquellen sind auf 8/16/24 nach Qualitätsstufe und zwei pro 96-Welteinheiten-Bereich begrenzt. Überlappender Explosionsrauch wird zusätzlich abgeschwächt. Partikel, Feuer, Splitter und Kamerastoß laufen aus. Außerhalb des sichtbaren Kameraausschnitts werden Effekte und Reste nicht gezeichnet.

Gebäude besitzen Vorblitze vor der Hauptdetonation; der Baukern behält seine gesonderte Überladung. Auswahlringe und Lebensbalken liegen nach Explosionen, Rauch und Nebel, mit dunkler Kontrastkante. Fremde Markierungen benötigen weiterhin aktuelle Sicht. Unsichtbare Todesereignisse erzeugen keine kosmetischen Reste; bereits bestätigte Spuren werden nur in erkundetem Gebiet gezeichnet und durch Fog of War abgedunkelt.

## Spielstände und Authority

Optionales `visual_state` neben dem unveränderten Format-1-Simulationssnapshot speichert ausschließlich Ruinen/Krater: Typ, Position, Orientierung, Radius, Variante, Footprint und Alter. Feuer/Rauch werden aus dem Alter rekonstruiert. Partikel, Shake und Zufallsgenerator werden nicht gespeichert. Vollständige Validierung von Mengen, endlichen Werten, Grenzen und Typen geschieht vor dem Wechsel der aktiven Mission. Bei fehlerhaften kosmetischen Daten bleibt die bisherige Mission erhalten. Alte Spielstände ohne Feld laden mit leerem kosmetischen Zustand. Alte bereits verschwundene Wracks können nicht rückwirkend rekonstruiert werden.

Die Renderinitialisierung nach Laden bewahrt den installierten lokalen Zustand. Keine Reste wirken als Collider, Pfadhindernisse oder Schadensquelle. Kein visueller Zufall und kein Alter fließen in Commands oder Simulation zurück. Dies bereitet getrennte lokale Darstellung für spätere Multiplayer-Authority vor; Netzwerktransport wird dadurch nicht implementiert.

Modern zeichnet dieselben Daten in hoher Auflösung. Classic rendert tatsächlich 640×360 und vergrößert mit Nearest-Filtering; keine Reste oder Zustandsinformation werden wegen des Modus entfernt.

## Nachweise

`tests/persistent_destruction.gd` prüft echte Tankgeschosse, sofortige Auswahlbereinigung, schwere Gebäudeschäden, Fabrik-/Baukernruinen, 15 Minuten kosmetische Lebenszyklen, JSON und tatsächliches Save/Load, atomare Ablehnung beschädigter Persistenzdaten, Legacy-Spielstände, unveränderte Authority/RNG, reale 20-gegen-20-Simulation und Budgets. Dieser Langzeitnachweis beschleunigt die kosmetische Zeit; er ist kein 15-minütiger menschlicher Spieltest.

Native Bilder: `persistence_destruction_modern`, `persistence_cold_modern`, `persistence_cold_classic`, `persistence_20v20_modern`, `persistence_20v20_classic`, `persistence_20v20_aftermath`. Menschliche Lesbarkeit und Framerate auf weiterer Zielhardware bleiben ergänzende QA.

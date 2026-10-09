# Grafik- und Assetprüfung v0.38.0

Stand: 09.10.2026

## Ergebnis

Die acht Gebäuderollen haben nun eigene, zweckgebundene Blender-Modelle: Kommandozentrum, Reaktor, Raffinerie, Montagewerft, Geschützstellung, Radar, Reparaturhangar und Munitionswerk. Die Unterschiede liegen in Grundriss und Silhouette, Anlagen und beweglichen Baugruppen; sie beruhen nicht allein auf Farbvarianten. Alle sieben Kampf- und Aufklärungsfahrzeuge haben ebenfalls rollenspezifische Formen und Geräte. Der bereits spezialisierte Solarit-Sammler bleibt als eigenes Modell erhalten.

Die Modelle nutzen gemeinsame tilebare PBR-Oberflächen für Keramik, Graphit, Stahl, Emaille, Warnlackierung und Gummi. Ein GLB-Postprozessor verlinkt diese sechs Textursätze extern statt sie in jede Modelldatei zu kopieren; alle Einheiten verwenden denselben importierten Texturpool. Die 16 Gebäude- und Kampf-/Aufklärungsfahrzeug-GLBs schrumpfen gemeinsam von 82,6 MB auf rund 22,1 MB, bei unveränderter Texturauflösung von 512×512. Statische Bauteile werden pro Material zusammengefasst; funktionale Teile behalten eigene Dreh- und Gelenkpunkte.

Im vorhandenen Godot-SubViewport- und Cache-Renderer werden jetzt Zustände für Raffinerie-Entladung, laufende Fertigung, Radar/Reaktor, Montagekran, Reparaturarme, Kommando-Sensor und Geschützturm berücksichtigt. Diese Architektur wurde nicht ersetzt. Die Zustands-, Asset- und Galerietests prüfen die Rollen, Materialien, Pivot-Knoten und Cache-Umschaltungen.

## Prüfung und Messungen

Ausgeführt wurden die vollständige `Test-Solarit.ps1`-Suite, fokussierte GLB-/Blend- und Cache-Zustandstests, die 2,5D-Modellprüfung sowie beschriftete Gebäude-, Fahrzeug- und Spielszenen-Galerien. Die Suite meldete keine fehlgeschlagenen Tests. Die Bewegungsposen werden über gerichtete Simulation geprüft; die Galerie zeigt die Standmodelle. Die Raffinerie-Entladung wird über einen aktiven Cache-Zustand und den Spiel-Showcase geprüft.

Der gleiche GPU-Benchmark lief mit Godot 4.7.2 und NVIDIA RTX 3060 bei 1920×1080. Die angezeigten v0.38-Werte sind der Median aus zwei Durchläufen nach dem Teilen der Texturen; der archivierte v0.37.0-Vergleich stammt aus einem Durchlauf und ist deshalb ein Richtwert, kein kontrollierter statistischer Vergleich.

| Szene | v0.37.0 FPS | v0.38.0 FPS, Median | Gebäude-Pass v0.38.0 |
|---|---:|---:|---:|
| Ruhe, 40 Einheiten | 109,4 | 92,1 | 0,014 ms |
| Minikarte ausgeblendet | 143,6 | 114,1 | 0,011 ms |
| Sichtlast, 1.240 Einheiten | 92,8 | 97,5 | 0,013 ms |
| Statischer Kampf | 145,2 | 136,2 | 0,013 ms |
| Laufender Kampf | 29,1 | 26,6 | 0,012 ms |

Die Pässe für Gebäude und Fahrzeuge bleiben selbst im Gefecht klein (Gebäude median 0,012 ms, Fahrzeuge median 0,16 ms). Durch das Teilen der Maps verbesserte sich der mittlere Gefechtstest von 23,9 auf 26,6 FPS gegenüber der ersten v0.38-Fassung mit eingebetteten Texturkopien; die endgültigen GLBs sind zusammen rund 73 % kleiner. Die endgültigen v0.38-Gesamt-FPS liegen in vier Vergleichsszenen weiterhin unter dem einzelnen v0.37-Messwert, während die Sichtlast leicht besser ist. Teile der Bildzeit liegen außerhalb der instrumentierten Godot-Pässe, die alte Referenz hat nur einen Messlauf, und die Galerieszene mit 145 FPS ist kein direkter Vergleich. Die Performance bleibt daher ein klarer Optimierungspunkt; vor einer größeren Erhöhung gleichzeitiger Einheiten sollten SubViewport-GPU-Zeit und Cache-Erstellungen separat vermessen werden.

## Qualitätsgrenzen und nächste Stufe

Die Pipeline ist für weitere GLB-Modelle geeignet: Blender ist der Autorierungsweg, glTF/GLB das Laufzeitformat, und Godot behält seinen bestehenden Renderer. Dieses Update erzeugt über Blender-Python reproduzierbare Assets mit individuellen Silhouetten, mechanischen Baugruppen, extern geteilten PBR-Maps und animierbaren Knoten. Es bleibt jedoch prozedural aufgebautes Hard-Surface-Modelling; es ersetzt weder ein manuell modelliertes High-Poly-Design noch sculpted Oberflächen, individuelle Decals, ausgefeilte UV-Materialschichten oder vollständige Ketten-/Radanimationen. Kleine Details werden durch die Top-Down-Ansicht und die zwischengespeicherten Rendergrößen begrenzt.

Für eine weitere Qualitätsstufe können einzelne Rollen in Blender gezielt von Hand ausgearbeitet und weiterhin als GLB in dieselbe Pipeline importiert werden. Sinnvolle Kandidaten sind zuerst Sammler und Panzer: sichtbare Werkzeuge/Fördertechnik beziehungsweise ein korrekt proportioniertes Fahrwerk mit echten umlaufenden Ketten. Modell-, Textur- und Cache-Auflösung sollten dabei zusammen mit GPU-Frametime und Arbeitsspeicher budgetiert werden.

## Galerien

Die ausführbaren Galerien liegen nach dem Testlauf in `test-output/`:

- `buildings_gallery_v0.38.0.png`
- `vehicles_gallery_v0.38.0.png`
- `industrial_showcase_v0.38.0.png`
- `industrial_detail_zoom_125_v0.38.0.png`
- `industrial_detail_zoom_150_v0.38.0.png`

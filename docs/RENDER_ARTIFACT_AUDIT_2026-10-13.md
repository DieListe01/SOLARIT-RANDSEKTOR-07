# Renderartefakt-Audit – 13.10.2026

## Aufnahme und Methode

Untersucht wurde `C:\Users\dirkl\Desktop\12-10-2026_16-32-44.mp4` mit FFprobe und FFmpeg. Die Aufnahme ist 1912×1016, H.264, rund 30,21 fps mit leicht unregelmäßigen Frame-Zeitstempeln und 97,593 s Laufzeit. Für die gemeldeten Stellen wurden benachbarte Frames und vergrößerte Ausschnitte verglichen; eine einzelne weit auseinanderliegende Screenshot-Auswahl wäre für kurze Sprünge ungeeignet.

## Nachweis

Bei **72,908733 s** ist ein Ein-Frame-Sprung der Fahrzeugwerft sichtbar: In den benachbarten Frames bleibt das Gebäude in seiner üblichen schrägen Ansicht, im Zwischenframe erscheint an derselben Stelle eine deutlich abweichende frontale/prozedurale Darstellung und direkt danach wieder die normale Ansicht. Gelände, HUD und benachbarte Objekte bleiben stabil. Das spricht für einen Objekt-/Rendererpfadwechsel und gegen eine globale Capture-Störung. Der Frameausschnitt liegt unter `test-output/flicker-v03818/exact_72_8_roi.png`.

Der Quellcode enthält einen konkreten Pfad, der dieses Verhalten erklären kann: Bei einem Gebäude-Cache-Miss gab `draw_cached_building()` bisher `false` zurück; der Aufrufer zeichnete im selben Frame anschließend `draw_building(e)`, also die prozedurale Fallbackdarstellung. Sobald die asynchron erzeugte 3D-Textur bereit war, wechselte das Gebäude zurück auf die 3D-Ansicht. Der frühere Renderer protokollierte den Cache-Schlüssel und den gewählten Visualpfad nicht. Daher ist der Videozeitpunkt eindeutig belegt, der damalige konkrete Cache-Miss jedoch nicht nachträglich anhand eines Runtime-Logs beweisbar.

## Weitere markierte Zeitpunkte

- **34,1 s:** Die Kontaktfolge zeigt Bau-/Gebäudezustandswechsel. Kein einzelner isolierter falscher Frame ist anhand dieser Folge sicher belegt.
- **74,3 s:** Die Werft/der Bauplatz wechselt sichtbar über Bauansichten. Die Folge passt zu Fortschritt/Bauphase; kein separater fehlerhafter Zwischenframe ist damit bewiesen.
- **82,8 s:** Kurze Ansichtswechsel am Gebäude sind erkennbar. Sie passen zum beschriebenen Wechsel zwischen Cacheansicht und prozeduralem Fallback, aber die Aufnahme enthält keine damaligen Cache-Diagnosedaten; Ursache bleibt begründete Vermutung.
- **85,6–86,7 s:** Es gibt Zustandswechsel im Bereich der Werft und daneben. Die Aufnahme belegt nicht hinreichend, dass jeder Wechsel ein falsches Einzelbild statt einer Produktions-/Bauzustandsänderung ist.

## Korrektur und Schutz vor Wiederkehr

Bei einem animierten Gebäude-Cache-Miss wird jetzt, falls vorhanden, die letzte gültige 3D-Ansicht derselben semantischen Gebäudefamilie weitergezeichnet, bis die gewünschte Pose fertig ist. Gebäudetyp, Fraktion, Ausrichtung, Turmziel, Ausbaustufe, Entladezustand und Bauphase bleiben strikt getrennt. Nur Aktivität und Animationsframe dürfen sich einen kurzfristigen Struktur-Fallback teilen. Für eine noch nie gerenderte Familie bleibt der anfängliche prozedurale Aufbau zulässig, damit ein Gebäude ohne Cache nicht unsichtbar bleibt.

Ein optionaler, standardmäßig ausgeschalteter Ereignispuffer erfasst pro gezeichnetem Gebäude Frame, Entity-ID, Fraktion, Gebäudetyp, Modell-/GLB-Pfad, Bau-/Produktions-/Schadens-/Animationszustand, Orientierung, angeforderten und gewählten Cache-Key, Textur-ID, Fallback-Key, Cache-Treffer und Fallbackgrund. Der Puffer ist auf 8192 Einträge begrenzt.

Die Renderer-Regression prüft semantische Key-Grenzen, verbietet fraktions-, orientierungs- und bauphasenübergreifende Fallbacks und hält eine passende Werfttextur über 600 aufeinanderfolgende Produktions-, Freigabe- und Queue-Samples verfügbar. Die RendererCache-Gruppe einschließlich `building_asset_states.gd` sowie `update_info.gd` besteht lokal.

## Performance-Gate und gezielte CPU-Korrektur

Der Tag-Workflow `v0.38.19` bestand alle Regressiongruppen bis auf `performance.gd`; GitHub Actions meldete für 200 bewegte Panzer und 300 Simulationsticks 34,08 ms/Tick bei einem bestehenden Grenzwert von 33,3 ms/Tick. Der Runner war Windows Server 2025 mit EPYC 9V74 und Microsoft-Hyper-V-Videotreiber. Derselbe Test lag lokal vor der Korrektur bei 14,73 ms/Tick. Die Abweichung war ein echtes CPU-Benchmark-Gate, nicht der Renderer; der Renderartefakt-Fix kann diesen `SceneTree`-Simulationstest nicht beeinflussen.

Ursache war die automatische Zielsuche: Jede bewaffnete Einheit durchlief für die Gegnersuche alle Einheiten inklusive sämtlicher Verbündeter. Eine bei Spawn gepflegte Besitzliste reduziert diese Schleife auf gegnerische Einheiten; Zerstörung, Save/Load und Multiplayer-Neustart pflegen den Index mit. Die vorhandene Performance-Assertion bleibt unverändert. Zwei lokale Läufe nach der Korrektur ergaben 10,53 und 10,60 ms/Tick und bestanden; der neue tagbasierte Windows-Workflow muss diese Änderung noch bestätigen.

## Umfangsgrenze

Dieser Update-Stand bearbeitet den konkret nachgewiesenen Werft-Cache-Fallbackpfad und den durch das Release-Gate belegten CPU-Kostenpunkt. Er ist keine vollständige Abnahme des gesamten Grafik-/Audio-Auftrags: Fraktionssilhouetten, Werft-/Harvester-Visual-Impact, Audiohörtest, Langzeitmatch, Multiplayer-/Save-Load-Visuals, neues Gameplay-Testvideo und durchgängige Abwesenheit aller Renderartefakte bleiben separat zu prüfen. Das alte Video ist nicht instrumentiert; für einen zweifelsfreien Laufzeitnachweis muss ein neues Video mit aktivierter Gebäudediagnose aufgenommen werden.

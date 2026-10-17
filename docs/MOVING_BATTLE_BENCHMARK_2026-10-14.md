# Bewegter Gefechtsbenchmark – 2026-10-14

## Testaufbau

Gemessen wurde lokal mit dem normalen Godot-Vulkan-Renderer auf einer NVIDIA RTX 3060 bei 1920×1080. Die Szene enthält bis zu 40 gemischte Fahrzeuge, vier Gruppen mit wechselnden Bewegungs- und Angriffsaufträgen, aktive Gegner, Treffer, Projektile, Spuren und 39–43 Wracks. Während mindestens 95,6 % der gefrorenen-cache-Messframes und 96,9 % der beiden Live-Messfenster bewegten sich mindestens acht Fahrzeuge. Der Lauf enthält jeweils 900 Frames Warm-up, Cache-Aufbau und 900 Messframes.

Der Benchmark wurde in zwei Formen ausgeführt:

- **Cache eingefroren:** Nach dem Warm-up wurden neue Fahrzeugpose-Bakes blockiert. Fehlende Ansichten mussten auf die nächste vorhandene Textur zurückfallen. Das prüft die Battlefield-Kosten ohne laufende Pose-Erzeugung.
- **Live-Cache:** Die normale serielle Pose-Erzeugung blieb aktiv. Das entspricht dem bisherigen Laufzeitverhalten und zeigt die tatsächlich entstehenden Bakes.

Der eingefrorene Lauf ist damit ein Kontrolllauf, kein Abnahmenachweis für normales Live-Rendering.

## Gemessene Ergebnisse

| Lauf | Ø FPS | Ø Framezeit | langsamstes 1%-Mittel | schlechtester Frame | neue Fahrzeugposen | Fahrzeug-/Gebäude-Readbacks | Pose-Misses | bewegte Frames |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Live-Cache, Lauf 1 | 25,41 | 39,360 ms | 94,280 ms | 339,783 ms | 900 | 0 / 0 | 24.442 | 96,9 % |
| Live-Cache, Lauf 2 | 25,18 | 39,709 ms | 64,252 ms | 135,078 ms | 900 | 0 / 0 | 24.565 | 96,9 % |
| Live-Cache, 384×384 / 2× MSAA | 24,89 | 40,177 ms | 57,606 ms | 61,831 ms | 900 | 0 / 0 | 29.203 | 97,3 % |
| Live-Cache, 256×256 / MSAA aus | 26,81 | 37,300 ms | 53,883 ms | 59,559 ms | 900 | 0 / 0 | 26.392 | 97,2 % |
| Cache eingefroren, adaptive | 79,90 | 12,516 ms | 24,321 ms | 27,859 ms | 0 | 0 / 0 | 27.258 | 95,6 % |
| Cache eingefroren, VFX begrenzt | 74,10 | 13,495 ms | 27,500 ms | 32,170 ms | 0 | 0 / 0 | 29.837 | 96,3 % |
| Cache eingefroren, volle Qualität 1 | 55,29 | 18,085 ms | 32,379 ms | 34,560 ms | 0 | 0 / 0 | 29.570 | 96,2 % |
| Cache eingefroren, Spuren reduziert | 59,97 | 16,676 ms | 29,710 ms | 34,895 ms | 0 | 0 / 0 | 30.380 | 96,8 % |
| Cache eingefroren, volle Qualität 2 | 59,77 | 16,732 ms | 31,877 ms | 39,753 ms | 0 | 0 / 0 | 30.009 | 96,8 % |
| Cache eingefroren, Wracks kompakt | 58,13 | 17,202 ms | 33,156 ms | 39,693 ms | 0 | 0 / 0 | 30.565 | 97,4 % |
| Cache eingefroren, volle Qualität 3 | 52,44 | 19,069 ms | 37,171 ms | 40,661 ms | 0 | 0 / 0 | 30.322 | 97,7 % |
| Cache eingefroren, kombiniert | 74,47 | 13,429 ms | 33,065 ms | 45,136 ms | 0 | 0 / 0 | 31.578 | 97,8 % |

Die drei vollen Qualitätskontrollen streuen zwischen 52,44 und 59,77 FPS. Die Messungen wurden nacheinander und nicht in randomisierten, gepaarten Blöcken ausgeführt; deshalb lässt sich aus der scheinbaren Verbesserung der kombinierten Variante kein belastbarer Einzelgewinn für VFX, Spuren oder Wracks ableiten. Diese Qualitätsbehandlungen bleiben Benchmark-Schalter und werden nicht als globale Produktreduktion übernommen.

## Befund zum Pose-Cache

Der Live-Cache erzeugte in beiden 900-Frame-Messfenstern genau eine neue Pose pro Frame. Dabei trafen etwa 27 Cache-Misses je Frame ein, während nur ungefähr drei bis vier Anfragen einen Cache-Hit erzielten. Der Bestand blieb bei 640 Pose-Texturen. Es gab in den Messfenstern keine Fahrzeug- oder Gebäude-`get_image()`-Readbacks. Der Fahrzeugpfad behält die Viewport-Textur GPU-resident; der Building-Cache enthält weiterhin einen `get_image()`-Pfad, der nun separat gezählt wird. Dieser Pfad wurde in diesen beiden Messfenstern nicht aufgerufen.

Die längsten Frames fallen unmittelbar mit langen Wartezeiten auf das Pose-SubViewport zusammen:

- Lauf 1: Frame 498 dauerte 339,783 ms; der erfasste SubViewport-Render-Warteabschnitt betrug 309,114 ms. In diesem Frame wurde eine Pose erzeugt.
- Lauf 2: Frame 581 dauerte 135,078 ms; der Render-Warteabschnitt betrug 126,809 ms. In diesem Frame wurde eine Pose erzeugt.

Das ist eine reproduzierte zeitliche Korrelation zwischen Live-Pose-Erzeugung und den langen Ausreißern. Der Lauf weist keinen CPU-Readback als Ursache aus; die teure Arbeit ist das Live-Rendern und Warten auf den SubViewport. Beide Live-Läufe verfehlen das Ziel von mindestens 60 FPS und das 1%-Low-Ziel. Der zweite Lauf reproduzierte zugleich den früheren Bereich von 12–30 FPS.

Die Richtungen sind bereits diskret: 32 Chassis-Winkel und 16 Turmwinkel; geringfügige Winkelabweichungen bilden daher nicht jeweils einen eigenen Key. Im Key stehen zusätzlich Fahrzeugtyp, Fraktion, Besitzer, Teamfarbe, drei Schadensstufen, Cargo-Stufe, Arbeits-/Fahrzustand und Antriebsphase. Im bewegten Test wurden 2.182 verschiedene Schlüssel angelegt, deutlich mehr als die Cache-Kapazität von 640. Die Misses sind daher kein Beleg für kontinuierliche Winkel, sondern für die Kombination diskreter Zustände und ein Arbeitsset, das den Cache übersteigt. Für ein Fahrzeug mit Turm und zwei im Test aktiven Fraktions-/Besitzer-/Farbkombinationen liegt die kombinatorische Obergrenze des aktuellen Keys bei bis zu 24.576 Posen (32×16×3×1×2×4×2), bevor weitere Varianten berücksichtigt werden.

Die beiden zusätzlichen Live-Renderprofile lieferten keinen tragfähigen Grund, die Bildqualität global zu senken: 384×384 / 2× MSAA war mit 24,89 FPS langsamer als die 512er-Läufe. 256×256 ohne MSAA erreichte 26,81 FPS, nur 1,63 FPS mehr als Live-Lauf 2 und weiterhin weit unter 60 FPS. Die laufende Pose-Erzeugung blieb bei beiden Profilen bei 900 Bakes pro 900 Messframes. Die Kontaktbilder sind bei normalem Spielzoom visuell ähnlich; eine pixelgenaue, gepaarte Detailprüfung wurde nicht gemacht. Daher bleibt 512×512 / 4× MSAA als Referenz erhalten, und die geringfügige FPS-Differenz rechtfertigt keine globale Qualitätsreduktion.

## Schlussfolgerung und offene Arbeit

Der nachgewiesene warme Engpass ist die aktive Pose-Cache-Erzeugung samt SubViewport-Render-Wartezeit. Das Einfrieren entfernt die Pose-Erzeugung, erhöht aber nicht die Cache-Trefferquote: zehntausende Misses bleiben und werden durch die nächste vorhandene Pose ersetzt. Diese Kontrollvariante verändert somit die momentane Darstellung und ist keine akzeptable endgültige Lösung.

Der nächste sinnvolle technische Schritt ist, die Cache-Dimensionen zu entkoppeln oder die benötigten Fahrzeugansichten vorab GPU-seitig bereitzustellen, sodass während des Gefechts kein neues Fahrzeug-SubViewport gerendert werden muss. Eine weitere reine Qualitätsreduktion bei VFX, Wracks oder Spuren ist durch diesen Test nicht begründet. Ein neuer, gepaarter Benchmark muss nach der Cache-Änderung dieselbe Bewegungsszene wiederholen. Die normale Spielqualität, besonders bei schrägen Fahrtrichtungen und sichtbarer Turmdrehung, muss dabei visuell gegengeprüft werden.

## Reproduzierbarkeit und Artefakte

Ausführung:

```powershell
$env:APPDATA = Join-Path (Get-Location) '.local'
$env:LOCALAPPDATA = $env:APPDATA
.\tools\Godot_v4.7.2-stable_win64_console.exe --path . --script tests/moving_battle_benchmark.gd
```

`-- --live-only` führt nur den Live-Cache-Lauf aus. Ergebnisse liegen in `test-output/moving_battle_benchmark.csv`, `test-output/moving_battle_benchmark_frames.csv` und `test-output/moving_battle_pose_keys.csv`. Der vorherige Acht-Varianten-Lauf mit eingefrorenem Cache wurde separat unter `test-output/moving_battle_frozen_20261014/` aufbewahrt.

## Asynchroner Pose-Abschluss – 2026-10-14

Der Live-Pfad wartet jetzt nicht mehr als Coroutine auf `RenderingServer.frame_post_draw`. Ein einzelner Pose-Auftrag rendert weiter seriell in seinem SubViewport; bis zum Post-Draw-Callback bleibt die nächstgelegene fertige Ansicht sichtbar. `pending_pose_keys` verhindert weiterhin doppelte Aufträge. Die gemessene Spalte heißt deshalb jetzt `subviewport_completion_latency_ms`: Sie misst die Zeit vom Start des Auftrags bis zum Post-Draw-Callback und ist ausdrücklich keine reine GPU-Zeit.

Der identische 512×512/4×-MSAA-Live-Lauf auf RTX 3060 ergab nach der Änderung:

| Lauf | Ø FPS | Ø Framezeit | schlechtestes 1%-Mittel | schlechtester Frame | Pose-Erzeugungen | Readbacks |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Live, synchroner alter Pfad, Lauf 1 | 25,41 | 39,360 ms | 94,280 ms | 339,783 ms | 900 | 0 |
| Live, synchroner alter Pfad, Lauf 2 | 25,18 | 39,709 ms | 64,252 ms | 135,078 ms | 900 | 0 |
| Live, asynchroner Abschluss | 24,11 | 41,484 ms | 70,129 ms | 145,978 ms | 900 | 0 |

Der asynchrone Abschluss vermeidet das explizite Blockieren bis zum Pose-Render, beseitigt aber den GPU-Aufwand der SubViewports nicht. Der Mittelwert ist im Einzel-Lauf nicht besser, und das Ziel ≥60 FPS wird klar verfehlt. Die Reduktion des schlechtesten Frames gegenüber Lauf 1 ist ermutigend, aber wegen der Streuung gegenüber Lauf 2 kein belastbarer Performancegewinn. Daher ist diese Änderung ein begrenzter Schutz gegen synchrones Warten, keine Abnahme der Cache-Architektur. Der Produktions-Missionsstart friert den Cache nach seinem Start-Warm-up ein; dieser absichtlich aktive Live-Diagnoselauf erzwingt weitere Bakes und ist von normalen Matches zu unterscheiden.

### Terrain-Layer-Isolation

Der Terrain-Visualtest erstellt bei feststehender Kamera zusätzlich A/B-Bilder mit allen Terrain-Layern, ohne `terrain_detail`-Sprite, ohne Terrain-Detail-Meshes, ohne Fog und mit beiden Detailpfaden aus. In der Testkamera lag die mittlere RGB-Abweichung zum All-On-Bild bei 0,015 für Fog aus, 4,061 für das Detail-Sprite aus und 1,501 für die Detail-Meshes aus. Das Sprite trägt hier den größeren Anteil am sichtbaren Detail; der Test isoliert aber noch nicht pixelgenau die Blockstellen im vom Nutzer gezeigten Videobereich, weil dessen Kameraausschnitt anders ist. Die Screenshots und CSV-/PNG-Diagnosen liegen unter `test-output/terrain_layers_*.png` und `test-output/terrain_diag_*.png`. Das ist ein reproduzierbarer Layer-Befund, noch keine begründete globale Detailreduktion oder fertige Korrektur.

## Bewegter Gefechtsbenchmark erneut ausgeführt — 2026-10-15

Der 40-Fahrzeuge-Vulkanbenchmark lief erneut lokal auf der RTX 3060: 900 Warmup-Frames, bis zu acht serielle Cache-Drain-Durchgänge und danach je 900 Messframes pro Variante. In 90,3–97,7 % der Messframes bewegten sich mindestens acht Einheiten. Die Varianten liefen nacheinander mit gleicher Seed-/Szenario-Initialisierung, nicht randomisiert und nicht in gepaarten Blöcken; kleine Einzellauf-Unterschiede sind daher kein sicherer kausaler Effekt.

| Variante | Ø FPS | schlechtestes 1%-Mittel | schlechtester Frame | neue Posen | Readbacks | Bewegungsanteil |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Adaptiver VFX-Tier | 76,48 | 25,108 ms | 26,304 ms | 0 | 0 | 95,9 % |
| Begrenzter VFX-Tier | 77,74 | 24,816 ms | 27,742 ms | 0 | 0 | 96,2 % |
| Volle Qualität 1 | 58,78 | 32,870 ms | 39,734 ms | 0 | 0 | 96,9 % |
| Spuren reduziert | 58,56 | 31,858 ms | 38,398 ms | 0 | 0 | 96,8 % |
| Volle Qualität 2 | 55,86 | 33,561 ms | 40,416 ms | 0 | 0 | 97,7 % |
| Kompakte Wracks | 53,34 | 33,457 ms | 41,101 ms | 0 | 0 | 97,2 % |
| Volle Qualität 3 | 56,98 | 34,528 ms | 40,269 ms | 0 | 0 | 97,1 % |
| VFX/Spuren/Wracks kombiniert | 72,88 | 31,560 ms | 41,691 ms | 0 | 0 | 97,4 % |
| Pose-Cache live | 20,46 | 80,483 ms | 87,743 ms | 900 | 0 | 90,3 % |

Die drei Vollqualitäts-Kontrollen liegen im Mittel bei 57,21 FPS, 33,65 ms für das schlechteste 1%-Mittel und 40,14 ms für den jeweils schlechtesten Frame. Der adaptive VFX-Lauf überschreitet im Durchschnitt 60 FPS, verfehlt mit 25,108 ms im 1%-Mittel aber weiterhin das 45-FPS-Slow-Tail-Ziel. Reduzierte Spuren und kompakte Wracks übertreffen ihre benachbarten Vollqualitätsläufe nicht. Die Kombination erreicht 72,88 FPS, bleibt unter dem adaptiven VFX-Lauf und hat mit 41,691 ms den größten Maximalframe unter den eingefrorenen Varianten. Wegen der Laufstreuung und sichtbarer Änderungen an VFX/Spuren/Wracks wird keine globale Qualitätsreduktion übernommen.

Der Live-Cache-Fall reproduziert weiterhin den Hitch-Auslöser: 900 neu erzeugte Posen, null CPU-Readbacks, 80,483 ms schlechtestes 1%-Mittel und 87,743 ms maximaler Frame. Damit ist das Live-SubViewport-Rendering selbst der Kostenpfad; `get_image()` war nicht beteiligt. Das Einfrieren hält im gesamten Messfenster Bakes und Readbacks bei null, doch der Cache bleibt bei 640 Posen, während zehntausende Anfragen danebenliegen und eine nahe Textur verwenden. Responsive Darstellung ist damit erreicht, aber identische Animation und Orientierung jeder Einheit nicht bewiesen. Der warme Vollqualitätslauf bleibt außerdem unter dem FPS-Ziel.

Bei eingefrorenem Cache kostete der WorldRenderer in den drei Vollqualitätsläufen 8,38–9,12 ms/Frame und die Simulation 1,24–1,74 ms/Frame. Sichtbare Kategorien: Fahrzeuge 1,73–1,94 ms, Kampf-VFX 1,63–1,74 ms, Spuren 0,94–1,08 ms und Wracks 0,87–0,92 ms. Im Live-Cache-Lauf stieg Fahrzeuge-Rendering auf 7,31 ms und Simulation auf 6,63 ms; Zielsuche und Kampf stiegen mit der langsameren Framerate. Pathfinding lag bei ungefähr 0,01 ms und war nicht der Engpass dieses Laufs.

Rohdaten: `test-output/moving_battle_benchmark.csv`, `test-output/moving_battle_benchmark_frames.csv`, `test-output/moving_battle_pose_keys.csv`; Bildbeispiele: `test-output/moving_baseline_fullquality_1.png` und `test-output/moving_combined.png`. Es wurde keine Produktqualitätseinstellung für den Benchmark verändert. Vor einer Cache-Änderung braucht es weiterhin einen gepaarten Lauf und eine visuelle Prüfung im echten Match, damit die Fallback-Posen nicht als uneingeschränkte Bildqualitätsabnahme gelten.

### Frame-Tail-Auswertung derselben Vollqualitätsläufe — 2026-10-15

Die 2.700 per-Frame-Zeilen der drei Vollqualitätsläufe wurden nach `frame_ms` zusammengefasst. Die 29 Frames im obersten Prozent lagen im Mittel bei 33,40 ms, gegenüber 17,49 ms über alle Frames; der schlechteste Frame lag bei 40,42 ms. In den Tail-Frames stiegen die gemessenen Kategorien `world_ms` im Mittel um 5,73 ms, `vehicles_ms` um 4,51 ms und `simulation_ms` um 4,30 ms. Innerhalb der Simulation stiegen `combat_ms` um 3,53 ms und `target_search_ms` um 3,09 ms; `pathfinding_ms` blieb mit 0,025 ms im Tail klein.

Die Pose-Misses waren im Tail nicht erhöht (31,28 gegenüber 33,35 pro Frame); `poses_created` und CPU-Readbacks blieben in diesen eingefrorenen Vollqualitätsläufen bei null. Das spricht in diesem Datensatz gegen einen Zusammenhang der schlechten Warm-Frames mit Cache-Erzeugung. Die Messabschnitte überschneiden sich teilweise und dürfen nicht addiert oder als isolierte A/B-Kausalität gelesen werden. Der Befund grenzt die warmen Ausreißer auf Renderer-/Fahrzeugarbeit sowie variable Kampf-/Zielsuche ein, beweist aber noch keinen einzelnen dominanten Render-Primitive. Keine Qualitätsreduktion wurde daraus übernommen.

### Terrain-Basispass-A/B — 2026-10-15

Zur Prüfung des warmen Renderer-Anteils wurde dieselbe bewegte 40-Fahrzeuge-Szene viermal in ABBA-Reihenfolge ausgeführt: Terrain-Basispass an, aus, aus, an. Auflösung, Vulkan-Forward+-Renderer (RTX 3060), Kamera, Gefecht, Warm-up und 900 Messframes blieben gleich. Pose-Caches wurden vor der Messung aufgebaut und während der Messfenster eingefroren. Der einzige Eingriff war das Sichtbarmachen des Terrain-Basis-Sprites; Gelände-Detailobjekte blieben aktiv. „Aus“ ist ein Diagnosezustand, kein akzeptabler Spielmodus.

| Variante | Ø FPS | Ø Framezeit | langsamstes 1%-Mittel | schlechtester Frame | WorldRenderer | Simulation | Bewegung ≥8 Einheiten |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Terrain an, Lauf 1 | 62,50 | 16,000 ms | 30,795 ms | 33,974 ms | 8,107 ms | 0,990 ms | 96,1 % |
| Terrain aus, Lauf 1 | 62,05 | 16,116 ms | 29,597 ms | 33,195 ms | 8,158 ms | 1,111 ms | 96,4 % |
| Terrain aus, Lauf 2 | 58,73 | 17,028 ms | 31,874 ms | 34,118 ms | 8,536 ms | 1,280 ms | 97,0 % |
| Terrain an, Lauf 2 | 56,65 | 17,654 ms | 32,729 ms | 35,055 ms | 8,822 ms | 1,448 ms | 97,2 % |

Über beide Wiederholungen lag „Terrain aus“ im Mittel bei 60,39 FPS und „Terrain an“ bei 59,58 FPS. Die mittleren Framezeiten unterschieden sich nur um 0,255 ms. Renderer- und Simulationszeiten sowie Gefechtszustand variierten ebenfalls; ein stabiler, klar zuordenbarer FPS-Gewinn beim Abschalten trat nicht auf. Das langsamste 1%-Mittel lag bei abgeschaltetem Terrain im Schnitt etwa 1 ms niedriger, was allein keinen belastbaren Ursachennachweis liefert.

Die visuellen Kontrollbilder zeigen, dass das Abschalten des Basispasses die Geländeoberfläche weitgehend schwarz zurücklässt. Die Variante ist deshalb sichtbar unbrauchbar und wird nicht übernommen. **Befund:** Dieser A/B-Test weist den Terrain-Basis-Shader nicht als warmen Hauptengpass nach. Der kleine, instabile Messunterschied rechtfertigt weder eine Qualitätsreduktion noch einen Shader-Umbau.

Vor dem wiederholten ABBA-Lauf gab es ein separates exploratives Zweierpaar, das ebenfalls archiviert ist. Dessen Terrain-an-Baseline überschritt einmal den Benchmarkvertrag: 670,970 ms Gesamtframe bei nur 9,255 ms im gemessenen WorldRenderer und 3,389 ms Simulation, ohne Pose-Erzeugung oder Readback; dieser Einzellauf endete daher mit Exitcode 1. Im damaligen Terrain-aus-Lauf lag der schlechteste Frame bei 33,635 ms. Der 670-ms-Abstand tauchte in keinem der vier nachfolgenden ABBA-Läufe wieder auf. Die Zeit ist in den gemessenen Renderer-/Simulationsspannen nicht erklärt; ein externer Scheduler-/Warteeffekt ist möglich, aber anhand dieser Messung nicht bewiesen. Er darf weder dem Terrain-Shader zugeschrieben noch als erledigter Hitch behandelt werden.

Die erste diagnostische Zweiermessung ist separat archiviert unter `test-output/moving_battle_pre_terrain_ab_20261015/`. Die vier Wiederholungen stehen in `test-output/moving_battle_benchmark.csv` und `test-output/moving_battle_benchmark_frames.csv`; die Kontaktbilder (`moving_baseline_terrain_base_1.png`, `moving_terrain_base_off_1.png`, `moving_terrain_base_off_2.png`, `moving_baseline_terrain_base_2.png`) liegen in `test-output/`.

### Bewegter A/B-Lauf: Kampf-VFX, Kettenspuren und Wracks — 2026-10-16

Nach dem Warm-up und einer identischen 30-Frame-Beruhigungsphase wurden acht Varianten je 900 Frames mit eingefrorenem Produktions-Pose-Cache gemessen. Das Vulkan-Forward+-Rendering und die unveränderte Gefechtsszene liefen auf der RTX 3060. Alle Varianten hatten null neue Posen, null Cache-Neuerzeugungen und null CPU-Readbacks.

| Variante | Ø FPS | Ø Framezeit | langsamstes 1%-Mittel | schlechtester Frame | WorldRenderer | Fahrzeuge | VFX | Spuren | Wracks |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Adaptiver VFX-Tier | 81,14 | 12,324 ms | 24,521 ms | 29,048 ms | 6,333 ms | 1,324 ms | 1,578 ms | 0,357 ms | 0,792 ms |
| VFX begrenzt | 76,69 | 13,039 ms | 25,822 ms | 31,573 ms | 6,443 ms | 1,365 ms | 1,602 ms | 0,357 ms | 0,827 ms |
| Volle Qualität 1 | 51,42 | 19,446 ms | 35,338 ms | 39,372 ms | 9,514 ms | 2,025 ms | 1,752 ms | 1,184 ms | 0,974 ms |
| Spuren optimiert | 62,44 | 16,016 ms | 37,624 ms | 55,856 ms | 7,929 ms | 1,689 ms | 1,752 ms | 0,568 ms | 0,832 ms |
| Volle Qualität 2 | 58,57 | 17,073 ms | 39,669 ms | 97,712 ms | 8,327 ms | 1,682 ms | 1,608 ms | 0,995 ms | 0,875 ms |
| Wracks kompakt | 56,58 | 17,674 ms | 39,925 ms | 45,092 ms | 8,668 ms | 1,835 ms | 1,624 ms | 0,991 ms | 0,881 ms |
| Volle Qualität 3 | 50,78 | 19,695 ms | 36,090 ms | 44,318 ms | 9,494 ms | 2,010 ms | 1,756 ms | 1,233 ms | 0,975 ms |
| VFX/Spuren/Wracks kombiniert | 63,09 | 15,850 ms | 34,159 ms | 43,349 ms | 7,433 ms | 1,707 ms | 1,730 ms | 0,350 ms | 0,926 ms |

Die drei Vollqualitäts-Kontrollen streuten von 50,78 bis 58,57 FPS; auch die zwei frühen adaptiven Varianten lagen deutlich höher als die späteren Kontrollen. Weil die Messreihenfolge nicht randomisiert oder gepaart war und die Grundlast während des Durchlaufs stark wanderte, lässt sich der FPS-Abstand nicht kausal den jeweils abgeschalteten Effekten zuschreiben. Begrenzte VFX senkten den gemessenen VFX-Anteil nicht. Die Spurvariante reduzierte den Spur-Aufwand von ungefähr 1,0–1,2 ms auf 0,57 ms, die Kombination auf 0,35 ms; ein stabiler 1%-Tail-Gewinn gegenüber den Kontrollen ist damit nicht belegt. Kompakte Wracks senkten deren Renderzeit nicht erkennbar. Die Kombination blieb bei 63,09 FPS, während ihre einzelne Vollqualitäts-Kontrolle davor 50,78 FPS erreichte; diese Einzelpaarung reicht wegen der Drift nicht als Wirkungsnachweis.

Während des Laufs meldete WDDM eine sehr hohe belegte VRAM-Menge, lieferte aber keine belastbare Prozesszuordnung. Das ist eine dokumentierte Einschränkung des Messumfelds, keine bestätigte Ursache der Drift. **Es wurde keine globale Qualitätsreduktion übernommen.** Diese acht Läufe zeigen weiter null Pose-Bakes und null Readbacks im aktiven Match, aber sie bestimmen keinen belastbaren warmen FPS-Haupttreiber. Die 1%-Slow-Tails liegen zwischen 24,5 und 39,9 ms; das Ziel von höchstens 22,2 ms für 45 FPS wird in keinem der drei Vollqualitätsläufe erreicht. Rohmessungen und per-Frame-Zeitreihen stehen in `test-output/moving_battle_benchmark.csv` und `test-output/moving_battle_benchmark_frames.csv`; Vergleichsbilder liegen unter `test-output/moving_baseline_fullquality_3.png` und `test-output/moving_combined.png`.

### Kettenspuren: Sichtbarkeitsdiagnose — 2026-10-15

Der Renderer erhielt einen rein diagnostischen Zähler für Spursegmente, deren um 12 Welteinheiten vergrößerte Begrenzungsbox den Kamerabereich schneidet. Die Kettenzeichnung und ihre Lebensdauer blieben unverändert. Aufruf: `tools/Godot_v4.7.2-stable_win64_console.exe --path . --rendering-method forward_plus --rendering-driver vulkan --script tests/moving_battle_benchmark.gd -- --track-visibility-count`.

Im warmen bewegten 40-Fahrzeuge-Lauf lagen 1.800 Segmente im Speicher; über 900 Frames waren durchschnittlich 807,5 von durchschnittlich 807,5 gezeichneten Segmenten im sichtbaren Kamerabereich. In dieser Testszene gibt es somit praktisch keine außerhalb des Bildes gezeichneten Spuren, die ein Sichtbarkeits-Culling einsparen könnte. Das Zählen allein ist kein Beleg für einen messbaren FPS-Gewinn; ein Culling-Eingriff wurde deshalb nicht eingebaut. Die Messung erreichte 61,14 FPS im Mittel, 30,270 ms schlechtestes 1%-Mittel und 35,399 ms Maximalframe; WorldRenderer 8,682 ms, Simulation 0,982 ms und Spuren 0,961 ms. Bewegung war in 96,8 % der Frames aktiv. Pose-Erzeugungen und Readbacks blieben null, während 29.848 exakte Cache-Misses auf nahe Fallback-Posen auswichen; das ist ein bestehender Cache-Abdeckungsbefund und keine Spurwirkung.

Die Diagnosebild- und CSV-Dateien liegen unter `test-output/moving_battle_track_visibility_20261015/`. Dieser Lauf ersetzte die zuvor im Projektwurzelordner liegenden Terrain-ABBA-Rohdateien; deren dokumentierte Messwerte stehen weiterhin in der obigen Tabelle, während die zugehörigen finalen Rohdateien dort nicht mehr vorhanden sind. Die zuvor archivierte erste Terrain-Diagnose blieb erhalten.

### Pose-Cache-Kapazitätsprüfung — 2026-10-16

Der 40-Fahrzeuge-Live-Lauf wurde auf der RTX 3060 bei 1920×1080 mit Forward+/Vulkan erneut ausgeführt. Die Referenz blieb bei 512×512 / 4× MSAA und der Produktionskapazität von 640 Einträgen. Im 900-Frame-Messfenster erreichte sie **15,53 FPS** im Mittel (64,407 ms), einen schlechtesten 1%-Mittelwert von **92,288 ms**, maximal **100,062 ms**, **900 neue Posen**, **0 GPU→CPU-Readbacks**, 2.731 Hits und 22.396 Misses. Mindestens acht Fahrzeuge bewegten sich in 97,0 % der Frames. Der Live-Cache-Vertrag scheiterte wegen der Pose-Bakes und des Frames über 100 ms.

Ein diagnostischer Vorwärm-/Kapazitätslauf setzte 256×256 ohne MSAA und 1.024 Cache-Einträge. Nach zehn Vorwärmrunden war die Warteschlange leer; im anschließend zurückgesetzten 900-Frame-Gefecht entstanden trotzdem **899 neue Posen**. Der Mittelwert stieg auf **22,55 FPS** (44,346 ms), der schlechteste 1%-Mittelwert lag bei **64,342 ms** und der Maximalframe bei **68,737 ms**. Es gab **0 Readbacks**, aber 6.171 Hits und 22.943 Misses; mindestens acht Fahrzeuge bewegten sich in 94,7 % der Frames. Die gerenderte Ansicht liegt unter `test-output/moving_baseline_live_prewarmed_256.png`; ein gepaarter pixelgenauer Qualitätsvergleich mit 512×512 wurde nicht vorgenommen, daher gilt diese Variante nicht als angenommene Produktqualität. Der verschärfte Prewarm-Vertrag scheiterte erwartungsgemäß an den 899 neuen Posen.

Zwei reine Diagnoseversuche mit 512×512 / 4× MSAA und Cachekapazitäten 1.024 bzw. 3.072 endeten bereits im Warm-up mit Vulkan-Fehler `Couldn't create Vulkan image in memory` beim Erzeugen weiterer SubViewport-Renderziele. Sie lieferten keine gültigen Performancewerte. Das GPU-Speicherlimit macht eine einfache Kapazitätserhöhung bei unveränderter Pose-Auflösung unbrauchbar. Nach Beendigung der Diagnoseprozesse waren keine Godot-Prozesse übrig.

**Befund:** GPU-Readback blieb in beiden abgeschlossenen Messfenstern bei null; der beobachtete aktive Kostenpfad ist weiterhin Pose-Erzeugung und SubViewport-Rendering samt Cache-Arbeitsset. 256er Texturen und 1.024 Einträge verbessern den Mittelwert und den Tail, verfehlen aber das Ziel von ≥60 FPS und erzeugen fast in jedem Messframe weiter eine Pose. Es wird keine globale Auflösung oder Qualitätsstufe geändert. Der Diagnosemodus `--live-prewarmed-256` im bewegten Benchmark verlangt nun ausdrücklich 0 aktive Pose-Bakes und zeigt, dass diese Bedingung noch nicht erfüllt ist. Der nächste Umsetzungsschritt muss die Pose-Dimensionen entkoppeln oder sie offline vorbacken; eine weitere reine Kapazitätserhöhung ist durch den Vulkan-Speicherfehler nicht vertretbar.

### Cache-Miss-Ursache und Produktionspfad — 2026-10-16

Der Diagnosebenchmark zählt jetzt zusätzlich `poses_recreated`, also Pose-Schlüssel, die schon einmal erzeugt und später erneut gebacken wurden. Das trennt Cache-Churn durch Verdrängung von tatsächlich neuen Schlüssel-Kombinationen. Im 900-Frame-Lauf `--live-prewarmed-256` entstanden 899 Posen, davon **0 erneut erzeugte**. Die Hitches dieses absichtlich ungebremsten Diagnosepfads stammen somit aus immer neuen Schlüsseln, nicht aus einem zu kleinen Cache, der dieselben Schlüssel wiederholt verliert. Der Lauf lag bei **22,93 FPS**, 43,618 ms mittlerer Framezeit, **118,251 ms** schlechtestem 1%-Mittel und 160,517 ms Maximalframe. Er hatte 22.488 Cache-Misses, 5.939 Hits, **0 Readbacks** und 1.024 Einträge. Diese Diagnosekonfiguration umgeht den Gameplay-Freeze; sie entspricht nicht dem aktiven Produktionspfad.

Danach lief die gleiche bewegte Gefechtsszene mit dem normalen Vorwärmen und dem Gameplay-Freeze, 512×512 / 4× MSAA und 640 gespeicherten Fahrzeugposen. Über 900 Messframes erreichte sie **64,38 FPS**, 15,532 ms mittlere Framezeit, **31,654 ms** schlechtestes 1%-Mittel (entspricht 31,6 FPS im langsamen Prozent) und 36,315 ms Maximalframe. Während des aktiven Messfensters gab es **0 neue oder erneut erzeugte Posen, 0 Readbacks und 0 aktive SubViewports**. Es wurden 2.991 exakte Treffer und 28.555 Misses gezählt; bei Misses zeigt der Renderer die nächste fertige Orientierung, ohne den Frame auf einen Bake warten zu lassen. Bewegung war in 96,3 % der Frames aktiv. Das Diagnosebild ist `test-output/moving_track_visibility_count.png`; die Messwerte stehen in `test-output/moving_battle_benchmark.csv` und `test-output/moving_battle_benchmark_frames.csv`.

Der 64,38-FPS-Lauf besteht das Durchschnittsziel und hat keine systematischen 100-ms-Hitches, verfehlt mit 31,654 ms im langsamsten Prozent aber das angestrebte 45-FPS-1%-Low. Eine Qualitätsreduktion wurde nicht vorgenommen. Die verbleibende Lücke ist die Zahl der unterschiedlichen Richtungs-/Turm-/Schadens-/Animationsschlüssel innerhalb des endlichen Vorwärm- und Cachebudgets: 28.555 Misses wechseln im laufenden Kampf auf die nächste vorhandene Pose. Der Schlüssel enthält Fahrzeugtyp, Fraktion, Besitzer, Teamfarbe, 32 Körperrichtungen, 16 relative Turmrichtungen, drei Schadensstufen, Erntefracht/-zustand und Fahr-/Arbeitsphase. Der frühere Schlüssel-Auditlauf fand 2.178 tatsächlich verwendete Kombinationen; die theoretische Obergrenze ist viel größer, besonders beim Sammler mit neun Frachtstufen und acht Arbeitsphasen. Weitere Kapazitätserhöhung ist wegen der reproduzierten Vulkan-Bildspeicherfehler keine sichere Lösung. Eine Reduktion der Winkelstufen wäre eine sichtbare Änderung und wurde hier nicht vorgenommen.

### Rendering-A/B Terrainbasis und Messharness — 2026-10-16

Der erste Terrain-ABBA-Diagnoselauf erzeugte bis zu 306-ms-Frames direkt nach den periodischen 90-Frame-Statusausgaben. Diese Ausgabe lag innerhalb des gemessenen Zeitfensters und konnte damit den Slow-Tail selbst belasten. Der Benchmark gibt während der Messframes nun keine Statuszeilen mehr aus. Im sauberen Wiederholungslauf lagen alle Maximalframes unter 40 ms; die früheren 100–300-ms-Spitzen gelten deshalb als Messharness-Artefakt, nicht als belegte Spielhitches.

Im sauberen ABBA-Vergleich (je 900 Frames, normaler 512×512-/4×-MSAA-Pfad, Cache während des Spiels eingefroren) erreichten die Referenzläufe **65,06 und 61,58 FPS** sowie 29,305 und 31,849 ms für den schlechtesten 1%-Frame-Mittelwert. Die zwei Läufe mit ausgeschaltetem Terrainbasisbild erreichten **60,60 und 61,61 FPS** sowie 34,233 und 30,493 ms im schlechtesten Prozent. Gemittelt brachte das Ausschalten keinen Gewinn: Referenz 63,32 FPS / 30,577 ms Slow-Tail; Terrain aus 61,11 FPS / 32,363 ms Slow-Tail. Im Terrain-aus-Bild verschwindet die lesbare Grundfläche deutlich, während die mittlere Terrain-Profilzeit mit rund 0,82 ms unverändert bleibt. Diese Änderung wird nicht übernommen.

In allen vier Messfenstern gab es 0 Pose-Bakes, 0 erneute Bakes, 0 Readbacks und keine Frames über 40 ms. Die Bewegung war in 96–98 % der Frames aktiv. Die langsamsten Frames korrelierten nicht mit Pose-Misses: bei ihnen entstanden keine Posen oder Readbacks. Der sichtbare Terrain-Entzug bringt also keinen messbaren Performancevorteil; die verbleibende Slow-Tail-Schwankung ist über diese kontrollierte A/B-Probe nicht auf den Terrainbasispass zurückzuführen. Rohdaten und Vergleichsbilder liegen in `test-output/moving_battle_benchmark.csv`, `test-output/moving_battle_benchmark_frames.csv` und den `moving_baseline_terrain_base_*` / `moving_terrain_base_off_*` Bildern.

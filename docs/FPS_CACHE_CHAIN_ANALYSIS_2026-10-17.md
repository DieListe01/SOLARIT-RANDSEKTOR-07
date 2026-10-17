# FPS- und Fahrzeug-Pose-Cache-Analyse — 2026-10-17

## Ergebnis in Kürze

Der kontrollierte Vulkan-/RTX-3060-Lauf mit 10 Gebäuden und 50 Fahrzeugen erreicht nach dem Cache-Freeze **86,77 FPS** im Mittel bei **11,525 ms** mittlerer Framezeit. In 900 gültigen Messframes gab es **0 Pose-Bakes, 0 GPU→CPU-Readbacks, 0 Evictions und 0 Frames über 33 ms**. Die langsame 1-%-Framezeit liegt im Mittel bei **26,466 ms** (entspricht rund 37,8 FPS im langsamen Prozent); damit ist das Durchschnittsziel erreicht, das 1-%-Ziel von mindestens 45 FPS jedoch nicht.

Das Ergebnis gilt für diese reproduzierbare Szene und den normalen lokalen Forward+/Vulkan-Renderer auf einer RTX 3060 bei 1920×1080. Es beweist nicht, dass jeder reale Matchzustand oder die vom Nutzer beobachteten 7 FPS vollständig erklärt sind.

## A. Pose-Bakes und Readbacks

Ein absichtlicher Live-Bake-Kontrolllauf mit derselben Benchmarkfamilie erzeugte in 900 Frames 900 neue Posen und 900 CPU-Readbacks. Er erreichte 21,12 FPS im Mittel, 47,359 ms Framezeit, 74,583 ms als Mittel der langsamsten 1 % und 85,318 ms maximal. 841 Frames dauerten länger als 33 ms und 251 länger als 50 ms. Der Readback-Pfad benötigte insgesamt 11.475 ms, also durchschnittlich 12,75 ms pro Sample-Frame, in einzelnen Frames bis zu 42,886 ms. Der laufende SubViewport-Render-/Abschlussabschnitt erreichte bis zu 42,128 ms.

Das bestätigt die Bake-/Readback-Kette als massiven Auslöser. Im regulären Match wird die Cache-Erzeugung vor der Kontrolle des Spielers eingefroren. Fehlende exakte Schlüssel verwenden die nächste passende residente Pose; sie lösen kein SubViewport und kein `get_image()` aus.

## B. Cache-, Fallback- und RenderTarget-Verhalten

Der aktuelle Baseline-Lauf füllte den vorhandenen Cache auf **512 Texturen** (Kapazität 640). Für die vollständige Baseline wurden 511 Posen nachgeladen; insgesamt fielen während dieser Vorbereitung 512 Readbacks mit kumuliert 2.607 ms Readback-Zeit an. Die Vorbereitung dauerte 9.616 ms. Nachher waren **0 SubViewports** aktiv oder gespeichert. Diese Arbeit liegt beim Matchstart, nicht im 900-Frame-Messfenster.

Während des Messfensters gab es 33.594 Cache-Misses und 1.593 exakte Hits. Das ist eine niedrige exakte Trefferquote von 4,5 %, aber kein Pose-Churn mehr: alle 33.594 Misses fanden eine fertige Familien-Pose; **0 leere und 0 prozedurale Fallbacks**. Der Fallback-Index gruppiert Einträge nach Fahrzeugtyp/Fraktion/Besitzer/Farbe, speichert geparste Richtungs- und Zustandsdaten und merkt die nächste Pose bis zur nächsten Cache-Generation. Dadurch wurden 32.607 der 33.594 Anfragen als Memo-Treffer beantwortet; für alle übrigen Suchen wurden insgesamt 31.584 Kandidaten geprüft. Die gesamte gemessene Fallback-Suchzeit betrug 139,362 ms über 900 Frames (0,155 ms/Frame im Mittel).

Die Queue blieb im aktiven Benchmark bei **0**; es gab keine wartenden oder veralteten Pose-Aufträge, keine Evictions und keine gespeicherten Viewports. Das Cache-Limit wurde nicht erhöht. Historische Diagnoseausgaben, die Queue-Länge und `pending_pose_keys` addierten, zählten dieselben eingereihten Keys doppelt; aktuelle Benchmarkausgaben trennen Queue, Pending-Keys und In-Flight-Arbeit.

Der Godot-Videospeicher-Monitor meldete im eingefrorenen Lauf rund 1.280 MB. Diese Messgröße ist kein prozessgenauer VRAM-Zähler und kann von `nvidia-smi` abweichen. Ein früherer Vergleich mit den zuvor behaltenen 4×-MSAA-SubViewports hatte den nahezu vollständigen 12-GB-Adapter gezeigt. Der aktuelle Cache behält nur die ausgelesenen `ImageTexture`s, nicht die MSAA-RenderTargets; damit ist der frühere RenderTarget-/VRAM-Churn strukturell entfernt. Die Qualität/Auflösung wurde nicht pauschal reduziert.

## C. Verbleibende normale Render- und Simulationskosten

Im aktuellen Baseline-Lauf lagen die gemittelten gemessenen Zeiten bei: WorldRenderer 5,406 ms, Fahrzeuge 0,381 ms, Simulation 0,880 ms, Pathfinding 0,004 ms, Separation 0,253 ms, Zielsuche 0,159 ms, Kampf 0,264 ms, Kampf-VFX 1,188 ms und Kettenspuren 0,570 ms. Zielsuche erreichte maximal 1,47 ms; sie war in dieser Szene nicht der dominante Kostentreiber.

Der langsamste Frame dauerte 28,561 ms. In keinem der 900 Frames gab es einen Wert über 33, 50 oder 100 ms. Die langsamsten Einzel-Frames waren nicht mit Pose-Bakes oder Readbacks verbunden. Die noch offene Leistungsspitze ist damit kein reproduzierbarer >100-ms-Pose-Hitch mehr, sondern die verbleibende Render-/VFX-/Szenenlast und die Streuung im langsamen Prozent. Einzelne VFX- oder Spur-Kosten werden hier nicht als Anlass für eine globale Qualitätsreduktion gewertet.

## D. Startpfad und Kompatibilitätsrenderer

Der visuelle UI-Regressionslauf benutzt absichtlich Godots OpenGL-Kompatibilitätsrenderer. Dort blieb der `frame_post_draw`-Abschluss für den Fahrzeug-SubViewport aus; 511 Baseline-Aufträge blieben nach der Warmup-Phase unerledigt. Die Startlogik besitzt jetzt einen Fortschritts-Watchdog: nach 240 Frames ohne Pose-Abschluss wird nur die laufende Cache-Arbeit abgebrochen, übrige Aufträge werden verworfen, und das Match startet mit residenten Fallbacks statt bis zum vollen 1.800-Frame-Budget zu warten. Im 2D-Klassikmodus wird der nicht verwendete 3D-Pose-Prewarm ganz übersprungen.

Der UI-Integrationstest wartet jetzt auf das Ende dieses begrenzten Warmups (maximal 1.200 Testframes) und prüft ausdrücklich, dass es vor den Eingabeprüfungen beendet wurde. Die bestehenden Gameplay-Assertions bleiben unverändert. Die lokale UI-Regression bestand danach in 125,4 s. Der OpenGL-Test schrieb zusätzlich die GLES3-Warnung `Parameter "material" is null`; der Testprozess beendete sich dennoch mit Exitcode 0. Vulkan ist der Benchmark-Renderer und hat den vollständigen Baseline-Prewarm mit 512 fertigen Texturen erfolgreich ausgeführt.

## Messwerttabelle

| Messung | Ø FPS | Ø Framezeit | langsamstes 1-%-Mittel | Maximum | >33 ms | >50 ms | >100 ms | Posen | Readbacks |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Live-Bake-Kontrolle, 900 Frames | 21,12 | 47,359 ms | 74,583 ms | 85,318 ms | 841 | 251 | 0 | 900 | 900 |
| eingefrorene Baseline, 900 Frames, aktueller Stand | 86,77 | 11,525 ms | 26,466 ms | 28,561 ms | 0 | 0 | 0 | 0 | 0 |

Weitere aktuelle Werte: 50 Fahrzeuge im Benchmark, mindestens 4 und durchschnittlich 38,3 in Bewegung, Bewegung in 98,2 % der Frames; 10 Gebäude; 39 Wracks; mittlere Kamera-/Grafikqualität; 512 residente Fahrzeug-Texturen; aktive Queue 0; aktive SubViewports 0.

## Geänderte Dateien

- `scripts/world_renderer.gd` — Familienindex/Memo-Fallback, Pending-/Queue-Bounds, Bake-Freeze, einmaliger Loading-Readback in normale `ImageTexture`, Harvester-Turm-Key entfällt.
- `scripts/main.gd` — begrenzter Pose-Baseline-Warmup mit Fortschritts-Watchdog; 2D-Klassikmodus überspringt ungenutzte 3D-Posen.
- `tests/render_performance.gd` — Cache-Freeze, Queue/Pending und Harvester-Key geprüft.
- `tests/ui_integration.gd` — Warmup-Ende vor UI-Eingabeprüfungen abwarten, ohne bestehende Erwartungen zu ändern.
- `tests/fps_10buildings_50vehicles_benchmark.gd` — reproduzierbare 10-Gebäude-/50-Fahrzeuge-Szene, Warmup, 900-Frame-Messung und getrennte Cache-/Fallback-/Simulationswerte.
- `docs/FPS_CACHE_CHAIN_ANALYSIS_2026-10-17.md` — diese Messdokumentation.

Rohdaten:

- `test-output/fps_10buildings_50vehicles_active_bakes_control.csv`
- `test-output/fps_10buildings_50vehicles_active_bakes_control_frames.csv`
- `test-output/fps_10buildings_50vehicles_baseline_only.csv`
- `test-output/fps_10buildings_50vehicles_baseline_only_frames.csv`
- `test-output/fps_10buildings_50vehicles_baseline_only_pose_keys.csv`
- `test-output/moving_scale_active_cache.png`

## Grenzen und nächste Architektur

Der Pose-/Readback-Hitch und die Fallback-Scan-Kosten sind für die getestete Szene deutlich reduziert. Die exakte Cache-Trefferquote bleibt absichtlich gering, weil der begrenzte, qualitätsschonende Cache nicht alle Kombinationen aus Fraktion, Richtung, Turm, Schaden und Animation enthält. Der Fallback verhindert dabei Bake- und Readback-Hitches, kann aber eine benachbarte Pose statt einer pixelgenau exakten Animation zeigen. Eine produktionsweite 100-%-visuelle Freigabe jedes Fahrzeugzustands ist durch den Benchmark allein nicht belegt.

Langfristig ist ein versionierter, reproduzierbarer Offline-Atlas aus den vorhandenen GLB-Modellen vorzuziehen. Für Fahrzeuge mit unabhängig drehbarem Turm sollte ein kleiner Chassis-/Turm-Kompositionsprototyp separat mit identischer Kamera und normalem Spielzoom geprüft werden; er wird nicht ohne visuellen und Performance-A/B-Nachweis übernommen. Der nächste Performance-Schritt sollte die 1-%-Framezeit im echten Nutzer-Match messen und nur reproduzierbare Kosten bei VFX, Spuren oder WorldRenderer weiter optimieren.

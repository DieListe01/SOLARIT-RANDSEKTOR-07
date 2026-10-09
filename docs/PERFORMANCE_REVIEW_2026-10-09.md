# Fahrzeug-Cache und Gefecht: Performanceprüfung vom 09.10.2026

## Testaufbau

Die Läufe wurden mit Godot 4.7.2, Vulkan Forward+, einer NVIDIA GeForce RTX 3060 und einem 1920×1080-Fenster durchgeführt. Der Benchmark startet für jede Variante einen neuen Prozess, lädt dieselbe Karte, wärmt Renderer und Shader 360 Frames auf und misst danach 900 Frames derselben reproduzierbaren Gefechtsszene: 40 sichtbare Fahrzeuge (im Mittel 10,2 bewegt), 16 Wracks, laufende Geschosse und identische Befehlswechsel alle vier Simulationssekunden. A–D nutzen unverändert die bisherige Cachekapazität 192. Der Cold-Abschnitt ist die erste Cachefüllung; „laufend“ ist die anschließende aktive Gefechtsmessung. A-warm wiederholt exakt dieselbe aufgezeichnete Einheiten- und Zeitsequenz bei gleicher 512er-Auflösung und 4× MSAA, nachdem alle 652 benötigten Posen im Cache liegen (Kapazität 768).

Die Rendergeometrie, Kamerapose, Einheitenzahl und Spielregeln blieben in allen Läufen gleich. Nur bei B–D änderten sich Auflösung und MSAA. Die Framewerte stammen aus echten Vulkan-Prozessen, nicht aus dem Null-Renderer. Warm-up-Ladevorgänge und Shaderkompilierung sind vom 900-Frame-Messabschnitt getrennt.

## Varianten A–D

| Variante | Pose-Cache | Cold: Ø FPS / 1%-Low / schlechtester Frame | Laufendes Gefecht: Ø FPS / 1%-Low / schlechtester Frame | neue Posen/s | Readback ms/s | SubViewport-Wartezeit ms/s |
|---|---:|---:|---:|---:|---:|---:|
| A | 512², 4× MSAA | 17,51 / 10,42 / 320 ms | 19,84 / 6,66 / 187,5 ms | 14,9 | 183,2 | 464,2 |
| B | 512², MSAA aus | 18,03 / 10,71 / 347,5 ms | 20,02 / 6,81 / 175,0 ms | 15,0 | 175,3 | 468,5 |
| C | 384², 2× MSAA | 17,80 / 9,70 / 353,8 ms | 20,14 / 6,81 / 155,1 ms | 15,1 | 179,8 | 460,8 |
| D | 256², MSAA aus | 17,90 / 9,88 / 350,5 ms | 20,14 / 7,24 / 146,4 ms | 15,1 | 181,4 | 458,7 |

Der Auflösungs-/MSAA-Wechsel verringerte weder Pose-Neuerzeugungen noch SubViewport-Wartezeiten und verbesserte den laufenden Mittelwert im 192er-Cache-Lauf um höchstens 0,3 FPS. Der SSIM-Vergleich der damaligen Gameplay-Referenzbilder lag bei A–B 0,99796, A–C 0,99793 und A–D 0,99663. Diese Whole-Frame-Werte sind keine isolierte Asset-Qualitätsmessung.

Zusätzlich wurde jede Variante mit Cachekapazität 768 vollständig vorgewärmt und exakt dieselbe aufgezeichnete Posefolge ein zweites Mal abgespielt:

| Warm-Replay | Bildqualitätseinstellung | Ø FPS | 1%-Low | schlechtester Frame | neue Posen / Readbacks |
|---|---|---:|---:|---:|---:|
| A-warm | 512², 4× MSAA | 20,79 | 17,91 | 58,8 ms | 0 / 0 |
| B-warm | 512², MSAA aus | 20,41 | 15,66 | 70,8 ms | 0 / 0 |
| C-warm | 384², 2× MSAA | 20,68 | 18,00 | 58,9 ms | 0 / 0 |
| D-warm | 256², MSAA aus | 22,98 | 19,07 | 56,1 ms | 0 / 0 |

D war in dieser warmen Wiederholung rund 2,2 FPS schneller als A und belegte rund 457 statt 970 MB Godot-Videospeicher; C erreichte praktisch dieselbe mittlere Bildrate wie A bei rund 671 MB. Das ist ein messbarer Auflösungs-/Speichertrade-off, aber kein Beleg dafür, dass kleinere Ansichten den Cache-Stall im laufenden Spiel lösen. Der direkte Bildvergleich war eine ganze Gameplay-Ansicht mit kleinen Fahrzeugen und wechselnden Effekten; er reicht nicht aus, um feinste Modellkanten pixelgenau zu bewerten. A bleibt die empfohlene Standardeinstellung für maximale Detailtreue; C ist eine plausible optionale Speicherstufe. D spart weiter Speicher und gewinnt in der warmen Wiedergabe etwas Bildrate, birgt aber das größte Risiko, mechanische Details bei naher Kamera zu glätten.

## Cold Cache, laufender Cache und exakt warmer Cache

`get_image()` wird pro neuem Cache-Eintrag einmal ausgeführt. Bereits angelegte Texturen verursachen im normalen Draw-Pass keinen Readback. Der serielle Worker hatte im ganzen A–D-Test höchstens ein aktives SubViewport. In der A-Frame-Spur hatten 675 von 900 Messframes eine neu fertiggestellte Pose: diese Frames dauerten im Mittel 57,75 ms, Frames ohne Poseabschluss 28,35 ms. Alle zwölf langsamsten A-Frames enthielten einen Poseabschluss. Der einmalige Cold-Abschnitt enthielt ebenfalls sehr lange Frames bis 320–354 ms. Damit sind Pose-Erzeugung, Post-Draw-Warten und Readback als Ursache **spitzer Ruckler belegt**.

Die exakte Wiederholung A-warm (512²/4× MSAA; Kapazität 768, damit alle 652 im Lauf benutzten Posen gehalten werden) erzeugte 0 Posen und führte 0 Readbacks aus. Sie erreichte 20,79 FPS im Mittel, 17,91 FPS im 1%-Low und 58,8 ms im schlechtesten Frame. Die laufende A-Messung mit Kapazität 192 erreichte 19,84 FPS, 6,66 FPS 1%-Low und 187,5 ms maximal. Vollständiges Vorwärmen beseitigt also den Großteil der extremen Ausreißer und verbessert die schlechten Frames stark; **es hebt die durchschnittliche Bildrate aber nicht auf 50–60 FPS**. Cache-Aufbau ist ein wesentlicher Hitch-Faktor, jedoch nicht der alleinige oder hauptsächliche Grund für die niedrige Dauerbildrate.

Pro A–D-Lauf wurden rund 102 Cache-Miss-Anfragen/s registriert, aber nur etwa 15 neue Cache-Einträge/s fertiggestellt. Das zeigt viele zusätzliche Anfragen während eine Pose noch in der seriellen Queue steht. Die aktive Gefechtsspur nutzte 652 eindeutige Posen: 32 Karosseriewinkel bei den meisten Fahrzeugtypen, dazu bis zu 16 Turmstellungen. Bei Kapazität 192 verdrängt der Cache Einträge, die später erneut gebraucht werden.

Der ergänzende Lauf mit Kapazität 640, weiter bei 512²/4×, senkte die Eintragserzeugung von 14,9 auf 7,9/s, Misses von 101,5 auf 39,0/s, Readbackzeit von 183 auf 77 ms/s und SubViewport-Wartezeit von 464 auf 224 ms/s. Der Mittelwert stieg auf 23,70 FPS (+19,5% gegenüber A), aber der 1%-Low blieb mit 6,52 FPS genauso schwach. Der Cache war am Messende nahezu groß genug (19 Verdrängungen, sieben zuvor erzeugte Posen wiederholt). Die gemessene VRAM-Nutzung stieg von 464 MB bei A auf 912 MB bei Kapazität 640. Das ist ein echter Kompromiss: keine Bildqualitätsminderung und weniger Cache-Hitches, dafür ungefähr 448 MB zusätzlicher VRAM; die hohen Lastspitzen des Gesamtrenderers bleiben.

Die Ereignisspur `test-output/vehicle-cache-W-events.csv` protokolliert pro Pose Miss-Queue, SubViewport-Erstellung/Renderstart/-ende, `get_image()`-Start/-Ende und Cacheabschluss mit Zeitstempel und Dauer. In der vollständig warmen Wiedergabe waren es 0 Readbacks; pro neu gebautem Eintrag gab es genau einen. `test-output/vehicle-cache-W-frames.csv` enthält die korrespondierende Frame-Zeitreihe.

## Tatsächliche Kosten im Gefecht

Im Messabschnitt A mit Cache-Neuerzeugung beanspruchte der WorldRenderer im Mittel 17,36 ms. Davon entfielen rund 5,13 ms auf Boden-VFX, 3,82 ms auf Treffer/Impacts, 3,03 ms auf Wracks und 2,92 ms auf Geschosse. Die Simulation selbst lag bei 1,24 ms. Diese Werte erklären zusammen nicht die vollständigen rund 43–50 ms Framezeit; ein erheblicher Anteil liegt außerhalb des gemessenen WorldRenderer-/Simulationsabschnitts (unter anderem GPU-Ausführung und Präsentation). Die Messung erlaubt daher keine belastbare Zuordnung dieses Restes zu einem einzelnen Godot-Pass.

Ein separater vorhandener Gefechtsmatrix-Lauf erreichte bei bewegten 40 Fahrzeugen 32,28 FPS. Mit zusätzlich 46 Wracks und 1.800 Spursegmenten fiel er auf 20,29 FPS; der Wrack-Pass kostete dann 6,41 ms und der WorldRenderer 14,62 ms. Das belegt Wrack-/Spurmenge als zusätzlichen Kostentreiber in dieser Matrix, aber der Test kombiniert beide Größen und trennt ihren Einzelanteil nicht. VFX/Spuren/Wracks und der nicht aufgeschlüsselte GPU-/Präsentationsanteil müssen als nächstes gezielt isoliert werden. Die Simulation war hier kein Engpass.

## Erntemaschine – getrennte Sichtprüfung

Die 32-Ansichten-/Animationsvorschau wurde direkt mit dem Fahrzeug-Cache-Painter erstellt. Der Modelltest bestätigt, dass 32 Winkelbilder verschieden sind, die GLB-Animationen `Move`, `Harvest` und `Unload` auswählbar sind und Schneidkopf-/Klappen-Knoten sich zwischen Zuständen bewegen. Der Kontaktbogen ist unter `test-output/harvester_turntable_animation_sheet.png` abgelegt. Bei 128×128 Pixeln sind die zeitlichen Änderungen subtil und im Bogen nur schwach zu erkennen; das ist ein Hinweis auf geringe Lesbarkeit im kleinen Spielmaßstab, kein belegter Orientierungs-, Layer- oder Skalierungsfehler.

Die Tests belegen außerdem quantisierte Cargo-Stufen und vorhandene Cargo-/Schadensdetails. Sie demonstrieren keinen vollständigen live beobachteten Zyklus vom Kristallabbau bis zum Andocken und Entladen. Ein entsprechender Gameplay-Videolauf bleibt für die visuelle Abnahme offen; daraus wird hier kein Fehler abgeleitet. Performance- und Asset-/Animationsbefund bleiben getrennt.

## Ergebnis und nächste Schritte

- **Nachgewiesen:** On-demand Pose-Aufbau verschlechtert Cold-Frames und 1%-Lows deutlich. Jeder Eintrag führt zu einem einzelnen CPU-Readback; normale Cache-Hits lesen keine GPU-Bilder aus.
- **Nicht nachgewiesen:** Die Reduktion von SubViewport-Auflösung oder MSAA verbessert die Performance relevant.
- **Empfehlung:** 512²/4× beibehalten. Den Cache auf 640 Einträge setzen: damit wurden im kontrollierten Lauf Cache-Aufbau und Miss-Raten etwa halbiert, ohne Fahrzeuge zu verändern. Die rund 448 MB zusätzliche VRAM-Belegung gegenüber A dokumentieren und auf schwächeren Grafikkarten beobachten.
- **Noch nicht erreicht:** 50–60 FPS und robuste 1%-Lows in der vollen Gefechtsszene. Ein warmer Cache reduziert Hitches, aber die warme Wiedergabe bleibt bei etwa 21 FPS im Mittel. Deshalb keine weitere Pose-Cache-Optimierung als vermeintliche Lösung der Dauerbildrate.
- **Offen:** getrennte GPU-/VFX-/Wrack-/Spurtests sowie Live-Aufnahme des Ernte- und Entladezyklus. Der vorhandene Performance-Regressionstest und die volle Regression sind vor Release erforderlich.

Messdateien A–D, G und W liegen in `test-output/vehicle-cache-*.json` und `*-frames.csv`; die temporären Benchmarkskripte und Ausgaben gehören nicht zum Installer.

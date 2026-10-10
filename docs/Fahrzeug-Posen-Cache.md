# Fahrzeug-Posen-Cache: Analyse und Abnahme

Stand: 10.10.2026, SOLARIT 0.38.2

## Schlüssel und Zustandsraum

Ein Cache-Key besteht aus Fahrzeugtyp, Fraktion, Besitzer, Teamfarbe, Rumpfrichtung, Turmrichtung, Schadensstufe, Ladungsstufe, Arbeits-/Bewegungszustand und Antriebsphase. Die Winkel sind nicht kontinuierlich: Der Rumpf wird auf 32 Stufen (11,25°), der relative Turm auf 16 Stufen (22,5°) quantisiert. Kleine Winkelbewegungen erzeugen daher erst beim Überschreiten einer Stufengrenze einen anderen Key.

Theoretische Obergrenzen je visueller Variante, also je Kombination aus Fraktion, Besitzer und Teamfarbe:

| Typgruppe | Obergrenze | Annahme |
| --- | ---: | --- |
| Kettenfahrzeug (Panzer, Belagerer) | 7.680 | 32 Rumpf × 16 Turm × 3 Schäden × (1 Standphase + 4 Fahrphasen) |
| Raider ohne animierte Ketten | 3.072 | 32 × 16 × 3 Schäden × 2 Zustände |
| Sammler | 345.600 | 32 × 16 × 3 Schäden × 9 Ladestufen × (1 Standphase + 3 Arbeitszustände × 8 Phasen) |

Das sind Kombinationsobergrenzen, keine Zahl gleichzeitig benötigter Ansichten. Bewegungszustände, Turmziele und Ladungsstufen treten nicht unabhängig voneinander auf.

Im bewegten 40-Fahrzeuge-Test wurden über den vollständigen Variantenlauf 834 verschiedene erzeugte Keys gezählt: 603 Panzer, 100 Belagerer, 130 Raider und ein Späher. Ein einzelner statischer Zustand landet bei acht Ansichten, weil Rumpf-/Turmwinkel, Schaden, Ladung und Animationsphase dort weitgehend konstant bleiben. Im Gefecht überschreiten Einheiten dagegen mehrere der 32/16 Winkelzellen und wechseln Fahr-/Standphasen; schon kleine Winkeländerungen erzeugen beim Überschreiten einer festen Zellenkante einen anderen Key. Es gab keine kontinuierlich genaue Winkelkomponente.

## Laufzeitverhalten

Gerenderte Fahrzeugansichten bleiben als GPU-residente `ViewportTexture` erhalten. Der Fahrzeugpfad ruft kein `get_image()` auf. Fehlende Keys werden höchstens einmal in `pending_pose_keys` aufgenommen; der Cache-Ersatz wird pro angefragtem Key zwischengespeichert und verworfen, sobald der Cache wächst oder eine Ansicht verdrängt wird.

Pose-Bakes sind im aktiven Gefecht absichtlich eingefroren. Der nächste vorhandene Fahrzeug-Key wird ohne Warten gezeigt. Die deduplizierte Queue wird beim Missions-Warmup oder in einer Pause verarbeitet; danach verwendet die Einheit automatisch ihre exakte Ansicht. Die Queue ist auf 640 Einträge begrenzt.

Ein Kontrolllauf mit freigegebenem seriellen Live-Bake zeigte, dass „asynchron“ allein keinen sicheren Betrieb garantiert: 84 neue Ansichten in 900 Frames, 0 Readbacks, aber nur 34,72 FPS und ein Frame von 359,8 ms. Deshalb wird im Gefecht keine neue SubViewport-Pose erzeugt. Diese Messung begründet den Lade-/Pausepfad.

## Bewegter Benchmark

Gemessen wurde derselbe Vulkan-Forward+-Test auf RTX 3060: 40 Fahrzeuge, vier gleichzeitig befehligte Gruppen, Richtungswechsel, Separation, aktive Gegner, Schüsse/Treffer, Wracks und Kettenspuren. Nach 900 Warmup-Frames folgten 900 Messframes je Variante. Normale Geometrie, 512×512, 4× MSAA und Zoom blieben gleich.

| Lauf | Ø FPS | Framezeit Ø | Mittel der schlechtesten 1 % | Max. Framezeit | neue Posen | Readbacks |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Vor Änderung, aufgezeichneter Lauf | 45,1 | 22,2 ms | 134,2 ms | 145,6 ms | 258 | 258 |
| Nachher, normale Baseline (3 Läufe) | 60,9 | 16,42 ms | 26,68 ms | 30,11 ms | 0 | 0 |

Die drei Nachher-Baselines lagen einzeln bei 59,75, 59,60 und 56,93 FPS; es gab in keinem der 7.200 Baseline-Messframes einen Frame über 100 ms. Die Messung zählt wiederholte Cache-Miss-Zugriffe pro sichtbarer Einheit und Frame, nicht eindeutige Keys; die fehlende exakte Pose führt weder zu einem Bake noch zu einem Readback. Der A/B-Runner bricht ab, wenn neue Posen oder Readbacks während eines Samples auftreten oder ein Frame 100 ms überschreitet.

Spurenbegrenzung allein verbesserte diesen Lauf nicht stabil. Kompakte Wracks steigerten die Messung auf 89,88 FPS und senkten deren Renderkosten von etwa 3,3 ms auf 0,64 ms, veränderten jedoch die Wrack-Silhouetten sichtbar. Diese Qualitätsreduktion wird deshalb nicht pauschal aktiviert. Die Kombinationsvariante erreichte 107,40 FPS, schaltet aber mehrere Battlefield-Details gleichzeitig zurück und ist kein geeigneter Qualitätsstandard.

## Persistent-Cache-Einschätzung

Eine aktive `ViewportTexture` ist eine GPU-Ressource und lässt sich nicht als solche portabel serialisieren. Ein echter Disk-Cache müsste die Ansichten als Offline-Atlas (PNG/KTX2 plus Key-Metadaten) backen oder als separate Ladezeit-Bakes speichern. Eine komplette Kombinationstabelle wäre insbesondere beim Sammler sehr groß. Sinnvoll wäre später ein versionierter, kuratierter Atlas pro Fahrzeug mit ausgewählten Turm-/Schadens-/Arbeitszuständen; sein Fingerprint müsste GLB, Materialien, Kamera/Renderprofil, MSAA und Atlaslayout umfassen. Das ist bewusst noch nicht Teil dieses Updates. Die jetzige Lösung erhält die 3D-Modelle und Qualität und eliminiert Readbacks sowie Pose-Bakes im aktiven Gefecht.

## Abgrenzung zur Erntemaschine

Diese Änderung betrifft ausschließlich Pose-Cache und Gefechtsleistung. Die Lesbarkeit der Sammelbewegung, des Kristalleinzugs und der Entladung ist damit nicht abgenommen und bleibt eine separate Grafik-/Animationsaufgabe.

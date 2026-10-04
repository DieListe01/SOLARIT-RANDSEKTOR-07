# Prüfung am 1. Oktober 2026

Engine: Godot **4.7.2 stable**, offizieller Build `ed1daf0bf`. Rendering: OpenGL Compatibility, NVIDIA GeForce RTX 3060. Die Tests liefen in der vorhandenen Windows-Arbeitsumgebung.

## Nachgewiesen

Version 0.2 ergänzt ein 15-Sekunden-Intro, eine animierte Menühintergrundszene und die eigene 32-Sekunden-Titelmusik. Dafür wurden 17 zusätzliche Prüfungen ausgeführt: Start ohne Gameplay-Simulation, Audiostart, vollständige Tracklänge, Überspringen mit Escape/Enter/Leertaste, automatischer Übergang, Wiederholung, echte Classic-Auflösung, erreichbare Optionen und Briefing sowie korrekte Musikwechsel einschließlich Lautstärke null. Alle 135 Funktionsprüfungen bestehen. Bilder von Anflug, Titelenthüllung und beiden Menü-Renderpfaden wurden erzeugt und visuell geprüft. Das Menü ist auch nach kurzem Einblenden sofort interaktiv. Die neu exportierte Windows-EXE hat Intro sowie Modern-/Classic-Menü gerendert und den Test mit Code 0 beendet.

| Prüfung | Ergebnis |
|---|---|
| Simulationsregression | 76 Prüfungen bestanden |
| Echte UI-Ereignisse und Darstellung | 26 Prüfungen bestanden |
| Audiotransport, Layerwechsel und Jingle | 16 Prüfungen bestanden |
| Bezahlte vollständige Partie | Sieg nach 292,4 s, 7.760 Solarit geliefert, 15 Fahrzeuge produziert, 19 Gegner zerstört, 6 eigene Fahrzeuge verloren |
| 200-Fahrzeug-Simulation | 300 Takte; mittlere Zeit 9,01 ms, maximale Zeit 16,79 ms im 0.2-Lauf; keine offenen Pfadanfragen am Ende. Ein früherer Lauf hatte eine Spitze von 76,41 ms. |
| Frischer Projektordner ohne Importcache | Erstimport und anschließender Spielstart bestanden |
| Windows-Release | Exportiert; eigenständige EXE startet und rendert Modern/Classic, beendet sich mit Code 0 |

Die UI-Prüfung verwendet `Input.parse_input_event` für tatsächliche Auswahl-, Befehls- und Buttonereignisse. Classic-Eingaben treffen dieselben Weltkoordinaten. Die übrigen Szenarien betätigen die implementierten Szenenfunktionen und Produktionssysteme; sie sind keine Behauptung eines umfassenden menschlichen Spieltests.

Geprüfte Fenstergrößen: 1280×720, 1600×900, 1920×1080, 2560×1440 und 3840×2160. Bilder der Menüs, Basis, Optionen, Pause, des Classic-Renderpfads und des Sieg-Debriefings wurden erzeugt. Menü, Basis und Optionen wurden visuell inspiziert. Die Größenprüfung erfolgte über Godots tatsächliche Fenster- und Rendergrößen, nicht auf fünf physischen Monitoren.

Spielstände wurden über JSON serialisiert und wieder geladen. Getestet: Credits, Ressourcenverbrauch, Entitäten, Pfade, Produktionswarteschlangen, KI-Sichtwissen, Gruppen, Auswahl, fortgesetzte Produktion, unbekannte Version und fehlende Entitätsfelder. Ein vollständig umstellter Produktionsausgang hält fertige Aufträge zurück und arbeitet nach Öffnung weiter.

Audio: vier gleichzeitig laufende Spuren, vollständige 16-Sekunden-Loopgrenzen auch mit Godots WAV-Kompression, Kontaktwechsel nach Mindestdauer auf Taktgrenze, Basisalarm-Layer, Pausentransport und Sieg-Jingle. Diese automatisierten Tests ersetzen keine abschließende Abhör- und Mixprüfung mit mehreren Ausgabegeräten.

## Behobene Fehler während der Prüfung

- Namenskollision mit `Object.free()` im Grid.
- Getrenntes Wegziel für Angriffsmarsch und temporäre Verfolgung; Marsch wird nach verlorenem Kontakt wieder aufgenommen.
- Zu aggressive frühe KI im ruhigen Schwierigkeitsgrad; Produktion, Angriffstruppe und Aufbauzeit werden jetzt datengetrieben unterschiedlich gewählt.
- Mausereignisse benötigen explizite Umrechnung aus dem aktuellen Viewport in das 1920er-Layout.
- Produktionsausgänge dürfen keine Fahrzeuge durch einen geschlossenen Gebäudering versetzen.
- JSON-Zahlen müssen für Entitäts-IDs und Auswahl wieder zu Integern normalisiert werden.
- Ungültige Spielstände müssen vor Veränderungen an der Simulation abgelehnt werden.
- UTF-8-Zeichen in Daten und UI korrigiert.
- WAV-Loopgrenze wird aus Audiodauer und Mixrate berechnet; komprimierte Datenbytes sind keine PCM-Samples.
- Audioplayer werden beim Wechsel und Herunterfahren angehalten und freigegeben.

## Grenzen

Die 200-Fahrzeug-Messung enthält einzelne Taktspitzen. Sie belegt keine durchgehend garantierten 60 FPS auf Zielhardware und ist kein vollständiger Test einer 200-Einheiten-Schlacht. Größere kreuzende Gruppen, langfristige Sammlerstaus und komplette Blockaden sämtlicher Raffinerien benötigen zusätzliche Spieltests und gegebenenfalls räumliche Nachbarschaftsindizes.

Normale und entschlossene KI sowie die beiden weiteren Fraktionsprofile starten und nutzen dieselben Systeme; ein kompletter Sieg wurde bisher für Kobalt gegen Wanderpakt mit ruhiger KI nachgewiesen. Es gibt noch keine Langzeit-Balanceprüfung aller Kombinationen.

Classic Retro ist ein echter niedriger Renderpfad, verwendet aber noch die integrierte Schrift und dieselben geometrischen Zeichenmotive. Eine speziell gestaltete Bitmap-Schrift, tiefere Gebäudevariationen und aufwendigere Animationen sind weitere Grafikarbeit.

Die isolierte Ausführungsumgebung meldet beim Engine-Start `Failed to read the root certificate store`. Das Offline-Spiel benutzt keine Netzwerkfunktionen; Import, Tests und Export liefen trotzdem. Diese Meldung ist von Script-, Gameplay- und Ressourcenfehlern getrennt zu bewerten.

Linux, Steam Deck, Controller, langfristige Dateimigration und alle späteren Entwicklungsphasen wurden nicht getestet. Eine vollständige Umsetzung des umfangreichen Gesamtauftrags wird hier ausdrücklich nicht behauptet.

## Detaildarstellung 0.3

Moderne Materialtexturen, facettierte Kristalle, Metall- und Fahrzeugdetails, geglättete Konturen und weich interpolierter Sichtnebel. Classic bleibt 640×360 mit Nearest-Filter. Briefingbreite und sichtbare Texthöhe werden zusätzlich geprüft. 139 Funktionsprüfungen erfolgreich (76 Regression, 16 Audio, 26 UI, 21 Frontend), vollständiger bezahlter Durchlauf weiterhin gewonnen. Simulation mit 200 Fahrzeugen: Mittel 9,62 ms, Maximum 35,57 ms pro Tick.

## Grafik und Sammlersteuerung 0.4

154 Funktionsprüfungen bestanden: 79 Regression, 16 Audio, 38 UI, 21 Frontend. Neue reale Maus-Eingabetests prüfen Rechtsziehen in Modern/Classic ohne Auftragsänderung, Freigabe über dem HUD, Auswahl des Sammlers, Rechtsklick-Sammelauftrag, Sammeln per Schaltfläche und Linksklick sowie Rückkehr zur Raffinerie mit tatsächlich gutgeschriebenem Solarit. Regressionen prüfen abgebrochene Pfadanfragen und Beibehaltung des gewählten Feldes nach dem Abladen. Ein JSON-Vergleich verwendet eine absolute Toleranz von 1e-9 für Gleitkomma-Ressourcen, da ein Roundtrip eine Abweichung unterhalb dieser Grenze zeigte.

Der vollständig bezahlte Durchlauf gewann bei 262,5 Sekunden: 6800 Solarit gesammelt, 13 Fahrzeuge produziert, 18 Gegner zerstört, 2 eigene Fahrzeuge verloren. Simulation mit 200 Fahrzeugen: Mittel 9,81 ms, Maximum 39,40 ms pro Tick; keine ausstehenden Pfadanfragen. Das ist keine FPS-Garantie für die Grafik.

Die separate Grafikszene in tests/visual_showcase.gd zeigt alle sieben Gebäude und vier Fahrzeuge sowie Effekte über den ausgelieferten Renderer. Sie ist eine isolierte Testszene, keine Kampagne und kein gespeicherter Spielstand. Screenshots: industrial_showcase.png, modern_effects.png, industrial_classic.png.

## Automatik 0.5

Neue Regressionen prüfen mehrere Sammel-/Abladezyklen ohne einen einzigen Sammelbefehl, automatische Wiederaufnahme nach Verschieben, bewusstes Stoppen, automatische Gegenwehr während eines Fahrbefehls, unverändertes Fahrziel und Ausschluss verdeckter Gegner. 86 Regressionen erfolgreich; automatische Priorisierung bewaffneter Bedrohungen ebenfalls geprüft. Insgesamt 161 Funktionsprüfungen erfolgreich. Vollständig bezahlter Durchlauf: Sieg nach 249,9 s, 6320 Solarit, 12 produzierte Fahrzeuge, 18 zerstörte Gegner, 1 eigener Verlust. 200 Fahrzeuge: 14,76 ms mittlere Tickzeit, maximal 29,45 ms.

## Version 0.6

86 Simulationsprüfungen, vollständiger Missionsdurchlauf (Sieg nach 249,9 Sekunden), 38 UI-Prüfungen und 21 Frontendprüfungen bestanden. Audiotest: 16 Prüfungen bestanden im gezielten Wiederholungslauf; im ersten Lauf schlug einmal die zeitabhängige Transport-Synchronisation fehl. Native Grafikprüfung aller sieben Gebäude und vier Fahrzeuge in beiden Modi; Modern-Fixture setzt nun explizit Modern, Classic nutzt denselben Kameraausschnitt und Zoom. Shaderfehler beim ersten Grafiklauf behoben, anschließend Grafiklauf ohne Shaderfehler. Simulation mit 200 Einheiten: Mittel 14,94 ms/Tick, schlechtester Tick 45,31 ms.

Neue Grafik: geschichtetes Terrain, identische Detailmodelle in beiden Modi, Bauphasen, kritische Brände, Solaritdichte nach Vorrat, Fahrspuren und Fertigstellungspulse. UI-Schrift für Sammleraktionen verkleinert, damit Beschriftungen in ihre Schaltflächen passen. Spieler-/Command-Architektur aus der neuen Spezifikation noch nicht umgesetzt.

## Version 0.7: Farbwelt und Friend/Foe

174 Funktionsprüfungen bestanden: 86 Simulation, 16 Audio, 38 UI, 21 Frontend sowie 13 neue Identitätsprüfungen. Letztere prüfen Cyan und Rot in den tatsächlich gerenderten Weltbildern bei 1920×1080 und 640×360, gespeicherte und ungültige Farbpaletten, unveränderten Spielzustand beim Moduswechsel sowie echte Klickereignisse zur Gegnerinspektion ohne Befehlsübernahme. Zunächst fehlerhafte Testfixture (HARVEST ohne Ressourcenfeld und fehlende reale Sicht beim Wiederaufnehmen) korrigiert; gezielter Wiederholungslauf besteht ohne Script-/Shaderfehler. Snapshot-Farbarray kopiert, um nachträgliche Änderungen von gespeicherten Paletten zu verhindern.

Vollständiger Missionsdurchlauf unverändert: Sieg nach 249,9 Sekunden, 6320 gesammelt, 12 produziert, 18 Abschüsse, ein Verlust. 200 Einheiten: durchschnittlich 14,02 ms/Tick, maximal 21,46 ms (Simulation, keine GPU-FPS-Messung). Native Modern- und Classic-Bilder mit eigenen und feindlichen Gebäuden/Fahrzeugen geprüft. Acht Farbslots sind Datenvorbereitung, keine Behauptung eines fertigen Mehrspielermodus oder acht aktiver Spieler.

Windows-Export 0.7: Gameplay-Smoke und Intro-/Menü-Smoke mit Code 0 abgeschlossen; keine Script-/Shaderfehler in den Release-Logs.

## Version 0.8: Visual Polish Pass 2

188 Funktionsprüfungen bestanden: 86 Simulation, 16 Audio, 38 UI, 21 Frontend, 13 Fraktionskennung und 14 neue Polish-Prüfungen. Neue Prüfungen: tatsächliche Schuss-/Treffer-/Zerstörungsereignisse, eigene Sound-Cues, Trümmer, lokaler Kameraimpuls, unveränderte Simulation und Kamera, identischer Spielzustand beim Classic-Wechsel, OFF-Verhalten, begrenzte Effektmengen, vollständiges Auslaufen, echte Einstellungsbuttons und gespeicherte Präsentationspräferenzen. Kampf, Rauch-/Trümmerphase und Optionslayout nativ gerendert und visuell geprüft.

Mission vollständig bestanden: Sieg nach 249,9 Sekunden, 6320 gesammelt, 12 produziert, 18 Abschüsse, ein Verlust. Simulation mit 200 Einheiten: Mittel 14,02 ms/Tick, Maximum 21,92 ms. Dies misst die Simulation und ist keine GPU-Framerate-Zusage. Effektspeicher begrenzt auf 220 Ereignisse und 100 Ruinen; wichtige Formen bleiben auch im niedrigen Profil sichtbar.

Release 0.8: Gameplay-Smoke und Intro-/Menü-Smoke jeweils Exit 0; keine Script-/Shaderfehler in Export und Runtime-Logs.

## Version 0.9: Combat VFX

188 bestehende Funktionsprüfungen sowie 23 neue Combat-Prüfungen bestanden. Die neuen Prüfungen kontrollieren acht Profile und je zwei Audio-Cues, kosmetische Krater, unveränderten Snapshot und Simulations-RNG, exakte Schadensgrenzen, gesonderten Baukern-Blast, Ruinen, begrenzte Speicherbudgets, Kamerastoß OFF und vollständiges Auslaufen. Native Bilder: combat_families_modern/classic, combat_critical_damage, combat_core_destruction, combat_core_smoke. Die Galerie ist eine isolierte Präsentationsfixture; fünf der acht Profile sind noch keiner aktiven Waffe zugeordnet.

Bestehender Missionsdurchlauf unverändert gewonnen nach 249,9 s; 6320 gesammelt, 12 produziert, 18 Abschüsse, ein Verlust. Simulation: 200 Fahrzeuge, 300 Ticks, durchschnittlich 13,97 ms, maximal 36,26 ms. Keine Aussage zur GPU-Framerate. Mündungsvarianten nutzen ausschließlich einen lokalen RandomNumberGenerator. Flugkurve ist ein Draw-Offset ohne Änderung physischer Projektile. Anfängliche Einrückungsfehler korrigiert, anschließend native Suite ohne Script-/Shaderfehler.

Release 0.9: Windows-Export, Gameplay-Smoke und Intro-/Menü-Smoke erfolgreich; beide Runtime-Prüfungen Exit 0, keine Script-/Shaderfehler. Bekannte lokale Meldung zum Root-Zertifikatsspeicher ohne Einfluss auf Offline-Spiel.

## Version 0.10: Style Consolidation

260 Funktionsprüfungen bestanden: 211 bestehende sowie 49 neue Prüfungen. Neue Checks: JSON-Command-Roundtrip, authentisch übergebener Issuer gegenüber Payload-Owner, atomare Ablehnung gemischter/fremder/duplizierter/ungültiger Entity-IDs und nichtendlicher Positionen, Sichtprüfung bei Angriff, Stop/Hold/Guard, Rally, Repair, Produce/Cancel, Harvest/Return, Build-Validierung, explizite Identität, Legacy-Migration und atomare Ablehnung inkonsistenter gespeicherter Eigentümer. Keine Netzwerkauthentifizierung implementiert.

Präsentationschecks: Auswahlporträt, sichtbare Waffenrolle/Bauzeit, vollständig sichtbare Auswahltexte, korrekt dünner Produktionsbalken, echte Zerstörungsereignisse mit typisierten Ruinen, wahre 640×360-Textur, unveränderter Snapshot beim Moduswechsel, Mehrfachauswahl, FOW-Verdeckung lokaler Events und zeitliches Auslaufen von Resten. Screenshot-Fixture zeigt beide Teams, Ressourcen, Produktion, Konstruktion, kritischen Schaden, Schüsse und erkennbare Nachweise nach Zerstörung. Native Aufnahmen in Modern/Classic und der Nachkampfphase visuell geprüft. Die Szene ist isoliert und keine Kampagne.

Anfangs zeigte eine Fixture-Prüfung fälschlich die physische Fenstergröße statt interner Rendertextur; korrigiert. Bildprüfung fand einen zu hohen ProgressBar und geclippten Auswahltext; beide wurden korrigiert und durch Checks abgesichert. Bestehende UI-Eingabeprüfungen und vollständiger bezahlter Missionsdurchlauf erfolgreich. Keine Script-/Shaderfehler im abschließenden Lauf; lokale Meldung zum Root-Zertifikatsspeicher bleibt ohne Auswirkung auf das Offline-Spiel.

Release 0.10: Windows-Export erfolgreich, Gameplay-Smoke und Intro-/Menü-Smoke beide Exit 0; keine Script-/Shaderfehler. Finale native Artprüfung aller sieben Gebäude und vier Fahrzeuge in Modern/Classic erfolgreich. Simulation: 200 Fahrzeuge, 300 Ticks, 13,98 ms im Mittel, maximal 21,02 ms; keine GPU-FPS-Zusage. Missionsdurchlauf: Sieg nach 249,9 s, 6320 gesammelt, 12 produziert, 18 Abschüsse, ein Verlust.

## Version 0.11: Readability & Persistent Destruction

287 Funktionsprüfungen bestanden: 260 bestehende Checks und 27 neue Persistenzprüfungen. Vollständige Suite im abschließenden Lauf erfolgreich; nach Ergänzung der Recycling-Grenzfälle gezielter Persistenzlauf mit 27/27 erfolgreich. Keine Script-, Shader- oder Polygonfehler in den abschließenden Logs. Die lokale Meldung zum Root-Zertifikatsspeicher bleibt ohne Einfluss auf das Offline-Spiel.

Neue Nachweise: echter Tankbeschuss bis zum Tod, unmittelbare Auswahlbereinigung, schwere Werksschäden, Fabrik-/Baukernreste, fünfzehn Minuten beschleunigte kosmetische Zeit, JSON-Roundtrip, echter Save/Load inklusive Renderer-Neuinitialisierung, fünf atomar verworfene beschädigte Datenformen, unveränderte aktive Mission bei ungültiger kosmetischer Save-Erweiterung, Legacy-Saves, unveränderte Simulation/RNG beim Alterungsdurchlauf, Classic mit echter 640×360-Textur, echte 20-gegen-20-Ticks, feste Budgets, Missionsreset und priorisiertes Recycling. Selbst ein ausschließlich mit Baukernen gefüllter Pool bewahrt das neueste Wrack und recycelt ein älteres Objekt.

20 gegen 20: 25 bestätigte Wracks, schlechtester gemessener Tick einschließlich FX-Update 2,87 ms im letzten gezielten Lauf. Dies misst Simulation/Update, keine GPU-Framerate. 200 Fahrzeuge und 300 Ticks: 13,84 ms im Mittel, maximal 20,55 ms. Bezahlter Missionsdurchlauf unverändert: Sieg nach 249,9 s, 6320 gesammelt, 12 produziert, 18 Abschüsse, ein Verlust.

Native Modern-/Classic-Aufnahmen des Gefechts und der kalten Nachkampfphase visuell geprüft. Bildprüfung fand zunächst zu dichten Rauch im Massengefecht: Rauchüberlagerungen abgeschwächt und räumliche Quellenbegrenzung ergänzt; Fahrzeuge, Teamflächen und World-Status sind danach besser sichtbar. Ein zunächst ungültiges Kristallschatten-Polygon korrigiert. Speicher-Roundtrip-Prüfungen vergleichen normalisierte JSON-Daten und den regulären Legacy-Restore als Referenz, um Zahlentyp-Konvertierungen nicht mit State-Änderungen zu verwechseln.

Die Simulation wurde gegen das ausgelieferte 0.10-Quellarchiv verglichen: einziger Unterschied ist die zusätzliche ID im kosmetischen Todesereignis; sämtliche Gameplay-JSON-Dateien bytegleich. Persistenzdaten liegen außerhalb des Simulationssnapshots. Missionslange Reste sind auf 128, Krater auf 80 begrenzt; Transients weiterhin 220. Cold-Phase beendet Rauch nach 60/90 Sekunden. Auswahl-/Lebensbalken werden nach VFX und Nebel gezeichnet. Vorhandene Palette, UI, Musik und Balance erhalten.

Release 0.11: Windows-Export erfolgreich, Dateiversion 0.11.0.0. Gameplay-Smoke und Intro-/Menü-Smoke beide Exit 0; keine Script-/Shaderfehler. ZIP-Archive nach Erstellung per CRC geprüft. Mechanik und Grenzen beschrieben in PERSISTENT_DESTRUCTION_IMPLEMENTATION.md. Screenshots unter test-output/persistence_*.png. Subjektive Qualitätsbewertung, menschliche Langzeit-Spieltests und GPU-Leistung auf weiterer Hardware bleiben ergänzende QA.


## Version 0.12: Modelle und Updateinfo — 02.10.2026

310 Funktionsprüfungen bestanden: 287 bestehende und 23 neue Updateinfo-Prüfungen. Tests prüfen zwölf datierte und eindeutige Versionsdatensätze, konsistente Export-/Menüversion, aktuellen Eintrag beim Öffnen, alte Releases, echte Pfeiltasten-Navigation, scrollbar angelegte Änderungstexte, Zugriff aus dem Pausenmenü, unveränderten kompletten Missionssnapshot beim Zurückkehren und Weiterlaufen nach Schließen. Native Modern- und Classic-Bilder der Updateinfo sowie der Grafikszene geprüft.

Ein Einrückungsfehler in der Turmgrafik wurde im ersten Durchlauf erkannt und korrigiert. Abschließende vollständige Suite ohne Script-, Shader- oder Polygonfehler. Lokale Meldung zum Root-Zertifikatsspeicher weiterhin ohne Einfluss auf das Offline-Spiel. Missionsdurchlauf unverändert: Sieg nach 249,9 s, 6320 gesammelt, 12 produziert, 18 Abschüsse, ein Verlust. 200 Fahrzeuge: 13,74 ms mittlere Tickzeit, 21,36 ms Maximum; dies ist keine GPU-Framerate. Persistenztest 20 gegen 20: 25 Wracks, maximal 2,88 ms pro Tick inklusive FX-Update.

Archivabgleich: scripts/simulation.gd, data/catalog.json und data/veyra.json sind gegenüber 0.11 bytegleich. Neue Kristallvariation verwendet ausschließlich lokale mathematische Werte. Auswahländerung liegt weiterhin über VFX und respektiert Sicht/Culling. Historische Datumsangaben stammen aus den vorhandenen Windows-Release-Archiven; die Einträge behaupten keine separaten Veröffentlichungen außerhalb dieses Projekts. Neue Einträge werden in data/update_history.json gepflegt und das Export-Versionsfeld entsprechend aktualisiert.

Release-Prüfung 0.12: Windows-Export erfolgreich; Dateiversion und Produktversion 0.12.0.0. Exportierte EXE mit --smoke und --frontend-smoke jeweils Exit 0. Keine Script-, Shader-, Parse- oder Polygonfehler in den Release-Protokollen. Modern- und Classic-Updateinfo visuell geprüft. Die bekannte Zertifikatsspeicher-Meldung beeinträchtigt das Offline-Spiel nicht. Windows- und Quellcode-Archiv nach Erstellung per CRC geprüft.


## 0.13 — Objektinfos, Reparatur und Gefechtsdetails — 02.10.2026

337 einzelne Funktionsprüfungen bestanden: 287 bestehende, 24 Updateinfo- und 26 Reparatur-/Objektinfo-Prüfungen. Neue Tests bestätigen Gebäudereparaturknopf und Abschalten, 26 HP/s, korrekte Kosten, keine Gratisheilung bei 0 Credits, exakte Vollheilungsgrenze, automatische freundliche Hangarreparatur, keine Feindreparatur, erreichbare Serviceziele, tatsächliche Fahrzeugankunft und Heilung, Ablehnung fremder/in Bau befindlicher Objekte, Energieausfall, Wartephase beschädigter Sammler, Wiederaufnahme nach Vollheilung, Save/Load von Reparaturflag und Serviceauftrag, technische Daten und Pause im Infofenster, Modern/Classic und deaktivierte Feindreparatur.

Ein erster Musikdurchlauf scheiterte an einer zeitabhängigen Alarm-Lautstärkeprüfung; separater Wiederholungslauf: 16/16 bestanden, keine Musikänderungen. Ein zu knappes Seitenleistenlayout wurde von der Sichtbarkeitsprüfung erkannt: Objektinfo/Reparatur jetzt oben, ursprüngliche Textfläche wiederhergestellt, 49/49 Style-Checks bestanden. Einrückung und fehlerhafte Testtextkodierung wurden vor den abschließenden Prüfungen korrigiert. Fahrzeugfahrt wird von einer tatsächlich freien Teststartzelle geprüft.

Neue Grafik: kleinere Brandspuren, Metalltrümmer mit Kanten/Rädern/Motorrippen, gebrochene Fundamente, mehrschichtige Flammen statt Dreiecke, kompakte Auswahlwinkel, Lebensbalken mit begrenzter lokaler Entzerrung. Sichtbarkeit, Wrackpersistenz, Speichern und Classic bleiben geprüft. Modell- und Reparaturinformationen visuell in beiden Modi geprüft; Missionsdurchlauf 249,9 s, 6320 gesammelt, 12 produziert, 18 Abschüsse, ein Verlust. Simulation mit 200 Fahrzeugen: 14,33 ms mittlere Tickzeit; einzelnes Maximum 72,19 ms, keine zugesicherte GPU-Framerate. Die lokale Zertifikatsspeicher-Meldung bleibt ohne Wirkung auf Offline-Spiel.

Release 0.13: Windows-Export erfolgreich, Datei-/Produktversion 0.13.0.0. Exportierte EXE startet mit --smoke und --frontend-smoke jeweils Exit 0. Abschließende Export-/Release-/Reparatur-/Style-/Persistenzprotokolle ohne Script-, Shader-, Parse- oder Polygonfehler. Windows- und Source-ZIP nach Erstellung per CRC geprüft.


## 0.14 — Gebäudedrehung, Details und Sound — 02.10.2026

372 Funktionsprüfungen bestanden: 287 bestehende, 25 Updateinfo, 26 Reparatur/Objektinfo und 34 neue Rotation/Sound. Rotation wird durch echte E-Tastenereignisse und den sichtbaren Drehknopf geprüft. Rückwärtsdrehen, atomare Ablehnung ungültiger Bauwinkel, vertauschte Raffineriefläche, belegte Rasterzellen, Save/Load, Altsaves ohne Winkel, ungültige gespeicherte Ausrichtung, Freigabe nach Zerstörung, Werft-Vorderausgang und Sammelpunkt. Modern/Classic der vier Ausrichtungen visuell geprüft. Je Waffenfamilie drei Varianten geladen; 24 Stimmen, Limiter, unabhängige Waffenklänge und Dreh-/Reparaturfeedback geprüft.

Alle 60 neuen WAVs auf Stereo, 44100 Hz, nicht stumm und Spitzen unter 30000/32767 geprüft. Keine Hörbewertung durch diese Zahlenprüfung behauptet; Soundprobe in test-output/soundprobe_0.14.wav. Originale reproduzierbare Synthese in tools/generate_detail_audio.py; keine fremden Samples. Das SFX-Limit ist zusätzlich zum Einzeldatei-Headroom aktiv.

Fehler aus Erstläufen korrigiert: Typinferenz bei Variantenpfaden, numerische Typnormalisierung gespeicherter KI-Erinnerungen und Gebäudewinkel, Spiegelung der Gebäudequerachse. Der Musiktest erkannte einen verpassten Kontakt-Taktwechsel: Erkennung jetzt über gewechselten Taktindex statt eines schmalen Abfragefensters; Test wartet begrenzt auf Zustand und Mix-Fade. Abschließender Audio- und alle UI-/Grafik-/Reparatur-/Rotationstests bestanden.

Regression 86/86; vollständiger Missionsdurchlauf weiterhin Sieg nach 249,9 s mit 6320 gesammelt, 12 produziert, 18 Abschüssen und einem Verlust. 200 Fahrzeuge: 13,47 ms mittlere Simulations-Tickzeit, 21,63 ms Maximum; keine GPU-FPS-Zusage. Zertifikatsspeicher-Meldung weiter ohne Einfluss auf Offline-Spiel. Geänderte Simulation beschränkt sich auf Bauausrichtung, passende Flächen/Ausgänge und Speicherung; Kampfwerte, Kosten und Heilungsrate unverändert.

Release 0.14: Windows-Export erfolgreich; Datei- und Produktversion 0.14.0.0 geprüft. Exportierte EXE mit --smoke und --frontend-smoke jeweils Exit 0; keine Script-, Shader- oder Parse-Fehler in den Abschlussprotokollen. Windows- und Source-ZIP erstellt und vollständig per CRC geprüft.



## 0.15 — Renderlast und Einsatzvorbereitung — 02.10.2026

Render-Messung mit 40 sichtbaren Fahrzeugen, pausierter Simulation und Godot 4.7.2 auf NVIDIA RTX 3060: Detailpfad vor Optimierung 4,6 FPS bei etwa 28.556 Zeichenaufrufen; nach Textur-Atlas, Crowded-Battle-Fahrzeug-LOD und ausgedünnten Bodenmarken etwa 29 FPS bei rund 6.475 Zeichenaufrufen. Ohne Hitzeflimmern veränderte sich die Messung kaum. Das misst einen absichtlich dichten Standbildfall, nicht jede Spielszene oder andere Hardware; 60 FPS sind auf diesem Stressfall noch nicht erreicht.

Die neue Missionsvorbereitung ist eine eigenständige Bildschirmansicht. Facettierte Solarit-Atlasdatei und zugehöriger Generator liegen unter assets/ und tools/. Finale Export-, Bedien- und Updateinfo-Prüfungen für 0.15 folgen nach dem Windows-Export.

Abschlussversion 0.15: aktuelle Fraktions-/Briefingansicht durch Frontendprüfung (26/26) und Updatehistorie (26/26) geprüft. Exportierte Windows-Datei startet mit --smoke und --frontend-smoke jeweils mit Exit 0. Datei- und Produktversion 0.15.0.0. Windows- und Quellcodepaket erstellt, beide CRC-Prüfungen erfolgreich.



## 0.16 — Solaritfelder — 02.10.2026
Ursache: Der Atlasgenerator zeichnete die Kristalle bei der Ursprungskachel, ohne den Offset für die jeweilige Zeile und Spalte anzuwenden. Damit waren die Kacheln der tatsächlich verwendeten Form-/Dichtevarianten transparent, obwohl die Startkarte Ressourcenvorkommen enthielt. Generator korrigiert und assets/solarit_atlas.png neu importiert; alle zwölf Atlaszellen enthalten jetzt sichtbare Pixel. Die aktuelle Startkartenansicht wurde visuell geprüft; Solaritfelder sind wieder klar erkennbar.

Abschlussversion 0.16: UI-Integration 38/38 ohne Fehler; Updateinfo 27/27 ohne Fehler. Exportierte Windows-Datei mit --smoke und --frontend-smoke jeweils Exit 0. Datei-/Produktversion 0.16.0.0. Windows- und Quellcodepaket erstellt, CRC-Prüfung jeweils erfolgreich.


## 0.17 — Rendering-Optimierung — 02.10.2026

Fahrzeuge werden bei gleicher Zoomstufe unabhängig von der sichtbaren Fahrzeugzahl in voller Detailstufe dargestellt. Ihr statischer Körper, Schatten und Turm werden in 256×256 hochauflösenden Texturvarianten gespeichert; Varianten berücksichtigen Team, Turmausrichtung, Schadensband und Harvesterladung. Kettenstreifen werden bei Bewegung separat animiert. Positions-, Rumpf- und Turmwerte werden ausschließlich für die Darstellung zwischen festen Simulationsticks interpoliert. Ein serieller Cache-Aufbau vermeidet gleichzeitige SubViewport-Spitzen.

Statische Fels-/Bodendetails werden beim Kartenwechsel in 16×16-Terrainkacheln als Mesh aufgebaut und außerhalb des Kamerabereichs übersprungen. Ressourcen bleiben dynamisch abbaubar. Fahrspuren verwenden einen zusammengefassten Mehrfachlinienaufruf; Partikel und VFX bleiben aktiv.

Reproduzierbare Render-Messung auf NVIDIA RTX 3060, Godot 4.7.2, gleicher pausierter Missionsszene und 120 Messframes nach 75 Aufwärmframes:

| Sichtbare Fahrzeuge | Vorher FPS | 0.17 FPS | Draw Calls 0.17 |
|---:|---:|---:|---:|
| 1 | — | 53,87 | 4.636 |
| 10 | — | 48,12 | 4.633 |
| 20 | — | 52,42 | 4.633 |
| 40 | 5,9 | 51,31 | 4.632 |

Der historische Vorherwert stammt aus dem bisherigen 40-Fahrzeuge-Stresslauf mit 21.580 Zeichenaufrufen. Die neue 40-Fahrzeuge-Szene benötigt rund 78,5 % weniger Aufrufe und läuft etwa 8,7-mal schneller. Ein automatischer Vergleich desselben Fahrzeugbereichs bei 1 und 40 Fahrzeugen ergab 2,93 % mittlere RGB-Abweichung; Sichtprüfung ergab gleichbleibende Modellkonturen und Details. Der Vergleich toleriert höchstens 3 %, hauptsächlich wegen wechselnder animierter Bodendetails.

40 bewegte Fahrzeuge plus fortlaufende Kampf-VFX: 20,88 FPS, 6.658 Draw Calls und 297.471 Primitives. Damit bleibt das 60-FPS-Ziel verfehlt, besonders im bewegten Effektfall. Statische Gebäudegeometrie ist in diesem Pass noch nicht gecacht und wird weiter pro Frame gezeichnet; als Nächstes sind Gebäude-Caches mit separater Animationsschicht und die Überarbeitung der VFX-Zeichenaufrufe nötig. Es gibt keinen sichtbarkeitszahlabhängigen Fahrzeug-LOD.

UI-Integration 38/38 ohne Fehler. Render-Performance-Harness deckt 1/10/20/40 Fahrzeuge, 40 bewegte Fahrzeuge mit VFX sowie den 1-gegen-40-Bildvergleich ab. Die Godot-Ausgabe meldet beim Test weiterhin einen fehlenden Windows-Zertifikatsspeicher; Offline-Spiel und Messung laufen weiter.

## 0.18 — FPS-Monitor und Einbruchprotokoll — 02.10.2026

Die Statusleiste zeigt in Einsätzen laufend die aus Frameanzahl und verstrichener Zeit gemessenen FPS. Die Farbe wechselt bei 50/30 FPS. Das Logging wertet 0,4-Sekunden-Fenster aus und schreibt einen LOW_FPS-Eintrag nach mindestens einer Sekunde unter 45 FPS; RECOVERED wird ab 50 FPS protokolliert. CSV: `user://performance_events.csv`; Felder umfassen Zeitstempel, Missionszeit, Dauer, Durchschnitt/Minimum, Gesamtzahl und eigene/feindliche Fahrzeuge/Gebäude, sichtbare Einheiten/Gebäude, VFX, Draw Calls, Primitives, Prozess-/Physikzeit und Vehicle-Cache-Zähler. Es wird nur im aktiven Missionskontext protokolliert; pausierte Missionen bleiben messbar.

Prüfung 0.18: FPS-Monitor 7/7 und Updateinfo 29/29; Windows-Export 0.18.0.0 erstellt, `--smoke` und `--frontend-smoke` mit Exit 0 gestartet. Regression, Missionsdurchlauf, Audio, UI, Frontend, Stil, Kampf-VFX, Zerstörung, Reparatur und Rotation bestanden. Einschränkung dieses Suite-Laufs: `color_identity.gd` bekam bei beiden automatischen Screenshot-Aufnahmen ausschließlich schwarze Pixel und schlug dadurch bei der Bildfarbprüfung fehl; der isolierte Showcase-Lauf meldete ebenfalls gerenderte Objekte, seine gespeicherte Aufnahme war schwarz. Die Bildaufnahme dieser automatisierten Umgebung bestätigt daher die Freund/Feind-Farben in diesem Lauf nicht.

## 0.19 — Einsatzrekorde — 02.10.2026

Abschlüsse schreiben eine Top 10 je Mission nach `user://highscores.json`. Wertung: 1.000 Basis, +250 pro Abschuss, Solarit ×0,5, +120 pro produziertem Fahrzeug, +100 pro errichtetem Gebäude, bis zu +3.600 Zeitbonus sowie −200 pro verlorenem Fahrzeug und −500 pro verlorenem Gebäude. Bei Punktgleichheit zählt die schnellere Zeit. Die Laufkennung wird mit Spielständen gespeichert und dedupliziert gewertete Siege. `tests/highscore.gd`: 8/8 Prüfungen für Punktberechnung, Sortierung, Duplikatvermeidung, Niederlagenausschluss, Ein-Level-Katalog und UI-Zugriff. Updateinfo 30/30, UI-Integration 38/38, Frontend 26/26.

## 0.20 – Missionssystem / drei Einsätze

Neu geprüft bzw. als Testfall ergänzt:
- alle drei Missionsdateien werden vom `Catalog` validiert;
- Mission 02 endet erst, wenn Solaritmenge, zwei Raffinerien und feindliche Raffinerie gemeinsam erfüllt sind;
- optionale Ziele blockieren den Sieg nicht;
- Mission 03 erzeugt zeitgesteuerte reale Gegnerfahrzeuge und löst dieselbe Welle nicht doppelt aus;
- der Schutz des eigenen Baukerns hat weiterhin Vorrang vor einem möglichen Sieg;
- Wellenfortschritt bleibt in Spielständen erhalten.

Automatischer Test: `tests/mission_system.gd` (über `Test-Ashline.ps1`).

Startdiagnose 0.20: Der Quellstart war durch einen doppelt definierten `_input`-Handler blockiert; nach dessen Zusammenführung verhinderte eine als Fehler behandelte Typinferenzwarnung im Renderer den Skript-Compile. Beide Stellen wurden korrigiert. Editor-Parsecheck und Laufzeitstart ohne GDScript-Fehler; Frontend 26/26, UI-Integration 38/38, Updateinfo 31/31. Frischer Windows-Export 0.20.0.0; exportiertes Spiel und Menü mit `--smoke` sowie `--frontend-smoke` jeweils Exit 0. Die Windows-Zertifikatsspeicher-Meldung bleibt bestehen und ist für Offline-Spiel nicht relevant.

## 0.21 — Detailliertes Renderprofil — 02.10.2026

F3 misst die CPU-Zeichenzeit für Terrain/Resourcenzellen, Ruinen und Trümmer, Gebäude, Fahrzeuge und Kampfeffekte und zeigt deren jeweilige Objektzahlen. Die Messungen werden ausschließlich bei aktivierter F3-Diagnose erhoben. `tests/performance_monitor.gd` prüft Profilwerte und HUD-Ausgabe.

Auf NVIDIA RTX 3060 mit Godot 4.7.2, GL Compatibility, 1920×1080: ruhende 40-Fahrzeug-Szene rund 54 FPS; gemessene CPU-Zeichenzeit rund 4,7 ms, darin Gebäude 3,4 ms, Fahrzeuge 0,1 ms, Terrain 0,6 ms. 40 bewegte Fahrzeuge plus laufende Kampfeffekte: rund 23 FPS und 15 ms gemessene Zeichenzeit, davon rund 6,9 ms Fahrzeuge. 25 sichtbare Gebäude: rund 71 ms Bildzeit, davon 68,5 ms Gebäudezeichnung. 36 erzeugte Fahrzeug-/Gebäuderuinen mit Rauch: rund 59 ms Bildzeit, davon 10,4 ms Ruinenzeichnung.

Die 36-Wrack-Messung liegt nahe an den 17 FPS des gemeldeten Spielstands und macht Ruinen/Trümmer zum wahrscheinlichen Hauptverursacher dort. Die Messung ist ein isolierter Stresstest; der genaue Anteil in einem echten gespeicherten Einsatz hängt von Sichtbereich, Gebäudezahl und aktiven Effekten ab. Es erfolgte in 0.21 keine Renderoptimierung; Gebäude- und Ruinendarstellung bleiben die nächsten konkreten Optimierungsziele.

Prüfung 0.21: Render-Benchmark mit allen vier Fahrzeugstufen, 40 Fahrzeugen plus Kampf-VFX, 25 Gebäuden und 36 Wracks durchgelaufen; F3-/FPS-Test 10/10 und Updateinfo 32/32. Windows-Export 0.21.0.0 erstellt; `--smoke` mit Exit 0. Der bestehende `build/ASHLINE.exe` konnte nicht überschrieben werden, daher liegt der neue Testbuild separat als `build/ASHLINE-0.21.exe`.

## 0.22 — Gebäudecache für große Basen — 02.10.2026

Fertige, intakte Strukturen werden einmal in ein transparentes 512×512-Renderziel gezeichnet und als hochauflösende Textur wiederverwendet. Die Textur wird mit halber Größe dargestellt, damit die native Vektorauflösung beim Herunterskalieren erhalten bleibt. Pro Cacheeintrag werden Zustand, Eigentümer, Fraktion, Drehung und aktive Fabrikproduktion unterschieden; animierte Maschinendetails erhalten in Intervallen ein neues Bild. Baustellen, aktive Reparaturen und Gebäude unter 65 % Integrität bleiben live gerendert und bewahren Montage-, Reparatur- und Schadenseffekte.

Der GPU-Benchmark auf RTX 3060 / Godot 4.7.2 GL Compatibility bestätigte Cache-Treffer für alle 50 zusätzlich sichtbaren Kraftwerke (51 sichtbare Gebäude einschließlich Missionskern). Der Gebäude-Zeichenpass lag nach dem Aufwärmen bei rund 0,13 ms pro Bild; vier zusätzliche Gebäude bei rund 0,02 ms. Die Gesamtmessung lag bei 115 FPS mit vier und 110 FPS mit 50 zusätzlichen Gebäuden. Die Grafik wurde mit einem gerenderten Screenshot auf korrekte Größe und Schärfe geprüft. 40 Fahrzeuge stationär: rund 98 FPS; 40 fahrende Fahrzeuge mit Kampf-VFX: rund 34 FPS. Der Benchmark prüft 50 zusätzliche Gebäude plus Missionskern und verwendet eine leere VFX-Szene, um die Gebäude isoliert zu messen. Headless-Benchmarkwerte werden nicht gewertet, da der Dummy-Renderer keine GPU-Texturen oder echten Draw Calls unterstützt.

## 0.23 — Adaptive Gefechts-VFX — 03.10.2026

Bei mehr als zehn gleichzeitig sichtbaren Zerstörungen erhalten Kernexplosionen und eine Teilmenge der übrigen Explosionen die volle Detailstufe. Weitere Detonationen reduzieren Radialpartikel, Rauch-/Staubpunkte und Trümmerlinien; gleichzeitig werden dynamische Flammen- und Rauchquellen an Ruinen begrenzt. Die Detailreduktion steigt nur mit Effektlast, sodass normale Gefechte ihre bestehende Darstellung behalten. Zusätzlich vereinfacht die Ruinendarstellung ab 17 sichtbaren Wracks Bodenkrater, Gebäudeschutt, Mauerstücke und kleine Fragmente.

RTX 3060, Godot 4.7.2 GL Compatibility, pausierte Szene mit 36 gleichzeitig sichtbaren Zerstörungseffekten: Effekt-Zeichenzeit sank von 40,33 auf 12,38 ms pro Bild (−69 %); Ruinen-/Trümmerpass sank von 9,48 auf 8,10 ms; gesamter gemessener Renderpass sank von 50,66 auf 21,39 ms. Das entspricht rund 47 FPS für diesen isolierten Zeichenpass. 40 bewegte Fahrzeuge plus laufende Kampf-VFX lagen in diesem Lauf bei rund 33 FPS und bleiben ein separater Engpass. Der Stresstest mit 50 zusätzlichen Gebäuden lag bei rund 104 FPS; deren Gebäude-Zeichenpass betrug 0,13 ms. Die große Gebäudemenge ist im isolierten Basistest daher nicht der dominante Kostentreiber.

Prüfung 0.23: GL-Renderbenchmark mit 1/10/20/40 Fahrzeugen, 40 bewegten Fahrzeugen mit Kampf-VFX, 4/50 zusätzlichen Gebäuden sowie 36 gleichzeitigen Zerstörungen bestanden. Updateinfo 34/34 und Performance-Monitor 10/10 bestanden. Windows-Export `build/ASHLINE-0.23.exe` erstellt und `--smoke` mit Exit 0 gestartet. In der isolierten Umgebung kann Godot weiterhin keine `user://`-Logs, Shader-Caches oder Test-Screenshots ablegen; das Spiel und die Render-/UI-Tests laufen trotzdem. Der Export-Presetname wurde nach dem CLI-Aufruf wieder auf `Windows Desktop` gesetzt.

## 0.24 — Gefechts-Rendering und FPS-Pass — 03.10.2026

Der Desktop-Renderer wurde nach einem A/B-Vergleich auf Forward+ umgestellt. Dieselbe reproduzierbare, bewegte 20-gegen-20-Einheitenschlacht lag zuvor mit GL Compatibility bei 46 FPS und danach bei 78 FPS auf der RTX 3060. Bewegte Kettenlinien und Treffer-/Licht-/Rauchformen laufen in gebündelten Zeichenaufrufen. Das F3-Profil trennt zusätzlich Ruinenzeichnung und HUD-Aktualisierung.

Der A–G-Benchmark misst ruhende und bewegte Fahrzeuge, Projektile, Treffer, Explosionen, echte Gefechte und angesammelte Ruinen/Spuren getrennt. Der Fünf-Minuten-Lauf schreibt Messpunkte nach 30 Sekunden, 2 Minuten und 5 Minuten und zählt Einheiten, Effekte, Pool, Wracks, Spuren, Draw Calls und Primitives. Matrix- und Langzeit-CSV liegen in `test-output/`.

Ergebnis und Grenze: Der aktuelle Forward+-Matrixlauf erreicht im bewegten 40-Fahrzeug-Gefecht 76,44 FPS; GL Compatibility liegt mit exakt demselben Szenario bei 45,98 FPS. Der dichte Trümmerfall mit 36 Explosionen, 42 Wracks und 1.467 Spuren fällt mit 31,14 FPS weiterhin darunter und bleibt ein offener Engpass. Er wird nicht durch Entfernen sichtbarer Fahrzeugdetails kaschiert.

Der korrigierte Fünf-Minuten-Lauf hielt Bewegung und automatische Gefechts-VFX durch regelmäßige Attack-Move-Befehle aktiv. Die Messfenster erreichten 83,89 FPS nach 30 Sekunden, 96,99 FPS nach 2 Minuten und 108,53 FPS nach 5 Minuten. Der 40-Fahrzeug-Roster erzeugte bis zu vier Wracks; bis zu 51 Partikel waren gleichzeitig aktiv und der Pool wurde bis zu 8.033-mal wiederverwendet. Auch die letzten Messpunkte enthielten noch Geschosse und Treffer-Effekte. Die CSV-Spalte `roster_units` zählt das ursprüngliche Aufgebot; Wracks sind separat erfasst. Matrix- und Langzeit-CSV sind dem Patch beigelegt.

Updateinfo 0.24 und Exportmetadaten wurden auf 0.24.0.0 angehoben. Der Engine-Editor-Scan konnte alle globalen GDScript-Klassen registrieren. Es bleiben Umgebungswarnungen, weil die isolierte Testumgebung kein `user://`-Verzeichnis, keinen Shader-Cache und keinen Windows-Zertifikatsspeicher bereitstellt; die Tests schreiben ihre Ergebnisse in das Projektverzeichnis.

# Kommandantenakte und globales Spielerprofil

Das lokale Profil wird in user://commander_profile.json gespeichert. Es enthält profile_version: 1, eine beim ersten Speichern erzeugte stabile profile_id, den Nickname, Ergebnisstatistiken, den besten Einzelspieler-Score, die letzten 30 abgeschlossenen Einsätze und bis zu 60 IDs für den Duplikatschutz. Speicherung erfolgt über eine temporäre Datei mit Sicherung der letzten gültigen Datei. Ein beschädigtes Profil blockiert das Spiel nicht; der Nickname kann erneut angelegt werden, die defekte Datei bleibt als .previous erhalten, sobald das neue Profil gespeichert wird.

Der Name ist 2 bis 20 Zeichen lang und darf Unicode-Buchstaben, Ziffern, Leerzeichen, Bindestrich und Unterstrich enthalten. Ein neues Profil wird einmalig nach Intro und vor dem normalen Menü abgefragt. Oben rechts im Hauptmenü steht KOMMANDANT mit dem aktiven Nickname. SPIELER WECHSELN öffnet direkt die bestehende Identifikationsmaske; die Anzeige wird nach Bestätigung sofort aktualisiert. Ohne Profil erscheinen NICHT IDENTIFIZIERT und IDENTIFIKATION STARTEN. Der Profilbereich unter Optionen öffnet weiterhin die Kommandantenakte und ermöglicht ebenfalls das Ändern des Namens. Ein Namewechsel behält Profil-ID, Historie und Statistik. Bestehende Highscores behalten den bei ihrem Ergebnis gespeicherten Namen.

Ergebnisstatistiken zählen nur reguläre Siege und Niederlagen. Abgebrochene Partien und bloße Starts werden nicht verbucht. Die zentrale Ergebnisfunktion nimmt Einzelspieler-, Duell- oder Koop-Ergebnisse auf, begrenzt Zeitwerte auf die tatsächlich simulierte Matchzeit und ignoriert wiederholte Result-ID. Der beste Score wird aus dem bestehenden Einzelspieler-Score berechnet.

Jede regulär beendete Partie erhält zusätzlich einen ausführlichen Bericht unter `user://match_reports/`. Er speichert das Berichtsschema und die konkrete Spielversion, Karte, Modus, Schwierigkeit, Ergebnis, Kommandantennamen und beide Fraktionen. Alle fünf Simulationssekunden erfasst die Zeitreihe Solarit-Lager, Fahrzeug- und Gebäudebestand samt Typen sowie gesammeltes Solarit, Produktion, Errichtungen, Abschüsse und Verluste; dazu kommt ein Endpunkt beim Partieabschluss. Ereignisse halten Bauanfang/-abschluss, Fahrzeugproduktion, Ausbau, Zerstörung und erkannte Führungswechsel mit Partiezeit und Position fest. Führungswechsel lassen sich damit auf etwa fünf Sekunden genau einordnen. Das Archiv ist unbegrenzt; die Akte zeigt die letzten 30 Partien und bietet zusätzlich „Alle Partieberichte“. Diagramme vergleichen beide Seiten. Im Duell überträgt der Host am Spielende den vollständigen Bericht, damit auch der Client die Gegnerstatistik erhält. Berichte entstehen erst bei Sieg oder Niederlage, nie bei Abbruch.

Highscores behalten ihre bestehende Dateiformatversion und erhalten für neue Einträge profile_id und nickname. Alte Einträge bleiben unverändert; ohne gespeicherten Namen erscheinen sie als UNBEKANNT. Neue und gespeicherte Spielstände ergänzen commander_profile_id und commander_nickname. Ältere Spielstände bleiben ladbar und werden nicht nachträglich umgeschrieben.

## Geänderte und neue Dateien

- scripts/player_profile.gd: versioniertes Profil, Validierung, Statistik, Historie, Berichtverweis und Ergebnis-Duplikatschutz.
- scripts/match_recorder.gd, scripts/match_chart.gd: versionierte Matcharchive, Vergleichszeitreihen, Ereignisse und Diagrammzeichnung.
- scripts/main.gd, scripts/simulation.gd: Archivierung, vollständiger Hostbericht für den Duellclient, Partiearchiv und Berichtansicht.
- scripts/online_session.gd, scripts/network_protocol.gd: geprüfter Namensaustausch, Systemchat, Readiness-Duplikatschutz, Matchbericht-RPC und Protokollversion 5.
- tests/player_profile.gd, tests/frontend.gd, tests/highscore.gd, tests/network_game.gd, tests/ui_integration.gd: Profil-, Ergebnis-, Lobby-, Chat- und Menünavigationstests.
- Test-Solarit.ps1: Profiltest in die Prüfsuite aufgenommen.
- docs/MULTIPLAYER.md, README.md: Bedienung und Protokoll aktualisiert.

## Prüfungen und Grenzen

tests/player_profile.gd prüft Namen, Persistenz, stabile Profil-ID, Ergebniszählung, getrennte Modi, aktive Zeit, Bestscore, Historienlimit und beschädigte Profildateien. tests/match_recorder.gd prüft Zeitreihen, Ressourcen und Fahrzeuge beider Seiten, Führungswechsel, Abbruchverhalten, Versionierung und gespeicherte Zerstörungsereignisse. Highscore-, Frontend-, UI- und Host/Client-Tests prüfen Einträge, Erststart, Kommandantenakte, Bildschirmgrößen und übermittelte Namen.

Es gibt weiterhin nur ein lokales Profil pro Installation. Online-Ergebnisse werden lokal im jeweiligen Profil gespeichert. Es gibt keine gemeinsame Online-Bestenliste, keinen Login und keine synchronisierte Statistik über mehrere PCs. Für alte abgeschlossene Partien lassen sich Statistiken nicht verlässlich rekonstruieren; sie beginnen im Profil bei null.

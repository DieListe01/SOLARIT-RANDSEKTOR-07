# Fraktions-Voice-System

`voice_catalog.json` ist der zentrale Text-/ID-Katalog und die Austauschstelle für finale Aufnahmen. Für jede Zeile ist `asset` absichtlich leer und `asset_state` ist `recording_required`: Das Projekt enthält noch keine deutschen Sprecheraufnahmen. Die einzige lokal installierte Systemstimme ist englisch und wird bewusst nicht als Fraktionsstimme ausgegeben.

Finale Dateien gehören in `kobalt/`, `wanderpakt/`, `prisma/` oder `neutral/`, als mono OGG Vorbis mit normalisiertem Sprachpegel. Empfohlene Namen: `<fraktion>_<bereich>_<ereignis>_<variante>.ogg`, zum Beispiel `kobalt_units_move_01.ogg` oder `prisma_harvester_unload_02.ogg`. Unterschiedliche Fraktionsidentitäten sollen mit eigenständigen Sprecherleistungen entstehen; keine gemeinsame Stimme nur per Pitch-Shift vervielfältigen. Prisma darf dezent technisch bearbeitet werden, Verständlichkeit hat Vorrang.

Nach Aufnahme und Hörabnahme wird pro Textzeile nur der jeweilige `asset`-Pfad gesetzt; Ereignis- und UI-Code bleibt unverändert. Es gibt daher in diesem Stand noch keine Sprachsamples, auch keine als final getarnten TTS-Platzhalter.

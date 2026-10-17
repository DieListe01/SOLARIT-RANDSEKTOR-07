# Fraktions-Voice-System

`voice_catalog.json` ist der zentrale Text-/ID-Katalog und die Austauschstelle für finale Aufnahmen. Der aktuelle Stand enthält 118 eingebundene deutsche Piper-Neural-TTS-Kandidaten (96 Fraktionszeilen und 22 Systemzeilen). Sie sind spielbar und im Review-Katalog auffindbar, aber `candidate` / `pending`: keine davon gilt als finale Studioaufnahme oder als unabhängig gecastete Fraktionsstimme.

Finale Dateien gehören in `kobalt/`, `wanderpakt/`, `prisma/` oder `neutral/`, als mono OGG Vorbis mit normalisiertem Sprachpegel. Empfohlene Namen: `<fraktion>_<bereich>_<ereignis>_<variante>.ogg`, zum Beispiel `kobalt_units_move_01.ogg` oder `prisma_harvester_unload_02.ogg`. Unterschiedliche Fraktionsidentitäten sollen mit eigenständigen Sprecherleistungen entstehen; keine gemeinsame Stimme nur per Pitch-Shift vervielfältigen. Prisma darf dezent technisch bearbeitet werden, Verständlichkeit hat Vorrang.

Bis professionelle Sprecheraufnahmen verfügbar sind, bleiben die 118 TTS-Kandidaten aktiv und ausdrücklich unfreigegeben. Die lokale Hörseite `test-output/audio-review/index.html` enthält Fraktions- und Systemstimmen samt Status und Quelle. Nach Aufnahme und Hörabnahme wird pro Textzeile der jeweilige `asset`-Pfad ersetzt; Ereignis- und UI-Code bleibt unverändert. TTS-Dateien dürfen nicht als finale Sprecherproduktion ausgegeben werden.

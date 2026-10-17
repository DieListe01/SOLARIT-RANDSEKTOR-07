# Engine und eingebettete Bibliotheken

SOLARIT: RANDSEKTOR 07 verwendet Godot Engine 4.7.2 stable. Copyright (c) 2014-present Godot Engine contributors. Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur. Godot steht unter der MIT-Lizenz; der folgende Text gilt für die Engine:

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Godot enthält weitere Bibliotheken und die Standardschrift. Deren Copyright- und Lizenztexte werden von Godot selbst eingebettet und sind außerdem in der versionsbezogenen [COPYRIGHT-Datei](https://github.com/godotengine/godot/blob/4.7.2-stable/COPYRIGHT.txt) dokumentiert.

## Audio-Kandidaten

Die folgenden lizenzierten Quellen sind für den internen Audio-Abnahmestand verarbeitet. Sie sind technisch in das Spiel eingebunden, aber noch nicht als finale Audioqualität freigegeben:

- Kenney, *Sci-Fi Sounds*, CC0 1.0. Lizenzkopie im Projekt unter `assets/audio/licenses/Kenney-SciFiSounds-LICENSE.txt`; https://kenney.nl/assets/sci-fi-sounds
- SRG774, *Dark Sci-Fi Audio Pack*, CC0 1.0; https://opengameart.org/content/dark-sci-fi-audio-pack. Verarbeitete Tracks daraus speisen Prisma-Ruhe/Alarm und globale Stinger. Sieben MP3-Quellfassungen liegen zusätzlich nur lokal unter `tools/audio_sources/candidates/dark_sci_fi_pack/` zum A/B-Hörvergleich; sie werden nicht direkt ausgeliefert.
- Alexander Ehlers / tricksntraps, *T&T Free Cyberpunk Pack 2*, CC0 1.0; https://opengameart.org/content/t-t-free-cyberpunk-pack-2
- vitalezzz, *Inevitable*, CC0 1.0; https://opengameart.org/content/inevitable
- Emma_MA, *Determined Pursuit*, CC0 / Public Domain; https://opengameart.org/content/determined-pursuit-epic-orchestra-loop
- Basil, *Prepare to Fight*, CC0 1.0; https://opengameart.org/content/prepare-to-fight
- Bobjt, *Our Expanse*, CC0 1.0; https://opengameart.org/content/our-expanse
- skrjablin, *The Final Battle*, CC0 1.0 / public domain; https://opengameart.org/content/the-final-battle
- TinyWorlds, *Space Graveyard - Ambient Track*, CC0; https://opengameart.org/content/space-graveyard-ambient-track. Wanderpakt-Ruhe B Kandidat im Runtime-Katalog (`assets/audio/music/wanderpakt/calm_b.ogg`), noch nicht hörfreigegeben.
- Some Weirdo, *Noisy Battle*, CC0; https://opengameart.org/content/noisy-battle. 180-Sekunden-OGG-Alternative für Prisma-Gefechtsmusik (`assets/audio/music/prisma/battle_high_noisy.ogg`); Runtime-Integration ist ein unfreigegebener Kandidat und bleibt bis zum Hörtest `pending`.
- Tarush Singhal, *Epic Fight Theme/Boss Battle*, CC0; https://opengameart.org/content/epic-fight-themeboss-battle. Ungeprüfter Wanderpakt-Kandidat für intensive Gefechte.
- cynicmusic / pixelsphere, *Battle Theme A*, CC0; https://opengameart.org/content/battle-theme-a. Ungeprüfter Kobalt-Kandidat für intensive Gefechte.
- MintoDog, *Space Battle*, CC0 1.0; https://opengameart.org/content/space-battle. Prisma-Kandidat für intensive Gefechte; 44.1 kHz stereo OGG wurde nach 48 kHz stereo Vorbis konvertiert, Originalschleifenlänge erhalten.
- Leonardo Paz (leohpaz), *Outer Space Music Pack*, CC-BY 4.0; https://opengameart.org/content/outer-space-music-pack. Das Kampf-Intro und der dazugehörige Loop werden ausschließlich als Hörvergleich im lokalen Abnahmeboard bereitgestellt, noch nicht im Runtime-Spiel verwendet. Attribution bei späterer Runtime-Übernahme: „Outer Space Music Pack“ von Leonardo Paz (leohpaz), CC BY 4.0, OpenGameArt.org.
- rubberduck, *60 CC0 Sci-Fi SFX*, CC0 1.0; https://opengameart.org/content/60-cc0-sci-fi-sfx. Downloaded for review; not yet selected for runtime.
  - bart, *Steam boiler sound loop*, CC0; https://opengameart.org/content/steam-boiler-sound-loop. Converted to a low-level refinery ambience runtime candidate; remains pending in-game listening approval.
- Fupi, *Long Sci-fi Sting*, CC0; https://opengameart.org/content/long-sci-fi-sting. Local audition candidate only; not yet assigned to a runtime event.
- qubodup, *(defect) motor loop*, CC0; https://opengameart.org/content/defect-motor-loop. Source describes a graphics-card fan; retained in the local candidate record but excluded from runtime pending a suitability review.
- pauliuw, *Engine sounds(2)*, CC0; https://opengameart.org/content/engine-sounds2. Two source MP3s are included only on the local listening board as vehicle-engine comparisons; neither is assigned to runtime playback.
- Thorsten-Voice emotional Piper-Modell und Sprechdatenbank, CC0 1.0; https://huggingface.co/rhasspy/piper-voices/tree/v1.0.0/de/de_DE/thorsten_emotional/medium. Nur die generierten Sprachclips werden ausgeliefert; das Inferenzmodell bleibt außerhalb des Spielpakets.
- Multilingual LibriSpeech (MLS) Deutsch, OpenSLR SLR94, CC BY 4.0; https://www.openslr.org/94/. Das fest gepinnte Piper-Mehrsprechermodell wird nur für sechs lokale Hörvergleichsclips verwendet; diese sind nicht im Runtime-Katalog. Bei späterer Übernahme müssen OpenSLR/MLS und die Modellkarte in den Spielcredits genannt werden.

Die Musiktitel sind kuratierte und bearbeitete CC0-Aufnahmen, keine neu komponierte Originalmusik. Die Sprachclips sind neuronale deutsche TTS-Stimmen, keine Studioaufnahmen. Alle Audioeinträge bleiben bis zur Abnahme als `candidate` markiert. Die Renderwerkzeuge verwenden FFmpeg und libvorbis während der Asset-Erzeugung, werden jedoch nicht in den Windows-Spielbuild eingebettet.

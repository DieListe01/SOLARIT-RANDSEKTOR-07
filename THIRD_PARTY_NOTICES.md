# Engine und eingebettete Bibliotheken

SOLARIT: RANDSEKTOR 07 verwendet Godot Engine 4.7.2 stable. Copyright (c) 2014-present Godot Engine contributors. Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur. Godot steht unter der MIT-Lizenz; der folgende Text gilt für die Engine:

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Godot enthält weitere Bibliotheken und die Standardschrift. Deren Copyright- und Lizenztexte werden von Godot selbst eingebettet und sind außerdem in der versionsbezogenen [COPYRIGHT-Datei](https://github.com/godotengine/godot/blob/4.7.2-stable/COPYRIGHT.txt) dokumentiert.

## Audio-Kandidaten

Die folgenden lizenzierten Quellen sind für den internen Audio-Abnahmestand verarbeitet. Sie sind technisch in das Spiel eingebunden, aber noch nicht als finale Audioqualität freigegeben:

- Kenney, *Sci-Fi Sounds*, CC0 1.0. Lizenzkopie im Projekt unter `assets/audio/licenses/Kenney-SciFiSounds-LICENSE.txt`; https://kenney.nl/assets/sci-fi-sounds
- SRG774, *Dark Sci-Fi Audio Pack*, CC0 1.0; https://opengameart.org/content/dark-sci-fi-audio-pack
- Alexander Ehlers / tricksntraps, *T&T Free Cyberpunk Pack 2*, CC0 1.0; https://opengameart.org/content/t-t-free-cyberpunk-pack-2
- vitalezzz, *Inevitable*, CC0 1.0; https://opengameart.org/content/inevitable
- Emma_MA, *Determined Pursuit*, CC0 / Public Domain; https://opengameart.org/content/determined-pursuit-epic-orchestra-loop
- Basil, *Prepare to Fight*, CC0 1.0; https://opengameart.org/content/prepare-to-fight
- Bobjt, *Our Expanse*, CC0 1.0; https://opengameart.org/content/our-expanse
- skrjablin, *The Final Battle*, CC0 1.0 / public domain; https://opengameart.org/content/the-final-battle
- rubberduck, *60 CC0 Sci-Fi SFX*, CC0 1.0; https://opengameart.org/content/60-cc0-sci-fi-sfx. Downloaded for review; not yet selected for runtime.
- Thorsten-Voice emotional Piper-Modell und Sprechdatenbank, CC0 1.0; https://huggingface.co/rhasspy/piper-voices/tree/v1.0.0/de/de_DE/thorsten_emotional/medium. Nur die generierten Sprachclips werden ausgeliefert; das Inferenzmodell bleibt außerhalb des Spielpakets.

Die Musiktitel sind kuratierte und bearbeitete CC0-Aufnahmen, keine neu komponierte Originalmusik. Die Sprachclips sind neuronale deutsche TTS-Stimmen, keine Studioaufnahmen. Alle Audioeinträge bleiben bis zur Abnahme als `candidate` markiert. Die Renderwerkzeuge verwenden FFmpeg und libvorbis während der Asset-Erzeugung, werden jedoch nicht in den Windows-Spielbuild eingebettet.

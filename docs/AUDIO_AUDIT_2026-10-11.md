# SOLARIT Audio-Bestandsaufnahme (2026-10-11)

Quelle: aktueller Projektstand plus `tools/generate_*.py`; alle `assets/audio/*.wav` wurden direkt aus den WAV-Headern/Samples gelesen. Peak und RMS sind linear aus PCM berechnet; LUFS ist hier nicht behauptet. Loop-Punkt im Runtime-Code ist jeweils Dateiende (vollständige Dateilänge), sofern nicht anders eingetragen.

## Musikdateien

| Datei | Fraktion/Zustand | Länge | Format | Peak | RMS | Start/End-Differenz | SHA-256 (12) |
|---|---|---:|---|---:|---:|---:|---|
| `drift_alarm.wav` | drift / alarm | 24.00s | PCM16 22050 Hz, 1ch | 0.780 | 0.166 | 0.000 | `5dd65da3392a` |
| `drift_battle.wav` | drift / battle | 24.00s | PCM16 22050 Hz, 1ch | 0.780 | 0.137 | 0.000 | `4e7c19cbfbff` |
| `drift_calm.wav` | drift / calm | 24.00s | PCM16 22050 Hz, 1ch | 0.780 | 0.151 | 0.000 | `0c60bd557800` |
| `drift_contact.wav` | drift / contact | 24.00s | PCM16 22050 Hz, 1ch | 0.780 | 0.183 | 0.000 | `de57a52b48e0` |
| `first_signal.wav` | first / signal | 24.00s | PCM16 22050 Hz, 1ch | 0.780 | 0.147 | 0.000 | `e7c55b1eadcd` |
| `forge_alarm.wav` | forge / alarm | 24.00s | PCM16 22050 Hz, 1ch | 0.780 | 0.172 | 0.000 | `c62091639ec7` |
| `forge_battle.wav` | forge / battle | 24.00s | PCM16 22050 Hz, 1ch | 0.780 | 0.135 | 0.000 | `d87c8a1160b0` |
| `forge_calm.wav` | forge / calm | 24.00s | PCM16 22050 Hz, 1ch | 0.780 | 0.159 | 0.000 | `a54e6359db8c` |
| `forge_contact.wav` | forge / contact | 24.00s | PCM16 22050 Hz, 1ch | 0.780 | 0.150 | 0.000 | `5d6d344e77aa` |
| `lumen_alarm.wav` | lumen / alarm | 24.00s | PCM16 22050 Hz, 1ch | 0.780 | 0.167 | 0.000 | `45fc83341ef6` |
| `lumen_battle.wav` | lumen / battle | 24.00s | PCM16 22050 Hz, 1ch | 0.780 | 0.139 | 0.000 | `f80d602bbe14` |
| `lumen_calm.wav` | lumen / calm | 24.00s | PCM16 22050 Hz, 1ch | 0.780 | 0.146 | 0.000 | `8fc5d4b189c0` |
| `lumen_contact.wav` | lumen / contact | 24.00s | PCM16 22050 Hz, 1ch | 0.780 | 0.183 | 0.000 | `50fe8204f1b5` |

### Fraktionsähnlichkeit (gemittelte FFT-Magnitude, 128 Bins)

Cosine-Ähnlichkeit der vier 2-s Spektralfenster: 0 = verschieden, 1 = sehr ähnlich. Das ist ein automatischer Hinweis, kein Hörurteil.
- **calm**: forge_calm–drift_calm 0.348, forge_calm–lumen_calm 0.433, drift_calm–lumen_calm 0.776
- **contact**: forge_contact–drift_contact 0.850, forge_contact–lumen_contact 0.743, drift_contact–lumen_contact 0.898
- **battle**: forge_battle–drift_battle 0.995, forge_battle–lumen_battle 0.997, drift_battle–lumen_battle 0.995
- **alarm**: forge_alarm–drift_alarm 0.915, forge_alarm–lumen_alarm 0.814, drift_alarm–lumen_alarm 0.853

## Gesamter WAV-Inventar

Alle hier gelisteten SFX sind aktuell vorhandene Dateien. Zuordnung zur konkreten Spielereignisstelle muss anhand `scripts/main.gd` und `CombatEffects` erfolgen; Namen allein sind kein Beleg für Laufzeitnutzung.

| Datei | Länge | Format | Peak | RMS | Endpunkt-Diff | SHA-256 (12) |
|---|---:|---|---:|---:|---:|---|
| `alarm.wav` | 0.495s | PCM16 22050 Hz, 1ch | 0.265 | 0.076 | 0.000 | `06779b0b967a` |
| `artillery_impact.wav` | 1.100s | PCM16 44100 Hz, 2ch | 0.820 | 0.134 | 0.000 | `25756a4c5e6e` |
| `artillery_impact_v1.wav` | 1.100s | PCM16 44100 Hz, 2ch | 0.820 | 0.140 | 0.000 | `e8fb8321bc5b` |
| `artillery_impact_v2.wav` | 1.100s | PCM16 44100 Hz, 2ch | 0.820 | 0.132 | 0.000 | `9a3708892744` |
| `artillery_shot.wav` | 0.800s | PCM16 44100 Hz, 2ch | 0.820 | 0.153 | 0.000 | `b8c8374112b5` |
| `artillery_shot_v1.wav` | 0.800s | PCM16 44100 Hz, 2ch | 0.820 | 0.157 | 0.000 | `8ebcd7b7acf6` |
| `artillery_shot_v2.wav` | 0.800s | PCM16 44100 Hz, 2ch | 0.820 | 0.161 | 0.000 | `fc30f90a0c91` |
| `autocannon_impact.wav` | 0.720s | PCM16 44100 Hz, 2ch | 0.820 | 0.099 | 0.000 | `bcb1a1e78c13` |
| `autocannon_impact_v1.wav` | 0.720s | PCM16 44100 Hz, 2ch | 0.820 | 0.117 | 0.000 | `121a03b0dd82` |
| `autocannon_impact_v2.wav` | 0.720s | PCM16 44100 Hz, 2ch | 0.820 | 0.108 | 0.000 | `d5a815deef9c` |
| `autocannon_shot.wav` | 0.420s | PCM16 44100 Hz, 2ch | 0.818 | 0.133 | 0.000 | `c34fac834266` |
| `autocannon_shot_v1.wav` | 0.420s | PCM16 44100 Hz, 2ch | 0.820 | 0.140 | 0.000 | `c568945ce2bc` |
| `autocannon_shot_v2.wav` | 0.420s | PCM16 44100 Hz, 2ch | 0.806 | 0.145 | 0.000 | `56beec50f420` |
| `ballistic_heavy_impact.wav` | 1.100s | PCM16 44100 Hz, 2ch | 0.820 | 0.142 | 0.000 | `efd11913eb36` |
| `ballistic_heavy_impact_v1.wav` | 1.100s | PCM16 44100 Hz, 2ch | 0.820 | 0.152 | 0.000 | `5c9a2703118f` |
| `ballistic_heavy_impact_v2.wav` | 1.100s | PCM16 44100 Hz, 2ch | 0.820 | 0.138 | 0.000 | `512ac784cfe0` |
| `ballistic_heavy_shot.wav` | 0.800s | PCM16 44100 Hz, 2ch | 0.820 | 0.156 | 0.000 | `2fae3eca7eaf` |
| `ballistic_heavy_shot_v1.wav` | 0.800s | PCM16 44100 Hz, 2ch | 0.820 | 0.165 | 0.000 | `3f82c4ea72ba` |
| `ballistic_heavy_shot_v2.wav` | 0.800s | PCM16 44100 Hz, 2ch | 0.809 | 0.164 | 0.000 | `be3dd4ad1e04` |
| `ballistic_light_impact.wav` | 0.720s | PCM16 44100 Hz, 2ch | 0.811 | 0.105 | 0.000 | `6c4e3861e136` |
| `ballistic_light_impact_v1.wav` | 0.720s | PCM16 44100 Hz, 2ch | 0.820 | 0.113 | 0.000 | `0d58f818d0cb` |
| `ballistic_light_impact_v2.wav` | 0.720s | PCM16 44100 Hz, 2ch | 0.820 | 0.105 | 0.000 | `2e779b03d91a` |
| `ballistic_light_shot.wav` | 0.420s | PCM16 44100 Hz, 2ch | 0.820 | 0.139 | 0.000 | `c5c0a7991057` |
| `ballistic_light_shot_v1.wav` | 0.420s | PCM16 44100 Hz, 2ch | 0.820 | 0.139 | 0.000 | `b4aabbbb1d33` |
| `ballistic_light_shot_v2.wav` | 0.420s | PCM16 44100 Hz, 2ch | 0.790 | 0.140 | 0.000 | `380db68ecba6` |
| `build.wav` | 0.550s | PCM16 44100 Hz, 2ch | 0.398 | 0.052 | 0.000 | `9da0c7ca805a` |
| `cannon_shot.wav` | 0.450s | PCM16 22050 Hz, 1ch | 0.746 | 0.123 | 0.212 | `184fb39a5a75` |
| `complete.wav` | 0.650s | PCM16 44100 Hz, 2ch | 0.369 | 0.045 | 0.000 | `43fb16d4139e` |
| `core_impact.wav` | 1.650s | PCM16 44100 Hz, 2ch | 0.820 | 0.102 | 0.000 | `4d4e95eae68c` |
| `core_impact_v1.wav` | 1.650s | PCM16 44100 Hz, 2ch | 0.820 | 0.113 | 0.000 | `f6c82aa03f45` |
| `core_impact_v2.wav` | 1.650s | PCM16 44100 Hz, 2ch | 0.820 | 0.117 | 0.000 | `fb01f88c7506` |
| `core_shot.wav` | 1.350s | PCM16 44100 Hz, 2ch | 0.820 | 0.123 | 0.000 | `a0d5ab622b01` |
| `core_shot_v1.wav` | 1.350s | PCM16 44100 Hz, 2ch | 0.820 | 0.119 | 0.000 | `5cdd572af3dd` |
| `core_shot_v2.wav` | 1.350s | PCM16 44100 Hz, 2ch | 0.820 | 0.121 | 0.000 | `4dcba0d859aa` |
| `defeat.wav` | 1.260s | PCM16 22050 Hz, 1ch | 0.161 | 0.056 | 0.000 | `c6e670992f3a` |
| `energy_impact.wav` | 0.720s | PCM16 44100 Hz, 2ch | 0.705 | 0.093 | 0.000 | `3459aa6a64d9` |
| `energy_impact_v1.wav` | 0.720s | PCM16 44100 Hz, 2ch | 0.665 | 0.096 | 0.000 | `103321ed31ba` |
| `energy_impact_v2.wav` | 0.720s | PCM16 44100 Hz, 2ch | 0.720 | 0.090 | 0.000 | `601d5c817ca9` |
| `energy_shot.wav` | 0.420s | PCM16 44100 Hz, 2ch | 0.695 | 0.121 | 0.000 | `f3c580ac00be` |
| `energy_shot_v1.wav` | 0.420s | PCM16 44100 Hz, 2ch | 0.673 | 0.125 | 0.000 | `ceb2f9c15fa0` |
| `energy_shot_v2.wav` | 0.420s | PCM16 44100 Hz, 2ch | 0.712 | 0.117 | 0.000 | `67566913ac75` |
| `engine.wav` | 2.000s | PCM16 22050 Hz, 1ch | 0.363 | 0.169 | 0.040 | `f56767e70538` |
| `error.wav` | 0.430s | PCM16 22050 Hz, 1ch | 0.194 | 0.066 | 0.000 | `5be6905302ed` |
| `explosion.wav` | 1.100s | PCM16 44100 Hz, 2ch | 0.820 | 0.138 | 0.000 | `512ac784cfe0` |
| `impact.wav` | 0.350s | PCM16 22050 Hz, 1ch | 0.687 | 0.090 | 0.405 | `dfac25c54aad` |
| `missile_impact.wav` | 0.720s | PCM16 44100 Hz, 2ch | 0.820 | 0.115 | 0.000 | `33b965d9113c` |
| `missile_impact_v1.wav` | 0.720s | PCM16 44100 Hz, 2ch | 0.820 | 0.113 | 0.000 | `8d4e11e59d34` |
| `missile_impact_v2.wav` | 0.720s | PCM16 44100 Hz, 2ch | 0.820 | 0.113 | 0.000 | `0e31793d811e` |
| `missile_shot.wav` | 0.420s | PCM16 44100 Hz, 2ch | 0.820 | 0.146 | 0.000 | `90c13b8b45ae` |
| `missile_shot_v1.wav` | 0.420s | PCM16 44100 Hz, 2ch | 0.813 | 0.156 | 0.000 | `34e2c14f6c76` |
| `missile_shot_v2.wav` | 0.420s | PCM16 44100 Hz, 2ch | 0.820 | 0.142 | 0.000 | `9217543dbc63` |
| `move.wav` | 0.430s | PCM16 22050 Hz, 1ch | 0.256 | 0.067 | 0.000 | `84ab21343757` |
| `pulse_shot.wav` | 0.220s | PCM16 22050 Hz, 1ch | 0.510 | 0.107 | 0.028 | `437df28e85f5` |
| `ready.wav` | 0.400s | PCM16 44100 Hz, 2ch | 0.413 | 0.060 | 0.000 | `6741ae31dc9d` |
| `repair.wav` | 0.320s | PCM16 44100 Hz, 2ch | 0.308 | 0.064 | 0.000 | `5d7f3f5451dd` |
| `rotate.wav` | 0.220s | PCM16 44100 Hz, 2ch | 0.308 | 0.077 | 0.000 | `5bff205c6273` |
| `save.wav` | 0.495s | PCM16 22050 Hz, 1ch | 0.321 | 0.082 | 0.000 | `162d90e090f4` |
| `select.wav` | 0.430s | PCM16 22050 Hz, 1ch | 0.231 | 0.067 | 0.000 | `c5a334d01696` |
| `shot.wav` | 0.120s | PCM16 22050 Hz, 1ch | 0.624 | 0.098 | 0.084 | `72c5142d67d0` |
| `siege_impact.wav` | 1.100s | PCM16 44100 Hz, 2ch | 0.820 | 0.138 | 0.000 | `a5f9bcd8c683` |
| `siege_impact_v1.wav` | 1.100s | PCM16 44100 Hz, 2ch | 0.820 | 0.139 | 0.000 | `48a16168f949` |
| `siege_impact_v2.wav` | 1.100s | PCM16 44100 Hz, 2ch | 0.820 | 0.145 | 0.000 | `1d19441303c6` |
| `siege_shot.wav` | 0.800s | PCM16 44100 Hz, 2ch | 0.820 | 0.160 | 0.000 | `6c91ab0da4d5` |
| `siege_shot_v1.wav` | 0.800s | PCM16 44100 Hz, 2ch | 0.820 | 0.164 | 0.000 | `b6019eb424e4` |
| `siege_shot_v2.wav` | 0.800s | PCM16 44100 Hz, 2ch | 0.820 | 0.158 | 0.000 | `40f2646742b7` |
| `special_impact.wav` | 0.720s | PCM16 44100 Hz, 2ch | 0.686 | 0.093 | 0.000 | `08161defb0ec` |
| `special_impact_v1.wav` | 0.720s | PCM16 44100 Hz, 2ch | 0.662 | 0.096 | 0.000 | `860e1a24c2d0` |
| `special_impact_v2.wav` | 0.720s | PCM16 44100 Hz, 2ch | 0.683 | 0.090 | 0.000 | `e3b03f0e7e7b` |
| `special_shot.wav` | 0.420s | PCM16 44100 Hz, 2ch | 0.712 | 0.121 | 0.000 | `b35381eead79` |
| `special_shot_v1.wav` | 0.420s | PCM16 44100 Hz, 2ch | 0.661 | 0.125 | 0.000 | `90930206b749` |
| `special_shot_v2.wav` | 0.420s | PCM16 44100 Hz, 2ch | 0.655 | 0.117 | 0.000 | `41bae983b79d` |
| `victory.wav` | 1.740s | PCM16 22050 Hz, 1ch | 0.167 | 0.058 | 0.000 | `73da37a9a6e7` |

## Befunde und Grenzen

- Die zwölf Fraktions-/Zustandsdateien sowie `first_signal.wav` sind **24.00 s, 22,050 Hz, mono PCM16**; der Titelgenerator `tools/generate_frontend_audio.py` schreibt dagegen 32 s, 22,050 Hz, mono und der gegenwärtige `tools/generate_audio.py` schreibt 16 s, 22,050 Hz, mono. Damit reproduzieren die im Repository liegenden Generatoren die eingecheckten Musikdateien nicht in Länge/Format; die Asset-Pipeline ist inkonsistent.
- Die vier Zustandsdateien jeder Fraktion sind unabhängig erzeugte, gleich lange Vollmischungen, keine klar separierten, aufeinander abgestimmten Musikstems. Das aktuelle gleichzeitige Auf-/Abblenden kann deshalb konkurrierende Patterns überlagern.
- Der Loop-Punkt ist hart am Dateiende. Die automatischen Messungen dokumentieren den sampleweisen Endpunkt-Abstand, ersetzen aber keinen hörbaren Loop-Test und erkennen keine musikalische/harmonische Naht zuverlässig.
- Alle analysierten Musikdateien sind mono; Stereo-Raumbewegung und echte Stereo-Breite fehlen. Dateipeak/RMS sind messbar, LUFS erfordert ein geeignetes Loudness-Messverfahren.
- Spectral cosine misst nur grobe, gemittelte Energieverteilung. Ähnlichkeit/Originalität und Dramaturgie erfordern zusätzlich Hörabnahme.
- Keine lizenzierten Fremdquellen in der erfassten Pipeline ersichtlich; Generatoren erklären die Klänge als intern synthetisiert. Das ist keine vollständige rechtliche Prüfung jeder Datei.

## Neue Demo-/Referenzassets (2026-10-11)

Alle neuen OGGs wurden aus den Quelldaten via FFmpeg decodiert und gemessen. Peak/RMS unten beziehen sich auf ein Diagnose-Decoding auf 11.025-Hz-Mono, nicht auf die Original-Stereo-Loudness. Keine LUFS-Angabe ohne geeichtes Loudness-Verfahren.

| Datei | Länge | Codec / Originalrate / Kanäle | Peak | RMS | Größe |
|---|---:|---|---:|---:|---:|
| `music\drift_alarm_demo.ogg` | 108.90s | vorbis, 48000 Hz, 2ch | 0.220 | 0.043 | 2937 KiB |
| `music\drift_battle_demo.ogg` | 108.90s | vorbis, 48000 Hz, 2ch | 0.660 | 0.131 | 1922 KiB |
| `music\drift_calm_demo.ogg` | 108.90s | vorbis, 48000 Hz, 2ch | 0.573 | 0.103 | 1974 KiB |
| `music\drift_contact_demo.ogg` | 108.90s | vorbis, 48000 Hz, 2ch | 0.536 | 0.069 | 2525 KiB |
| `music\first_signal_demo.ogg` | 160.00s | vorbis, 48000 Hz, 2ch | 0.833 | 0.116 | 3119 KiB |
| `music\forge_alarm_demo.ogg` | 106.70s | vorbis, 48000 Hz, 2ch | 0.301 | 0.054 | 2632 KiB |
| `music\forge_battle_demo.ogg` | 106.70s | vorbis, 48000 Hz, 2ch | 0.694 | 0.152 | 1421 KiB |
| `music\forge_calm_demo.ogg` | 106.70s | vorbis, 48000 Hz, 2ch | 0.669 | 0.109 | 2151 KiB |
| `music\forge_contact_demo.ogg` | 106.70s | vorbis, 48000 Hz, 2ch | 0.298 | 0.043 | 1116 KiB |
| `music\lumen_alarm_demo.ogg` | 150.00s | vorbis, 48000 Hz, 2ch | 0.103 | 0.016 | 3561 KiB |
| `music\lumen_battle_demo.ogg` | 150.00s | vorbis, 48000 Hz, 2ch | 0.765 | 0.116 | 1461 KiB |
| `music\lumen_calm_demo.ogg` | 150.00s | vorbis, 48000 Hz, 2ch | 0.553 | 0.076 | 2755 KiB |
| `music\lumen_contact_demo.ogg` | 150.00s | vorbis, 48000 Hz, 2ch | 0.276 | 0.033 | 1537 KiB |
| `sfx\harvest_collect_demo.ogg` | 1.15s | vorbis, 48000 Hz, 2ch | 0.342 | 0.097 | 35 KiB |
| `sfx\harvest_start_demo.ogg` | 0.90s | vorbis, 48000 Hz, 2ch | 0.553 | 0.159 | 23 KiB |
| `sfx\harvest_unload_demo.ogg` | 1.65s | vorbis, 48000 Hz, 2ch | 0.423 | 0.109 | 46 KiB |
| `sfx\harvester_work_demo.ogg` | 3.84s | vorbis, 48000 Hz, 2ch | 0.433 | 0.144 | 68 KiB |

### Spektralvergleich Battle

- `forge_battle_demo` / `drift_battle_demo`: 0.675
- `forge_battle_demo` / `lumen_battle_demo`: 0.496
- `drift_battle_demo` / `lumen_battle_demo`: 0.584

Die 13 Musik-OGGs sind auf 48 kHz Stereo begrenzt und enthalten je Fraktion vier taktgleiche, einzeln regelbare Referenz-Layer; je Loop umfasst 48 oder 56 Takte. First Signal ist 160 Sekunden. Die vier Harvester-Sounds sind eigenständige 48-kHz-Stereo-Referenzdateien; der Arbeitsklang looped nach 3,84 Sekunden.

Alle neuen Tracks und Sampler sind **Demo-/Referenzmaterial bis zur menschlichen Hörabnahme**. Automatische Messungen belegen Dauer, Format, Sample-Peak/RMS und grobe spektrale Unterschiede, aber weder musikalische Qualität noch Müdungsfreiheit nach 20 Minuten.

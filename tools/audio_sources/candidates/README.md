# CC0-Musikquellen für Runtime-Kandidaten und Hörvergleich

`space_graveyard.mp3` is now used for Wanderpakt's `calm_b` runtime slot after conversion from the full seamless source loop. It remains a `candidate` with human listening approval `pending`. `noisy_battle.ogg` remains only an audition alternative and is not assigned to a runtime slot. Listen to both before release use.

| Titel | Autor | Quelle | Lizenz | Format / Länge | SHA-256 |
|---|---|---|---|---|---|
| Space Graveyard - Ambient Track | TinyWorlds | https://opengameart.org/content/space-graveyard-ambient-track | CC0 | MP3, 44.1 kHz mono, 312.726 s | `21af1b4854e6ce4330a0fad51e4b68227b37182be4b4beede70f9906991d2c60` |
| Noisy Battle | Some Weirdo | https://opengameart.org/content/noisy-battle | CC0 | OGG Vorbis, 44.1 kHz stereo, 99.997 s | `d09d84341fc6de6051a574c84e06495946575dea883505ab56f33d23abf10823` |

The OpenGameArt pages label both works CC0. They permit commercial use and modification without required attribution. Credits are retained here for provenance. *Noisy Battle* is also now mastered into a Prisma high-battle runtime alternative; the processed game asset remains `candidate` and `pending` listening review.

## Additional sound-effect auditions — 2026-10-14

These downloads are not assigned to runtime events. Their OpenGameArt entries identify them as CC0; they were downloaded solely for the local listening board. The source `fan_interval.wav` is described by its author as a graphics-card fan recording, so it is excluded from game use unless a later sound review finds a suitable transformation.

| Title | Author | Source | License | Source format / duration | SHA-256 | Status |
|---|---|---|---|---|---|---|
| Steam boiler sound loop (`generator_loop.wav`) | bart | https://opengameart.org/content/steam-boiler-sound-loop | CC0 | WAV, 44.1 kHz stereo, 22.154 s | `64b174cf8ef71e7f71aa03cf29864ab489f7be1f624456cab916043da38911bd` | converted as refinery ambience runtime candidate; pending in-game listening review |
| Long Sci-fi Sting (`longscifisting_2.ogg`) | Fupi | https://opengameart.org/content/long-sci-fi-sting | CC0 | OGG Vorbis, 44.1 kHz stereo, 12.0 s | `aef9c2134d5f0106e28b09fa850f4e56eb92907611bd79e1ee8bbbe2abb5fe31` | audition only; alert/intro sting candidate |
| (defect) motor loop (`fan_interval.wav`) | qubodup | https://opengameart.org/content/defect-motor-loop | CC0 | WAV, 44.1 kHz stereo, 3.011 s | `4c0287ffdad82a7001403c82ab77e2a04475fb30c9919938b311f644f429c531` | excluded from runtime; author identifies source as a graphics-card fan |

The steam-boiler source is now also prepared as `assets/audio/sfx/industrial/refinery_ambience.ogg`. Its build master is a 48 kHz, 24-bit stereo WAV normalized by FFmpeg `loudnorm=I=-28:LRA=8:TP=-9`, then encoded as 48 kHz stereo Vorbis quality 6. Runtime SHA-256: `905837bc0f5857374efbb9d1e29f996850c86c789ab6935c1c8733167d3e0dc3`. It fades in only when the player's completed refinery is active and fades out when none remain. This is a low-level ambience candidate, not an approved final sound; its CC0 source is verified but its in-game suitability still needs listening approval.

FFprobe confirmed source codecs, rates, channel counts, and durations. No loudness normalization, looping, or game integration has been applied to these three samples. Listening approval remains pending.

## Vehicle-engine sound comparison — 2026-10-15

pauliuw's *Engine sounds(2)* page labels both recordings CC0. The MP3 source files are retained unmodified for listening comparison only; neither is wired to runtime playback. FFprobe reports 48 kHz stereo MP3, 20.712 seconds each. Source URL: https://opengameart.org/content/engine-sounds2.

| File | SHA-256 | Status |
|---|---|---|
| `engine_sound.mp3` | `6ac9e73a6e4d0ec2a7d70f1f2c833622f60c60f517488600b070708b2b4c2396` | listening candidate only |
| `engine_sound_1.mp3` | `44d3023e98918de97436712c42383a7c8430fd49b54c50eb80a53a05ad054044` | listening candidate only |

The listening board labels both as CC0, gives their source link, and keeps them separate from the approved/runtime SFX catalogue.

## Additional orchestral comparison — 2026-10-14

Leonardo Paz (leohpaz)'s *Outer Space Music Pack* includes a separate battle intro and loop. OpenGameArt lists CC-BY 4.0 and CC-BY 3.0 and requests credit; this project records the comparison under CC-BY 4.0 with the required author/title/source attribution. Both untouched OGG source files are only copied into the local listening board and are not assigned to a runtime slot until reviewed.

| File | Duration | Format | SHA-256 |
|---|---:|---|---|
| `06_battle_in_space_intro.ogg` | 44.769 s | Vorbis, 44.1 kHz stereo | `9c11426e10816c4bdb3361a4d2f09353951946999420e5ba69f2d27714658ac2` |
| `06_battle_in_space_loop.ogg` | 44.769 s | Vorbis, 44.1 kHz stereo | `38a5099a8d31a1eb21f134562e162034a68785b414a06d0fcea45dc4a5645e9f` |

Source page: https://opengameart.org/content/outer-space-music-pack. Attribution if later integrated: “Outer Space Music Pack” by Leonardo Paz (leohpaz), CC BY 4.0, OpenGameArt.org. These are comparison candidates, not approved audio.

# SOLARIT audio production status — 2026-10-13

## Decision

The current music is not approved as final. The project catalog marks the title theme and all faction/state tracks as `asset_status: placeholder`, with `human_listening_approval: pending`; the catalog itself declares `production_status: placeholder_not_final`. The files use `_demo.ogg` names. No track is being promoted by this update.

## Available tools and realistic quality

FFmpeg and FFprobe are installed for technical inspection, loudness measurement, conversion, and validation. Music Maker Premium 2023 is installed, but the requested production does not have to use it. The verified alternative is Voltage Modular as a standalone instrument/sequencer and SOUND FORGE Audio Studio for recording and editing; no separate multitrack DAW has been verified. Cherry Audio documents standalone operation and sequencer modules for Voltage Modular, so original patches and sequences can be captured without Music Maker. The commercial-use status of installed plugin modules, Soundpool loops, and bundled samples has not been established; do not ship any such material unless its license is verified. No licensed field-recording collection or mastered production stems have been verified. FFmpeg filters and generated oscillators would not satisfy the requested sound-design standard, so they are not being used to manufacture replacement music.

A read-only registry inventory found the Windows OneCore voices `de-DE-Hedda`, `de-DE-Katja`, and `de-DE-Stefan` installed, even though the legacy SAPI voice enumerator exposed only `en-US-Zira` in this environment. This establishes that German system voices exist locally, but neither their naturalness for faction barks nor the rights to redistribute generated audio have been verified. They can be privately auditioned as production references; no TTS recordings are included or marked approved.

The current OGG files are 48 kHz stereo and have loop lengths between about 106 and 160 seconds. An FFmpeg EBU R128 pass on 2026-10-13 measured integrated loudness from −19.9 to −18.1 LUFS, loudness range from 2.5 to 9.8 LU, and true peak from −9.2 to −1.7 dBFS. The six battle/alarm arrangements are at 2.5–4.7 LU LRA. This confirms consistent technical encoding and relatively narrow loudness movement in those cues; it does not by itself prove a musical quality defect or replace listening approval. Existing `first_signal.wav` is a legacy asset; the live catalog points to `first_signal_demo.ogg`.

## Existing runtime preparation

`assets/audio/music_catalog.json` already provides per-faction calm, contact, battle, and alarm choices, tempo/meter and loop metadata, weights, and transition bars. `scripts/music_director.gd` loads full-mix arrangements, synchronizes their playback, and crossfades tactical states at bar boundaries. The menu has its own title stream. This is sufficient to replace the placeholder files in-place without replacing the Godot audio architecture.

The current music files still provide only complete demo mixes. The runtime now accepts an optional faction-level `adaptive_stems` set with synchronized `atmosphere`, `pulse`, `bass`, `rhythm`, `percussion`, `motif`, `combat`, and `critical` layers. It fades those layers against combat intensity and state, and falls back to the existing full-mix catalog if a set is incomplete. No actual stem files are present in the catalog, so this infrastructure produces no new audible music by itself. Each faction/state currently still has one demo, and the five requested intensity levels are not yet represented by approved compositions.

## Production needed before approval

Create or commission original, commercially usable sessions without depending on Music Maker and export at least the requested title, calm, and battle comparisons for all three factions. The available route is to author complex patches and sequences in Voltage Modular, record and edit in SOUND FORGE Audio Studio, and use only self-authored or license-verified material. Kobalt needs heavy industrial percussion and moving mechanical bass; Wanderpakt needs rougher broken patterns and aggressive motion; Prisma needs complex spectral/granular timbres with a deep rhythmic foundation. Avoid imitating named soundtracks. Record source and license details in `THIRD_PARTY_NOTICES` when external material is used.

After import, verify clipping and integrated loudness technically, then listen to each track at 30 seconds, after five minutes, and in a real match. Only after those listening checks should catalog entries change to an approved production state. Until then, keep the demo filenames, placeholder status, and pending approvals. No claim of completed high-quality music is justified by this update.

## Scope of this update

This update prepares the runtime for authored music stems and records the production constraints; it does not replace the music, add voice samples, or complete the broader graphics/audio brief. The alternative toolchain above is available without Music Maker, but no production sessions, approved music, or recorded voice samples have been created yet.

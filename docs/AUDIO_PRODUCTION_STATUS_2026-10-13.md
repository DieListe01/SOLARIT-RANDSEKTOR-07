# SOLARIT audio production status — 2026-10-13

## Decision

The current music is not approved as final. The project catalog marks the title theme and all faction/state tracks as `asset_status: placeholder`, with `human_listening_approval: pending`; the catalog itself declares `production_status: placeholder_not_final`. The files use `_demo.ogg` names. No track is being promoted by this update.

## Available tools and realistic quality

FFmpeg and FFprobe are installed. They support encoding, technical inspection, loudness measurement, format conversion, and asset validation, but they are not music composition, sound-design, or multitrack production tools. The project runtime is Godot. No DAW, sampler library, licensed field-recording collection, or mastered production stems were found in the checked local installation paths. FFmpeg filters and generated oscillators would not satisfy the requested sound-design standard, so they are not being used to manufacture replacement music.

The current OGG files are 48 kHz stereo and have loop lengths between about 106 and 160 seconds. Those format and duration values say nothing about musical quality, arrangement, clipping, loudness, or whether the cues pass the required listening checks. Existing `first_signal.wav` is a legacy asset; the live catalog points to `first_signal_demo.ogg`.

## Existing runtime preparation

`assets/audio/music_catalog.json` already provides per-faction calm, contact, battle, and alarm choices, tempo/meter and loop metadata, weights, and transition bars. `scripts/music_director.gd` loads full-mix arrangements, synchronizes their playback, and crossfades tactical states at bar boundaries. The menu has its own title stream. This is sufficient to replace the placeholder files in-place without replacing the Godot audio architecture.

The current arrangement system does not yet provide authored multi-stem mixing: each tactical state is a complete mix, not a set of independently controllable percussion, bass, texture, and motif stems. The catalog can list alternate cues, but currently each faction/state has one demo. These are known gaps for the eventual production pass, not claims of completed features.

## Production needed before approval

Create or commission original, commercially usable sessions and export at least the requested title, calm, and battle comparisons for all three factions. Kobalt needs heavy industrial percussion and moving mechanical bass; Wanderpakt needs rougher broken patterns and aggressive motion; Prisma needs complex spectral/granular timbres with a deep rhythmic foundation. Avoid imitating named soundtracks. Record source and license details in `THIRD_PARTY_NOTICES` when external material is used.

After import, verify clipping and integrated loudness technically, then listen to each track at 30 seconds, after five minutes, and in a real match. Only after those listening checks should catalog entries change to an approved production state. Until then, keep the demo filenames, placeholder status, and pending approvals. No claim of completed high-quality music is justified by this update.

## Scope of this update

This is a production-readiness audit and guardrail only. It does not replace the music, add samples, or complete the broader graphics/audio brief. A suitable DAW or final licensed/commissioned assets are still needed for that work.

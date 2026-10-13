# SOLARIT audio production status — 2026-10-13

## Current result

The runtime music catalogue now points at a 148.4-second CC0 title track, *Our Expanse*, which its author describes as a calm space theme that builds to an energetic transition. Wanderpakt's high-battle state now uses the CC0 orchestral track *The Final Battle*. Existing faction/state selections, transitions, global stingers, voices, and Kenney sound effects remain available. The two added recordings are processed as 48 kHz stereo OGG candidates; their original CC0 sources are kept under `tools/audio_sources` so the build is reproducible.

This is a curated music selection and technical mastering pass. It is not an original SOLARIT score, commissioned composition, or approval of the artistic fit. The adaptive system uses complete tracks, not stems. Every track remains `candidate` / `pending` until listening review.

The German voice catalogue contains 118 clips generated from one Piper Thorsten emotional model, with speaker/emotion variants. These are playable synthetic German barks, not human studio performances or three independently cast faction voices. The generated voice model is not shipped with the game. Voice clip review remains pending.

The existing Kenney CC0 bank covers UI, weapon, metal impact, explosion, engine, and harvester cues. The harvester sound flow was corrected: starting work starts the motor loop and voice response; metallic crystal accents follow actual cargo growth; unloading plays its own cue. This prevents the collection sound from firing at the same instant as the work-start sound. A separate downloaded 60-clip CC0 sci-fi pack remains audition-only because its filenames are numeric and no sound-by-sound match has been confirmed.

## Tools and licensing

FFmpeg and FFprobe perform source conversion, 48 kHz / 24-bit WAV mastering, OGG encoding, file probing, and loudness/loop checks. No Music Maker session is required for this pass. FFmpeg processing does not create a composed score or replace human listening. The added songs and existing sound packs are listed in `THIRD_PARTY_NOTICES.md`; the project's strict audio release gate preserves `pending` status until a person listens and records evidence.

## Listening and release gate

Open `test-output/audio-review/index.html` for the current per-asset listening board. The two new tracks are included with their attribution and review state. Check the title at 30 seconds and after five minutes of looping, listen to all tactical states and stingers, and audition the three faction voices and sound effects in a real match. Review should check musical fit, repetition, loop seams, mix against speech and combat, German pronunciation, and voice fatigue.

The catalog and manifest pass technical integrity checks, but the strict release gate must continue to fail while any required asset is pending. Do not mark any asset approved without actual listening evidence. Paid services and API access were not used; no API key or new account is needed for this CC0 candidate pass.

## Rebuild and validation

`python tools/build_curated_audio.py --build` rebuilds the new title and battle candidates from the checked-in CC0 sources under `tools/audio_sources`; other original pass sources are staged outside the release package. `python tools/audio_pipeline.py --refresh-manifest` inventories assets without approving them. `--check` validates catalogue and hashes. `--release-gate` remains blocked pending human review. The targeted audio group and full regression still need to run for this working-tree change.

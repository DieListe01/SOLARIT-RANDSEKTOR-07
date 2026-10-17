# SOLARIT: RANDSEKTOR 07 — Sonic Bible

This document defines the sound identity that new music, voices, production audio, and combat effects must follow. It is a production guide, not an approval record. Assets in `assets/audio/music_catalog.json`, `assets/audio/voice/voice_catalog.json`, and `assets/audio/sfx_catalog.json` remain candidates until listening approval is recorded per the audio release gate.

## Shared mix rules

- Keep command and alert speech intelligible over music and combat. Speech ducks music to −6 dB with an approximately 56 ms attack and 333 ms recovery; avoid clipping and sudden bus-level jumps.
- Keep the battlefield alive with restrained wind, machinery, terrain, and Solarit ambience. Allow quiet stretches so alerts and combat entries have contrast.
- The adaptive score moves through calm, contact, low battle, high battle, and critical states. Transitions use bar-aware changes or fades; high battle must feel substantially larger than a small skirmish.
- Avoid a persistent high-pitched sine lead, organ-like pad, repetitive confirmation beep, or one identical explosion for every weapon class.
- Runtime assets use OGG Vorbis; music is stereo and speech is mono. The manifest records provenance, technical data, and approval status.

## Faction identities

| Faction | Rhythm and weight | Harmonic / timbral character | Voice direction | Avoid |
| --- | --- | --- | --- | --- |
| Kobalt-Konsortium (`forge`) | Slow-to-mid, deliberate, heavy pulse; strong downbeats and mechanical meter | Low bass, industrial metal percussion, restrained distortion, hydraulic and machine textures; controlled rather than chaotic | Low, calm, professional command voice; light radio band, clear consonants | Whistles, organ, thin bright leads, playful rhythms, overdriven unintelligible radio |
| Wanderpakt (`drift`) | Faster, broken or asymmetrical grooves; dry transient-heavy drums | Rough metallic scrapes, aggressive bass sequences, short noise and machine bursts; modular and improvisational | Rougher, quicker, direct delivery; short acknowledgements, light grit | Smooth corporate polish, uniform four-square march, random clutter that masks orders |
| Prisma-Konklave (`lumen`) | Precise, measured pulses with controlled changes in density | Glassy and granular tones, spatial pads, spectral motion, unusual harmony, energy pulses | Cool, controlled, clearly articulated, subtly processed | Dominant sine whistles, exaggerated robot effects, harsh distortion, human-like warmth as the main identity |

Fraktion identity should survive a low-volume and mono check. Do not rely on color-coded UI or stereo placement to distinguish a faction.

## Music direction

`FIRST SIGNAL` should introduce mystery, scale, and an alien industrial world within its opening seconds. It should develop through changes in density and texture, with a clean loop or intentional ending. A long render alone does not count as development.

Kobalt's score should sound like a controlled industrial war machine gathering force. Wanderpakt should feel quicker, rougher, and less predictable. Prisma should feel precise, spatial, and technologically unfamiliar. High-battle and critical states need clear contrast without simply making every layer louder.

Use stems when clean stems are supplied. Where they are unavailable, use synchronized full arrangements and musical fades; do not claim that full tracks are stems. The current director supports synchronized arrangements, state fades, stingers, voice ducking, and optional named stem sets.

## Speech direction

Normal RTS responses should be short, distinct, and understandable. Vary frequent selection, movement, and attack lines. Reserve urgency for damage, base alarms, full harvesters, mission warnings, victory, and defeat. Keep faction-specific performance separate; pitch-shifting one shared speaker is not a substitute for distinct casting.

The current catalog contains 118 playable German Piper neural-TTS candidate recordings across three faction banks and system lines. They demonstrate event coverage and runtime integration, but they are not studio performances and are not approved final casting. The generated speaker comparison is audition-only and does not assign speakers to factions.

## SFX direction

- UI cues should be brief and quiet enough to leave room for orders.
- Light ballistic, heavy cannon, artillery/siege, missile, energy, and special weapons need distinct attack and impact envelopes, not only pitch-shifted copies.
- A heavy vehicle needs low engine weight, track/ground movement, and turret movement. Light vehicles should sound quicker and less massive.
- The harvester needs separate idle, travel, cutting, conveying, full-load, return, unload, and damaged cues. Its work loop must be identifiable without overwhelming speech.
- Raffinery and vehicle-yard mechanisms should have their own motors, hydraulic motions, gates, and completion cues.
- Solarit is a restrained resonant/crystalline texture that changes with a deposit, collection, depletion, and unloading. It must not become a constant beep.
- Use CC0 or otherwise clearly commercial-safe sources only; preserve source URL, author, license, processing notes, and hashes with every external asset.

## Current implementation boundary

The music director currently has faction-specific catalogs, adaptive intensity states, arrangement crossfades, global stingers, voice ducking, audio buses, randomized SFX banks, and an optional synchronized stem path. The current music/SFX libraries are curated CC0 candidates. The voice bank is neural-TTS audition material. No candidate is marked approved by this document; final hearing review and the strict release gate remain mandatory.

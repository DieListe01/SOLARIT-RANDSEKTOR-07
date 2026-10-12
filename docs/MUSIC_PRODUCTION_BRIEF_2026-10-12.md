# SOLARIT music production brief — 2026-10-12

## Current status

The current soundtrack is still demo/reference material. The 13 music-catalog entries (First Signal plus four states for each of three factions) are now explicitly marked `asset_status: placeholder` and `human_listening_approval: pending`. The catalog-level `production_status` is `placeholder_not_final`. Their existing `_demo.ogg` filenames remain intact. The audio asset validator rejects missing or inconsistent placeholder labels; passing that technical check does not approve the music.

No final composition or mix was created in this pass. This workstation has FFmpeg and FFprobe, the project Python at `F:\Python\python.exe` (Python 3.10 with NumPy and SciPy), a separate bundled Python 3.12 without SciPy, and Blender 5.2 at `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`. The project Python can run the existing reference renderer, but that renderer synthesizes notes and timbres from oscillators, partials and noise and is explicitly unsuitable as a final composer. Blender is available for 3D asset work, not a substitute for a multitrack audio workstation. `Resolve.exe`, REAPER, Audacity, FL Studio, Ableton Live, LMMS, FluidSynth, SoX and TiMidity were not found in the checked locations or on PATH. The Blackmagic folder contains only an `audio` directory, not DaVinci Resolve/Fairlight. CIM inventory was inaccessible, so the inventory finding is limited to these checks.

FFmpeg/FFprobe can inspect, trim, transcode and measure audio, and apply technical mastering filters. They cannot provide the missing authored instruments, licensed sample library, sound-design session or musical judgement. The existing Python reference renderer remains a demo-generation tool only. No external sample source or license was introduced.

## Sound direction for a future authored score

- **Kobalt Consortium:** slow, massive industrial pulse; layered metal strikes, hydraulic/mechanical recordings, moving low drones and controlled distortion. The signature should be a weighty rhythm/timbre, not a high held lead.
- **Wanderpakt:** dry broken percussion, irregular accents, rough machine scrapes and mobile distorted bass; faster and less symmetrical without becoming a generic action beat.
- **Prisma Conclave:** deep foundation under evolving granular/glassy spectra, complex modulation and spatial energy pulses. Avoid a simple sine/whistle lead.
- **First Signal:** establish SOLARIT in its opening 10–15 seconds with an uneasy spatial texture and an original mechanical/spectral motif, then develop through distinct sections rather than holding a pad.

Calm, contact, battle and alarm need audible changes in density, rhythm and motif. Battle should add energy and movement; alarm should communicate urgency through its rhythm and sound design rather than merely louder mastering. Each faction needs its own rhythmic/timbral identity that survives a gray-box frequency/tempo comparison.

## Asset handoff and game integration

1. Author a multitrack session from original recordings, commissioned/licensed samples and designed instruments. Record source and license in `THIRD_PARTY_NOTICES` before importing anything external.
2. Export 48 kHz stereo, preferably 24-bit PCM masters. Make musical sections and loops sample-aligned; avoid relying on an end fade to disguise a musically incorrect loop. Keep headroom and avoid clipping/brickwall limiting. Target approximately -16 to -14 LUFS integrated as a starting point, with true peak below -1 dBTP, then balance in game.
3. Export real stems that share tempo, meter, bar zero and exact loop length. Do not export four independent complete mixes and call them stems. Calm/contact/battle/alarm layers must be intentionally mix-compatible, or the runtime must select/crossfade complete arrangements instead of summing them.
4. Version each approved asset and its source session. Replace the matching `*_demo.ogg` catalog path only after all listening checks pass; then set that entry to `asset_status: approved`, record approver/date and attach review evidence. The validator should be extended to enforce approved-master loudness and provenance when the first final master arrives.

## Required listening gate

Compare old reference and proposed mix for First Signal, Kobalt calm/battle, Wanderpakt battle and Prisma battle. Review each at 30 seconds, 5 minutes, and in an actual match. Record comments on organ/whistle/MIDI character, repetition, faction identity, battle lift, loop seams, dialogue/SFX masking and fatigue. Spectral, codec, peak and LUFS reports are supporting evidence only; they cannot pass this gate.

Until suitable composition tools/source material and a human listening pass are available, the existing OGGs remain playable demos. They must not be announced or released as the completed high-quality soundtrack.

## Runtime safeguard added in v0.38.18

The current catalog files are independent complete demo arrangements, not authored stems. The runtime now selects the calm, contact, battle, or alarm arrangement for the tactical state and transitions at bar boundaries. A 1.25-second equal-power crossfade can overlap only the old and new full mixes; it no longer sums calm, contact, battle, and alarm arrangements at once. This corrects the playback architecture, but does not change the demo audio itself or pass the human listening gate.

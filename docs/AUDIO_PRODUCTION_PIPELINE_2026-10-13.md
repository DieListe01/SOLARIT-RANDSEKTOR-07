# SOLARIT audio pass — 2026-10-13

## Runtime work in this pass

- Replaced the short music demos in the runtime catalogue with a 148.4-second *Our Expanse* title candidate. Its source description promises a calm space opening and a rising cinematic transition; this is a CC0 selection, not an original SOLARIT composition. The catalogue still contains six full-mix tactical states per faction and five global stingers.
- Added the CC0 orchestral *The Final Battle* as the Wanderpakt high-battle candidate. It loops to the same three-minute runtime target as the other tactical full mixes. The state tracks are not stems and remain separate complete pieces, so their musical continuity still needs listening review.
- Expanded tactical transitions to six synchronized, bar-aware full-mix layers: calm A, calm B/economy, contact, battle low, battle high, and critical. The game crossfades to the layer appropriate to the current combat state.
- Added licensed Kenney CC0 Sci-Fi Sounds to the runtime SFX bank for command feedback, weapon families, metallic impacts, explosions, vehicle ambience, harvester collection, and unloading. The harvester work loop and engine ambience use compressed OGG assets. Harvest start now starts the work loop without simultaneously firing the collection sound; a crystal accent is emitted only when cargo actually increases, and unloading has its own one-shot.
- Generated 118 German neural-TTS candidate lines from the CC0 Thorsten emotional model: 96 faction barks plus 22 system lines. Three model speaker/emotion profiles are assigned to Kobalt, Wanderpakt, and Prisma. The clips are preloaded by the existing voice director and are used by the existing selection, movement, attack, damage, harvest, construction, and mission events.
- Music and voice masters are processed at 48 kHz / 24-bit PCM before OGG Vorbis runtime encoding. Voice candidates are mono; music is stereo. The music generator normalizes the source and prepares seamless, short-faded loop boundaries.

## Approval and limits

Every imported and generated asset is marked `candidate` with human approval `pending`. The voice samples are synthetic and use speaker/emotion variants of one model; they are not studio actors and do not yet sound like three independently cast units. Music is a curated and mastered CC0 source selection, not a newly composed original score. Kenney effects are mapped to gameplay cues, but the mapping still needs listening and gameplay review. No candidate is represented as final or approved.

Human review remains required before a public release: listen to the music at 30 seconds and five minutes, play it in a real match, and review the voices and SFX in context. Do not change candidate status or listening evidence until that review is actually completed. The strict release gate must remain blocked in the meantime.

## Licensed sources

- Kenney, *Sci-Fi Sounds*, CC0: https://kenney.nl/assets/sci-fi-sounds. License copy: `assets/audio/licenses/Kenney-SciFiSounds-LICENSE.txt`.
- SRG774, *Dark Sci-Fi Audio Pack*, CC0: https://opengameart.org/content/dark-sci-fi-audio-pack.
- Alexander Ehlers / tricksntraps, *T&T Free Cyberpunk Pack 2*, CC0: https://opengameart.org/content/t-t-free-cyberpunk-pack-2.
- vitalezzz, *Inevitable*, CC0: https://opengameart.org/content/inevitable.
- Emma_MA, *Determined Pursuit*, CC0 / public domain: https://opengameart.org/content/determined-pursuit-epic-orchestra-loop.
- Basil, *Prepare to Fight*, CC0: https://opengameart.org/content/prepare-to-fight.
- Bobjt, *Our Expanse*, CC0: https://opengameart.org/content/our-expanse.
- skrjablin, *The Final Battle*, CC0 / public domain: https://opengameart.org/content/the-final-battle.
- rubberduck, *60 CC0 Sci-Fi SFX*, CC0: https://opengameart.org/content/60-cc0-sci-fi-sfx. The numeric files were staged for audition only and have not been integrated without sound-by-sound selection.
- Thorsten-Voice emotional Piper model, CC0 voice dataset: https://huggingface.co/rhasspy/piper-voices/tree/v1.0.0/de/de_DE/thorsten_emotional/medium. The inference model is staged locally and is not bundled into the game.

## Rebuilding and checks

`tools/build_curated_audio.py --build` creates runtime music and stingers from source files under `tools/audio_sources` and the remaining source files staged in `test-output/audio-tools/sources`. The committed title and battle sources are CC0. `tools/generate_voice_samples.py` renders the catalog into German voice OGGs; it needs the Piper package and the model/config passed on the command line. The ignored model and remaining source staging stay outside the game package. Generated OGGs and their provenance are checked into the asset catalogs/manifest.

Run `python tests/audio_asset_validation.py`, `python tests/voice_catalog_validation.py`, `python tests/audio_pipeline_validation.py`, then the Godot `audio_integration` and `voice_system` tests. `python tools/audio_pipeline.py --refresh-manifest` inventories newly added assets without granting approval; `--check` checks catalog and file integrity; `--release-gate` must fail until every required asset has recorded human approval.

The candidate audio assets and scripts were technically validated, then exercised through the existing Godot runtime tests. Technical tests do not establish that the mix is artistically right; the listening decision remains open.

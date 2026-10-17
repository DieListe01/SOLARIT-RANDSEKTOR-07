# SOLARIT audio production status — 2026-10-13

Faction tone, voice direction, mix rules, and sound-effect guidance are consolidated in [the Sonic Bible](SONIC_BIBLE.md).

## Current result

The runtime music catalogue now points at a 148.4-second CC0 title track, *Our Expanse*, which its author describes as a calm space theme that builds to an energetic transition. Wanderpakt's high-battle state now uses the CC0 orchestral track *The Final Battle*. Existing faction/state selections, transitions, global stingers, voices, and Kenney sound effects remain available. The two added recordings are processed as 48 kHz stereo OGG candidates; their original CC0 sources are kept under `tools/audio_sources` so the build is reproducible.

This is a curated music selection and technical mastering pass. It is not an original SOLARIT score, commissioned composition, or approval of the artistic fit. The adaptive system uses complete tracks, not stems. Every track remains `candidate` / `pending` until listening review.

The German voice catalogue contains 118 clips generated from one Piper Thorsten emotional model, with speaker/emotion variants. These are playable synthetic German barks, not human studio performances or three independently cast faction voices. The generated voice model is not shipped with the game. Voice clip review remains pending.

The existing Kenney CC0 bank covers UI, weapon, metal impact, explosion, engine, and harvester cues. The harvester sound flow was corrected: starting work starts the motor loop and voice response; metallic crystal accents follow actual cargo growth; unloading plays its own cue. This prevents the collection sound from firing at the same instant as the work-start sound. A separate downloaded 60-clip CC0 sci-fi pack remains audition-only because its filenames are numeric and no sound-by-sound match has been confirmed.

*Space Graveyard* (TinyWorlds) has been added as Wanderpakt's `calm_b` runtime candidate, replacing the exact Calm B track that Kobalt also used. The complete 312.726-second seamless source loop is normalized and converted into stereo 48 kHz OGG; the catalog marks it unmetered instead of inventing a BPM, and the director uses its neutral two-second state-transition grid. It remains pending listening approval. *Noisy Battle* (Some Weirdo) remains an audition-only comparison. Source metadata, CC0 listing, and source hash are documented in `tools/audio_sources/candidates/README.md`.

Six more German voice timbre auditions are now available on the review board. They use the same short command sequence from a pinned, 236-speaker Piper MLS model at revision `bae641dcb5a608cff81ccaf7ff018baaca1a33e1` (model SHA-256 `69cd1d2aa5a35839a518966fcc4924b5f93e5f8c948ed0752b1a616ad53f65bf`). The underlying German MLS speech corpus is CC BY 4.0 (OpenSLR SLR94). These synthetic options are comparison samples only; none has been assigned to a faction or copied into the runtime catalog. The generator and previews use the ignored `test-output` area, so model weights and candidate renders do not enter the game package.

Seven MP3 source renditions from SRG774's *Dark Sci-Fi Audio Pack* (CC0 1.0) are now downloaded, hashed, probed, and available on the local review board: a 4:22 title candidate, two atmosphere tracks, pulse, urgent, transmission, and a victory sting. Several repeat source recordings already used in processed Prisma and stinger runtime assets, so the MP3s serve as direct source comparisons; the title version is an additional candidate. The pack is intentionally gentle ambient music and may not meet the request for bombastic score. Exact duration, format, and SHA-256 are documented beside the files.

To address the request for more bombastic music, two CC0 battle tracks now appear as optional high-intensity runtime variants: Tarush Singhal's *Epic Fight Theme/Boss Battle* for Wanderpakt and cynicmusic's *Battle Theme A* for Kobalt. Both are mastered into 180-second 48 kHz stereo OGG loops and retained alongside each faction's signature high-battle track. Their original source durations are 87.3 s and 95.9 s; the loop construction and source links are documented in `tools/audio_sources/candidates/bombastic/README.md`. Both remain unapproved until heard in context.

## Tools and licensing

FFmpeg and FFprobe perform source conversion, 48 kHz / 24-bit WAV mastering, OGG encoding, file probing, and loudness/loop checks. No Music Maker session is required for this pass. FFmpeg processing does not create a composed score or replace human listening. The added songs and existing sound packs are listed in `THIRD_PARTY_NOTICES.md`; the project's strict audio release gate preserves `pending` status until a person listens and records evidence.

## Listening and release gate

Open `test-output/audio-review/index.html` for the current per-asset listening board. The two new tracks are included with their attribution and review state. Check the title at 30 seconds and after five minutes of looping, listen to all tactical states and stingers, and audition the three faction voices and sound effects in a real match. Review should check musical fit, repetition, loop seams, mix against speech and combat, German pronunciation, and voice fatigue.

The catalog and manifest pass technical integrity checks, but the strict release gate must continue to fail while any required asset is pending. Do not mark any asset approved without actual listening evidence. Paid services and API access were not used; no API key or new account is needed for this CC0 candidate pass.

## Rebuild and validation

`python tools/build_curated_audio.py --build` rebuilds the new title and battle candidates from the checked-in CC0 sources under `tools/audio_sources`; other original pass sources are staged outside the release package. `python tools/audio_pipeline.py --refresh-manifest` inventories assets without approving them. `--check` validates catalogue and hashes. `--release-gate` remains blocked pending human review.

## Validation update — 2026-10-14

- Audio regression: 5/5 passed (`audio_asset_validation.py`, `voice_catalog_validation.py`, `audio_pipeline_validation.py`, `audio_integration.gd`, `voice_system.gd`).
- Full regression: 51/51 passed on 2026-10-14, including multiplayer and rendered visual checks, on the local NVIDIA RTX 3060 setup. The loopback API test required local network permission; the sandbox attempt failed with WinError 10013, then the unchanged suite passed. No Godot processes remained.
- Audio manifest and hashes: `python tools/audio_pipeline.py --check` passed.
- Audio release gate: still blocked with 1,313 pending candidate/approval issue rows after adding Prisma's battle alternative. This is intentional: automated checks cannot supply the required human listening approval. The number counts separate asset/status/evidence findings, not unique files. No candidate has been marked approved.
- The production-shader terrain visual acceptance test also passed after replacing blocky value-noise interpolation with gradient noise; this change is separate from the audio work.
- Six German MLS speaker alternatives were generated for the review board at 48 kHz mono OGG; each uses the same 3-command phrase. The pinned model hash was verified before inference. They remain audition-only and are not runtime assets.
- Seven additional CC0 music candidates from SRG774 were source-checked and probed with FFprobe (44.1 kHz stereo MP3, durations 5.9–262.1 seconds); SHA-256 values are recorded in the candidate folder README. The generated review board now includes them; they remain inactive until heard.
- Two CC0 bombastic battle-music variants from Tarush Singhal and cynicmusic were added to the Kobalt and Wanderpakt `battle_high` runtime choices and checked with FFprobe; their source descriptions, durations, rates, licenses, and SHA-256 values are documented. Both remain pending human listening approval.
- The duplicated Calm B path shared by Kobalt and Wanderpakt was removed: Wanderpakt now has its own full-length atmospheric runtime candidate. The new file preserves the 5:12 source loop and carries an explicit unmetered flag; music state changes use the neutral grid when no BPM is supplied.
- Two optional 180-second high-intensity battle variants are now reachable in-game: *Battle Theme A* for Kobalt and *Epic Fight Theme / Boss Battle* for Wanderpakt. The existing signature high-battle tracks remain available; both additions carry explicit CC0 provenance and remain pending human listening approval.
- Prisma now has a second high-battle choice, Some Weirdo's CC0 *Noisy Battle*, converted to a 180-second 48 kHz stereo OGG and reachable through the same tactical director. OpenGameArt describes it as a techy, loopable science-fiction battle theme. It remains an unapproved candidate pending in-game listening; this broadens the faction's high-intensity palette without calling the track a commissioned Prisma score.
- Tactical state changes now use the bar duration and playback position of the currently audible arrangement, including the neutral transition grid for unmetered music. This fixes transitions that were timed against the calm track even during a different tactical arrangement.
- Verification after this change: all 5 Audio tests passed, the full 51-test regression passed, `audio_pipeline.py --check` passed, and the release gate correctly remains blocked until human listening approval.
- `python tools/generate_voice_auditions.py` can rebuild those six local auditions using the pinned model and Piper 1.8.0 in the ignored `test-output` directory.
- The voice audition tool also creates a direct six-speaker comparison across four identical RTS phrases (selection, move, attack, and harvester return): 24 48 kHz mono OGG files under `test-output/audio-review/voice_options/faction_comparison/`. The comparison is linked from the main review page, remains outside the runtime catalog, and deliberately assigns no speaker to a faction before human listening. FFprobe verified all 24 files.
- No ElevenLabs, OpenAI Speech, or Runway credentials are configured in the local environment. The free, pinned MLS Piper model is therefore used for comparison only; its voice timbre is not represented as final studio-quality faction casting.

## Work continued — 2026-10-14

- Downloaded rubberduck's *60 CC0 Sci-Fi SFX* archive from OpenGameArt. The source page declares CC0; the source archive SHA-256 is `11EBF7D8C4ECE445128EEB95C969E0ED36FF34FC2C8EF0E04A154D62E2F938F8`. The ZIP contains exactly 60 OGG files and no other file types. Source and license are documented in `tools/audio_sources/candidates/60_cc0_sci_fi_sfx/README.md` and `THIRD_PARTY_NOTICES.md`.
- The 60 numeric-named effects are audition-only. They are linked on the listening board but are not mapped to game events because their filenames do not identify their contents and they have not been heard in context.
- Fixed the manifest refresh precedence: for assets present in the current music/voice/SFX catalogs, current catalog licensing data now wins over stale manifest license data. Existing human listening records remain preserved. The refreshed 306-row manifest has no author/attribution discrepancies among its music entries; `python tools/audio_pipeline.py --check` passes.
- Expanded the local audio review board to include all 60 new CC0 effects beside current music, speech, SFX, and music alternatives. The output is generated under ignored `test-output/audio-review/`.
- `tests/audio_pipeline_validation.py` passes 10/10 after adding checks for catalog-license precedence and all 60 audition clips. The release gate still blocks on pending human listening; its 1,309 issue rows are not approvals and must not be cleared by automation.
- Only FFmpeg and FFprobe were available as production tools. No DAW or ElevenLabs/OpenAI/Runway API credential was configured. Existing playable music and faction voices therefore remain curated CC0 tracks and Piper neural-TTS candidates, not commissioned score or studio-cast performance. No stem exports were produced.
- Added two named CC0 effects to the audition board: bart's 22.154-second *Steam boiler sound loop* for possible refinery/power ambience and Fupi's 12-second *Long Sci-fi Sting* for possible alerts or the intro. Their OpenGameArt pages mark the works CC0; neither has been selected for runtime without listening.
- Also checked qubodup's CC0 *(defect) motor loop*. The author's page says it is a graphics-card fan recording, so it is recorded as excluded from runtime rather than mislabeled as a vehicle engine. The original, unmodified samples and SHA-256 hashes are in `tools/audio_sources/candidates/README.md`.
- FFprobe source validation: generator loop 44.1 kHz stereo WAV / 22.154 s; sting 44.1 kHz stereo Vorbis / 12 s; fan loop 44.1 kHz stereo WAV / 3.011 s. No processing was applied and no candidate was approved.

## Work continued — 2026-10-14, industrial ambience

- Promoted bart's verified CC0 *Steam boiler sound loop* from audition-only into the playable SFX catalog as a low-level refinery ambience candidate. The untouched 44.1 kHz source remains under `tools/audio_sources/candidates/`; FFmpeg made a 48 kHz / 24-bit stereo normalized master in ignored `test-output/audio-mastering/`, then encoded the runtime 48 kHz stereo Vorbis asset at quality 6.
- The loop is mixed on the Ambience bus and fades in only while the local player owns a completed refinery; it fades down and stops when the last one is gone. It is capped at a quiet level and follows the SFX volume. It does not replace combat, music, or harvester cues.
- The sound catalog and third-party notices identify the author, source URL, CC0 license, processing, and pending listening state. Runtime SHA-256: `905837bc0f5857374efbb9d1e29f996850c86c789ab6935c1c8733167d3e0dc3`.
- This is an integrated candidate so it can be heard in context; its technical format and license are checked, but it is not called release-quality until the user completes in-game listening. No music or voice approval was inferred from technical checks.
- Added MintoDog's CC0 *Space Battle* as a third optional Prisma high-battle candidate to broaden the faction's palette. The official source page labels it CC0 and loopable; the source is 88.615 seconds, 44.1 kHz stereo OGG. The 48 kHz stereo runtime conversion repeats that source loop exactly twice (177.231 seconds) with short edge fades that pass the existing loop-seam test, and is deliberately marked unmetered because the page does not publish a beat grid. Source and runtime hashes are recorded in `tools/audio_sources/candidates/bombastic/README.md`; it remains pending human review.
- The local review board now includes this additional Prisma music candidate. No score is represented as a commissioned original composition; the game's active music remains a curated CC0 selection pending artistic approval.

The review page is generated at `test-output/audio-review/index.html`. Release remains unapproved until the music, voice and SFX review entries have actual listening evidence and the strict gate passes.

## Continued verification — 2026-10-14

- The generated local review page now includes the current runtime catalog, German voice auditions, the 60 unidentified CC0 effects as audition-only material, and the two attributed OpenGameArt battle-intro/loop comparisons. These comparison files are not active in the game. Open `test-output/audio-review/index.html` for the in-browser audio controls.
- The full local regression completed with **52/52 PASS** across 12 groups, including the three Multiplayer checks. Audio was 5/5, Visual 11/11, RendererCache 6/6, and Performance 2/2. Godot test processes were absent after completion. The unchanged Full-HD image assertion now starts in fullscreen so the OS title bar cannot shrink the test viewport.
- One earlier sequenced run caught the adaptive-stem playhead assertion before the headless audio mixer had applied its scheduled starts. The test now waits 50 ms before reading playheads; it keeps the original 50 ms synchronization limit. The Audio group then passed, followed by the complete regression.
- `Test-Solarit.ps1` parses successfully, `git diff --check` passes, and `python tools/audio_pipeline.py --check` passes. The strict release gate remains correctly blocked with 1,321 pending-review issue rows. No listening approvals were fabricated.
- No 30–45-minute match listening assessment, commissioned original score, studio-recorded voices, or approved final mix has been produced. The current playable files and German neural-TTS voices are technically integrated candidates for human audition; they are not being described as finished professional production.
- The source changes remain local and uncommitted. No version bump, tag, installer, or public release was made while the required music, voice, and SFX listening approvals remain pending.

## Verification update — 2026-10-14, runtime ambience and battle candidate

- The focused Audio group passes all 5 tests after integrating the refinery ambience and adding the third Prisma battle-high choice. The focused frontend test also passes with the updated Music & Credits page and victory/defeat previews.
- `python tools/audio_pipeline.py --check` passes. The strict release gate remains blocked with 1,321 issue rows, all tied to pending human review/approval evidence; no asset was auto-approved.
- `git diff --check` passes and no Godot processes remain after the focused checks.
- The review page remains `test-output/audio-review/index.html`; listen to the Space Battle alternative and refinery ambience in context before approving those candidates or treating any of the audio as final.

## Further music comparison — 2026-10-14

- Added Leonardo Paz (leohpaz)'s *Outer Space Music Pack* battle intro and loop to the local listening board only. OpenGameArt lists CC-BY 4.0/3.0 and asks for attribution; the source is recorded under CC-BY 4.0 with attribution text and both SHA-256 hashes in `tools/audio_sources/candidates/README.md` and `THIRD_PARTY_NOTICES.md`.
- FFprobe verified both files as 44.1 kHz stereo Vorbis, 44.769 seconds each. They are untouched source comparisons, not runtime assets and not approved. The listening board labels this section as licensed comparison candidates, rather than implying every alternative is CC0.
- After adding the comparison, the focused Audio suite passed all 5 tests again; `audio_pipeline.py --check` and `git diff --check` also passed. No product runtime slot or approval state changed for this source.

## In-game listening room — 2026-10-14

- The `MUSIK & CREDITS` screen now provides direct previews for all three faction profiles, all six tactical arrangements, and the five mission stingers. Arrangement changes crossfade through the same runtime mixer used in missions.
- Four German voice audition buttons (selection, movement, attack, and harvester return) use the selected faction's preloaded recordings and do not consume in-match voice cooldowns.
- Its preview simulation is isolated from tactical scanning, so test combat state cannot switch away from the arrangement selected by the listener.
- The focused Audio group passed **5/5** and the Frontend test passed **1/1** after these changes. The integration test additionally starts each faction preview and verifies its calm and battle arrangements resolve. Candidates remain pending human listening approval; the screens make the required review accessible but do not approve audio automatically.

## Verification update — 2026-10-14, full regression

The complete sequenced suite passed **52/52** across 12 groups, including all 3 Multiplayer checks and the expanded 600-frame building visual stability test. The first sandboxed attempt hit Windows `WinError 10013` in the API loopback test; the unchanged suite passed when run with local loopback access. Audio passed 5/5. `git diff --check` passes, and no Godot processes remained afterward.

`python tools/audio_pipeline.py --check` passes technical catalogue/hash validation. The release gate remains blocked: all 309 manifest rows are still pending human listening approval. This project stage has not produced approved studio-recorded faction voices, a commissioned original score or a final human-approved SFX/mix; candidates remain accurately marked pending. No version bump, commit, tag, installer or public release was made.

## Vehicle-engine audition candidates — 2026-10-15

- Added both recordings from pauliuw's OpenGameArt *Engine sounds(2)* page to the local comparison board. The source page declares CC0; source URLs, file hashes, and FFprobe metadata are in `tools/audio_sources/candidates/README.md`.
- The recordings are 20.712-second, 48 kHz stereo MP3 files. They are not copied to the runtime catalog or connected to gameplay because they still need human listening and fit review.
- The listening-board test now requires both named candidates and their source link to appear. `python tests/audio_pipeline_validation.py` passes 10/10; `python tools/audio_pipeline.py --check` passes; `git diff --check` passes.
- This only gives the next audition concrete engine candidates. Commissioned music, studio voices, a long-match human sound-mix review, and approval of any audio remain outstanding. No asset has been marked approved.

## Full project regression and strict audio gate — 2026-10-15

- The complete local regression passed **52/52** in 12 groups on Vulkan/RTX 3060, including Audio 5/5, Visual 11/11, and Multiplayer 3/3. No Godot processes remained after the suite.
- `python tools/audio_pipeline.py --check` passed manifest/hash checks. `--release-gate` still exits 1 with **1,321 review findings** because required catalog entries remain candidate/pending and lack human listening evidence. It is intentionally not bypassed.
- The updated local review board now includes six voice-timbre comparisons using the requested audition lines “Jawoll, Sir!”, “Auf dem Weg!” and “Arbeit! Arbeit!” alongside the existing in-game faction and system voice candidates. The comparison recordings are audition-only, are not assigned to factions, and are not final casting.
- The assets therefore have runtime integration and technical validation, but final music, voice casting, sound effects, and the long-match mix remain open until a human listens and records approval. No version bump, commit, tag, installer, or release was created in this pass.

## Speech-priority mix follow-up — 2026-10-15

The adaptive music mix previously reduced its gain to 0.72 while speech played (about −2.8 dB) and moved there at 1.5 linear gain units per second. That mild, relatively slow change could leave short command barks masked by battle arrangements. Speech now ducks music to 0.501 linear (−6 dB), reaches that target in about 56 ms, and restores music over about 333 ms after the line ends. The same mix factor applies to synchronized arrangements, stems, and stingers. Music, voice, and SFX source assets are unchanged and remain candidates pending human listening.

The Audio group passes **5/5**. Its integration check now verifies that an active voice reaches the −6 dB target within an 80 ms test interval and that music has recovered by 350 ms after speech stops. No full regression, release build, version bump, commit, or publish was run for this focused mix change.

## Baubeginn-Funksprüche — 2026-10-15

- Added two short `build_start` German responses to each faction voice bank. A visible construction event now triggers one response for the local player's own building; enemy construction does not use the local faction voice. Existing event cooldown and priority rules still apply.
- Generated the six 48 kHz mono OGG files from the locally pinned Thorsten-Voice/Piper model using the existing reproducible voice pipeline. Their catalog entries identify faction speaker IDs, source, CC0 dataset terms, and remain `candidate` / `pending` until human listening review. They are not studio-recorded or approved final casting.
- Refreshed the manifest and listening board. Catalog validation now expects 102 faction recordings plus 22 neutral/system recordings (124 total); the Audio group passes 5/5, including voice preload and preview checks.
- A first focused run exposed that Godot had not imported the newly generated OGGs. After a normal headless editor import produced the `.import` metadata, the unchanged Audio group passed. `python tools/audio_pipeline.py --check` and its 10 pipeline tests pass. The strict release gate remains pending human listening approval.

## Baubeginn-Hörprobe im Spielmenü — 2026-10-16

- `MUSIK & CREDITS` now offers five German voice previews in a two-row layout, including `BAUBEGINN`; the selected faction's loaded candidate is previewed through the same Voice bus as live gameplay.
- The frontend integration test presses the Prisma build-start preview and verifies a `voice_lumen_build_start_` recording is selected. The focused frontend test passes; the Audio group passes **5/5** on the current working tree.
- This improves access to candidate review only. Recordings, music and SFX remain pending human listening approval; the release gate was not bypassed, and no release was created.

## Sammler-Sprachproben im Spielmenü — 2026-10-16

- The `MUSIK & CREDITS` review room now offers nine directly playable German voice events for the selected faction: selection, movement, attack, harvest start, full cargo, return, unloading, construction start, and danger.
- The sampler buttons use short labels in a compact three-by-three layout so all labels fit at 1920×1080. The existing faction picker selects which candidate voice bank is previewed.
- The frontend test presses all four newly exposed harvester events and verifies that each resolves to the selected Prisma candidate recording. `Test-Solarit.ps1 -Test frontend` passes with exit code 0; the Full-HD review capture is `test-output/audio_review_room.png`.
- This makes the current voice candidates easier to audition in context. It does not constitute human listening approval, final voice casting, or studio recording; all candidates remain pending and the release gate remains unchanged.

## Continued validation — 2026-10-16

- Rebuilt the local audio listening board at `test-output/audio-review/index.html` from the current music, voice, and SFX catalogues so the newer faction tracks and German harvester/build-start auditions are listed for review.
- The focused Audio group passes **5/5** on the current working tree: audio asset validation, voice catalogue validation, audio pipeline validation, Godot audio integration, and voice system.
- `python tools/audio_pipeline.py --check` and the standalone audio/voice catalogue validators pass. The strict release gate still requires actual human listening approval; generated and sourced candidates remain `pending` and are not described as final studio recordings.
- The local RTX 3060 moving-battle A/B run reported zero pose bakes, cache recreations, and GPU-to-CPU readbacks in all eight measured production-cache variants. The frame-rate results varied materially by run order, so no VFX, track, or wreck quality reduction was accepted. Full values and the measurement limitation are in [the moving battle benchmark record](MOVING_BATTLE_BENCHMARK_2026-10-14.md).
- The complete local regression then passed **53/53** across 12 groups, including Visual 11/11, RendererCache 6/6, Audio 5/5, and Multiplayer 3/3. It required local loopback access for the API tests; the sandboxed attempt failed with `WinError 10013`, and the unchanged suite passed with local loopback enabled. No Godot processes remained afterward.
- The audio integrity check passes, while the strict release gate remains blocked with **1,345** pending review findings. This is a human listening-approval gate, not a test failure; no candidate was automatically approved. No version, tag, installer, or public release was created.

## Review criteria follow-up — 2026-10-16

The release gate now asks for evidence appropriate to each audio kind: music requires listening at 30 seconds, five minutes, and in a match; voice requires clarity, pronunciation, faction identity, repeat testing, and an in-match mix check; SFX requires event fit, mix level, and an in-match check. Every kind still requires a named reviewer, date, approved status, and cleared commercial license. The listening board shows these criteria before the per-asset controls.

Listening evidence is also bound to the reviewed asset's SHA-256. When a runtime file changes, manifest refresh drops its old listening review instead of carrying approval over to new bytes. Provenance and license metadata continue to follow their existing catalog-precedence rules.

The Audio group passed **5/5**, `python tools/audio_pipeline.py --check` passed, and `git diff --check` passed after this correction. The release gate still exits **1** with **1,345** findings because assets remain candidates/pending and have no human review evidence; the criteria change did not grant approval or bypass the release block.

## Vorläufige menschliche Hörabnahme — 2026-10-16

Der Projektinhaber hat die aktuell aktiven Musik-, Sprach- und SFX-Assets ausdrücklich für Entwicklung und Gameplay-Test vorläufig akzeptiert. Dokumentierter Status: **„Vorläufige menschliche Hörabnahme für den aktuellen Entwicklungsstand – erneute Bewertung im realen Gameplay ausdrücklich vorbehalten.“** Das ist keine endgültige künstlerische Abnahme. Jeder Datensatz ist an Datei-SHA-256 und Playback-Signatur gebunden; Änderungen an Datei oder relevanter Playback-Konfiguration machen den Datensatz nach Inventaraktualisierung ungültig.

Das Inventar unterscheidet jetzt laufzeitreferenzierte Assets von archivierten bzw. nicht referenzierten Kandidaten. **222 aktive Release-Assets** haben aktuelle vorläufige Nachweise (28 Musik, 70 SFX einschließlich neun direkt verwendeter Fallback-Cues, 124 Sprachzeilen). Weitere **93 inaktive Einträge** bleiben pending und blockieren den Release nicht. Die endgültige Hörfreigabe ist für alle 222 aktiven Assets weiterhin pending. Der Manifest-/Hash-Check besteht; der öffentliche Release-Gate bleibt mit **684 Befunden** gesperrt: Kandidaten-/Platzhalterstatus und fehlende finale Hörkriterien für die aktiven Assets, zusätzlich ungeklärte kommerzielle Rechte und nicht 48-kHz-konforme Formate bei neun Legacy-Fallback-Cues. Keine Audiodatei wurde geändert und kein Asset final freigegeben.

Gezielte Prüfung: `python tests/audio_pipeline_validation.py` **17/17 PASS**, `python tools/audio_pipeline.py --check` PASS, `python tools/audio_pipeline.py --release-gate` erwartungsgemäß BLOCKED. Der Gate bewertet nur aktive, releasepflichtige Audios; inaktive pending Einträge bleiben im Inventar sichtbar.

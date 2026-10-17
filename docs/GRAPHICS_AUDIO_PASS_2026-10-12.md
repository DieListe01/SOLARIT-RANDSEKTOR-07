# Graphics and audio pass — updated 2026-10-13

## Terrain diagnosis and change

The rectangular surface blocks in the current missions come from authored rectangular `terrain_regions` in the map data. Fog of war is a separate overlay and was not the source of these blocks: the A/B capture revealed every cell for both players and separately disabled terrain detail and the fog pass.

Each shipped mission has a baked 8× supersampled visual material mask with organically eroded rock, dune, crater, and restrained cliff-edge borders. These masks are presentation-only: gameplay cells, collisions, movement costs, build restrictions, resources, and pathfinding remain exact. Cliff interiors and Solarit resource cells are retained. The world sprite compensates for the larger texture so all masks cover the original map dimensions. They load from `assets/terrain_masks/` at mission start instead of synchronously running the expensive generator during gameplay. `tools/generate_terrain_visual_masks.gd` rebuilds the shipped masks from mission data.

The local Vulkan acceptance capture uses the GeForce RTX 3060, revealed terrain, and the normal game renderer. It shows the material boundaries in-game at two zoom levels; the mask generator and committed PNGs are compared for Veyra, Dry Vein, and Khepri, and tests confirm the simulation grid stays unchanged. The capture isolates terrain by disabling fog, detail meshes, units, buildings, combat, tracks, wrecks, health bars, and the heat overlay; a separate material-class image helps distinguish mask shape from shading. Captures are stored in `test-output/terrain_irregular_boundaries.png`, `test-output/terrain_irregular_boundaries_detail.png`, `test-output/terrain_material_only.png`, and `test-output/terrain_mask_classes.png`; the raw mask is `test-output/terrain_visual_mask.png`. A newly introduced mission without a baked mask still falls back to runtime generation and may incur a one-time loading stall until its mask is baked.

## Existing visual systems checked

The visual suite regenerates faction vehicle and building contact sheets and exercises authored assets, construction/production visuals, color identity, and the in-game showcase. The project already contains three faction vehicle families, faction-specific buildings, construction stages, animated vehicle production, the harvester work states, and destruction assets. This pass did not replace those models or change their gameplay stats.

## Audio status

The audio pass replaces the demo catalogue with a 148.4-second title candidate, six tactical states per faction, five stingers, 118 German neural-TTS voice candidates, and curated CC0 SFX. They are integrated and technically validated. For this local gameplay testbuild only, the user authorized the provisional status **„Vorläufige Audiofreigabe für Gameplay-Test – finale Hörabnahme nach praktischem Spieltest.“** The underlying assets remain `candidate` / `pending`; this is not final listening approval and does not unlock a public release. The music is curated and mastered CC0 material, not an original commissioned score; the voices are speaker variants of one TTS model, not studio actors.

Open `test-output/audio-review/index.html` for an individual player for each of the 180 music, voice, and SFX clips; `SOLARIT-Audio-Abnahme-Preview.ogg` is the timestamped medley. All audio paths in the page were checked. The previous review page pointed at superseded demos and has been replaced. The release gate intentionally blocks pending assets. Review still needs to cover the title and tactical music at 30 seconds and five minutes, plus voices and effects during a real match.

## Iteration v0.38.25 — role-specific Prisma building structure

The contact sheet exposed a weakness that the earlier asset checklist missed: several Prisma buildings were distinguished mainly by repeated rings and their purpose was hard to read at the shared game camera. All eight Prisma Blender sources and GLBs now have role-specific faceted housing meshes. The factory uses an open four-column production portal with guide rails; the refinery keeps an ore separator bed; the repair facility has service cross-members; and the armory has four angular storage magazines. Shared orbital rings were removed from the factory, repair, armory, and levitation feet. The normal Godot building cache and all named animation pivots are retained. The faction contact sheets render again through the actual painter and are available in `test-output/` after the Visual group.

This iteration improves one building family, not the full requested pass. It does not finish Wanderpakt building quality, all faction vehicle families, new licensed music, or German recorded unit voices. The generated models remain stylized hard-surface Blender assets and need a normal-match approval pass after release.

## Iteration v0.38.26 — make harvester cargo levels read at gameplay scale

The 0/25/50/75/100% comparison showed that cargo existed in all three authored harvesters but some crystals were too tightly grouped and low above the hopper. The Blender sources now distribute larger clusters over a wider footprint and raise the later row; the Wanderpakt and Prisma asset generator has a `--only-harvester` mode so this targeted bake does not rewrite unrelated faction vehicles. The shared cache camera, cargo-state quantization, movement, and gameplay values are unchanged.

The normal 160×160 in-game cache crop now records empty-to-full mean RGB differences of 0.01227 for Kobalt, 0.04845 for Wanderpakt, and 0.05125 for Prisma. The smallest 25%-step difference is 0.00198 (Kobalt); the others are at least 0.00752. `tests/harvester_cargo_visual.gd` now enforces >0.01 empty-to-full and >0.0015 for every adjacent load step. The focused RendererCache test passes on the local RTX 3060 / Vulkan renderer. These images show cache-scale model differences; final confirmation still requires a real match at normal camera zoom.

This visible cargo pass is not the complete graphics/audio brief. Final music, German recorded voices, normal-match capture/inspection, and the remaining asset/production audits remain open.

## Iteration v0.38.27 — faction-specific PBR surfaces on buildings

The 16 Wanderpakt and Prisma buildings now use the same 512×512 ceramic, graphite, and steel normal/roughness maps as the vehicle materials, plus each faction's authored tinted albedo maps. The glTF files point to a shared texture pool instead of embedding a duplicate set in every building. A forced Godot reimport confirmed that all three PBR channels reach the imported `StandardMaterial3D` materials; the Visual suite now checks that every one of the 16 faction buildings has textured surfaces. This adds readable panel seams, fastener marks, wear, and material response while retaining existing geometry, camera, animations, gameplay, and silhouettes.

The maps add close-view surface response but remain stylized, tileable materials rather than hand-painted unique UV atlases. The full real-match acceptance, higher-end hand-built vehicle/building detailing, final music and voice recordings remain open.

## Validation

- `Test-Solarit.ps1 -Group Gameplay -OverallTimeoutMinutes 20 -HeartbeatSeconds 30`: 8/8 PASS.
- `Test-Solarit.ps1 -Group UI -OverallTimeoutMinutes 20 -HeartbeatSeconds 30`: 5/5 PASS, including update history and version labels.
- `Test-Solarit.ps1 -OverallTimeoutMinutes 90 -HeartbeatSeconds 30`: 47/47 PASS across 12 groups; Multiplayer PASS; no Godot processes remained.
- `Test-Solarit.ps1 -Test terrain_visual_acceptance.gd -OverallTimeoutMinutes 10 -HeartbeatSeconds 30`: PASS on the RTX 3060 / Vulkan renderer; 8× mask data, irregular soft and cliff edges, cliff/resource preservation, all three generated-versus-baked mission masks, and unchanged simulation terrain checked.
- `Test-Solarit.ps1 -Group Audio -OverallTimeoutMinutes 15 -HeartbeatSeconds 30`: 4/4 PASS, including adaptive stem sync, incomplete-set fallback, combat/critical fades, and pause behavior.
- `Test-Solarit.ps1 -Group RendererCache -OverallTimeoutMinutes 20 -HeartbeatSeconds 30`: 6/6 PASS.
- Terrain-mask generator cost on the local test build is about 300 ms per map; shipped missions avoid this cost by loading baked PNGs. The procedural fallback for a new mission should be removed from the critical path by baking that mission before distribution.
- Candidate `v0.38.15` targeted gates: Visual 9/9, Audio 4/4, Gameplay 8/8, and `update_info.gd` PASS. The complete regression is the final remaining test gate for this candidate.
- PowerShell 7.6.5 is required for the local regression supervisor in this environment: the test supervisor reports valid child exit codes there. Windows PowerShell 5.1 returned a null `Process.ExitCode` for the Python child despite a passing child log; no test or assertion was changed for that host-specific behavior.
- The GitHub release workflow, export, installer, manifest and publish steps remain required before calling this version released.

## Iteration v0.38.28 — audio candidate package and terrain-mask correction

The renderer now builds an 8× supersampled presentation mask from mission terrain regions and irregular Solarit contours, while leaving the simulation grid intact. A resource-contour pass initially restored unshaped material pixels in the rest of each patch's square bounding box; this was removed so it adds Solarit only inside its contour. `terrain_visual_acceptance.gd` passes and checks generated/baked mask parity across all three missions. The in-game capture still has visible block-like tonal overlays on the ground, so the terrain presentation is not declared fully accepted.

`tools/build_audio_review.py` generates the corrected local audition page. `python tools/audio_pipeline.py --check` passes. The strict release gate remains blocked by pending human listening approvals and must stay so until listening evidence is recorded. No candidate is presented as a final approved score, voice performance, or SFX mix.

The full local regression completed with 50/50 PASS across all 12 groups, including all three Multiplayer tests. Its API test needs local loopback permission; the sandbox-only run failed with Windows `10013`, then the same test and full suite passed with local network access. The suite left no Godot processes behind. The regression summary and per-test stdout/stderr are under `test-output/ci/`.

## Iteration v0.38.29 — title and harvester audio revision

The title cue now uses the CC0 loop *Our Expanse* (148.4 seconds), described by its author as a calm space opening with a cinematic build. Wanderpakt high battle now uses the CC0 orchestral *The Final Battle*. These are selected third-party recordings rather than original SOLARIT compositions, and remain `candidate` / `pending`.

The harvester no longer triggers the crystal collection accent on the same frame as harvest start. Its work loop begins with the harvesting state, a metallic pickup accent follows actual cargo thresholds, and a distinct CC0 door mechanism cues unloading. The 60-file CC0 SFX pack was downloaded to an ignored review staging folder but was not imported because its numeric filenames do not identify individual sounds without audition.

The audio review page and manifest were regenerated. The strict release gate still blocks publication until the listening checks have been completed by a person. Focused audio tests and full regression for v0.38.29 are pending in this working-tree change.

## Open work

- Commission or supply German voice recordings for the existing line catalog.
- Compose, integrate, and listen-test final faction-specific music; the current demos do not meet final audio acceptance.
- Complete user-facing terrain review during a normal match; the latest diagnostic capture no longer shows an obvious large rectangular material overlay, but it is not a substitute for inspecting a recorded match.
- Conduct the full user-facing 2D/3D, harvesting, production, combat, destruction, and Full HD visual/audio acceptance on a real match recording.

## Runtime harvester pass — 2026-10-14

`tests/harvester_runtime_visual.gd` now runs a rendered gameplay fixture through idle, gathering, loaded return, refinery approach, unloading, and resumed work. It checks live cargo accumulation, return/unload states, credited resources, and the selected-unit capacity display, then saves one game-rendered capture per state in `test-output/harvester_runtime_*.png`. The focused test passed, as did the existing Gameplay group (8/8), Visual group (9/9), and `regression.gd` on this working tree.

Visual inspection confirms that the unit returns and the HUD reports cargo (for example `54 / 240` while gathering and `240 / 240` on return). At normal match zoom, however, the cargo crystals/material pile are still too small to read clearly on the vehicle itself; the HUD label is doing most of the explanatory work. This test establishes that the gameplay cycle and its rendered states occur, not that the cargo animation or material transfer is visually strong enough. A normal-match review of crystal loading, the moving cutter/conveyor, and the refinery unloading mechanism remains open.

The working tree has no version bump, release tag, or published installer. The strict audio release gate remains blocked pending human listening approval; the supplied recordings are still candidates, not final approved music or voice production. After the renderer identity guard and diagnostic export, the full local regression passed 51/51 with loopback access; no Godot processes remained.

The regenerated terrain acceptance captures were also visually inspected after the gradient-noise change. The close and normal views show irregular material boundaries and no obvious large rectangular material blocks in these captures. The test ran with gameplay overlays and combat objects disabled, so the remaining check is the same terrain in a normal, moving match recording.

## Building-cache artefact investigation — 2026-10-14

Adjacent frames 1029–1031 of the supplied 30.21-fps recording confirm a one-frame building visual change at about 34.1 s: frame 1030 shows a cyan, detailed facility where frames 1029 and 1031 show the same muted building. The terrain, HUD, cursor, and camera remain stable. This establishes a real rendered discontinuity in the recording, but does not by itself prove whether the cache, a placement preview, or another draw path supplied that frame.

The building painter now records the model source it actually instantiated (faction GLB, standard GLB, or procedural fallback). Each cached texture stores its key, kind, owner, faction, source path, and texture instance. Exact hits and same-family fallbacks validate that provenance before drawing; a mismatched kind/faction/source/texture association is evicted. Queued painter snapshots are checked against the key that requested them. Optional match diagnostics can be enabled with `SOLARIT_BUILDING_CACHE_DIAGNOSTICS=1`; on renderer teardown they write the frame-by-frame requests, chosen keys, actual source paths, and fallback reasons to `user://building_visual_events.json` (or the path named by `SOLARIT_BUILDING_CACHE_DIAGNOSTICS_PATH`).

The focused `building_asset_states` test checks snapshot-key reconstruction and rejects mismatched key/model provenance. It passes. This is a targeted cache-integrity safeguard and diagnostic path; it does not yet establish the root cause of the recorded frame, nor prove the flicker absent in a normal match. Capture a new instrumented gameplay sequence before describing the original artefact as fixed.

The rendered `harvester_runtime_visual` fixture also exercised the optional logger: it wrote 192 building events to the configured `user://` JSON file, including 185 exact cache hits, 5 initial procedural fallbacks, and 2 same-family fallbacks. No cache identity rejection occurred in this fixture. This validates the data path but does not recreate the older building flash.

## Harvester cargo legibility follow-up — 2026-10-14

The normal-zoom runtime captures showed that the numeric cargo display and crystals were doing most of the fill-state communication. The Kobalt, Wanderpakt, and Prisma Blender harvester sources now carry four larger emissive hopper-side gauge marks, parented to the existing cargo stages. The same quantized cargo state that reveals the ore also reveals the appropriate gauge marks; the camera, movement, harvest rules, cache, and vehicle dimensions are unchanged. The three `.blend` sources and their matching GLBs were rebuilt with Blender 5.2.2.

`tests/harvester_cargo_visual.gd` now also checks that the four gauge stages follow the 0/25/50/75/100% cargo states for all three imported models, in addition to its 160×160 cache-pixel comparisons. It passes. The measured empty-to-full difference remains 0.0123 for Kobalt, 0.0484 for Wanderpakt, and 0.0512 for Prisma; the smallest adjacent quarter-step is 0.0020 for Kobalt. The Full-HD `harvester_runtime_visual` also passes 24/24 checks through loaded return, refinery approach, unloading, and resumed work. These are rendered fixture results, not a long real-match performance or 30–45-minute audio acceptance run.

The Kobalt indicator reads subtly at the normal gameplay cache size; its low difference is still above the existing visual threshold. A real match review remains necessary to decide whether the amber/cyan side marks are clear enough under field crystals, combat clutter, and different camera headings. Audio remains candidate material pending human listening; this visual change does not close that gate.

The gameplay-space cargo meter was also widened from 36 to 72 world units and thickened from 3 to 7 units for its fill. This keeps the same two rectangle draw calls, resource fraction, and return/unload color, while making a quarter-full load occupy more pixels at normal zoom. The regenerated 1920×1080 `harvester_runtime_loaded.png` shows the `54 / 240` load and cyan fill more clearly; the close-up capture shows the same bar at `61 / 240`. This is still a selected runtime fixture with nearby crystals, so the unselected unit and real combat clutter need human review before calling cargo legibility accepted.

## Harvester cargo meter size and verification — 2026-10-15

After reviewing the regenerated Full-HD capture, the 48-unit meter remained too narrow at the normal game zoom. It is now 72 world units wide, with a 9-unit backing and 7-unit fill; the same cargo fraction, state colors, and two draw calls are retained. The updated `test-output/harvester_runtime_loaded.png` shows the 54/240 fill more clearly. This is a selected fixture, and the meter still needs an unselected real-match readability check.

Focused verification on 2026-10-15 passed: `harvester_runtime_visual.gd`, `harvester_cargo_visual.gd` (all three faction GLBs and five load stages), and `authored_assets.gd`. The Drift Bulwark warning came from a stale local Godot import cache dated 2026-10-11, not from its current GLB; its embedded texture URI and current Roughness resource path are valid. Removing only that generated `.godot/imported` scene/MD5 pair forced a fresh import. The post-import runtime test passed with an empty stderr log, and the rebuilt import cache is dated 2026-10-15. `git diff --check` passed; no Godot processes remained.

## Construction-pose transition follow-up — 2026-10-14

The prior-pose safeguard now also handles construction-stage changes. If a building changes from foundation to frame (or another construction stage) before that stage's 3D cache pose is ready, the renderer reuses only that same entity's last validated pose, provided its kind, owner, faction, orientation, source and texture identity still match. The phase transition can no longer fall through to the procedural building solely because the construction-stage key changed. `building_asset_states.gd` covers both the valid same-entity fallback and rejection across owners/factions.

The visual stability test's unchanged 1920x1080 assertion initially exposed that Godot's windowed client area was 1920x1061 on this desktop. Its test launch now explicitly requests fullscreen at 1920x1080; the assertion remains exact. The Visual group passes 10/10, RendererCache passes 6/6, Audio passes 5/5, and the focused harvester runtime check passes. The historical one-frame flash has still not been reproduced in a fresh normal match, so this is a targeted prevention path rather than proof of its original cause.

## Cache-eviction fallback follow-up — 2026-10-14

The building cache had a specific fallback stability gap: when LRU eviction removed a family's preferred pose, its fallback pointer was cleared even when another valid texture from that same semantic building family remained cached. A subsequent pose miss could therefore fall through to the procedural building renderer until the requested 3D pose finished baking. This is a plausible one-frame visual switch, but it has not been proven as the cause of the recorded 34.1-second video event.

The renderer now repairs the family's fallback pointer from the most recently used compatible cached pose immediately after eviction or stale-entry rejection. Cache identity checks still prevent crossing building kind, faction, owner, model source, or texture instance. Optional diagnostics also record cache eviction, replacement fallback, rejected snapshot keys, and completed pose sources.

`tests/building_asset_states.gd` now simulates eviction of a preferred pose while another valid pose for the same factory family remains, and verifies the other 3D pose is returned instead of the procedural fallback. The focused test passed, followed by the full local regression on 2026-10-14: 51/51 PASS, including Multiplayer; no Godot test processes remained. This proves the eviction recovery path and regression suite, not that the old video event was reproduced or visually eliminated. A match captured with the diagnostics enabled is still needed to close that last verification.

## Building-pose visual evidence — 2026-10-14

`building_visual_stability.gd` now verifies that each faction's cached idle factory pose contains nontrivial rendered pixel/color detail, not just a non-null texture or matching metadata. The 600-frame test also writes individual 640×640 cache-pose images at idle, production, four construction phases, and queue/gate transitions. `test-output/building_phase_contact_sheet.png` compares Kobalt, Wanderpakt, and Prisma in the same renderer camera; it confirms visibly different factory silhouettes and that the foundation/frame/commissioning rig renders.

The separate 1920×1080 root-viewport captures from this isolated script do show the test factory, so they verify its in-world compositing in the isolated renderer. They are not a replacement for a fresh normal-match recording. The direct cached 3D pose captures and per-frame cache identity checks support cache-render and state-stability claims only. The original flicker from the supplied older video remains un-reproduced after the fallback fixes; a new match video with cache diagnostics is still required to claim that the historical artifact is fixed.


## Frame-accurate review of supplied match recording — 2026-10-15

FFprobe reports `12-10-2026_16-32-44.mp4` as 97.5449 seconds, 1912×1016, H.264 video with average 30.21 fps and AAC audio. FFmpeg extraction of adjacent frames confirms the already reported construction/building discontinuity precisely: frame 1029 at 34.054533 s shows the ordinary core; frame 1030 at 34.090900 s replaces it for one frame with a large cyan factory-like model at the core location; frame 1031 at 34.127267 s returns to the ordinary core. The red placement preview remains near the cursor in the upper-right throughout this interval. The frame change is proven; its originating draw path is not proven from the video alone.

The sampled adjacent-frame strips around 72.7–73.1 s, 74.1–74.5 s, 82.6–83.0 s, and 85.4–85.8 s show the factory construction/commissioning animation progressing, without the same isolated oversized building overlay in those windows. These short windows do not prove the entire recording is artifact-free. The updated `building_visual_stability.gd` then passed 600 rendered frames for each of the three faction factories, with exact cache keys and model provenance, no queued pose misses, and a current Full-HD in-world factory capture. This supports the cache-protection path but does not replay the placement sequence from frame 1030; the historical flash cannot yet be called fixed until a fresh post-change match video is checked.

## Bauvorschau-/Baukern-Überlagerungstest — 2026-10-15

`building_visual_stability.gd` now also renders a Kobalt-, Wanderpakt- and Prisma-Baukern with the factory placement preview moving through four separated cells and rotations. It prewarms all eight animated core poses, checks the core's exact cache identity on each sample, and compares the actual 380×380 Full-HD root-viewport pixel region around the core against a no-preview baseline. For all three factions the pixel region stayed identical at every preview position, with no cache fallback or pose miss. The global heat-shimmer overlay is disabled only during this pixel equality assertion because its time-driven shader intentionally alters the whole screen between captures; gameplay rendering is unchanged.

The focused Vulkan/RTX 3060 run passed: `Test-Solarit.ps1 -Test building_visual_stability` — **9,343 checks, 0 failures**, 24.03 s. This verifies the current separated placement-preview scenario and cache identity. The exact one-frame event in the older user recording remains without a fresh post-change match recording, so this targeted pass does not by itself prove that historical incident fixed.

## Main-game viewport placement check — 2026-10-15

`visual_showcase.gd` now also drives the real `scenes/main.tscn` viewport in both display modes requested for Full HD: 3D Full HD and classic 2D Full HD. It asserts a 1920×1080 root, 1530×944 game viewport, full-size container with no retro shrink, and the expected 2D/3D mode flags. In each mode it captures the core's screen region and checks it again while moving and rotating the factory placement preview through four distant cells. The comparison waits for two identical baseline frames after a mode switch, then retains byte-exact equality at every preview position. The 2D Full-HD review image is `test-output/industrial_2d_full_hd_placement_review.png`. The pixel comparison disables only the full-screen time-driven heat layer for repeatability. Failures are explicitly counted, save baseline/preview crops, and return a failing process code rather than relying on Godot's log-only `assert` behavior. One earlier Visual-group run reported five changing core regions; an isolated rerun, a full group before baseline settling, and the latest full group after baseline settling all passed. This intermittent fixture result did not produce a saved mismatch image, so it does not establish a product overlay bug or prove it fixed. The latest Visual group passed 11/11 on Vulkan/RTX 3060; no Godot process remained. The engine emitted transient low-FPS warnings while the cold visual fixture loaded/captured; those are not a controlled performance measurement. This remains a fixture and not a fresh match recording; the historical video flash still needs post-change in-match verification.
# Abnahmefortsetzung — 2026-10-15

- Ein Vollregressionslauf auf Vulkan/RTX 3060 endete nach 52 Tests mit **52/52 PASS** (Core 4, Simulation 2, Mission 2, Gameplay 8, Save/Load 2, Profil/Highscore 2, Audio 5, UI 5, Visual 11, RendererCache 6, Performance 2, Multiplayer 3). Der API-Test benötigte lokalen Loopback-Zugriff; ohne diesen blockierte Windows mit `WinError 10013`. Nach dem Lauf waren keine Godot-Prozesse übrig. `git diff --check` war sauber; Git meldete nur bestehende LF/CRLF-Hinweise.
- Ein zuvor sporadischer UI-Testfehler war ein Fehler des synthetischen Klickhelpers: `screen_world()` zieht `renderer.visual_offset` (Treffer-/Kameraschütteln) ab, während der Test diesen Versatz bei der Umrechnung von Welt- nach Viewportkoordinaten nicht addierte. Dadurch konnte ein Klick 120 Weltpunkte neben seinem Ziel landen. Der Testhelper gleicht den Versatz jetzt korrekt aus; Move-, Harvest- und Sammel-Assertions bleiben unverändert.
- Der Full-HD-Platzierungsvergleich hatte zwei Ziele bei `origin.x - 15`, die beim Testkern außerhalb der Karte lagen. Der Test verwendet jetzt weit entfernte, gültige Zellen und prüft ihre Gültigkeit ausdrücklich; die pixelgenaue Kernregion-Gleichheit bleibt unverändert. `visual_showcase.gd` und anschließend alle 11 Visual-Tests bestanden.
- Drei Vollqualitäts-40-Fahrzeugläufe zeigten im obersten 1% der Frames höhere WorldRenderer-, Fahrzeug- und Simulationskosten; Pose-Misses waren dort nicht erhöht und es gab keine Posen-Erzeugungen oder GPU→CPU-Readbacks. Die Einzelwerte und Grenzen der nicht isolierten Frame-Timer stehen in `docs/MOVING_BATTLE_BENCHMARK_2026-10-14.md`.
- Audioassets, adaptive Faction-Musik und Voice-Kandidaten bestehen die technischen Audiodaten-/Integrationsprüfungen. Die kreative Hörabnahme der Kandidaten bleibt offen; der Audio-Release-Gate markiert sie weiterhin als `pending`. Damit sind sie ausdrücklich noch keine final freigegebene Studio-Musik oder Sprecherbesetzung.

## Harvester-Bewegungsabnahme — 2026-10-15

`tests/harvester_runtime_visual.gd` zeichnet zusätzlich je 24 benachbarte Bilder während `HARVEST` und `UNLOAD` auf. Jeder Einzel-Frame stammt aus einem bei 1920×1080 gerenderten Match; zur Bild-für-Bild-Prüfung wird das Spielfeld auf 900×700 Pixel ausgeschnitten. Die Testspur schreibt pro Bild den Harvest-Zustand, Ladung, Weltposition, Winkel und Geschwindigkeit. FFmpeg kodiert daraus je einen 2-Sekunden-H.264-Clip mit 12 fps; FFprobe bestätigt 24 Frames bei 900×700. Das ist ein gezielter Animationstest und kein FPS-Benchmark.

In der Harvest-Sequenz bleiben alle 24 aufgenommenen Frames im Zustand `HARVEST`, während die Ladung von 36 auf 160 steigt. Die frameweisen Kontaktblätter zeigten, dass Ladungsbalken und mechanische Kopfbewegung zwar vorhanden sind, der eigentliche Kristallfluss bei normalem Zoom aber zu schwach war. Der WorldRenderer zeichnet nun vier klarere, gerichtete Solarit-Splitter samt schmalem Förderstrom von der Ressourcenzelle zum Einzug. Framerate, Fahrzeuggeometrie, Pose-Key und Simulation bleiben unverändert.

In der Entladesequenz sinkt die Ladung in den ersten acht Frames von 155 auf 11; anschließend fährt der Sammler zurück ins Feld, dreht sichtbar und nimmt die Ernte wieder auf. Der Test bestätigt damit den Zustand- und Ladungsübergang im laufenden gerenderten Match. Er belegt keine vollständige Langzeit- oder Performance-Abnahme.

Die erzeugten Prüfartefakte liegen lokal und werden nicht in das Spielpaket aufgenommen: `test-output/harvester_motion_harvesting.mp4`, `test-output/harvester_motion_unloading.mp4`, die jeweiligen `frames.csv`-Spuren und Kontaktblätter. FFmpeg/FFprobe: H.264, 900×700, 12 fps, 24 Frames, 2.0 Sekunden je Sequenz. Der fokussierte `harvester_runtime_visual`-Test bestand nach der Änderung in 15.8 Sekunden.

## Main-game placement capture source follow-up — 2026-10-15

The Full-HD placement stability check occasionally found two small changing regions even after the game and renderer clocks were frozen. The same difference remained when the comparison was moved from the composed root image to the world SubViewport, so the capture compositor was not the cause. The affected pixels align with sparse wind streaks and ground-track details. Their density is intentionally selected from instantaneous FPS via the adaptive VFX tier; changing tiers between captures can add/remove these world-rendered marks without changing placement or simulation state.

`visual_showcase.gd` now compares the 380×380 core crop directly from the 1530×944 world SubViewport and holds the renderer's benchmark VFX override at tier 0 only during the byte-exact placement comparison. This freezes the adaptive detail budget while preserving the highest-detail effects and the exact pixel assertion. The test still independently requires an exact 1920×1080 root, checks both 3D Full HD and classic 2D Full HD, and moves/rotates placement through four distant cells. The focused showcase passed, then the complete Visual group passed with all 11 launched checks returning PASS, including the 600-frame building stability and runtime harvester capture tests. This diagnoses a fixture interaction with FPS-adaptive world decoration; no product placement/caching defect was reproduced by this check. It does not certify composited HUD pixels or replace a fresh normal-match recording.

## Adjacent-frame follow-up on the 12-10 capture — 2026-10-15

FFprobe reports the supplied `12-10-2026_16-32-44.mp4` as 1912×1016 H.264 with variable frame spacing and 97.59 s duration. FFmpeg extracted adjacent video frames around 34 s. At 34.054533 s the extra large cyan facility is absent; at 34.090900 s it appears over the battlefield; at 34.127267 s it is absent again. This confirms a one-frame visual discontinuity in that historical recording. The HUD shows active building-placement mode and a separate red placement ghost at the same time, so the clip alone does not establish whether the extra image came from a placed structure's cache, a stale preview, or another draw path. It predates the current frame-stability changes and is not proof of a present-day defect.

The 600-frame stability fixture now also holds a factory-placement ghost at a fixed Full-HD world position, freezes simulation and visual time, compares its 500×560 rendered world crop with the no-preview baseline, and checks five immediately adjacent frames for byte-identical pixels. The preview must visibly alter its crop, guarding against a vacuous equality test. Current Vulkan/RTX 3060 result: **9,427 checks, 0 failures** across Kobalt, Wanderpakt and Prisma; each factory also retains its existing 600-frame production/construction identity checks. The three preview captures are `test-output/building_preview_forge.png`, `building_preview_drift.png`, and `building_preview_lumen.png`.

This strengthens the deterministic preview/cache regression but does not recreate the user's old interactive cursor sequence. A fresh post-change normal-match recording is still needed to close that visual acceptance item; the historical frame is neither dismissed as encoding noise nor claimed fixed.

## Placement preview stale-cell guard — 2026-10-16

FFmpeg extraction of three adjacent frames around 34.05–34.13 s from `12-10-2026_16-32-44.mp4` shows the red placement ghost following the cursor in the first and third frames, with a cyan building image briefly appearing over the base at the old map location in the middle frame. In code, selecting a building set `renderer.placement` immediately, while `placement_cell` retained its previous/default value until `_process` received a valid world-pointer position; `_draw` did not distinguish that stale cell from a valid one. This is a reproduced stale-cell rendering defect and matches the location/timing pattern in the video, though the old recording did not capture the cell variable and cannot prove it was the only source of that individual frame.

The renderer now requires `placement_cell_valid` and an in-bounds grid cell before drawing a placement ghost. Starting a new build or loading a saved placement clears validity; the first world-pointer update establishes it. The renderer diagnostic log records the drawn or suppressed preview, building kind, cell, rotation and validity. This prevents the stale-cell overlay while preserving the normal ghost as soon as the cursor reaches the battlefield.

Targeted verification on 2026-10-16 passed: `building_visual_stability.gd` **9,439 checks / 0 failures**, including three-faction pixel equality when the stale cell is placed directly over the core; `visual_showcase.gd` passed its 2D and 3D Full-HD checks; `ui_integration.gd` passed **72 checks / 0 failures**; and the SaveLoad group passed **2/2**. The interactive UI check also verifies a newly selected build starts with an invalid cell. The old interactive sequence has not been recorded again, so a fresh user-scale gameplay capture remains needed to confirm the historical visual symptom is absent outside this deterministic reproduction.

The interactive route now has its own short test, `placement_preview_input.gd`, so it does not depend on the much longer UI suite. It waits for the actual startup pose warm-up, clicks the power-building catalog button through Godot input, and moves the pointer to a different visible map cell. **9 checks passed**. The per-frame renderer diagnostics for three consecutive frames are stored at `test-output/placement_input_frames.json`; each records `cell_valid: true` and the same pointer cell `(23,44)`, while the stale pre-placement cell was different. The test deliberately treats these as renderer-event evidence, not as saved screenshots; the script-mode viewport image readback was black in this environment. A new user-scale video is still required for visual acceptance.

The prior attempt to add that sequence inside `ui_integration.gd` stalled because awaiting `RenderingServer.frame_post_draw` from the synthetic input path did not resume the test coroutine. That wait was removed from the long integration test, which now completes again: **72 checks / 0 failures in 37.7 seconds**. The small standalone test advances two process frames before recording each adjacent render event.

The CI supervisor timeout probe was also rerun independently with `-Group CIHarness -SupervisorSelfTest -HeartbeatSeconds 2`: the slow probe emitted heartbeats, the hanging probe timed out at 10.2 seconds and its recorded child process was terminated, cleanup reported zero owned or Godot processes remaining, and the follow-up probe passed. `Test-Solarit.ps1` now accepts `CIHarness` as a group, guards absent PID-file lists, and holds the launched process handle until its exit code has been read. A separate attempt to run all tests through the self-test switch stopped at the API test because this local Windows sandbox denies the loopback socket (`WinError 10013`); this does not establish a product failure, and the full regression still needs a permitted environment.

## Harvester adjacent-frame review — 2026-10-16

The live-mission acceptance fixture captured 24 consecutive 1920×1080 rendered frames during harvesting and 24 around refinery unloading. FFmpeg assembled review clips at 12 fps from these consecutive game frames; FFprobe confirms 900×700 crops, 12 fps, two seconds each. The clips are `test-output/harvester_harvesting_motion.mp4` and `test-output/harvester_unloading_motion.mp4`; 6×4 contact sheets and per-frame state/position/cargo telemetry are stored beside them.

The harvest sequence shows the stationary working state while cargo rises from 36 to 158.7; its vehicle-region mean adjacent-frame RGB difference is 4.45/255 over 23 pairs, with a 5.16 maximum. In the unloading sequence, rows 0–7 remain at the refinery while cargo drops from 154.7 to 10.7; rows 8–14 show departure and rows 15–23 show resumed harvesting. That sequence's vehicle-region difference ranges to 43.13/255 because the vehicle moves and changes state; the entire 900×700 play-area mean remains at or below 1.13/255 per adjacent pair. No isolated full-frame flash appears in these short fixture captures.

This is direct evidence that harvesting, unloading, departure, and resumed work are rendered in adjacent frames, rather than inferred from isolated screenshots. It does not verify the older user-recorded flicker event, replace a fresh 30–45 minute match review, or establish that cutter/feed motion is sufficiently prominent to a human at normal zoom. These are test-generated samples, not a new manually played match recording.

The current complete local regression supersedes the earlier “full regression still needs a permitted environment” note above: on 2026-10-16, all 53 tests passed after enabling local loopback for the API suite; all three Multiplayer tests passed and no Godot processes remained.

## Intro-Kamerafahrt — 2026-10-16

Die 3D-Intro-Kamera wird jetzt direkt aus der verstrichenen Introzeit berechnet. Der Shot fährt von der weiten Beckenansicht in eine nähere Kolonieansicht und zieht zum Titel wieder etwas zurück; dadurch hängt die Komposition nicht mehr davon ab, wie viele Zwischenframes ein Test oder ein schneller Rechner verarbeitet. Das fest benannte gerichtete Intro-Licht wirft nun Schatten auf Kolonie, Kristalle und Sammler, damit diese im Becken sichtbaren Bodenkontakt erhalten. Die vorhandenen 3D-Modelle, Szenen und Spielmechanik bleiben unverändert. Die Titelaufnahme prüft zusätzlich den Kameraversatz; der Test prüft, dass das Intro-Licht Schatten aktiviert hat.

Gezielte Prüfung am 2026-10-16: `intro_cinematic.gd` PASS mit Vulkan auf RTX 3060; `frontend.gd` PASS. Die Aufnahmen `test-output/intro_3d_landing.png` und `test-output/intro_3d_title.png` zeigen zwei unterschiedliche Kompositionen und jetzt klar sichtbare gerichtete Bodenschatten. `git diff --check` PASS. Dies ist ein begrenzter Intro-Pass, keine Abnahme des vollständigen Grafik-/Audioauftrags. Die offene Audiofreigabe und ein frisches manuelles Spielvideo bleiben erforderlich.

## Werftbewegung bei Fahrzeugproduktion — 2026-10-16

Der Vergleich der tatsächlich gebackenen Idle- und Produktionsbilder zeigte, dass vier verschiedene Cache-Schlüssel allein keine lesbare Animation garantieren: bei Kobalt änderten sich zuvor nur wenige Pixel. Die drei Fraktionswerften bewegen ihre Produktionsmechanik jetzt sichtbar über die vorhandenen Schienen bzw. Montageflächen. Kobalt fährt den Laufkran über das Hallenbett und klappt die Ausfahrtrampe; Wanderpakt verschiebt seinen Kran und das modulare Chassis; Prisma führt den Montageschlitten über die schwebende Plattform und hebt das Werkstück.

`building_visual_stability.gd` vergleicht nun die tatsächlichen gerenderten Idle- und Produktionsposen in allen drei Fraktionen. Jede aktive Pose muss mindestens 600 abweichende Stichproben bei 2-Pixel-Abstand zeigen; auch jeder Schritt zwischen aufeinanderfolgenden Produktionsposen muss mindestens 250 geänderte Stichproben aufweisen. Cache-Identität und 600 aufeinanderfolgende Full-HD-Frames je Fraktion bleiben geprüft. Die gezielte Vulkan/RTX-3060-Prüfung bestand mit **9.460 Checks, 0 Fehlern**; `git diff --check` bestand. Die Bilder `building_pose_{forge,drift,lumen}_{idle,production_start,gate_release}.png` sichern den visuellen Vergleich. Dies belegt sichtbare Bewegung im Werft-Cache, ersetzt aber noch keine menschliche Abnahme im echten Matchvideo.

Die Fraktions-Gebäudekontaktbögen werden jetzt für die Sichtprüfung auf den vorhandenen Modellbereich zugeschnitten und größer gesetzt; die Graustufenversion behält dabei den transparenten Hintergrund. Der gezielte Lauf `faction_building_contact_sheet.gd` einschließlich des Assemblers bestand. Die aktualisierten Vergleiche liegen in `test-output/faction_building_contact_sheet.png` und `test-output/faction_building_contact_sheet_grayscale.png`.

## Abschlussprüfung Werft, angrenzende Funktionsgebäude und Audio-Gate — 2026-10-16

### Werft: technische und automatisierte Bildprüfung

Der vorherige Schwachpunkt war die geringe Veränderung zwischen IDLE und PRODUKTION, besonders bei Kobalt. Die bestehenden Werftmodelle verwenden jetzt je Fraktion eine eigene Bewegungslogik: Kobalt bewegt seine schwere Hydraulikrampe und den Hallenkran, Wanderpakt seinen offenen modularen Montage-/Rollerrahmen, Prisma den geometrischen Montageschlitten und die schwebende Bauplattform. Aktive Produktionspose, späte Pose und die Ausfahrt werden als klar getrennte Zustände im Building-Renderer ausgewählt; die vorhandene Simulationsübergabe erzeugt ein echtes Fahrzeug, bewegt es durch den Ausfahrtzustand und gibt erst danach die normale Bewegung frei.

`building_visual_stability.gd` rendert alle drei Fraktionen auf Vulkan/RTX 3060, wärmt die genauen Cache-Posen vor und prüft 600 Frames je Fabrik. Die Vollauflösungs-Cachebilder werden für den normalen Spielmaßstab auf 49,23 % verkleinert; das ist die Bildgröße, die der 640-Pixel-Posecache bei 1,25 Spielzoom im Renderer belegt. Ein Pixel gilt in der deterministischen, alle zwei Pixel abgetasteten ROI als verändert, wenn die maximale RGB-Kanalabweichung über 0,06 liegt. Mindestschwellen sind 120 geänderte Stichproben für IDLE→Produktion und 250 für aufeinanderfolgende Produktionsphasen. Gemessene Stichproben IDLE→Produktionspose: Kobalt 286/292/292/262, Wanderpakt 382/426/360/444, Prisma 254/443/460/370. Alle zwölf Messungen lagen über 120; alle drei tatsächlichen Produktionszyklen erzeugten ein fahrendes Fahrzeug, bewegten es durch die Ausfahrt und beendeten den Übergabestatus. Der abschließende Lauf bestand mit **9.643 Prüfungen / 0 Fehlern**.

Zusätzlich speichert der Test je Fraktion vier kurze Folgen mit je 24 direkt aufeinanderfolgenden 3D-Fabrikposen: Leerlauf, Produktion bei 55 %, nahe Fertigstellung bei 95 % und Ausfahrzustand. Die Exporte sind 12 fps und etwa zwei Sekunden lang. FFmpeg `tblend=all_mode=difference` plus `signalstats` vergleicht 22 benachbarte Paare je Clip; die Mittelwerte der Y-Luma-Abweichung (8-bit) sind:

| Fraktion | Idle | Produktion | 95 % | Ausfahrt |
| --- | ---: | ---: | ---: | ---: |
| Kobalt | 0,03 | 0,41 | 0,41 | 0,41 |
| Wanderpakt | 0,02 | 0,65 | 0,65 | 0,88 |
| Prisma | 0,02 | 0,58 | 0,58 | 0,58 |

Das sind Asset-/Poseclips in normalem Spielmaßstab und keine vollständige Matchaufnahme. Sie isolieren Gebäudeanimationen von Partikeln und Hintergrund. Die Simulation bestätigt den echten Ausfahrt- und Bewegungsübergang; in diesem Renderfixture ist das ausfahrende Fahrzeug nicht als vollständige bewegte Matchkomposition mit HUD und Gefecht zusammengesetzt. Eine frische manuelle Matchaufnahme mit mehreren gleichzeitig produzierenden Werften, Kamerafahrt und Kampf bleibt daher **MANUELLE VISUELLE ABNAHME AUSSTEHEND**. Der alte, vom Nutzer aufgenommene Flickerfall ist durch diese Poseprüfung nicht erneut reproduziert.

Die Prüfclips, FFprobe-Metadaten, benachbarten Frame-Differenzwerte und Kontaktbild liegen unter `test-output/factory_gameplay_review/`; das Kontaktbild ist `factory_idle_contact.png`. Es wurden keine Bildschirmbereiche außerhalb der Fabrik-ROI gewertet und keine zufälligen Partikel als Bewegung gezählt. Die automatische Messung ist reproduzierbar, ersetzt aber keine menschliche Lesbarkeitsabnahme im tatsächlichen Match.

### Weitere Funktionsgebäude

`building_asset_states.gd` bestand. Raffinerie, Impulswerk, Signalstation, Servicehangar und Rüstungswerkstatt behalten ihre vorhandenen zweckgebundenen Teile bzw. Zustände (Entladeklappe/Materialfluss, Generatorrotation, Radarrotor, Reparaturarme und Munitions-/Werkzeughub). Diese Gebäude wurden in diesem Pass nicht verändert. Die gezielte Prüfung belegt Assets/Zustände, aber keine separate menschliche Normalzoomabnahme jedes Betriebszyklus.

### Bewegter 40-Fahrzeuge-Benchmark

Der bereinigte Vulkan-Lauf verwendet projektlokales AppData, dieselbe erzeugte Szene und 900 Frames je Messfenster. Die sechs vollständig abgeschlossenen Messfenster waren: adaptive Baseline 80,81 FPS / 12,37 ms Mittel / 24,19 ms 1%-Tail / 28,15 ms Maximum; VFX-limitiert 66,87 / 14,95 / 31,20 / 36,18; Vollqualität 1 54,88 / 18,22 / 32,42 / 36,15; Spuren optimiert 61,77 / 16,19 / 30,03 / 35,13; Vollqualität 2 57,20 / 17,48 / 34,01 / 39,16; Wracks kompakt 55,42 / 18,04 / 36,13 / 41,95. Alle sechs zählten während der Messung **0 neue Posen und 0 Readbacks**. Die Spielszene bewegte sich in 94,8–95,9 % der Samples; die Vollqualitätsfenster erreichten 54,88–57,20 FPS. Die Varianten sind kurze automatisierte Vergleichsläufe und kein manueller Performance-Gate auf längerer Spielsession.

Der folgende Vollqualitätsdurchlauf brach im Benchmark-Harness ab: beim Posecache-Warm-up blieb der Worker aktiv, obwohl der Test ihn eingefroren hatte. In der Folge stoppten Simulationsfortschritt und Fahrzeuge; deshalb sind die danach protokollierten Fenster ungültig und nicht ausgewertet. Der Lauf wurde beendet, und es blieb kein Godot-Prozess zurück. Es wurde keine Grafikqualität reduziert. Dieser unvollständige A/B-Vergleich ist ein bekannter Harness-Restpunkt, kein Nachweis eines Spielabsturzes. Es wurden hier keine reproduzierbaren systematischen >100-ms-Spitzen in den gültigen Vollqualitätsfenstern beobachtet; längere manuelle Spielbeurteilung bleibt dem Testbuild vorbehalten.

### Audio, Freigaben und Abschlussstatus

Die Audio-Hörfreigabe ist zusätzlich an einen SHA-256-Playback-Fingerprint gebunden, der Gain, Bus, Looping, Ducking, Fades/Crossfade, Spatial-Konfiguration und Kriterienversion einschließt. Eine Änderung dieser Konfiguration verwirft alte Hörfreigaben; die Pipeline-Validierung bestand **15/15** und `audio_pipeline.py --check` bestand. Für diesen lokalen Testbuild sind aktive Audioassets vorläufig zum Gameplay-Test freigegeben; der strenge öffentliche Release-Gate bleibt gesperrt, bis die menschliche Hörabnahme erfolgt. Kein Asset wurde als endgültig `approved` markiert.

**Status:** Werft-Produktions-/Ausfahrtlogik und automatisierte Isolationsprüfung bestanden. Finale visuelle und akustische Abnahme ist für den praktischen Gameplay-Test vorgesehen. Lokaler Testbuild, kein öffentlicher Release, kein Tag und keine Versionsänderung.

### Lokaler Testbuild-Abschluss — 2026-10-16

Die komplette Regression auf dem Entwicklungsstand `0.38.29` bestand **53/53**. Dazu gehören Save/Load, UI/Placement Preview, Visual-/Gebäude-/Werftprüfungen, Audiointegration und alle Multiplayer-Tests. Der erste API-Lauf scheiterte unter der eingeschränkten Sandbox an Loopback-Fehler 10013; derselbe unveränderte Lauf bestand nach Freigabe lokaler Sockets vollständig. `audio_pipeline.py --check` und `git diff --check` bestanden. Es blieben keine von den Tests gestarteten Godot-Prozesse zurück.

Der Windows-Export mit eingebettetem PCK wurde erzeugt und 18 Sekunden interaktiv gestartet: Hauptfenster vorhanden, Prozess ansprechbar, kein früher Exit. Der lokale Testbuild liegt in `test-output/local-testbuild-v0.38.29/`. Die aktive Musik, Stimmen und SFX sind dort mit der vom Nutzer genehmigten vorläufigen Kennzeichnung enthalten; keine Hörfreigabe wurde finalisiert. Die praktische Beurteilung von Match, Harvester, Performance, Darstellung und Klang bleibt beim Nutzer.

## Testbuild aktualisiert — 2026-10-17

Der zuvor vorhandene Testbuild vom 16.10. enthielt noch nicht die danach ergänzte Audio-Freigabeverwaltung. Deshalb wurde aus dem aktuellen Arbeitsstand erneut ein lokaler Windows-Export erstellt, ohne Versionssprung oder Veröffentlichung. Version und Exportmetadaten bleiben konsistent auf 0.38.29. Der neue Build enthält ein eingebettetes PCK, ist 346.697.760 Bytes groß und hat SHA-256 `3a09e47ea4aed377478dd1526403092c53e148579873b7f7f59ca5dc0f161c11`.

Der 18-Sekunden-Starttest öffnete das Hauptfenster `SOLARIT RANDSEKTOR 07`; der Prozess blieb ansprechbar und wurde danach sauber beendet. Die vollständige Regression des aktuellen Arbeitsstands bestand mit 53/53 Tests, einschließlich Multiplayer. Die gezielte Audio-Pipeline-Validierung bestand mit 17/17; `audio_pipeline.py --check` bestand. Nach den Tests blieben keine Godot-Prozesse zurück.

Die vorläufige menschliche Hörfreigabe umfasst 222 aktive Assets und gilt nur für den Entwicklungs-/Gameplay-Test. Das öffentliche Audio-Release-Gate bleibt unabhängig davon blockiert: 222 aktive Assets haben noch keine finale Freigabe; zusätzlich sind 213 als Kandidat und 9 aktive Fallback-SFX als Platzhalter markiert. Für dieselben neun Fallback-SFX sind kommerzielle Rechte nicht explizit geklärt; sechs liegen bei 44,1 kHz und drei bei 22,05 kHz statt der geforderten 48 kHz. Weitere 93 inaktive Manifestkandidaten sind pending, blockieren den Release aber nicht.

Der Testbuild liegt unter `test-output/local-testbuild-v0.38.29/SOLARIT-RANDSEKTOR-07.exe`. Er wurde aus Commit `0a882392b182c17faff24e4de517f52d5a0072c0` plus lokalen, nicht committeten Änderungen erstellt. Daher ist er ein praktischer Teststand, kein unveränderlicher Commit-Artefakt. Es wurde kein Tag gesetzt und nichts veröffentlicht; die finale Hörabnahme bleibt ausdrücklich ausstehend.

### Musikübergänge nach menschlichem Matchtest — 2026-10-17

Der Nutzer bewertet Stimmen und SFX als gut, empfindet jedoch die Wechsel zwischen den Musikzuständen als zu schnell. Im `MusicDirector` war die Mindesthaltezeit nur zwei Sekunden; zusammen mit einem 1,25-Sekunden-Crossfade konnten taktische Zustände rasch aufeinanderfolgen. Die Übergangslogik hält normale Zustände nun mindestens 20 Sekunden und verlangt sechs Sekunden stabil anliegenden Folgezustand. Der Crossfade dauert vier Sekunden. Basisalarm sowie Sieg/Niederlage dürfen die Halte- und Stabilitätszeit umgehen und wechseln weiterhin am nächsten musikalischen Takt. Das verhindert kurze Intensitätsschwankungen als Auslöser, ohne wichtige Alarme zu verzögern.

Die gezielte Audio-Regressionsgruppe bestand nach der Anpassung mit 5/5; der Integrationstest prüft die Haltezeit, den stabilen Vorlauf, den längeren Fade und den bar-ausgerichteten Zustandswechsel. Der Wiedergabe-Fingerprint wurde um diese Parameter ergänzt und der Audiomanifest-Index aktualisiert. Damit gilt die vorherige vorläufige Hörbeurteilung für die geänderte Musikübergangskonfiguration nicht mehr als technische Abnahme. `audio_pipeline.py --check` besteht; der öffentliche Audio-Release-Gate bleibt wie zuvor blockiert, jetzt auch mit ausstehender erneuter Hörbeurteilung der Musikübergänge. Kein Musik-, Sprach- oder SFX-Inhalt wurde geändert.

**Nächste Hörprüfung:** Der Nutzer soll die Musik im normalen Match mit dem aktualisierten lokalen Testbuild beurteilen. Stimmen und SFX benötigen wegen der unveränderten Wiedergabeprofile keine neue Beurteilung. Es wurde weiterhin kein Release, Tag oder Versionssprung erstellt.

Der lokale Export wurde mit dieser Einstellung neu gebaut. SHA-256 `f9082adf6b659c383a71c4855d034855c2955dedffd4eb3732b36107fc74f4aa`, Größe 346.676.368 Bytes. Der 18-Sekunden-Hintergrund-Smoke-Test blieb ansprechbar und wurde sauber beendet; kein gestarteter Spielprozess blieb zurück. Die Regression bestand 53/53, einschließlich Multiplayer. Dieser Export ist weiter ein lokaler Testbuild aus nicht committeten Arbeitsänderungen, kein öffentlicher Release.

### GitHub-/Release-Abgleich — 2026-10-17

Der Remote-Branch `codex/release-v0.36.18` steht weiterhin auf `0a882392b182c17faff24e4de517f52d5a0072c0`; der dazugehörige Windows-Workflow Run [38476614856](https://github.com/DieListe01/SOLARIT-RANDSEKTOR-07/actions/runs/38476614856) ist erfolgreich, prüft aber nicht die hier uncommitteten Änderungen der Musikübergänge. Der öffentliche Release in `DieListe01/ASHLINE-Releases` ist weiterhin `v0.38.27`; er enthält Installer, SHA-256-Datei und Manifest für genau diese ältere Version. Der lokale `0.38.29`-Testbuild und seine Musikänderung sind nicht gepusht und nicht durch GitHub Actions geprüft. Daher ist der Gesamtpass nicht veröffentlicht oder abgeschlossen. Vor einem neuen Tag müssen Nutzer-Hörabnahme der geänderten Musik, der strengere Audio-Release-Gate, eine saubere versionskonsistente Release-Korrektur und ein neuer erfolgreicher Workflow auf dem finalen Commit erledigt sein. Diese Bestandsaufnahme ändert keine Tags, Releases oder Update-Metadaten.

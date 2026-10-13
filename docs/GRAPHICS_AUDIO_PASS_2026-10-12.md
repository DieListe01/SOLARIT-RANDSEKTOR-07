# Graphics and audio pass — updated 2026-10-13

## Terrain diagnosis and change

The rectangular surface blocks in the current missions come from authored rectangular `terrain_regions` in the map data. Fog of war is a separate overlay and was not the source of these blocks: the A/B capture revealed every cell for both players and separately disabled terrain detail and the fog pass.

Each shipped mission has a baked 8× supersampled visual material mask with organically eroded rock, dune, crater, and restrained cliff-edge borders. These masks are presentation-only: gameplay cells, collisions, movement costs, build restrictions, resources, and pathfinding remain exact. Cliff interiors and Solarit resource cells are retained. The world sprite compensates for the larger texture so all masks cover the original map dimensions. They load from `assets/terrain_masks/` at mission start instead of synchronously running the expensive generator during gameplay. `tools/generate_terrain_visual_masks.gd` rebuilds the shipped masks from mission data.

The local Vulkan acceptance capture uses the GeForce RTX 3060, revealed terrain, and the normal game renderer. It shows the material boundaries in-game at two zoom levels; the mask generator and committed PNGs are compared for Veyra, Dry Vein, and Khepri, and tests confirm the simulation grid stays unchanged. The capture isolates terrain by disabling fog, detail meshes, units, buildings, combat, tracks, wrecks, health bars, and the heat overlay; a separate material-class image helps distinguish mask shape from shading. Captures are stored in `test-output/terrain_irregular_boundaries.png`, `test-output/terrain_irregular_boundaries_detail.png`, `test-output/terrain_material_only.png`, and `test-output/terrain_mask_classes.png`; the raw mask is `test-output/terrain_visual_mask.png`. A newly introduced mission without a baked mask still falls back to runtime generation and may incur a one-time loading stall until its mask is baked.

## Existing visual systems checked

The visual suite regenerates faction vehicle and building contact sheets and exercises authored assets, construction/production visuals, color identity, and the in-game showcase. The project already contains three faction vehicle families, faction-specific buildings, construction stages, animated vehicle production, the harvester work states, and destruction assets. This pass did not replace those models or change their gameplay stats.

## Audio status

The audio pass replaces the demo catalogue with a 194.7-second title candidate, six tactical states per faction, five stingers, 118 German neural-TTS voice candidates, and curated CC0 SFX. They are integrated and technically validated, but all remain `candidate` / `pending` until the human listening gate is completed. The music is curated and mastered CC0 material, not an original commissioned score; the voices are speaker variants of one TTS model, not studio actors. This is a substantial candidate pass, not final professional audio approval.

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

## Open work

- Commission or supply German voice recordings for the existing line catalog.
- Compose, integrate, and listen-test final faction-specific music; the current demos do not meet final audio acceptance.
- Resolve the remaining block-like ground overlays visible in the current terrain acceptance capture.
- Conduct the full user-facing 2D/3D, harvesting, production, combat, destruction, and Full HD visual/audio acceptance on a real match recording.

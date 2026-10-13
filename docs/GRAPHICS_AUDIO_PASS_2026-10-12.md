# Graphics and audio pass — 2026-10-12

## Terrain diagnosis and change

The rectangular surface blocks in the current missions come from authored rectangular `terrain_regions` in the map data. Fog of war is a separate overlay and was not the source of these blocks: the A/B capture revealed every cell for both players and separately disabled terrain detail and the fog pass.

Each shipped mission has a baked 8× supersampled visual material mask with organically eroded rock, dune, crater, and restrained cliff-edge borders. These masks are presentation-only: gameplay cells, collisions, movement costs, build restrictions, resources, and pathfinding remain exact. Cliff interiors and Solarit resource cells are retained. The world sprite compensates for the larger texture so all masks cover the original map dimensions. They load from `assets/terrain_masks/` at mission start instead of synchronously running the expensive generator during gameplay. `tools/generate_terrain_visual_masks.gd` rebuilds the shipped masks from mission data.

The local Vulkan acceptance capture uses the GeForce RTX 3060, revealed terrain, and the normal game renderer. It shows the material boundaries in-game at two zoom levels; the mask generator and committed PNGs are compared for Veyra, Dry Vein, and Khepri, and tests confirm the simulation grid stays unchanged. The capture isolates terrain by disabling fog, detail meshes, units, buildings, combat, tracks, wrecks, health bars, and the heat overlay; a separate material-class image helps distinguish mask shape from shading. Captures are stored in `test-output/terrain_irregular_boundaries.png`, `test-output/terrain_irregular_boundaries_detail.png`, `test-output/terrain_material_only.png`, and `test-output/terrain_mask_classes.png`; the raw mask is `test-output/terrain_visual_mask.png`. A newly introduced mission without a baked mask still falls back to runtime generation and may incur a one-time loading stall until its mask is baked.

## Existing visual systems checked

The visual suite regenerates faction vehicle and building contact sheets and exercises authored assets, construction/production visuals, color identity, and the in-game showcase. The project already contains three faction vehicle families, faction-specific buildings, construction stages, animated vehicle production, the harvester work states, and destruction assets. This pass did not replace those models or change their gameplay stats.

## Audio status

The installed voice catalog still has no German recordings: every line has an empty asset and is marked `recording_required`. The only Windows system voice found here is Microsoft Zira (`en-US`), so it cannot provide credible German faction voices. Music files named `*_demo.ogg` remain reference compositions, not a final approved soundtrack. Voltage Modular plus SOUND FORGE Audio Studio provide a possible workflow that does not depend on Music Maker, but no production sessions or recordings have been created yet. This pass did not relabel either as finished content.

The demo files are complete arrangements rather than compatible stems. From v0.38.18, tactical states select one full arrangement and transition at bar boundaries; the four complete arrangements are no longer mixed simultaneously. The runtime can now accept authored synchronized stems and fade them by combat state, with a safe fallback to existing arrangements. No authored stems are in the catalog yet, so the shipped music sounds unchanged. The underlying demo compositions remain placeholders and still require replacement and human listening approval.

## Iteration v0.38.25 — role-specific Prisma building structure

The contact sheet exposed a weakness that the earlier asset checklist missed: several Prisma buildings were distinguished mainly by repeated rings and their purpose was hard to read at the shared game camera. All eight Prisma Blender sources and GLBs now have role-specific faceted housing meshes. The factory uses an open four-column production portal with guide rails; the refinery keeps an ore separator bed; the repair facility has service cross-members; and the armory has four angular storage magazines. Shared orbital rings were removed from the factory, repair, armory, and levitation feet. The normal Godot building cache and all named animation pivots are retained. The faction contact sheets render again through the actual painter and are available in `test-output/` after the Visual group.

This iteration improves one building family, not the full requested pass. It does not finish Wanderpakt building quality, all faction vehicle families, new licensed music, or German recorded unit voices. The generated models remain stylized hard-surface Blender assets and need a normal-match approval pass after release.

## Iteration v0.38.26 — make harvester cargo levels read at gameplay scale

The 0/25/50/75/100% comparison showed that cargo existed in all three authored harvesters but some crystals were too tightly grouped and low above the hopper. The Blender sources now distribute larger clusters over a wider footprint and raise the later row; the Wanderpakt and Prisma asset generator has a `--only-harvester` mode so this targeted bake does not rewrite unrelated faction vehicles. The shared cache camera, cargo-state quantization, movement, and gameplay values are unchanged.

The normal 160×160 in-game cache crop now records empty-to-full mean RGB differences of 0.01227 for Kobalt, 0.04845 for Wanderpakt, and 0.05125 for Prisma. The smallest 25%-step difference is 0.00198 (Kobalt); the others are at least 0.00752. `tests/harvester_cargo_visual.gd` now enforces >0.01 empty-to-full and >0.0015 for every adjacent load step. The focused RendererCache test passes on the local RTX 3060 / Vulkan renderer. These images show cache-scale model differences; final confirmation still requires a real match at normal camera zoom.

This visible cargo pass is not the complete graphics/audio brief. Final music, German recorded voices, normal-match capture/inspection, and the remaining asset/production audits remain open.

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

## Open work

- Commission or supply German voice recordings for the existing line catalog.
- Compose, integrate, and listen-test final faction-specific music; the current demos do not meet final audio acceptance.
- Conduct the full user-facing 2D/3D, harvesting, production, combat, destruction, and Full HD visual/audio acceptance on a real match recording.

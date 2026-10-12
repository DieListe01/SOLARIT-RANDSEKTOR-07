# Graphics and audio pass — 2026-10-12

## Terrain diagnosis and change

The rectangular surface blocks in the current missions come from authored rectangular `terrain_regions` in the map data. Fog of war is a separate overlay and was not the source of these blocks: the A/B capture revealed every cell for both players and separately disabled terrain detail and the fog pass.

Each shipped mission now has a baked 8× supersampled visual material mask with organically eroded rock, dune, and crater borders. These masks are presentation-only: gameplay cells, collisions, movement costs, build restrictions, resources, and pathfinding remain exact. Hard cliff boundaries and Solarit resource cells are retained. The world sprite compensates for the larger texture so all masks cover the original map dimensions. They load from `assets/terrain_masks/` at mission start instead of synchronously running the expensive generator during gameplay. `tools/generate_terrain_visual_masks.gd` rebuilds the shipped masks from mission data.

The local Vulkan acceptance capture uses the GeForce RTX 3060, revealed terrain, and the normal game renderer. It shows the organic boundaries in-game at two zoom levels; the mask generator and committed PNGs are compared for Veyra, Dry Vein, and Khepri, and tests confirm the simulation grid stays unchanged. Captures are stored in `test-output/terrain_irregular_boundaries.png` and `test-output/terrain_irregular_boundaries_detail.png`; the raw mask is `test-output/terrain_visual_mask.png`. A newly introduced mission without a baked mask still falls back to runtime generation and may incur a one-time loading stall until its mask is baked.

## Existing visual systems checked

The visual suite regenerates faction vehicle and building contact sheets and exercises authored assets, construction/production visuals, color identity, and the in-game showcase. The project already contains three faction vehicle families, faction-specific buildings, construction stages, animated vehicle production, the harvester work states, and destruction assets. This pass did not replace those models or change their gameplay stats.

## Audio status

The installed voice catalog still has no German recordings: every line has an empty asset and is marked `recording_required`. The only Windows system voice found here is Microsoft Zira (`en-US`), so it cannot provide credible German faction voices. Music files named `*_demo.ogg` remain reference compositions, not final approved soundtrack. This pass did not relabel either as finished content.

The demo files are complete arrangements rather than compatible stems. From v0.38.18, tactical states select one full arrangement and transition at bar boundaries; the four complete arrangements are no longer mixed simultaneously. The underlying demo compositions remain placeholders and still require replacement and human listening approval.

## Validation

- `Test-Solarit.ps1 -Group Gameplay -OverallTimeoutMinutes 20 -HeartbeatSeconds 30`: 8/8 PASS.
- `Test-Solarit.ps1 -Group UI -OverallTimeoutMinutes 20 -HeartbeatSeconds 30`: 5/5 PASS, including update history and version labels.
- `Test-Solarit.ps1 -OverallTimeoutMinutes 90 -HeartbeatSeconds 30`: 47/47 PASS across 12 groups; Multiplayer PASS; no Godot processes remained.
- `tests/terrain_visual_acceptance.gd`: PASS on the RTX 3060 / Vulkan renderer; 8× mask data, cliff/resource preservation, all three generated-versus-baked mission masks, and unchanged simulation terrain checked.
- Terrain-mask generator cost on the local test build is about 300 ms per map; shipped missions avoid this cost by loading baked PNGs. The procedural fallback for a new mission should be removed from the critical path by baking that mission before distribution.
- Candidate `v0.38.15` targeted gates: Visual 9/9, Audio 4/4, Gameplay 8/8, and `update_info.gd` PASS. The complete regression is the final remaining test gate for this candidate.
- PowerShell 7.6.5 is required for the local regression supervisor in this environment: the test supervisor reports valid child exit codes there. Windows PowerShell 5.1 returned a null `Process.ExitCode` for the Python child despite a passing child log; no test or assertion was changed for that host-specific behavior.
- The GitHub release workflow, export, installer, manifest and publish steps remain required before calling this version released.

## Open work

- Commission or supply German voice recordings for the existing line catalog.
- Compose, integrate, and listen-test final faction-specific music; the current demos do not meet final audio acceptance.
- Conduct the full user-facing 2D/3D, harvesting, production, combat, destruction, and Full HD visual/audio acceptance on a real match recording.

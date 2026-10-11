# Destruction and faction visual audit

Audit baseline: v0.38.9, 2026-10-11. This is an in-progress implementation record; it does not declare the full graphics order accepted and does not authorize a release.

## Baseline inventory

- The game has eight authored vehicle roles (`scout`, `raider`, `tank`, `siege`, `harvester`, `lancer`, `scorcher`, `bulwark`) and eight authored building roles (`power`, `refinery`, `factory`, `tower`, `radar`, `repair`, `armory`, `core`).
- Kobalt/Forge uses the standard vehicle and building GLBs. Wanderpakt/Drift and Prisma/Lumen each have separate GLBs for all 8 vehicle roles and all 8 building roles. The assets live under `assets/models/vehicles`, `assets/models/vehicles/factions`, `assets/models/buildings`, and `assets/models/buildings/factions`.
- The live battlefield renders authored 3D assets through SubViewport pose/building caches and then draws their GPU textures in the 2D world view. Vehicle GLBs contain named `DamageLight` and `DamageHeavy` modules. The live vehicle damage states already switch those modules without changing the simulation hitboxes.
- Before this pass, persistent vehicle wrecks and building ruins were made from `draw_polygon`, `draw_line`, and other Canvas calls. No dedicated destroyed/wreck GLBs or destruction `.blend` sources were present in the project asset folders. Editable intact vehicle and building Blender sources do exist under `assets/models/source`.
- Blender is not discoverable through this workspace's `PATH`; the atlas bake therefore uses Godot's existing imported GLBs and Vulkan rendering path. It does not alter the intact source models.
- Existing faction contact-sheet and balance-audit tests cover the three intact model families. Existing construction/harvester captures and the movement benchmark are separate acceptance material; they do not by themselves prove destruction quality.

## Destruction implementation now present

- `tests/bake_destruction_atlases.gd` renders each actual faction/role GLB to a static destruction view. It applies the authored heavy-damage mesh state, a role-specific collapsed pose (including displaced turrets or collector cutter), displaced model armor and 3D debris. The models are captured at 8 vehicle headings or 4 building rotations.
- The six shipped atlases in `assets/rendered/destruction` contain 192 vehicle views and 96 building views: 288 authored-GLB-derived poses total. The atlas bake is an offline asset step; run it with the normal Vulkan renderer, then let Godot import the generated PNG files. Do not run it during a mission.
- Destruction events now retain faction and owner identity. Mission setup loads the atlas resources before combat; a destroyed unit samples a resident texture region. Normal combat does not render a new destruction pose or call `get_image()` for the wreck.
- Persistent ruin saves continue to accept older records without a faction field; those records default to the Forge visual family. The simulation remains authoritative for health and collision; visual wreck size does not change gameplay geometry.
- After the transient blast expires, the display is a static 3D-rendered image, not a live `Node3D` wreck. This matches the low-cost cached-static-render direction, but it is not a full moving 3D structural-collapse animation. There is no rigid-body debris simulation.

## Visual acceptance evidence

- `tests/destruction_assets.gd`: passed; all 288 orientation cells are populated and all six atlases have the expected dimensions.
- `tests/persistent_destruction.gd`: passed, 30 checks, including faction persistence, preloaded atlas families, a 20-vs-20 combat sample, destruction/save-load behavior, and bounded persistent wreck storage. The test capture `test-output/persistence_destruction_modern.png` shows the battlefield after transient effects expire.
- `test-output/destruction_vehicles.png` and `test-output/destruction_vehicles_grayscale.png` compare all eight vehicle roles across Kobalt, Wanderpakt, and Prisma. `test-output/destruction_buildings.png` and its grayscale counterpart compare all eight building roles. These sheets use the same camera per role/faction and confirm visible silhouette differences without relying on faction color.
- `test-output/construction_phases.png` captures the eight Kobalt building roles at 20%, 50%, 80%, 95%, and 100% using the normal building-cache camera and 4× MSAA. The contact sheet confirms separate foundation, frame, montage, commissioning, and complete states. The final commissioning state now has four visible roof beacons; this is a diagnostic image, not a gameplay capture.
- The ruin contact sheets show recognizable collapsed forms and faction silhouettes, but every persistent wreck is still a static texture baked from a modified intact GLB. The harvester carries visible cargo/mechanism features; the screenshots do not yet prove a distinct, animated collection-machine break sequence. Building role-specific functional failures are represented by displaced pivots, charred surfaces and rubble; they do not yet have a short animated structural-collapse sequence or true live 3D runtime ruin.

## Moving-battle GPU acceptance run

Command: normal Godot 4.7.2 Forward+ / Vulkan on NVIDIA RTX 3060; 40 mobile units, retasked groups every four simulation seconds, active movement/separation/combat, 39 initial persistent wrecks, visible VFX and tracks; 900 warmup frames plus 900 measured frames per row. Cache was frozen during every sample. The CSV and per-frame trace are generated under `test-output` by `tests/moving_battle_benchmark.gd`.

| Variant | Avg FPS | Avg frame | 1% worst-frame avg | Max frame | Pose misses | New poses | Readbacks | WorldRenderer |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Baseline adaptive | 86.10 | 11.614 ms | 20.967 ms | 23.206 ms | 848 | 0 | 0 | 5.530 ms |
| VFX limited | 99.87 | 10.013 ms | 19.091 ms | 21.134 ms | 754 | 0 | 0 | 4.600 ms |
| Baseline full quality 1 | 79.67 | 12.551 ms | 22.696 ms | 26.418 ms | 418 | 0 | 0 | 5.928 ms |
| Tracks optimized | 78.22 | 12.785 ms | 21.396 ms | 22.853 ms | 4,201 | 0 | 0 | 6.017 ms |
| Baseline full quality 2 | 74.43 | 13.436 ms | 23.482 ms | 25.782 ms | 1,291 | 0 | 0 | 6.254 ms |
| Compact wrecks | 78.61 | 12.721 ms | 22.602 ms | 29.114 ms | 1,557 | 0 | 0 | 5.976 ms |
| Baseline full quality 3 | 76.58 | 13.058 ms | 23.896 ms | 29.575 ms | 982 | 0 | 0 | 6.120 ms |
| Combined | 95.97 | 10.420 ms | 20.429 ms | 21.727 ms | 1,215 | 0 | 0 | 4.738 ms |

Interpretation: this run reproduced **no** 100-ms hitch, pose bake, or pose-cache readback. Thousands of pose misses in some variants are an important distinction: they all used the nearest resident GPU pose and did not trigger new baking. Every row exceeded 60 average FPS and was above 40 FPS for the average of the slowest 1% of frames. VFX-limited was 20–25 FPS faster than the repeated full-quality baselines; track optimization and compact wrecks alone did not produce a repeatable gain. The combined row improved the timing, but sequential GPU runs show enough spread (baseline 74–86 FPS) that this is directional evidence, not a statistically isolated guarantee. This benchmark still omits an active collector/mining loop, construction, live AI production, and a building-destruction event.

## Remaining acceptance gates

- Add a baked short destruction transition (if it can remain pre-rendered), and inspect all role-specific ruin poses at actual battlefield zoom. The current gameplay capture shows the static results but the visual identity of some small wrecks is still weak at the far zoom.
- Complete a moving long-match benchmark including a harvester mining/delivery loop, live AI production, active construction, and a building destruction. Confirm the 3D-derived persistent building ruin and check the FPS tail over time.
- Full regression suite, multiplayer host/client harness, Windows GitHub workflow, API/import tests, controlled modular extraction from `main.gd` and `world_renderer.gd`, and version/release gates remain outstanding. No release has been prepared from these changes.

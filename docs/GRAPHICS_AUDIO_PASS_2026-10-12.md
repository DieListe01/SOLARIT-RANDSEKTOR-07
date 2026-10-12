# Graphics and audio pass — 2026-10-12

## Terrain diagnosis and change

The rectangular surface blocks in the current missions come from authored rectangular `terrain_regions` in the map data. Fog of war is a separate overlay and was not the source of these blocks: the A/B capture revealed every cell for both players and separately disabled terrain detail and the fog pass.

The terrain shader now uses a stronger two-scale visual domain warp and a restrained surface palette to make soft material boundaries less grid-like. Hard cliff boundaries fall back to the unwarped material index, and simulation terrain, collision, movement costs, build restrictions, and pathfinding are unchanged. The `terrain_detail` benchmark category now disables its sprite overlay as well as the detail meshes, so future A/B captures actually isolate that category.

The A/B captures use the Vulkan renderer on the local GeForce RTX 3060 at the normal game view, with fog fully revealed and terrain details disabled. They are stored in `test-output/terrain_ab_terrain_shader_on.png` and `test-output/terrain_ab_terrain_shader_off.png`. The stronger warp bends several exposed borders, but the rectangular shapes remain clearly visible because the source map masks are still rectangles. A complete removal needs authored irregular masks or a higher-resolution visual material mask; this pass does not claim that remaining artifact is solved.

## Existing visual systems checked

The visual suite regenerates faction vehicle and building contact sheets and exercises authored assets, construction/production visuals, color identity, and the in-game showcase. The project already contains three faction vehicle families, faction-specific buildings, construction stages, animated vehicle production, the harvester work states, and destruction assets. This pass did not replace those models or change their gameplay stats.

## Audio status

The installed voice catalog still has no German recordings: every line has an empty asset and is marked `recording_required`. The only Windows system voice found here is Microsoft Zira (`en-US`), so it cannot provide credible German faction voices. Music files named `*_demo.ogg` remain reference compositions, not final approved soundtrack. This pass did not relabel either as finished content.

## Validation

- `Test-Solarit.ps1 -Group Gameplay -OverallTimeoutMinutes 20 -HeartbeatSeconds 30`: 8/8 PASS.
- `Test-Solarit.ps1 -Group UI -OverallTimeoutMinutes 20 -HeartbeatSeconds 30`: 5/5 PASS, including update history and version labels.
- `Test-Solarit.ps1 -OverallTimeoutMinutes 90 -HeartbeatSeconds 30`: 47/47 PASS across 12 groups; Multiplayer PASS; no Godot processes remained.
- Terrain A/B capture: local Vulkan / RTX 3060, full map reveal and terrain details disabled. The remaining masks are still rectangular.
- The GitHub release workflow, export, installer, manifest and publish steps remain required before calling this version released.

## Open work

- Replace remaining rectangular map material masks with authored irregular visual masks while keeping gameplay terrain exact.
- Commission or supply German voice recordings for the existing line catalog.
- Compose, integrate, and listen-test final faction-specific music; the current demos do not meet final audio acceptance.
- Conduct the full user-facing 2D/3D, harvesting, production, combat, destruction, and Full HD visual/audio acceptance on a real match recording.

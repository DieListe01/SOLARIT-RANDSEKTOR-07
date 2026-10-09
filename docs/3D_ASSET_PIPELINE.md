# 3D asset pipeline

## Current approach

`LowpolyModelFactory` constructs vehicle and building scenes from Godot meshes. `VehicleCachePainter` and `BuildingCachePainter` light those scenes and render them into the existing `SubViewport` cache; the world renderer then draws the cached images into the isometric battlefield. Keep that rendering and world/UI architecture. It provides the established camera, lighting, selection, zoom and performance behavior independent of where a model came from.

Procedural meshes remain useful for early blockouts, inexpensive variants, simple props, and pieces whose shape is naturally parameterized. They also make it easy to create damage states and small gameplay variations. They are a poor long-term source for hero-quality vehicles: the current box/cylinder/prism vocabulary favors rectangular silhouettes, repeated seams, and shallow surface detail. As parts grow, every instance creates many scene nodes and draw submissions. More primitives or material tweaks cannot produce designed armor transitions, convincing track assemblies, layered silhouettes, authored UV detail, or the controlled asymmetry that distinguishes vehicle roles.

## Optional Blender asset slots

The cache painters first look for a matching authored scene and use the procedural model when it is absent. All eight building GLBs currently ship in the project, with their editable source scene and generator:

- `res://assets/models/vehicles/<kind>.glb` for each vehicle kind (`scout`, `tank`, `siege`, `harvester`, `raider`, `lancer`, `scorcher`, `bulwark`)
- `res://assets/models/buildings/<kind>.glb` for each building kind

The building source is `assets/models/source/industrial_buildings.blend`; regenerate its GLBs with Blender 5.2 or newer using `tools/create_building_assets.py`. The script's asset-kit coordinates are X width, Y height and Z depth. Its helper functions convert those coordinates into Blender's Z-up scene before exporting Y-up glTF. Keep this conversion in one place so vertical equipment stays above the roof after import.

The GLB root must be a `Node3D`. Vehicle forward is local **-Z**, the root origin sits on the ground at the center of the hull, and model dimensions should be authored in Godot world units to fit the isometric cache camera. A rotatable weapon assembly should be a child named `Turret`; the cache painter aligns it to the current aim direction. Name a mesh `TeamColor` when its white/base material should inherit the owning faction color. Building roots sit at ground level in the center of their footprint; the `TeamColor` hook works for them too.

The imported model is rendered by the same `SubViewport` and cache as the fallback. It therefore retains the current 2.5D presentation while gaining full 3D silhouettes and Blender-authored topology, UVs, materials, and details. Keep the model's exterior self-contained in its GLB; use a small number of shared PBR materials and appropriately sized textures. Imported clips must have a named animation contract and be sampled at a deterministic cache frame, rather than advanced separately on every visible unit.

Each building role should read from its roof and outline in the elevated battlefield camera: reactor stacks and containment ring for power, a horizontal ore line and exposed conveyor for the refinery, an open crane bay for the factory, a drive-through service gantry for repair, a dish and mast for radar, stacked sealed canisters for the armory, a compact rotating weapon for the tower, and a stepped low bunker for the core. Avoid applying the same roof ribs, luminous corner columns, or solid rectangular shell to every asset; those shared shapes erase role identity at the small cache size.

## First Blender vertical slice: H09 Solarit-Sammler

The working v0.37 branch now contains an editable Blender source at `assets/models/source/harvester.blend` and the in-game import at `assets/models/vehicles/harvester.glb`. Rebuild both with Blender 5.2 or newer using:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --python tools/create_high_end_harvester.py
```

The asset has a tapered faceted hull, distinct operator cab and ore hopper, twin tracked undercarriage, segmented cutter drum, articulated cutter mount, sloped conveyor, hydraulic lines, vents, fasteners, team-color markings, eight cargo stages, and two visible damage levels. The action names are `Idle`, `Move`, `Harvest`, and `Unload`. Harvester movement and work clips are sampled at eight deterministic phases and presented at six cache frames per second; the established renderer still caches 32 body headings. The camera stays fixed through every work state, so unloading cannot make the vehicle appear to reverse. Simulation harvest state, cargo fill, damage, faction tint, heading, and movement select the rendered cache entry; the game continues to use the existing `SubViewport` and screen-space cache.

`VehicleCachePainter` presents the work-facing end of the harvester to make its cutter readable. The authored harvester-only preview is reproducible with the Godot console renderer (without `--headless`, because a real graphics device is needed):

```powershell
& '.\tools\Godot_v4.7.2-stable_win64_console.exe' --path . --script tests/harvester_asset_preview.gd
```

The preview is written to `test-output/harvester_turntable_animation_sheet.png`. Its first four rows show all 32 body headings; the next rows show eight temporal phases each for Move, Harvest, and Unload. The test also compares downsampled 128×128 poses so direction and animation changes are measured near the size used in gameplay. `tests/prototype_25d.gd` verifies GLB import, faction tint, clip selection, distinct work-head transforms, staged cargo and damage meshes, and the procedural fallback.

This is the first production-shaped vehicle asset, not the final asset library. Its low-poly style is deliberately compatible with the game's current isometric scale. Several small fittings are still generated from simple forms by the Blender script; although the main hull, cutter, tracks, and details are real Blender mesh data and a GLB is shipped in the project, the model does not yet use hand-authored UV texture maps, sculpted surfaces, or a texture-baked material set. Buildings now have their own authored GLBs, but remain stylized low-poly modular assets; they do not yet have baked surface textures, extensive material wear, or animated production machinery. In-game review must check the silhouette at the actual cache size, not only in Blender's viewport.

## Long-term recommendation

Use Blender-authored GLB models for the eight distinctive combat/economy vehicles and the most visible buildings. Keep procedural meshes as blockout/fallback art and for small reusable hardware. The corrected Blender asset kit improves role identity while preserving the current pipeline; the remaining ceiling is the intentionally simple low-poly topology and untextured materials. Overcome that ceiling incrementally with artist-directed meshes, UV-unwrapped trim/weathering atlases, and targeted mechanical animation such as the refinery conveyor and the factory crane. Validate every asset in the model gallery and at gameplay resolution before adding more mesh detail; preserve the established `SubViewport` rendering pipeline.

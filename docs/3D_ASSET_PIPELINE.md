# 3D asset pipeline

## Current approach

`LowpolyModelFactory` constructs vehicle and building scenes from Godot meshes. `VehicleCachePainter` and `BuildingCachePainter` light those scenes and render them into the existing `SubViewport` cache; the world renderer then draws the cached images into the isometric battlefield. Keep that rendering and world/UI architecture. It provides the established camera, lighting, selection, zoom and performance behavior independent of where a model came from.

Procedural meshes remain useful for early blockouts, inexpensive variants, simple props, and pieces whose shape is naturally parameterized. They also make it easy to create damage states and small gameplay variations. They are a poor long-term source for hero-quality vehicles: the current box/cylinder/prism vocabulary favors rectangular silhouettes, repeated seams, and shallow surface detail. As parts grow, every instance creates many scene nodes and draw submissions. More primitives or material tweaks cannot produce designed armor transitions, convincing track assemblies, layered silhouettes, authored UV detail, or the controlled asymmetry that distinguishes vehicle roles.

## Optional Blender asset slots

The cache painters first look for a matching authored scene and use the procedural model when it is absent:

- `res://assets/models/vehicles/<kind>.glb` for each vehicle kind (`scout`, `tank`, `siege`, `harvester`, `raider`, `lancer`, `scorcher`, `bulwark`)
- `res://assets/models/buildings/<kind>.glb` for each building kind

The GLB root must be a `Node3D`. Vehicle forward is local **-Z**, the root origin sits on the ground at the center of the hull, and model dimensions should be authored in Godot world units to fit the isometric cache camera. A rotatable weapon assembly should be a child named `Turret`; the cache painter aligns it to the current aim direction. Name a mesh `TeamColor` when its white/base material should inherit the owning faction color. Building roots sit at ground level in the center of their footprint; the `TeamColor` hook works for them too.

The imported model is rendered by the same `SubViewport` and cache as the fallback. It therefore retains the current 2.5D presentation while gaining full 3D silhouettes and Blender-authored topology, UVs, materials, and details. Keep the model's exterior self-contained in its GLB; use a small number of shared PBR materials and appropriately sized textures. Imported clips must have a named animation contract and be sampled at a deterministic cache frame, rather than advanced separately on every visible unit.

## First Blender vertical slice: H09 Solarit-Sammler

The working v0.37 branch now contains an editable Blender source at `assets/models/source/harvester.blend` and the in-game import at `assets/models/vehicles/harvester.glb`. Rebuild both with Blender 5.2 or newer using:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --python tools/create_high_end_harvester.py
```

The asset has a tapered faceted hull, distinct operator cab and ore hopper, twin tracked undercarriage, segmented cutter drum, articulated cutter mount, sloped conveyor, hydraulic lines, vents, fasteners, team-color markings, eight cargo stages, and two visible damage levels. The action names are `Idle`, `Move`, `Harvest`, and `Unload`. Each cache render selects a clip and seeks to one of four stable phases. Simulation harvest state, cargo fill, damage, faction tint, heading, and movement select the rendered cache entry; the game continues to use the existing `SubViewport` and screen-space cache.

`VehicleCachePainter` presents the work-facing end of the harvester to make its cutter readable. The authored harvester-only preview is reproducible with the Godot console renderer (without `--headless`, because a real graphics device is needed):

```powershell
& '.\tools\Godot_v4.7.2-stable_win64_console.exe' --path . --script tests/harvester_asset_preview.gd
```

The previews are written to `test-output/harvester_idle.png`, `harvester_moving.png`, `harvester_harvesting.png`, and `harvester_unloading.png`. `tests/prototype_25d.gd` verifies GLB import, faction tint, clip selection, distinct work-head transforms, staged cargo and damage meshes, and the procedural fallback.

This is the first production-shaped asset, not the final asset library. Its low-poly style is deliberately compatible with the game's current isometric scale. Several small fittings are still generated from simple forms by the Blender script; although the main hull, cutter, tracks, and details are real Blender mesh data and a GLB is shipped in the project, the model does not yet use hand-authored UV texture maps, sculpted surfaces, or a texture-baked material set. The remaining vehicles and all buildings still use the Godot mesh fallback. The vertical slice therefore proves the asset route and integration seam; further artist-directed modeling and in-game readability review are required before calling the whole graphics modernization complete.

## Long-term recommendation

Use Blender-authored GLB models for the eight distinctive combat/economy vehicles and the most visible buildings. Keep procedural meshes as blockout/fallback art and for small reusable hardware. Bring assets in by role, validate their scale and headings in the existing model gallery and gameplay screenshots, then add explicit hooks only for shared needs such as team tint, damage states, track animation, and turret articulation. This hybrid path improves authored quality without replacing the established `SubViewport` rendering pipeline.

# 3D asset pipeline

## Current approach

`LowpolyModelFactory` constructs vehicle and building scenes from Godot meshes. `VehicleCachePainter` and `BuildingCachePainter` light those scenes and render them into the existing `SubViewport` cache; the world renderer then draws the cached images into the isometric battlefield. Keep that rendering and world/UI architecture. It provides the established camera, lighting, selection, zoom and performance behavior independent of where a model came from.

Procedural meshes remain useful for early blockouts, inexpensive variants, simple props, and pieces whose shape is naturally parameterized. They also make it easy to create damage states and small gameplay variations. They are a poor long-term source for hero-quality vehicles: the current box/cylinder/prism vocabulary favors rectangular silhouettes, repeated seams, and shallow surface detail. As parts grow, every instance creates many scene nodes and draw submissions. More primitives or material tweaks cannot produce designed armor transitions, convincing track assemblies, layered silhouettes, authored UV detail, or the controlled asymmetry that distinguishes vehicle roles.

## Optional Blender asset slots

The cache painters first look for a matching authored scene and use the procedural model when it is absent:

- `res://assets/models/vehicles/<kind>.glb` for each vehicle kind (`scout`, `tank`, `siege`, `harvester`, `raider`, `lancer`, `scorcher`, `bulwark`)
- `res://assets/models/buildings/<kind>.glb` for each building kind

The GLB root must be a `Node3D`. Vehicle forward is local **-Z**, the root origin sits on the ground at the center of the hull, and model dimensions should be authored in Godot world units to fit the isometric cache camera. A rotatable weapon assembly should be a child named `Turret`; the cache painter aligns it to the current aim direction. Name a mesh `TeamColor` when its white/base material should inherit the owning faction color. Building roots sit at ground level in the center of their footprint; the `TeamColor` hook works for them too.

The imported model is rendered by the same `SubViewport` and cache as the fallback. It therefore retains the current 2.5D presentation while gaining full 3D silhouettes and Blender-authored topology, UVs, materials, and details. Keep the model's exterior self-contained in its GLB; use a small number of shared PBR materials and appropriately sized textures. If a vehicle needs moving parts, add an explicit animation contract and drive it from the cached simulation frame before treating the animation as production-ready. The current seam handles hull heading, an optional `Turret` heading, and automatic team tint on `TeamColor` meshes; arbitrary GLB animation playback and runtime damage material swapping still need dedicated hooks.

## Long-term recommendation

Use Blender-authored GLB models for the eight distinctive combat/economy vehicles and the most visible buildings. Keep procedural meshes as blockout/fallback art and for small reusable hardware. Bring assets in by role, validate their scale and headings in the existing model gallery and gameplay screenshots, then add explicit hooks only for shared needs such as team tint, damage states, track animation, and turret articulation. This hybrid path improves authored quality without replacing the established `SubViewport` rendering pipeline.

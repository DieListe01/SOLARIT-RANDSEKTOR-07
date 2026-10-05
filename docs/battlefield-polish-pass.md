# SOLARIT: RANSEKTOR 07 — Battlefield polish

This pass improves battlefield readability and full-HD performance without changing simulation balance or save compatibility.

## Changes

- Reuses one terrain warp calculation for center and edge samples and removes two extra full-screen noise evaluations. Chunked terrain and Solarit meshes retain the added surface detail.
- Limits the vehicle-art cache to 16 pending textures and renders turret snapshots at 32 angles. When the cache is busy, it displays the nearest available snapshot instead of queuing an unbounded series of nearly identical textures.
- Under severe frame pressure, omits short-lived per-shot muzzle decoration while preserving projectiles, hit effects, and major explosions.
- Keeps damaged/selected unit and structure health bars legible, spaces group orders by unit footprint, and reduces crowd overlap.
- Prevents stale entity IDs from leaving an empty hover panel. Catalog tooltips show both missing prerequisites and insufficient Solarit; production priority moves a chosen vehicle directly behind the current job.
- Keeps the tactical map within the battlefield frame and accepts older saves without optional bookmark data.
- Removes fog-hidden and off-screen units from the renderer's sort, interpolation, effects, sprite, selection and health-bar passes. They continue to simulate normally. F3 and low-FPS CSV logs report fog and off-screen cull counts separately.
- Rasterizes the explored minimap terrain and resource overlay into a map-sized texture, refreshed at the existing 5 Hz minimap update rate.

## Verification

Godot 4.7.2; Windows; NVIDIA GeForce RTX 3060; 1920×1080; V-Sync disabled for measurement.

| Scenario | Earlier measurement | After pass |
| --- | ---: | ---: |
| 40 stationary units | 101 FPS | 111 FPS |
| 40 units in active battle | 34 FPS | 64 FPS |

The active battle sample reported 35 visible units, 209 active visual effects, and 27.5 ms p95 frame time. The 200-unit simulation test averaged 14.6 ms per tick and peaked at 24.1 ms. These numbers describe the test machine and benchmark scene, not a guarantee for every system.

The hover-panel edge cases passed: valid entities show a name and stale/missing entities clear and hide the panel. Catalog, production, persistent-destruction, combat-VFX, campaign, frontend, and multiplayer round-trip checks also passed. `Test-Solarit.ps1` completed its gameplay/network checks, but its final cleanup returned Windows `Get-CimInstance` access denied while inspecting child processes; no game assertion failed.

The title-audio file currently in the working tree is 24 seconds long, so the frontend duration check was aligned to that existing asset. Audio files were not included in this pass package.

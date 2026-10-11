# Windows regression inventory and diagnostics

The release regression remains sequential and fail-fast. `Test-Solarit.ps1`
retains every invocation that was in the historical full-suite script; it adds
process supervision and selection options, not test skips or weaker assertions.
Run the full suite locally with `.\Test-Solarit.ps1`, a group with
`.\Test-Solarit.ps1 -Group Visual`, or one existing test with
`.\Test-Solarit.ps1 -Test faction_vehicle_contact_sheet`.

## Current mapping

| GitHub step/group | Existing tests in that group | Runtime/outputs |
|---|---|---|
| Core | `crystal_atlas.py`, `server/test_solarit_api.py`, `player_profile.gd`, `regression.gd` | Python and Godot headless; API tests use Python unittest, a temporary SQLite database, and an ephemeral loopback HTTP port; profile tests write under the local app-data override. |
| Simulation | `mission_system.gd`, `playthrough.gd` | Godot headless; deterministic simulation/mission state. |
| Gameplay | `faction_vehicle_balance.gd`, `repair_details.gd`, `rotation_sound.gd`, `persistent_destruction.gd`, `battlefield_polish.gd`, `combat_vfx.gd`, `style_consolidation.gd`, `polish_pass.gd` | Mixed headless and rendered-window tests; several capture game-window PNGs; destruction/profile tests write local save data. |
| SaveLoad | `match_recorder.gd`, `factory_production.gd` | Godot headless; save, restore, production queue/exit state. |
| ProfileHighscore | `highscore.gd`, `online_stats.gd` | Rendered high-score UI plus headless/offline stats. Network access to the public stats service is disabled for tests. |
| Mission | `campaign_units.gd` | Godot headless; unlock/progression state. |
| Multiplayer | `network_protocol.gd`, `private_lobby_code.gd`, `Test-Multiplayer.ps1` (`versus.gd`, host/client `network_roundtrip.gd`, and `network_game.gd`) | Headless protocol checks plus local ENet host/client processes; TCP/UDP loopback ports 24651–24652; separate host/client stdout and stderr. |
| Audio | `audio_integration.gd` | Godot headless with bounded signal/state waits. |
| UI | `ui_integration.gd`, `frontend.gd`, `intro_cinematic.gd`, `update_info.gd`, `update_manager.gd` | Godot rendered-window tests; game-window captures; intro/update tests wait for rendered frames and read the rendered image. |
| Visual | `authored_asset_gallery.gd`, `faction_vehicle_contact_sheet.gd` + Python assembly, `faction_building_contact_sheet.gd` + Python assembly, `visual_showcase.gd`, `color_identity.gd`, `factory_production_visuals.gd` | GPU-backed window/SubViewport rendering. Contact sheets and screenshot tests use `RenderingServer.frame_post_draw`, `Texture2D.get_image()` and write PNGs under `test-output/`. |
| RendererCache | `prototype_25d.gd`, `authored_assets.gd`, `destruction_assets.gd`, `building_asset_states.gd`, `factory_production_preview_cache.gd` | Godot headless project tests; some create SubViewports and inspect assets/cache state. Preview-cache coverage checks cache construction and records its diagnostics; it does not convert hardware FPS into a CI pass criterion. |
| Performance | `performance.gd`, `performance_monitor.gd` | Headless CPU simulation throughput test (200 entities × 300 ticks, existing 33.3 ms/tick threshold) plus render-profiler instrumentation checks. The RTX/Vulkan moving-battle FPS benchmark is a separate local hardware release gate. |

Across the suite, Godot and Python tests write per-test stdout/stderr under
`test-output/ci/logs/`. Tests that already produce visual or CSV evidence keep
writing to `test-output/`; the workflow uploads both paths even on failure.
Some game tests use bounded `process_frame` waits; the supervisor also imposes
an external hard deadline if a renderer or awaited signal never returns.

Within the selected regression tests, explicit `SubViewport` use is in
`authored_asset_gallery.gd`, `faction_vehicle_contact_sheet.gd`,
`faction_building_contact_sheet.gd`, and `factory_production_preview_cache.gd`.
These wait for rendered frames, and the contact/gallery tests read back images
to save or validate generated preview output. The additional in-suite PNG
capture tests are `battlefield_polish.gd`, `color_identity.gd`, `combat_vfx.gd`,
`frontend.gd`, `intro_cinematic.gd`, `persistent_destruction.gd`,
`polish_pass.gd`, `repair_details.gd`, `rotation_sound.gd`,
`style_consolidation.gd`, `ui_integration.gd`, `update_info.gd`, and
`visual_showcase.gd`; they use the rendered game window and call
`get_texture().get_image()` before saving. The standalone `render_performance`,
`moving_battle_benchmark`, turntable, and atlas-bake tools are not part of the
current full regression command.

## Supervision and time limits

The default deadlines are 180 seconds for small Python/unit tests, 300 seconds
for ordinary Godot/regression tests, 600 seconds for visual/render-heavy,
playthrough/performance, or multiplayer cases, and 90 minutes for the whole
GitHub job. GitHub Actions continues to run one test group per named step and
sets its virtual Windows display to 1920×1080 before rendered tests, matching
the Full-HD fullscreen assertions without changing the game assertions.
The PowerShell supervisor writes a START marker before launch, then PASS/FAIL
with duration and exit code. At its configured heartbeat interval it reports
the current test, group, PID, child count, log size/mtime, and recent
stdout/stderr. The default local heartbeat is 45 seconds; GitHub Actions passes
30 seconds so hosted visual-test durations produce live heartbeats. A timeout or
failure records process ancestry and log tails in
`test-output/ci/CI-FAILURE-CONTEXT.txt`, then terminates only the supervised
process and its discovered descendants. Multiplayer additionally reports both
peer PIDs/ports and has a bounded 10-minute harness deadline.

The aggregate JSON/text summaries and `$GITHUB_STEP_SUMMARY` show status,
elapsed time, failures/timeouts, and the ten slowest tests. `-Group` and `-Test`
select existing tests without modifying their assertions. Godot's `--headless`
flag is preserved per test; actual GPU FPS is not required from GitHub's
hosted VM.

The 43 existing top-level suite entries retain these individual deadlines
(seconds); the Multiplayer wrapper contains separately supervised Godot cases:

| Group | Test name = seconds |
|---|---|
| Core | `crystal_atlas.py`=180, `server/test_solarit_api.py`=300, `player_profile.gd`=180, `regression.gd`=300 |
| Simulation | `mission_system.gd`=300, `playthrough.gd`=600 |
| Gameplay | `faction_vehicle_balance.gd`=300, `repair_details.gd`=300, `rotation_sound.gd`=300, `persistent_destruction.gd`=300, `battlefield_polish.gd`=300, `combat_vfx.gd`=300, `style_consolidation.gd`=300, `polish_pass.gd`=300 |
| SaveLoad | `match_recorder.gd`=300, `factory_production.gd`=300 |
| ProfileHighscore | `highscore.gd`=300, `online_stats.gd`=300 |
| Mission | `campaign_units.gd`=300 |
| Multiplayer | `network_protocol.gd`=300, `private_lobby_code.gd`=300, `Test-Multiplayer.ps1`=1500 (internally `versus.gd`=180, `network_roundtrip.gd` host+client=600, `network_game.gd` host+client=600) |
| Audio | `audio_integration.gd`=300 |
| UI | `ui_integration.gd`=300, `frontend.gd`=600, `intro_cinematic.gd`=600, `update_info.gd`=300, `update_manager.gd`=300 |
| Visual | `authored_asset_gallery.gd`=600, `faction_vehicle_contact_sheet.gd`=600, `assemble_faction_vehicle_contact.py`=300, `faction_building_contact_sheet.gd`=600, `assemble_faction_building_contact.py`=300, `visual_showcase.gd`=600, `color_identity.gd`=300, `factory_production_visuals.gd`=600 |
| RendererCache | `prototype_25d.gd`=300, `authored_assets.gd`=300, `destruction_assets.gd`=300, `building_asset_states.gd`=300, `factory_production_preview_cache.gd`=600 |
| Performance | `performance.gd`=600, `performance_monitor.gd`=300 |

The total is 43 catalog entries: Core 4, Simulation 2, Gameplay 8, SaveLoad 2,
ProfileHighscore 2, Mission 1, Multiplayer 3, Audio 1, UI 5, Visual 8,
RendererCache 5, Performance 2. The three synthetic supervisor probes used for
the local harness are not part of that catalog or normal regression.

The contact sheets are diagnostic artifacts. Screenshot capture remains part
of tests whose assertions inspect or whose contract explicitly produces that
image; this change does not enable extra captures for unrelated multiplayer
tests. Existing ObjectDB/resource shutdown warnings remain distinct from a
functional test failure and are not classified as a memory leak by this
supervisor.

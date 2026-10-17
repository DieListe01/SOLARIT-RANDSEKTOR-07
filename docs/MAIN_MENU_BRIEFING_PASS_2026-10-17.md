# Main menu and mission preparation pass — 2026-10-17

## Scope

The pass reorganizes the title screen around the campaign entry point and gives mission preparation a clearer information hierarchy. It keeps the existing frontend scene and renderer architecture; the background, insignia, and tactical preview remain lightweight Godot-drawn elements.

The menu now separates the campaign call to action from secondary modes and system links. Its existing outpost illustration has subtle pointer parallax and motion accents. The briefing groups campaign progress, faction identity, difficulty/threat, objectives, tactical map/intel, and launch controls into distinct regions. Faction cards use different insignia forms, and the tactical map adds restrained scan and route motion.

Mission descriptions now wrap without clipping. The frontend regression checks complete briefing text, objective-card boundaries, faction-choice cards, and layout bounds at 1920×1080.

## Visual captures

- `test-output/main_menu_redesign_1920.png` and `test-output/main_menu_motion_1920.png` — two menu frames at 1920×1080.
- `test-output/mission_briefing_redesign_1920.png` and `test-output/mission_briefing_motion_1920.png` — two briefing frames at 1920×1080.

These are local test captures, not release artwork or a public release package.

## Verification

Ran `.\Test-Solarit.ps1 -Group UI` on the local Windows/Godot renderer. All six tests passed: `ui_integration`, `placement_preview_input`, `frontend`, `intro_cinematic`, `update_info`, and `update_manager`. The frontend test captures two time-separated frames for each screen and compares sampled pixels to verify visible scene and tactical-map motion. It also validates that the complete briefing text and all three objective cards fit the Full-HD layout.

The artwork uses the existing lightweight Godot canvas renderer and does not add a 3D viewport or external assets. The UI regression confirms that the render path works; it is not a controlled FPS comparison, so no quantitative performance improvement or parity claim is made.

No full regression, export, installer, tag, or publication was performed for this UI pass.

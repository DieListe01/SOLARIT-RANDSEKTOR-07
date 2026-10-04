$ErrorActionPreference = 'Stop'
$gameRoot = $PSScriptRoot
$enginePath = Join-Path $gameRoot 'tools\Godot_v4.7.2-stable_win64_console.exe'
$env:APPDATA = Join-Path $gameRoot '.local'
$env:LOCALAPPDATA = $env:APPDATA
foreach ($testScript in @('regression', 'mission_system', 'playthrough', 'performance', 'audio_integration')) {
    & $enginePath --headless --path $gameRoot --script "tests/$testScript.gd"
    if ($LASTEXITCODE -ne 0) { throw "Test fehlgeschlagen: $testScript" }
}
& $enginePath --headless --path $gameRoot --script 'tests/campaign_units.gd'
if ($LASTEXITCODE -ne 0) { throw 'Kampagnenfreigaben und neue Einheiten fehlgeschlagen' }
& $enginePath --path $gameRoot --script 'tests/ui_integration.gd'
if ($LASTEXITCODE -ne 0) { throw 'UI-Integration fehlgeschlagen' }
& $enginePath --path $gameRoot --script 'tests/frontend.gd'
if ($LASTEXITCODE -ne 0) { throw 'Intro/Startmenü fehlgeschlagen' }
& $enginePath --path $gameRoot --script 'tests/visual_showcase.gd'
if ($LASTEXITCODE -ne 0) { throw 'Grafikprüfung fehlgeschlagen' }
& $enginePath --path $gameRoot --script 'tests/color_identity.gd'
if ($LASTEXITCODE -ne 0) { throw 'Farben und Fraktionskennung fehlgeschlagen' }
& $enginePath --path $gameRoot --script 'tests/polish_pass.gd'
if ($LASTEXITCODE -ne 0) { throw 'Effekte und Kamerastoß fehlgeschlagen' }

& $enginePath --path $gameRoot --script "tests/combat_vfx.gd"
if ($LASTEXITCODE -ne 0) { throw "Combat VFX fehlgeschlagen" }

& $enginePath --path $gameRoot --script "tests/style_consolidation.gd"
if ($LASTEXITCODE -ne 0) { throw "Style Consolidation fehlgeschlagen" }

& $enginePath --path $gameRoot --script "tests/persistent_destruction.gd"
if ($LASTEXITCODE -ne 0) { throw "Persistent Destruction fehlgeschlagen" }

& $enginePath --headless --path $gameRoot --script "tests/performance_monitor.gd"
if ($LASTEXITCODE -ne 0) { throw "FPS-Monitor fehlgeschlagen" }
& $enginePath --path $gameRoot --script "tests/highscore.gd"
if ($LASTEXITCODE -ne 0) { throw "Bestenliste fehlgeschlagen" }
& $enginePath --path $gameRoot --script "tests/update_info.gd"
if ($LASTEXITCODE -ne 0) { throw "Updateinfo fehlgeschlagen" }
& $enginePath --headless --path $gameRoot --script 'tests/update_manager.gd'
if ($LASTEXITCODE -ne 0) { throw 'Updatekanal fehlgeschlagen' }
& $enginePath --headless --path $gameRoot --script 'tests/network_protocol.gd'
if ($LASTEXITCODE -ne 0) { throw 'Multiplayer-Protokoll fehlgeschlagen' }

& $enginePath --path $gameRoot --script 'tests/repair_details.gd'
if ($LASTEXITCODE -ne 0) { throw 'Reparatur und Objektinfo fehlgeschlagen' }

& $enginePath --path $gameRoot --script 'tests/rotation_sound.gd'
if ($LASTEXITCODE -ne 0) { throw 'Rotation und Sound fehlgeschlagen' }

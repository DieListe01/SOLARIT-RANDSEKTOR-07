$ErrorActionPreference = 'Stop'
$gameRoot = $PSScriptRoot
$enginePath = Join-Path $gameRoot 'tools\Godot_v4.7.2-stable_win64_console.exe'
$pythonPath = (Get-Command python -ErrorAction Stop).Source
$env:PYTHONDONTWRITEBYTECODE = '1'
$previousOnlineStats = $env:SOLARIT_DISABLE_ONLINE_STATS
try {
$apiTestDirectory = Join-Path $gameRoot 'server'
if (Test-Path -LiteralPath (Join-Path $apiTestDirectory 'test_solarit_api.py')) {
    & $pythonPath -m unittest discover -s $apiTestDirectory -p 'test_*.py' -v
    if ($LASTEXITCODE -ne 0) { throw 'Online-API-Prüfungen fehlgeschlagen' }
}
$env:APPDATA = Join-Path $gameRoot '.local'
$env:LOCALAPPDATA = $env:APPDATA
$env:SOLARIT_DISABLE_ONLINE_STATS = '1'
& $enginePath --headless --path $gameRoot --script 'tests/player_profile.gd'
if ($LASTEXITCODE -ne 0) { throw 'Kommandantenakte fehlgeschlagen' }
& $enginePath --headless --path $gameRoot --script 'tests/match_recorder.gd'
if ($LASTEXITCODE -ne 0) { throw 'Partieberichte fehlgeschlagen' }
foreach ($testScript in @('regression', 'mission_system', 'playthrough', 'performance', 'audio_integration')) {
    & $enginePath --headless --path $gameRoot --script "tests/$testScript.gd"
    if ($LASTEXITCODE -ne 0) { throw "Test fehlgeschlagen: $testScript" }
}
& $enginePath --headless --path $gameRoot --script 'tests/prototype_25d.gd'
if ($LASTEXITCODE -ne 0) { throw '2.5D-Fahrzeug- und Gebäudemodelle fehlgeschlagen' }
& $enginePath --headless --path $gameRoot --script 'tests/campaign_units.gd'
if ($LASTEXITCODE -ne 0) { throw 'Kampagnenfreigaben und neue Einheiten fehlgeschlagen' }
& $enginePath --path $gameRoot --script 'tests/ui_integration.gd'
if ($LASTEXITCODE -ne 0) { throw 'UI-Integration fehlgeschlagen' }
$frontendProfile = Join-Path $gameRoot '.local\Godot\app_userdata\SOLARIT RANDSEKTOR 07\frontend_commander_profile.json'
Remove-Item -LiteralPath $frontendProfile -Force -ErrorAction SilentlyContinue
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

& $enginePath --path $gameRoot --script 'tests/battlefield_polish.gd'
if ($LASTEXITCODE -ne 0) { throw 'Schlachtfelddarstellung und Gruppenabstände fehlgeschlagen' }

& $enginePath --headless --path $gameRoot --script "tests/performance_monitor.gd"
if ($LASTEXITCODE -ne 0) { throw "FPS-Monitor fehlgeschlagen" }
& $enginePath --path $gameRoot --script "tests/highscore.gd"
if ($LASTEXITCODE -ne 0) { throw "Bestenliste fehlgeschlagen" }
& $enginePath --headless --path $gameRoot --script "tests/online_stats.gd"
if ($LASTEXITCODE -ne 0) { throw "Online-Spielerstatistik fehlgeschlagen" }
& $enginePath --path $gameRoot --script "tests/update_info.gd"
if ($LASTEXITCODE -ne 0) { throw "Updateinfo fehlgeschlagen" }
& $enginePath --headless --path $gameRoot --script 'tests/update_manager.gd'
if ($LASTEXITCODE -ne 0) { throw 'Updatekanal fehlgeschlagen' }
& $enginePath --headless --path $gameRoot --script 'tests/network_protocol.gd'
if ($LASTEXITCODE -ne 0) { throw 'Multiplayer-Protokoll fehlgeschlagen' }
& $enginePath --headless --path $gameRoot --script 'tests/private_lobby_code.gd'
if ($LASTEXITCODE -ne 0) { throw 'Private Multiplayer-Einladungscodes fehlgeschlagen' }

& $enginePath --path $gameRoot --script 'tests/repair_details.gd'
if ($LASTEXITCODE -ne 0) { throw 'Reparatur und Objektinfo fehlgeschlagen' }

& $enginePath --path $gameRoot --script 'tests/rotation_sound.gd'
if ($LASTEXITCODE -ne 0) { throw 'Rotation und Sound fehlgeschlagen' }

& (Join-Path $gameRoot 'Test-Multiplayer.ps1')
} finally {
    if ($null -eq $previousOnlineStats) { Remove-Item Env:SOLARIT_DISABLE_ONLINE_STATS -ErrorAction SilentlyContinue }
    else { $env:SOLARIT_DISABLE_ONLINE_STATS = $previousOnlineStats }
}

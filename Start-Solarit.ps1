$ErrorActionPreference = 'Stop'
$gameRoot = $PSScriptRoot
$enginePath = Join-Path $gameRoot 'tools\Godot_v4.7.2-stable_win64.exe'
if (-not (Test-Path -LiteralPath $enginePath)) {
    $godotCommand = Get-Command godot -ErrorAction SilentlyContinue
    if ($godotCommand) { $enginePath = $godotCommand.Source }
    else { throw 'Godot 4.7.2 stable fehlt. project.godot mit Godot öffnen oder die Engine in tools ablegen.' }
}
$env:APPDATA = Join-Path $gameRoot '.local'
$env:LOCALAPPDATA = $env:APPDATA
# The launcher promises Full HD fullscreen output. The saved 2D/3D display style
# remains user's choice and is preserved by main.gd.
$env:SOLARIT_LAUNCH_FULL_HD = '1'
if (-not (Test-Path -LiteralPath (Join-Path $gameRoot '.godot\global_script_class_cache.cfg'))) {
    $importRun = Start-Process -FilePath $enginePath -ArgumentList @('--headless', '--path', ('"' + $gameRoot + '"'), '--editor', '--import', '--quit') -WindowStyle Hidden -Wait -PassThru
    if ($importRun.ExitCode -ne 0) { throw 'Der Godot-Erstimport ist fehlgeschlagen.' }
}
& $enginePath --path $gameRoot --resolution 1920x1080 --fullscreen

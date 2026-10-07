param()

$ErrorActionPreference = 'Stop'
$gameRoot = $PSScriptRoot
$engine = Join-Path $gameRoot 'tools\Godot_v4.7.2-stable_win64_console.exe'
$template = Join-Path $gameRoot 'tools\windows_release_x86_64.exe'
$channelPath = Join-Path $gameRoot 'data\update_channel.json'
$buildDirectory = Join-Path $gameRoot 'build'

function Invoke-Checked([string]$FilePath, [string[]]$Arguments, [string]$FailureMessage) {
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$FailureMessage (Exitcode $LASTEXITCODE)" }
}

if (-not (Test-Path -LiteralPath $engine)) { throw "Godot 4.7.2 fehlt: $engine" }
$compilerCandidates = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
    (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe')
)
$compiler = $compilerCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $compiler) { throw 'Inno Setup 6 fehlt. Installiere Inno Setup 6 und starte Build-Release.ps1 erneut.' }

$history = Get-Content (Join-Path $gameRoot 'data\update_history.json') -Raw | ConvertFrom-Json
$version = [string]$history.current_version
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw "Ungültige Versionsnummer in data/update_history.json: $version" }
$releaseEntry = $history.entries | Where-Object { $_.version -eq $version } | Select-Object -First 1
if ($null -eq $releaseEntry) { throw "Update-Historie enthält keinen Eintrag für $version." }

if (-not (Test-Path -LiteralPath $template)) {
    Invoke-Checked 'python' @((Join-Path $gameRoot 'tools\fetch_windows_template.py')) 'Godot-Exportvorlage konnte nicht geladen werden'
}

$channelExisted = Test-Path -LiteralPath $channelPath
$previousChannel = if ($channelExisted) { [System.IO.File]::ReadAllBytes($channelPath) } else { $null }
try {
    New-Item -ItemType Directory -Path $buildDirectory -Force | Out-Null
    Invoke-Checked $engine @('--headless', '--editor', '--path', $gameRoot, '--quit') 'Godot-Projektimport fehlgeschlagen'
    Invoke-Checked (Join-Path $gameRoot 'Test-Solarit.ps1') @() 'Regressionstests fehlgeschlagen'

    $channel = @{
        format_version = 1
        repository = 'DieListe01/ASHLINE-Releases'
        installer_prefix = 'SOLARIT-RANDSEKTOR-07-Setup-'
        check_interval_hours = 24
    } | ConvertTo-Json
    [System.IO.File]::WriteAllText($channelPath, $channel, [System.Text.UTF8Encoding]::new($false))

    Invoke-Checked $engine @('--headless', '--path', $gameRoot, '--export-release', 'Windows Desktop', (Join-Path $buildDirectory 'SOLARIT-RANDSEKTOR-07.exe')) 'Windows-Spiel-Export fehlgeschlagen'
    Invoke-Checked $engine @('--headless', '--path', $gameRoot, '--script', 'tools/write_engine_notices.gd') 'Godot-Lizenzhinweise konnten nicht erstellt werden'
    $startupText = (Get-Content (Join-Path $gameRoot 'docs\Spielstart.txt') -Raw).Replace('@VERSION@', $version)
    [System.IO.File]::WriteAllText((Join-Path $buildDirectory 'Spielstart.txt'), $startupText, [System.Text.UTF8Encoding]::new($false))

    Invoke-Checked $compiler @("/DAppVersion=$version", (Join-Path $gameRoot 'installer\SOLARIT-RANDSEKTOR-07.iss')) 'Inno-Setup-Installer konnte nicht erstellt werden'
    $installer = Join-Path $buildDirectory "SOLARIT-RANDSEKTOR-07-Setup-$version.exe"
    if (-not (Test-Path -LiteralPath $installer)) { throw "Installer-Ausgabe fehlt: $installer" }
    $hash = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
    [System.IO.File]::WriteAllText("$installer.sha256", "$hash  $(Split-Path $installer -Leaf)`n", [System.Text.Encoding]::ASCII)
    $manifest = @{ version = $version; installer = (Split-Path $installer -Leaf); sha256 = $hash } | ConvertTo-Json
    [System.IO.File]::WriteAllText((Join-Path $buildDirectory "SOLARIT-RANDSEKTOR-07-$version-release.json"), $manifest, [System.Text.UTF8Encoding]::new($false))

    Write-Host "Release-Build $version ist fertig:" -ForegroundColor Green
    Write-Host "  Spiel:      $(Join-Path $buildDirectory 'SOLARIT-RANDSEKTOR-07.exe')"
    Write-Host "  Installer:  $installer"
    Write-Host "  SHA-256:    $hash"
    Write-Host 'Es wurde nichts zu GitHub hochgeladen.'
} finally {
    if ($channelExisted) { [System.IO.File]::WriteAllBytes($channelPath, $previousChannel) }
    elseif (Test-Path -LiteralPath $channelPath) { Remove-Item -LiteralPath $channelPath }
}

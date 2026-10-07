param([ValidateRange(1024,65534)][int]$Port = 24651, [switch]$SkipUI, [switch]$OnlyUI)
$ErrorActionPreference = 'Stop'
$gameRoot = $PSScriptRoot
$enginePath = Join-Path $gameRoot 'tools/Godot_v4.7.2-stable_win64_console.exe'
$logDirectory = Join-Path $gameRoot 'test-output'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
$previousOnlineStats = $env:SOLARIT_DISABLE_ONLINE_STATS

function Invoke-PeerTest([string]$Script, [int]$TestPort, [string]$Prefix, [bool]$Headless) {
    $peers = @()
    try {
        foreach ($role in @('host', 'client')) {
            $arguments = @('--path', ('"{0}"' -f $gameRoot), '--script', $Script, '--audio-driver', 'Dummy')
            if ($Headless) { $arguments += @('--headless', '--rendering-method', 'gl_compatibility') }
            else { $arguments += @('--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1280x720') }
            $arguments += @('--', $role, $TestPort)
            $launch = @{
                FilePath = $enginePath
                WorkingDirectory = $gameRoot
                ArgumentList = $arguments
                WindowStyle = 'Hidden'
                PassThru = $true
                RedirectStandardOutput = Join-Path $logDirectory "$Prefix-$role.log"
                RedirectStandardError = Join-Path $logDirectory "$Prefix-$role.err"
            }
            $peers += Start-Process @launch
            if ($role -eq 'host') { Start-Sleep -Milliseconds 200 }
        }
        $deadline = [DateTime]::UtcNow.AddSeconds(60)
        while ($peers.Where({ -not $_.HasExited }).Count -gt 0) {
            foreach ($peer in $peers) {
                if ($peer.HasExited -and $peer.ExitCode -ne 0) { throw "Multiplayer-Testprozess fehlgeschlagen: $Script" }
            }
            if ([DateTime]::UtcNow -gt $deadline) { throw "Multiplayer-Test: Zeitlimit erreicht: $Script" }
            Start-Sleep -Milliseconds 100
        }
        foreach ($role in @('host', 'client')) {
            Get-Content (Join-Path $logDirectory "$Prefix-$role.log")
            $errors = Get-Content (Join-Path $logDirectory "$Prefix-$role.err") -Raw
            if ($errors) { Write-Output $errors }
            $actionableErrors = $errors `
                -replace '(?m)^ERROR: Failed to read the root certificate store\.[\r\n]+\s*at: get_system_ca_certificates \(platform/windows/os_windows\.cpp:\d+\)[\r\n]*', '' `
                -replace '(?ms)^WARNING: \d+ ObjectDB instances were leaked at exit \(run with `--verbose` for details\)\.[\r\n]+\s*at: cleanup \(core/object/object\.cpp:\d+\)[\r\n]*', '' `
                -replace '(?ms)^ERROR: \d+ resources still in use at exit \(run with --verbose for details\)\.[\r\n]+\s*at: clear \(core/io/resource\.cpp:\d+\)[\r\n]*', ''
            $index = if ($role -eq 'host') { 0 } else { 1 }
            if ($peers[$index].ExitCode -ne 0 -or $actionableErrors -match '(?m)^ERROR:|SCRIPT ERROR:') {
                throw "Multiplayer-Test fehlgeschlagen: $role"
            }
        }
    } catch {
        foreach ($role in @('host', 'client')) {
            Get-Content (Join-Path $logDirectory "$Prefix-$role.log") -ErrorAction SilentlyContinue
            Get-Content (Join-Path $logDirectory "$Prefix-$role.err") -ErrorAction SilentlyContinue
        }
        throw
    } finally {
        foreach ($peer in $peers) {
            # Godot's console launcher owns a separate engine process.
            if (-not $peer.HasExited) {
                try {
                    $children = Get-CimInstance Win32_Process -Filter "ParentProcessId = $($peer.Id)" -ErrorAction Stop | Where-Object {
                        $_.ExecutablePath -eq (Join-Path $gameRoot 'tools/Godot_v4.7.2-stable_win64.exe')
                    }
                    foreach ($child in $children) { Stop-Process -Id $child.ProcessId -Force -ErrorAction SilentlyContinue }
                } catch {
                    # Process inspection can be denied in restricted runners; still stop the known launcher below.
                }
                Stop-Process -Id $peer.Id -Force -ErrorAction SilentlyContinue
            }
            $peer.Dispose()
        }
    }
}

try {
    $env:APPDATA = Join-Path $gameRoot '.local'
    $env:LOCALAPPDATA = $env:APPDATA
    # Multiplayer automation must stay deterministic and must not contact the public stats API.
    $env:SOLARIT_DISABLE_ONLINE_STATS = '1'
    if (-not $OnlyUI) {
        & $enginePath --headless --path $gameRoot --script tests/versus.gd
        if ($LASTEXITCODE -ne 0) { throw 'Duell-Regeltests fehlgeschlagen' }
        Invoke-PeerTest 'tests/network_roundtrip.gd' $Port 'network' $true
    }
    if (-not $SkipUI) { Invoke-PeerTest 'tests/network_game.gd' ($Port + 1) 'network-game' ($env:CI -eq 'true') }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
    $env:SOLARIT_DISABLE_ONLINE_STATS = $previousOnlineStats
}

param([ValidateRange(1024,65534)][int]$Port = 24651, [switch]$SkipUI, [switch]$OnlyUI)
$ErrorActionPreference = 'Stop'
$gameRoot = $PSScriptRoot
$enginePath = Join-Path $gameRoot 'tools/Godot_v4.7.2-stable_win64_console.exe'
$logDirectory = Join-Path $gameRoot 'test-output'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA

function Invoke-PeerTest([string]$Script, [int]$TestPort, [string]$Prefix, [bool]$Headless) {
    $peers = @()
    try {
        foreach ($role in @('host', 'client')) {
            $arguments = @('--path', ('"{0}"' -f $gameRoot), '--script', $Script)
            if ($Headless) { $arguments += '--headless' }
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
            $index = if ($role -eq 'host') { 0 } else { 1 }
            if ($peers[$index].ExitCode -ne 0 -or $errors -match '(?m)^ERROR:|SCRIPT ERROR:') {
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
            $children = Get-CimInstance Win32_Process -Filter "ParentProcessId = $($peer.Id)" | Where-Object {
                $_.ExecutablePath -eq (Join-Path $gameRoot 'tools/Godot_v4.7.2-stable_win64.exe')
            }
            foreach ($child in $children) { Stop-Process -Id $child.ProcessId -Force -ErrorAction SilentlyContinue }
            if (-not $peer.HasExited) { Stop-Process -Id $peer.Id -Force }
            $peer.Dispose()
        }
    }
}

try {
    $env:APPDATA = Join-Path $gameRoot '.local'
    $env:LOCALAPPDATA = $env:APPDATA
    if (-not $OnlyUI) {
        & $enginePath --headless --path $gameRoot --script tests/versus.gd
        if ($LASTEXITCODE -ne 0) { throw 'Duell-Regeltests fehlgeschlagen' }
        Invoke-PeerTest 'tests/network_roundtrip.gd' $Port 'network' $true
    }
    if (-not $SkipUI) { Invoke-PeerTest 'tests/network_game.gd' ($Port + 1) 'network-game' $false }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}

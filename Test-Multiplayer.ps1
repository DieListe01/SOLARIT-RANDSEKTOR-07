param([ValidateRange(1024,65534)][int]$Port = 24651, [switch]$SkipUI, [switch]$OnlyUI)
$ErrorActionPreference = 'Stop'
$gameRoot = $PSScriptRoot
$enginePath = Join-Path $gameRoot 'tools/Godot_v4.7.2-stable_win64_console.exe'
$logDirectory = Join-Path $gameRoot 'test-output\ci\logs'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
$previousOnlineStats = $env:SOLARIT_DISABLE_ONLINE_STATS

function Invoke-PeerTest([string]$Script, [int]$TestPort, [string]$Prefix, [bool]$Headless) {
    $peers = @()
    $peerRoles = @('host','client')
    $startedAt = [DateTime]::Now
    $peerDeadline = [DateTime]::UtcNow.AddMinutes(10)
    $lastHeartbeat = [DateTime]::UtcNow
    $ownedPids=[System.Collections.Generic.HashSet[int]]::new()
    Write-Host "START TEST`nname: $Script (host+client)`ngroup: Multiplayer`ntimestamp: $($startedAt.ToString('o'))`ntimeout_seconds: 600`nport: $TestPort`n==================================================" -ForegroundColor Yellow
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
            [void]$ownedPids.Add($peers[-1].Id)
            Write-Host "MULTIPLAYER $($role.ToUpperInvariant()) started pid=$($peers[-1].Id) port=$TestPort stdout=$($launch.RedirectStandardOutput) stderr=$($launch.RedirectStandardError)"
            if ($role -eq 'host') { Start-Sleep -Milliseconds 200 }
        }
        while ($true) {
            foreach ($peer in $peers) {
                # Refresh and wait before inspecting the status. Some Windows
                # console launchers still expose a null ExitCode; the final log
                # marker below is the authoritative completion signal in that case.
                $peer.Refresh()
                foreach($owned in @(Get-OwnedProcessTree $peer.Id)){[void]$ownedPids.Add([int]$owned.ProcessId)}
                if ($peer.HasExited) {
                    $peer.WaitForExit()
                    $peer.Refresh()
                    if ($null -ne $peer.ExitCode -and $peer.ExitCode -ne 0) { throw "Multiplayer-Testprozess fehlgeschlagen: $Script (Exit $($peer.ExitCode))" }
                }
            }
            $runningOwned=@($ownedPids|Where-Object {Get-Process -Id $_ -ErrorAction SilentlyContinue})
            if(-not $runningOwned.Count){break}
            if ([DateTime]::UtcNow -gt $peerDeadline) {
                Write-Host "TIMEOUT TEST`nname: $Script (host+client)`ngroup: Multiplayer`nstart: $($startedAt.ToString('o'))`nruntime: $([math]::Round(([DateTime]::Now-$startedAt).TotalSeconds,1))s`nport: $TestPort`npids: $(($peers | ForEach-Object Id) -join ',')"
                Write-PeerDiagnostics $peers $peerRoles $Prefix $TestPort
                throw "Multiplayer-Test: Zeitlimit erreicht (600s): $Script"
            }
            if (([DateTime]::UtcNow - $lastHeartbeat).TotalSeconds -ge 30) {
                $lastHeartbeat=[DateTime]::UtcNow
                foreach ($index in 0..($peers.Count-1)) {
                    $peer=$peers[$index]; $peer.Refresh()
                    $logPath=Join-Path $logDirectory "$Prefix-$($peerRoles[$index]).log"
                    $logFile=Get-Item -LiteralPath $logPath -ErrorAction SilentlyContinue
                    $tail=if($logFile){(Get-Content -LiteralPath $logPath -Tail 2 -ErrorAction SilentlyContinue) -join ' | '}else{'<no output yet>'}
                    $ownedForPeer=@(Get-OwnedProcessTree $peer.Id | Select-Object -ExpandProperty ProcessId)
                    $childrenForPeer=@($ownedForPeer|Where-Object {$_ -ne $peer.Id -and (Get-Process -Id $_ -ErrorAction SilentlyContinue)})
                    Write-Host "[HEARTBEAT] test: $Script (host+client) | group: Multiplayer | role: $($peerRoles[$index]) | runtime: $([math]::Floor(([DateTime]::UtcNow-$startedAt.ToUniversalTime()).TotalSeconds))s | pid: $($peer.Id) | running: $(-not $peer.HasExited) | last_activity: $($logFile.LastWriteTime), $($logFile.Length) bytes | child_processes: $($childrenForPeer.Count) | port: $TestPort | last_output: $tail"
                }
            }
            Start-Sleep -Milliseconds 500
        }
        foreach ($role in @('host', 'client')) {
            $log = Get-Content (Join-Path $logDirectory "$Prefix-$role.log") -Raw
            Write-Output $log
            $errors = Get-Content (Join-Path $logDirectory "$Prefix-$role.err") -Raw
            if ($errors) { Write-Output $errors }
            $actionableErrors = $errors `
                -replace '(?m)^ERROR: Failed to read the root certificate store\.[\r\n]+\s*at: get_system_ca_certificates \(platform/windows/os_windows\.cpp:\d+\)[\r\n]*', '' `
                -replace '(?ms)^WARNING: \d+ ObjectDB instances were leaked at exit \(run with `--verbose` for details\)\.[\r\n]+\s*at: cleanup \(core/object/object\.cpp:\d+\)[\r\n]*', '' `
                -replace '(?ms)^ERROR: \d+ resources still in use at exit \(run with --verbose for details\)\.[\r\n]+\s*at: clear \(core/io/resource\.cpp:\d+\)[\r\n]*', ''
            $index = if ($role -eq 'host') { 0 } else { 1 }
            $peers[$index].Refresh()
            $completion = if ($Script -like '*network_roundtrip*') { "NETWORK ROUNDTRIP $($role.ToUpperInvariant())" } else { "NETWORK GAME $($role.ToUpperInvariant())" }
            $completedMarker = $log.Contains($completion)
            if (($null -ne $peers[$index].ExitCode -and $peers[$index].ExitCode -ne 0) -or -not $completedMarker -or $actionableErrors -match '(?m)^ERROR:|SCRIPT ERROR:') {
                throw "Multiplayer-Test fehlgeschlagen: $role (Exit $($peers[$index].ExitCode), Abschlussmarke $completedMarker)"
            }
        }
        Write-Host "PASS TEST`nname: $Script (host+client)`nduration: $([math]::Round(([DateTime]::Now-$startedAt).TotalSeconds,1))s`nexit_code: 0" -ForegroundColor Green
    } catch {
        Write-Host "FAIL TEST`nname: $Script (host+client)`nduration: $([math]::Round(([DateTime]::Now-$startedAt).TotalSeconds,1))s`nreason: $($_.Exception.Message)" -ForegroundColor Red
        Write-PeerDiagnostics $peers $peerRoles $Prefix $TestPort
        foreach ($role in $peerRoles) {
            Get-Content (Join-Path $logDirectory "$Prefix-$role.log") -ErrorAction SilentlyContinue
            Get-Content (Join-Path $logDirectory "$Prefix-$role.err") -ErrorAction SilentlyContinue
        }
        throw
    } finally {
        $rootPeerIds=@($peers|ForEach-Object {$_.Id})
        foreach($ownedId in @($ownedPids)){if($ownedId -notin $rootPeerIds){Stop-Process -Id $ownedId -Force -ErrorAction SilentlyContinue}}
        foreach ($peer in $peers) {
            $peerId=$peer.Id
            Stop-OwnedProcessTree $peer.Id
            $peer.Dispose()
        }
        Start-Sleep -Milliseconds 250
        $left=@($ownedPids|Where-Object {Get-Process -Id $_ -ErrorAction SilentlyContinue})
        $godotLeft=@($left|Where-Object {(Get-Process -Id $_ -ErrorAction SilentlyContinue).ProcessName -match '^Godot'})
        Write-Host "OWNED PROCESS CLEANUP: $(if($left.Count){'FAIL'}else{'PASS'}) | remaining owned PIDs: $($left -join ',')"
        Write-Host "OWNED GODOT PROCESS LEFTOVERS: $($godotLeft.Count) | PIDs: $($godotLeft -join ',')"
        if($left.Count){Write-Error "Owned multiplayer processes remained after cleanup: $($left -join ',')"}
    }
}

function Get-OwnedProcessTree([int]$RootId) {
    try {
        $all=@(Get-CimInstance Win32_Process -ErrorAction Stop)
        $ids=[System.Collections.Generic.HashSet[int]]::new(); [void]$ids.Add($RootId)
        $changed=$true
        while($changed){$changed=$false;foreach($item in $all){if($ids.Contains([int]$item.ParentProcessId) -and $ids.Add([int]$item.ProcessId)){$changed=$true}}}
        return @($all | Where-Object {$ids.Contains([int]$_.ProcessId)})
    } catch { return @() }
}

function Stop-OwnedProcessTree([int]$RootId) {
    $tree=@(Get-OwnedProcessTree $RootId)
    foreach($item in @($tree | Sort-Object @{Expression={if($_.ProcessId -eq $RootId){0}else{1}}} -Descending)){
        Stop-Process -Id ([int]$item.ProcessId) -Force -ErrorAction SilentlyContinue
    }
    Stop-Process -Id $RootId -Force -ErrorAction SilentlyContinue
}

function Write-PeerDiagnostics($Peers, [string[]]$Roles, [string]$Prefix, [int]$Port) {
    Write-Host "MULTIPLAYER DIAGNOSTICS: port=$Port" -ForegroundColor Yellow
    $peerIds=@($Peers | ForEach-Object {$_.Id})
    foreach($peerId in $peerIds){
        $tree=@(Get-OwnedProcessTree $peerId)
        foreach($entry in $tree){
            $proc=Get-Process -Id ([int]$entry.ProcessId) -ErrorAction SilentlyContinue
            Write-Host ("PROCESS pid={0} parent={1} name={2} cpu={3} working_set_mb={4:N1} command={5}" -f $entry.ProcessId,$entry.ParentProcessId,$entry.Name,$proc.CPU,($proc.WorkingSet64/1MB),$entry.CommandLine)
        }
    }
    try { Get-NetTCPConnection -LocalPort $Port,($Port+1) -ErrorAction Stop | Select-Object LocalAddress,LocalPort,RemoteAddress,RemotePort,State,OwningProcess | Format-Table -AutoSize | Out-String | Write-Host }
    catch { Write-Host "Network socket details unavailable: $($_.Exception.Message)" }
    foreach($role in $Roles){
        $base=Join-Path $logDirectory "$Prefix-$role"
        Write-Host "--- $role stdout tail ---"; Get-Content "$base.log" -Tail 25 -ErrorAction SilentlyContinue | ForEach-Object {Write-Host $_}
        Write-Host "--- $role stderr tail ---"; Get-Content "$base.err" -Tail 25 -ErrorAction SilentlyContinue | ForEach-Object {Write-Host $_}
    }
}

function Invoke-SingleGodotTest([string]$Script, [int]$TimeoutSeconds, [string]$Prefix) {
    $stdout=Join-Path $logDirectory "$Prefix.stdout.log"
    $stderr=Join-Path $logDirectory "$Prefix.stderr.log"
    Remove-Item -LiteralPath $stdout,$stderr -Force -ErrorAction SilentlyContinue
    $startedAt=[DateTime]::Now; $watch=[Diagnostics.Stopwatch]::StartNew(); $timeout=$false
    Write-Host "START TEST`nname: $Script`ngroup: Multiplayer`ntimestamp: $($startedAt.ToString('o'))`ntimeout_seconds: $TimeoutSeconds`nstdout: $stdout`nstderr: $stderr`n==================================================" -ForegroundColor Yellow
    $proc=Start-Process -FilePath $enginePath -ArgumentList ('--headless --path "{0}" --script "{1}"' -f $gameRoot,$Script) -WorkingDirectory $gameRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    Write-Host "MULTIPLAYER PROCESS started pid=$($proc.Id) script=$Script"
    $owned=[System.Collections.Generic.HashSet[int]]::new(); [void]$owned.Add($proc.Id)
    $lastHeartbeat=[DateTime]::UtcNow
    try {
        while($true){
            $proc.Refresh(); foreach($item in @(Get-OwnedProcessTree $proc.Id)){[void]$owned.Add([int]$item.ProcessId)}
            $children=@($owned | Where-Object {$_ -ne $proc.Id -and (Get-Process -Id $_ -ErrorAction SilentlyContinue)})
            if($proc.HasExited -and -not $children.Count){$proc.WaitForExit();$proc.Refresh();break}
            if($watch.Elapsed.TotalSeconds -ge $TimeoutSeconds){$timeout=$true;break}
            if(([DateTime]::UtcNow-$lastHeartbeat).TotalSeconds -ge 30){
                $lastHeartbeat=[DateTime]::UtcNow; $proc.Refresh(); $tail=(Get-Content -LiteralPath $stdout -Tail 3 -ErrorAction SilentlyContinue) -join ' | '
                $errTail=(Get-Content -LiteralPath $stderr -Tail 2 -ErrorAction SilentlyContinue) -join ' | '
                $info=Get-Item -LiteralPath $stdout -ErrorAction SilentlyContinue
                Write-Host "[HEARTBEAT] test: $Script | group: Multiplayer | runtime: $([math]::Floor($watch.Elapsed.TotalSeconds))s | pid: $($proc.Id) | running: $(-not $proc.HasExited) | last_activity: $($info.LastWriteTime), $($info.Length) bytes | child_processes: $($children.Count) | last_output: $tail $errTail"
            }
            Start-Sleep -Milliseconds 500
        }
        if($timeout){
            Write-Host "TIMEOUT TEST`nname: $Script`ngroup: Multiplayer`nruntime: $([math]::Round($watch.Elapsed.TotalSeconds,1))s`npid: $($proc.Id)`nchild_pids: $($children -join ',')" -ForegroundColor Red
            Write-Host 'stdout tail:'; Get-Content -LiteralPath $stdout -Tail 30 -ErrorAction SilentlyContinue | ForEach-Object {Write-Host $_}
            Write-Host 'stderr tail:'; Get-Content -LiteralPath $stderr -Tail 30 -ErrorAction SilentlyContinue | ForEach-Object {Write-Host $_}
            Write-PeerDiagnostics @($proc) @('versus') $Prefix $Port
            Stop-OwnedProcessTree $proc.Id
            Start-Sleep -Milliseconds 250
            $left=@($owned|Where-Object {Get-Process -Id $_ -ErrorAction SilentlyContinue})
            $godotLeft=@($left|Where-Object {(Get-Process -Id $_ -ErrorAction SilentlyContinue).ProcessName -match '^Godot'})
            Write-Host "OWNED PROCESS CLEANUP: $(if($left.Count){'FAIL'}else{'PASS'}) | PIDs: $($left -join ',')"
            Write-Host "OWNED GODOT PROCESS LEFTOVERS: $($godotLeft.Count) | PIDs: $($godotLeft -join ',')"
            throw "Multiplayer Godot test timed out after $TimeoutSeconds seconds: $Script"
        }
        if($proc.ExitCode -ne 0){Write-Host 'stdout tail:';Get-Content -LiteralPath $stdout -Tail 30 -ErrorAction SilentlyContinue|ForEach-Object{Write-Host $_};Write-Host 'stderr tail:';Get-Content -LiteralPath $stderr -Tail 30 -ErrorAction SilentlyContinue|ForEach-Object{Write-Host $_};throw "Multiplayer Godot test failed (Exit $($proc.ExitCode)): $Script"}
        Write-Host "PASS TEST`nname: $Script`nduration: $([math]::Round($watch.Elapsed.TotalSeconds,1))s`nexit_code: 0" -ForegroundColor Green
    } finally { $watch.Stop();if(-not $proc.HasExited){Stop-OwnedProcessTree $proc.Id};$proc.Dispose() }
}

try {
    $env:APPDATA = Join-Path $gameRoot '.local'
    $env:LOCALAPPDATA = $env:APPDATA
    # Multiplayer automation must stay deterministic and must not contact the public stats API.
    $env:SOLARIT_DISABLE_ONLINE_STATS = '1'
    if (-not $OnlyUI) {
        Invoke-SingleGodotTest 'tests/versus.gd' 180 'versus'
        Invoke-PeerTest 'tests/network_roundtrip.gd' $Port 'network' $true
    }
    if (-not $SkipUI) { Invoke-PeerTest 'tests/network_game.gd' ($Port + 1) 'network-game' ($env:CI -eq 'true') }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
    $env:SOLARIT_DISABLE_ONLINE_STATS = $previousOnlineStats
}

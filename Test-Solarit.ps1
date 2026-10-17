param(
    [switch]$CI,
    [ValidateSet('Core','Simulation','Gameplay','SaveLoad','ProfileHighscore','Mission','Multiplayer','Audio','UI','Visual','RendererCache','Performance','CIHarness')]
    [string]$Group,
    [string]$Test,
    [ValidateRange(1,1440)][int]$OverallTimeoutMinutes = 90,
    [ValidateRange(1,600)][int]$HeartbeatSeconds = 45,
    [switch]$SupervisorSelfTest
)

$ErrorActionPreference = 'Stop'
$gameRoot = $PSScriptRoot
$enginePath = Join-Path $gameRoot 'tools\Godot_v4.7.2-stable_win64_console.exe'
$pythonPath = (Get-Command python -ErrorAction Stop).Source
$ciRoot = Join-Path $gameRoot 'test-output\ci'
$logRoot = Join-Path $ciRoot 'logs'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

if (-not $env:SOLARIT_CI_GROUP_RUN) {
    Remove-Item -LiteralPath (Join-Path $ciRoot 'regression-summary.json') -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $ciRoot 'regression-summary.txt') -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $ciRoot 'CI-FAILURE-CONTEXT.txt') -Force -ErrorAction SilentlyContinue
    $env:SOLARIT_CI_GROUP_RUN = [guid]::NewGuid().ToString()
}

$previousOnlineStats = $env:SOLARIT_DISABLE_ONLINE_STATS
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
$env:PYTHONDONTWRITEBYTECODE = '1'
$env:APPDATA = Join-Path $gameRoot '.local'
$env:LOCALAPPDATA = $env:APPDATA
$env:SOLARIT_DISABLE_ONLINE_STATS = '1'

$tests = [System.Collections.Generic.List[object]]::new()
function Add-GodotTest([string]$GroupName, [string]$Name, [bool]$Headless = $true, [int]$TimeoutSeconds = 300, [string]$RenderingMethod = '', [string]$RenderingDriver = '') {
    $args = @()
    if ($Headless) { $args += '--headless' }
    if ($RenderingDriver) { $args += @('--rendering-driver', $RenderingDriver) }
    if ($RenderingMethod) { $args += @('--rendering-method', $RenderingMethod) }
    $args += @('--path', ('"{0}"' -f $gameRoot), '--script', "tests/$Name.gd")
    $tests.Add([pscustomobject]@{ Group=$GroupName; Name="$Name.gd"; File="tests/$Name.gd"; Kind='Godot'; Executable=$enginePath; Arguments=$args; TimeoutSeconds=$TimeoutSeconds })
}
function Add-PythonTest([string]$GroupName, [string]$Name, [string]$Executable, [string[]]$Arguments, [int]$TimeoutSeconds = 180) {
    $tests.Add([pscustomobject]@{ Group=$GroupName; Name=$Name; File=$Name; Kind='Python'; Executable=$Executable; Arguments=$Arguments; TimeoutSeconds=$TimeoutSeconds })
}

# This catalog preserves the historical Test-Solarit.ps1 order and launch modes.
# Only tests previously in the full suite are included; hardware performance
# benchmarks are deliberately separate release gates, not GitHub-runner tests.
Add-PythonTest 'Core' 'crystal_atlas.py' $pythonPath @((Join-Path $gameRoot 'tests\crystal_atlas.py'))
Add-PythonTest 'Core' 'server/test_solarit_api.py' $pythonPath @('-m','unittest','discover','-s',(Join-Path $gameRoot 'server'),'-p','test_*.py','-v') 300
Add-GodotTest 'Core' 'player_profile' $true 180
Add-GodotTest 'Core' 'regression' $true 300

Add-GodotTest 'Simulation' 'mission_system' $true 300
Add-GodotTest 'Mission' 'special_orders' $true 300
Add-GodotTest 'Simulation' 'playthrough' $true 600

Add-GodotTest 'Gameplay' 'faction_vehicle_balance' $true 300
Add-GodotTest 'Gameplay' 'repair_details' $false 300
Add-GodotTest 'Gameplay' 'rotation_sound' $false 300
Add-GodotTest 'Gameplay' 'persistent_destruction' $false 300
Add-GodotTest 'Gameplay' 'battlefield_polish' $false 300
Add-GodotTest 'Gameplay' 'combat_vfx' $false 300
Add-GodotTest 'Gameplay' 'style_consolidation' $false 300
Add-GodotTest 'Gameplay' 'polish_pass' $false 300

Add-GodotTest 'SaveLoad' 'match_recorder' $true 300
Add-GodotTest 'SaveLoad' 'factory_production' $true 300

Add-GodotTest 'ProfileHighscore' 'highscore' $false 300
Add-GodotTest 'ProfileHighscore' 'online_stats' $true 300

Add-GodotTest 'Mission' 'campaign_units' $true 300

Add-PythonTest 'Audio' 'audio_asset_validation.py' $pythonPath @((Join-Path $gameRoot 'tests\audio_asset_validation.py')) 300
Add-PythonTest 'Audio' 'voice_catalog_validation.py' $pythonPath @((Join-Path $gameRoot 'tests\voice_catalog_validation.py')) 300
Add-PythonTest 'Audio' 'audio_pipeline_validation.py' $pythonPath @((Join-Path $gameRoot 'tests\audio_pipeline_validation.py')) 300
Add-GodotTest 'Audio' 'audio_integration' $true 300
Add-GodotTest 'Audio' 'voice_system' $true 300

Add-GodotTest 'UI' 'ui_integration' $false 600 'gl_compatibility' 'opengl3_angle'
Add-GodotTest 'UI' 'placement_preview_input' $false 300 'gl_compatibility' 'opengl3_angle'
Add-GodotTest 'UI' 'frontend' $false 600
Add-GodotTest 'UI' 'intro_cinematic' $false 600
Add-GodotTest 'UI' 'update_info' $false 300
Add-GodotTest 'UI' 'update_manager' $true 300

Add-GodotTest 'Visual' 'authored_asset_gallery' $false 600
Add-GodotTest 'Visual' 'faction_vehicle_contact_sheet' $false 600
Add-PythonTest 'Visual' 'assemble_faction_vehicle_contact.py' $pythonPath @((Join-Path $gameRoot 'tools\assemble_faction_vehicle_contact.py')) 300
Add-GodotTest 'Visual' 'faction_building_contact_sheet' $false 600
Add-PythonTest 'Visual' 'assemble_faction_building_contact.py' $pythonPath @((Join-Path $gameRoot 'tools\assemble_faction_building_contact.py')) 300
Add-GodotTest 'Visual' 'visual_showcase' $false 600
Add-GodotTest 'Visual' 'terrain_visual_acceptance' $false 300
Add-GodotTest 'Visual' 'color_identity' $false 300
Add-GodotTest 'Visual' 'factory_production_visuals' $false 600
Add-GodotTest 'Visual' 'building_visual_stability' $false 600
$tests[-1].Arguments += @('--fullscreen','--resolution','1920x1080')
Add-GodotTest 'Visual' 'harvester_runtime_visual' $false 600

Add-GodotTest 'RendererCache' 'prototype_25d' $true 300
Add-GodotTest 'RendererCache' 'authored_assets' $true 300
Add-GodotTest 'RendererCache' 'harvester_cargo_visual' $false 300
Add-GodotTest 'RendererCache' 'destruction_assets' $true 300
Add-GodotTest 'RendererCache' 'building_asset_states' $true 300
Add-GodotTest 'RendererCache' 'factory_production_preview_cache' $true 600

Add-GodotTest 'Performance' 'performance' $true 600
Add-GodotTest 'Performance' 'performance_monitor' $true 300

if ($SupervisorSelfTest) {
    $probeDir=Join-Path $ciRoot 'probes'; New-Item -ItemType Directory -Force $probeDir | Out-Null
    $slowPath=Join-Path $probeDir 'ci_runner_slow.ps1'
    $hangPath=Join-Path $probeDir 'ci_runner_hang.ps1'
    $childPath=Join-Path $probeDir 'ci_runner_child.ps1'
    $childPidPath=Join-Path $probeDir 'ci_runner_child.pid'
    $afterPath=Join-Path $probeDir 'ci_runner_after_timeout.ps1'
    $probeShell=(Get-Command pwsh -ErrorAction SilentlyContinue).Source
    if (-not $probeShell) { $probeShell=(Get-Command powershell -ErrorAction Stop).Source }
    Set-Content -LiteralPath $slowPath -Value "Write-Output 'slow probe started'; Start-Sleep -Seconds 8; Write-Output 'slow probe complete'" -Encoding utf8
    Set-Content -LiteralPath $childPath -Value "while (`$true) { Start-Sleep -Seconds 1 }" -Encoding utf8
    $quotedChildPath='"' + $childPath + '"'
    $quotedChildPidPath='"' + $childPidPath + '"'
    Remove-Item -LiteralPath $childPidPath -Force -ErrorAction SilentlyContinue
    Set-Content -LiteralPath $hangPath -Value "`$child=Start-Process -FilePath '$probeShell' -ArgumentList @('-NoProfile','-File',$quotedChildPath) -PassThru -WindowStyle Hidden; Set-Content -LiteralPath $quotedChildPidPath -Value `$child.Id; Write-Output ('hang probe started child PID '+`$child.Id); while (`$true) { Start-Sleep -Seconds 1 }" -Encoding utf8
    Set-Content -LiteralPath $afterPath -Value "`$childPid=[int](Get-Content -LiteralPath '$childPidPath' -Raw); if (Get-Process -Id `$childPid -ErrorAction SilentlyContinue) { Write-Error 'timeout left child process alive'; exit 9 }; Write-Output 'post-timeout probe started; child process is gone'; exit 0" -Encoding utf8
    $tests.Add([pscustomobject]@{Group='CIHarness';Name='ci_runner_slow';File='CI harness: heartbeat';Kind='PowerShell';Executable=$probeShell;Arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $slowPath));TimeoutSeconds=20})
    $tests.Add([pscustomobject]@{Group='CIHarness';Name='ci_runner_hang';File='CI harness: timeout cleanup';Kind='PowerShell';Executable=$probeShell;Arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $hangPath));TimeoutSeconds=10;ExpectedTimeout=$true;OwnedPidFiles=@($childPidPath)})
    $tests.Add([pscustomobject]@{Group='CIHarness';Name='ci_runner_after_timeout';File='CI harness: clean next process';Kind='PowerShell';Executable=$probeShell;Arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $afterPath));TimeoutSeconds=20})
}
Add-GodotTest 'Multiplayer' 'network_protocol' $true 300
Add-GodotTest 'Multiplayer' 'private_lobby_code' $true 300

# Reject accidental duplicate catalog entries and filter without altering the suite.
$duplicates = $tests | Group-Object File | Where-Object Count -gt 1
if ($duplicates) { throw "Duplicate CI test catalog entries: $($duplicates.Name -join ', ')" }
$selected = @($tests)
if ($Group) { $selected = @($selected | Where-Object Group -eq $Group) }
if ($Test) { $selected = @($selected | Where-Object { $_.Name -like "*$Test*" -or $_.File -like "*$Test*" }) }

$multiplayerEntry = [pscustomobject]@{
    Group='Multiplayer'; Name='Test-Multiplayer.ps1'; File='Test-Multiplayer.ps1'; Kind='PowerShell'
    Executable=(Get-Command pwsh -ErrorAction SilentlyContinue).Source
    Arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f (Join-Path $gameRoot 'Test-Multiplayer.ps1')))
    TimeoutSeconds=1500
}
if (-not $multiplayerEntry.Executable) {
    $multiplayerEntry.Executable=(Get-Command powershell -ErrorAction Stop).Source
    $multiplayerEntry.Arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f (Join-Path $gameRoot 'Test-Multiplayer.ps1')))
}
if ((-not $Group -and -not $Test) -or ($Group -eq 'Multiplayer' -and -not $Test) -or ($Test -and $multiplayerEntry.Name -like "*$Test*")) { $selected += $multiplayerEntry }
if ($selected.Count -eq 0) { throw "No tests matched Group='$Group' Test='$Test'." }

$summaryPath = Join-Path $ciRoot 'regression-summary.json'
$textSummaryPath = Join-Path $ciRoot 'regression-summary.txt'
$records = [System.Collections.Generic.List[object]]::new()
$baseRecords = @()
if (Test-Path -LiteralPath $summaryPath) {
    try { $baseRecords = @(Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json) } catch { $baseRecords = @() }
}
$overallWatch = [System.Diagnostics.Stopwatch]::StartNew()
$overallDeadline = [DateTime]::UtcNow.AddMinutes($OverallTimeoutMinutes)
$failed = $false

function Get-ProcessTreeBounded([int]$RootPid, [int]$TimeoutSeconds = 2) {
    # CIM can stall on hosted Windows runners. Never perform this inventory in
    # the test watchdog's critical path; use a thread job with a hard wait bound.
    $job = $null
    try {
        $job = Start-ThreadJob -ArgumentList $RootPid -ScriptBlock {
            param([int]$RequestedRootPid)
            try {
                $all = @(Get-CimInstance Win32_Process -ErrorAction Stop)
                $ids = [System.Collections.Generic.HashSet[int]]::new()
                [void]$ids.Add($RequestedRootPid)
                $changed = $true
                while ($changed) {
                    $changed = $false
                    foreach ($item in $all) {
                        if ($ids.Contains([int]$item.ParentProcessId) -and $ids.Add([int]$item.ProcessId)) { $changed = $true }
                    }
                }
                $all | Where-Object { $ids.Contains([int]$_.ProcessId) } | Select-Object ProcessId,ParentProcessId,Name,ExecutablePath,CommandLine,WorkingSetSize,UserModeTime,KernelModeTime
            } catch { }
        }
        if ($job | Wait-Job -Timeout ([math]::Max(1,$TimeoutSeconds))) {
            return @(Receive-Job -Job $job -ErrorAction SilentlyContinue)
        }
        Stop-Job -Job $job -ErrorAction SilentlyContinue
        return @()
    } catch {
        if ($job) { Stop-Job -Job $job -ErrorAction SilentlyContinue }
        return @()
    } finally {
        if ($job) { Remove-Job -Job $job -Force -ErrorAction SilentlyContinue }
    }
}

function Get-BestEffortCiSystemInfo([int]$TimeoutSeconds = 3) {
    if (-not (Get-Command Start-ThreadJob -ErrorAction SilentlyContinue)) {
        return [pscustomobject]@{ OS=$null; CPU=$null; GPU=@(); Error='ThreadJob unavailable; optional CIM inventory skipped' }
    }
    $job = $null
    try {
        $job = Start-ThreadJob -ScriptBlock {
            $os = $null; $cpu = $null; $gpu = @(); $errors = [System.Collections.Generic.List[string]]::new()
            try { $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop } catch { $errors.Add("OS: $($_.Exception.Message)") }
            try { $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1 } catch { $errors.Add("CPU: $($_.Exception.Message)") }
            try { $gpu = @(Get-CimInstance Win32_VideoController -ErrorAction Stop | ForEach-Object { $_.Name }) } catch { $errors.Add("GPU: $($_.Exception.Message)") }
            [pscustomobject]@{ OS=$os; CPU=$cpu; GPU=$gpu; Error=($errors -join '; ') }
        }
        if ($job | Wait-Job -Timeout ([math]::Max(1,$TimeoutSeconds))) {
            $result = Receive-Job -Job $job -ErrorAction SilentlyContinue | Select-Object -Last 1
            if ($result) { return $result }
            return [pscustomobject]@{ OS=$null; CPU=$null; GPU=@(); Error='CIM inventory returned no data' }
        }
        Stop-Job -Job $job -ErrorAction SilentlyContinue
        return [pscustomobject]@{ OS=$null; CPU=$null; GPU=@(); Error="CIM inventory exceeded ${TimeoutSeconds}s and was skipped" }
    } catch {
        if ($job) { Stop-Job -Job $job -ErrorAction SilentlyContinue }
        return [pscustomobject]@{ OS=$null; CPU=$null; GPU=@(); Error=$_.Exception.Message }
    } finally {
        if ($job) { Remove-Job -Job $job -Force -ErrorAction SilentlyContinue }
    }
}

function Get-TrackedProcessDetails([System.Collections.Generic.HashSet[int]]$OwnedPids) {
    if (-not $OwnedPids -or $OwnedPids.Count -eq 0) { return @() }
    $snapshot = @(Get-ProcessTreeBounded ($OwnedPids | Select-Object -First 1) 2)
    return @($snapshot | Where-Object { $OwnedPids.Contains([int]$_.ProcessId) })
}

function Stop-OwnedPids([System.Collections.Generic.HashSet[int]]$OwnedPids, [int]$RootPid) {
    if ($RootPid) {
        # taskkill /T operates on this test's root process tree and avoids
        # needing a successful WMI snapshot to enforce the timeout.
        try {
            $killer = Start-Process -FilePath "$env:SystemRoot\System32\taskkill.exe" -ArgumentList @('/PID',[string]$RootPid,'/T','/F') -WindowStyle Hidden -PassThru
            if (-not $killer.WaitForExit(2000)) {
                Stop-Process -Id $killer.Id -Force -ErrorAction SilentlyContinue
                Stop-Process -Id $RootPid -Force -ErrorAction SilentlyContinue
            }
            $killer.Dispose()
        } catch { Stop-Process -Id $RootPid -Force -ErrorAction SilentlyContinue }
    }
    foreach ($ownedId in @($OwnedPids | Where-Object { $_ -ne $RootPid })) {
        Stop-Process -Id $ownedId -Force -ErrorAction SilentlyContinue
    }
}

function Get-LogTail([string]$Path, [int]$Count = 10) {
    if (-not (Test-Path -LiteralPath $Path)) { return @('<no output yet>') }
    # Get-Content -Tail can allocate heavily when a renderer floods stderr or
    # emits a single very long line. Read a bounded byte window so diagnostics
    # continue working even when the child process exhausts runner memory.
    $stream = $null
    try {
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        if ($stream.Length -eq 0) { return @('<empty log>') }
        $encoding = [System.Text.Encoding]::UTF8
        if ($stream.Length -ge 2) {
            $stream.Position = 0
            $bom = [byte[]]::new(2)
            [void]$stream.Read($bom, 0, 2)
            if ($bom[0] -eq 0xFF -and $bom[1] -eq 0xFE) { $encoding = [System.Text.Encoding]::Unicode }
            elseif ($bom[0] -eq 0xFE -and $bom[1] -eq 0xFF) { $encoding = [System.Text.Encoding]::BigEndianUnicode }
        }
        $maxBytes = 131072
        $start = [Math]::Max(0, $stream.Length - $maxBytes)
        if ($encoding -ne [System.Text.Encoding]::UTF8 -and ($start % 2) -ne 0) { $start++ }
        $stream.Position = $start
        $remaining = [int]($stream.Length - $start)
        $bytes = [byte[]]::new($remaining)
        $read = 0
        while ($read -lt $remaining) {
            $chunk = $stream.Read($bytes, $read, $remaining - $read)
            if ($chunk -le 0) { break }
            $read += $chunk
        }
        $text = $encoding.GetString($bytes, 0, $read).Replace([string][char]0, '')
        $lines = @($text -split "`r?`n")
        if ($start -gt 0 -and $lines.Count -gt 1) { $lines = @($lines | Select-Object -Skip 1) }
        while ($lines.Count -gt 1 -and [string]::IsNullOrEmpty($lines[-1])) { $lines = @($lines | Select-Object -First ($lines.Count - 1)) }
        return @($lines | Select-Object -Last ([Math]::Max(1, $Count)))
    } catch {
        return @("<log unavailable: $($_.Exception.Message)>")
    } finally {
        if ($null -ne $stream) { $stream.Dispose() }
    }
}

function Write-CiSummary([switch]$AddStepSummary) {
    $allRecords = @($baseRecords) + @($records)
    $allRecords | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding utf8
    $lines = @('SOLARIT Regression Summary', "Generated: $([DateTime]::Now.ToString('o'))", '')
    foreach ($item in $allRecords) { $lines += ('{0,-18} {1,-42} {2,-8} {3,8:N1}s exit={4}' -f $item.Group,$item.Name,$item.Status,$item.DurationSeconds,$item.ExitCode) }
    $lines += ''; $lines += ('Total recorded duration: {0:N1}s' -f (($allRecords | Measure-Object DurationSeconds -Sum).Sum))
    $lines | Set-Content -LiteralPath $textSummaryPath -Encoding utf8
    if ($AddStepSummary -and $env:GITHUB_STEP_SUMMARY) {
        $groupRows = $allRecords | Group-Object Group | ForEach-Object {
            $items = @($_.Group); $duration=($items | Measure-Object DurationSeconds -Sum).Sum
        '| {0} | {1} | {2} | {3} | {4} | {5:N1}s |' -f $_.Name,$items.Count,@($items | Where-Object Status -eq 'PASS').Count,@($items | Where-Object Status -eq 'FAIL').Count,@($items | Where-Object { $_.Timeout -and -not $_.ExpectedTimeout }).Count,$duration
        }
        $top = @($allRecords | Sort-Object DurationSeconds -Descending | Select-Object -First 10)
        $markdown = @('', '### Regression test summary', '', '| Group | Tests | Pass | Fail | Timeout | Duration |','|---|---:|---:|---:|---:|---:|') + @($groupRows) + @('', '#### Slowest tests', '', '| Test | Group | Status | Duration |','|---|---|---|---:|')
        foreach ($item in $top) { $markdown += ('| `{0}` | {1} | {2} | {3:N1}s |' -f $item.Name,$item.Group,$item.Status,$item.DurationSeconds) }
        $failedTests=@($allRecords | Where-Object { $_.Status -in @('FAIL','TIMEOUT') })
        if($failedTests.Count){$markdown+=@('', '#### Failed or timed-out tests', '', '| Test | Group | Status | Exit code | Logs |','|---|---|---|---:|---|');foreach($item in $failedTests){$markdown+=('| `{0}` | {1} | {2} | {3} | stdout: `{4}`<br>stderr: `{5}` |' -f $item.Name,$item.Group,$item.Status,$item.ExitCode,$item.Stdout,$item.Stderr)}}
        Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value ($markdown -join [Environment]::NewLine) -Encoding utf8
    }
}

function Write-FailureContext($Entry, [int]$ProcessId, [double]$RuntimeSeconds, [string]$StdoutPath, [string]$StderrPath, [bool]$TimedOut, [System.Collections.Generic.HashSet[int]]$OwnedPids=$null) {
    $root = if ($ProcessId) { $ProcessId } elseif ($OwnedPids -and $OwnedPids.Count) { @($OwnedPids)[0] } else { 0 }
    $treeSource = if ($root) { @(Get-ProcessTreeBounded $root 2) } else { @() }
    if ($OwnedPids) { $treeSource = @($treeSource | Where-Object { $OwnedPids.Contains([int]$_.ProcessId) }) }
    $tree = if ($treeSource.Count) { @($treeSource | ForEach-Object { 'PID {0} PPID {1} {2} working_set_mb={3:N1} cpu_ms={4:N0} :: {5}' -f $_.ProcessId,$_.ParentProcessId,$_.Name,($_.WorkingSetSize/1MB),(($_.UserModeTime+$_.KernelModeTime)/10000),$_.CommandLine }) } else { @('<process tree unavailable or already exited>') }
    @(
        "workflow=$env:GITHUB_WORKFLOW"
        "run=$env:GITHUB_RUN_ID"
        "commit=$env:GITHUB_SHA"
        "branch=$env:GITHUB_REF_NAME"
        "test=$($Entry.Name)"
        "group=$($Entry.Group)"
        "runtime_seconds=$([math]::Round($RuntimeSeconds,1))"
        "timeout=$TimedOut"
        "timeout_seconds=$($Entry.TimeoutSeconds)"
        "pid=$ProcessId"
        "stdout_log=$StdoutPath"
        "stderr_log=$StderrPath"
        "timestamp=$([DateTime]::Now.ToString('o'))"
        'process_tree:'
    ) + $tree | Set-Content -LiteralPath (Join-Path $ciRoot 'CI-FAILURE-CONTEXT.txt') -Encoding utf8
}

try {
    $systemInfo = Get-BestEffortCiSystemInfo 3
    $os = $systemInfo.OS; $cpu = $systemInfo.CPU; $videoAdapters=@($systemInfo.GPU)
    if ($systemInfo.Error) { Write-Host "System inventory unavailable: $($systemInfo.Error)" }
    $disk = $null
    try { $disk = Get-PSDrive -Name ([System.IO.Path]::GetPathRoot($gameRoot).TrimEnd(':\')) -ErrorAction Stop } catch { Write-Host "Free disk inventory unavailable: $($_.Exception.Message)" }
    Write-Host 'CI ENVIRONMENT' -ForegroundColor Cyan
    Write-Host "Windows=$(if($os){$os.Caption}else{'unavailable'}) $(if($os){$os.Version}else{'unavailable'}) | CPU=$(if($cpu){$cpu.Name}else{'unavailable'}) | RAM_GB=$(if($os){[math]::Round($os.TotalVisibleMemorySize / 1MB,1)}else{'unavailable'}) | FreeDisk_GB=$(if($disk){[math]::Round($disk.Free / 1GB,1)}else{'unavailable'})"
    Write-Host "PowerShell=$($PSVersionTable.PSVersion) | Python=$(& $pythonPath --version 2>&1) | Godot=$enginePath | Renderer=Godot test-specific (headless/rendered per catalog)"
    Write-Host "GPU/Display: $($videoAdapters -join '; ')"
    Write-Host "Visible test groups in this invocation: $((@($selected | Select-Object -ExpandProperty Group -Unique)) -join ', ')"

    foreach ($entry in $selected) {
        if ([DateTime]::UtcNow -ge $overallDeadline) { throw "Regression overall timeout reached ($OverallTimeoutMinutes minutes)." }
        $safeName = [regex]::Replace($entry.Name,'[^A-Za-z0-9_.-]','_')
        $stdoutPath = Join-Path $logRoot "$safeName.stdout.log"
        $stderrPath = Join-Path $logRoot "$safeName.stderr.log"
        Remove-Item -LiteralPath $stdoutPath,$stderrPath -Force -ErrorAction SilentlyContinue
        $started = [DateTime]::Now
        $watch = [System.Diagnostics.Stopwatch]::StartNew()
        Write-Host "==================================================`nSTART TEST`nname: $($entry.Name)`ngroup: $($entry.Group)`ntimestamp: $($started.ToString('o'))`ntimeout_seconds: $($entry.TimeoutSeconds)`nstdout: $stdoutPath`nstderr: $stderrPath`n==================================================" -ForegroundColor Yellow
        $process = $null
        $heldProcessHandle = $null
        $processHandleRefAdded = $false
        $testPid = $null
        $ownedProcessIds = [System.Collections.Generic.HashSet[int]]::new()
            $descendantsDiscovered = $false
        $status = 'FAIL'
        $exitCode = $null
        $timedOut = $false
        try {
            $argumentLine = ($entry.Arguments -join ' ')
            $windowStyle='Hidden'
            if($entry.Kind -eq 'Godot' -and $entry.Arguments -notcontains '--headless'){$windowStyle='Normal'}
            $previousSkipPoseWarmup = $env:SOLARIT_TEST_SKIP_POSE_PREWARM
            if ($env:CI -and $entry.Name -eq 'ui_integration.gd') { $env:SOLARIT_TEST_SKIP_POSE_PREWARM='1' }
            try {
                $process = Start-Process -FilePath $entry.Executable -ArgumentList $argumentLine -WorkingDirectory $gameRoot -WindowStyle $windowStyle -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
            } finally {
                if ($null -eq $previousSkipPoseWarmup) { Remove-Item Env:SOLARIT_TEST_SKIP_POSE_PREWARM -ErrorAction SilentlyContinue }
                else { $env:SOLARIT_TEST_SKIP_POSE_PREWARM = $previousSkipPoseWarmup }
            }
            $testPid = $process.Id
            $heldProcessHandle = $process.SafeHandle
            $heldProcessHandle.DangerousAddRef([ref]$processHandleRefAdded)
            [void]$ownedProcessIds.Add($testPid)
            $lastHeartbeat = [DateTime]::UtcNow
            while ($true) {
                $process.Refresh()
                if ($process.HasExited -and -not $descendantsDiscovered) {
                    # Snapshot descendants once at parent exit. The watchdog
                    # itself never waits synchronously on CIM between checks.
                    foreach ($owned in @(Get-ProcessTreeBounded $testPid 2)) { [void]$ownedProcessIds.Add([int]$owned.ProcessId) }
                    $descendantsDiscovered = $true
                }
                if ($process.HasExited) {
                    $runningOwnedChildren=@($ownedProcessIds | Where-Object { $_ -ne $testPid -and (Get-Process -Id $_ -ErrorAction SilentlyContinue) })
                    if ($runningOwnedChildren.Count -eq 0) {
                        $process.WaitForExit()
                        $process.Refresh()
                        $exitCode = $process.ExitCode
                        break
                    }
                }
                $now = [DateTime]::UtcNow
                if ($watch.Elapsed.TotalSeconds -ge $entry.TimeoutSeconds) { $timedOut=$true; break }
                if ($now -ge $overallDeadline) { $timedOut=$true; break }
                if (($now - $lastHeartbeat).TotalSeconds -ge $HeartbeatSeconds) {
                    $lastHeartbeat=$now
                    $recent = Get-LogTail $stdoutPath 4
                    if ((Test-Path -LiteralPath $stderrPath) -and (Get-Item -LiteralPath $stderrPath).Length -gt 0) { $recent += Get-LogTail $stderrPath 3 }
                    $logItem = Get-Item -LiteralPath $stdoutPath -ErrorAction SilentlyContinue
                    $errorLogItem = Get-Item -LiteralPath $stderrPath -ErrorAction SilentlyContinue
                    $lastActivity = "stdout=$($logItem.LastWriteTime) ($($logItem.Length) bytes), stderr=$($errorLogItem.LastWriteTime) ($($errorLogItem.Length) bytes)"
                    $knownChildren = @($ownedProcessIds | Where-Object { $_ -ne $testPid }).Count
                    Write-Host "[HEARTBEAT] test: $($entry.Name) | group: $($entry.Group) | runtime: $([math]::Floor($watch.Elapsed.TotalSeconds))s | pid: $testPid | running: $(-not $process.HasExited) | last_activity: $lastActivity | known_child_processes: $knownChildren"
                    foreach ($line in $recent) { Write-Host "[LAST OUTPUT] $line" }
                }
                Start-Sleep -Milliseconds 500
            }
            if ($timedOut) {
                $status='FAIL'
                foreach ($pidFile in @($entry.OwnedPidFiles)) {
                    if (-not [string]::IsNullOrWhiteSpace([string]$pidFile) -and (Test-Path -LiteralPath $pidFile)) {
                        $fixturePid=0
                        if ([int]::TryParse((Get-Content -LiteralPath $pidFile -Raw),[ref]$fixturePid) -and $fixturePid -gt 0) { [void]$ownedProcessIds.Add($fixturePid) }
                    }
                }
                $tree = @(Get-ProcessTreeBounded $testPid 2)
                foreach ($owned in $tree) { [void]$ownedProcessIds.Add([int]$owned.ProcessId) }
                if (-not $tree.Count) { $tree=@([pscustomobject]@{ProcessId=$testPid;ParentProcessId=$null;Name='root process';CommandLine='Process-tree inventory unavailable after 2 seconds'}) }
                Write-Host "TIMEOUT TEST`nname: $($entry.Name)`ngroup: $($entry.Group)`nstart: $($started.ToString('o'))`nruntime: $([math]::Round($watch.Elapsed.TotalSeconds,1))s`npid: $testPid`nprocess tree: $($tree | ConvertTo-Json -Depth 4 -Compress)" -ForegroundColor Red
                Write-Host 'stdout tail:'; Get-LogTail $stdoutPath 30 | ForEach-Object { Write-Host $_ }
                Write-Host 'stderr tail:'; Get-LogTail $stderrPath 30 | ForEach-Object { Write-Host $_ }
                Write-FailureContext $entry $testPid $watch.Elapsed.TotalSeconds $stdoutPath $stderrPath $true $ownedProcessIds
                $ownedSnapshot=@($ownedProcessIds)
                Stop-OwnedPids $ownedProcessIds $testPid
                Start-Sleep -Milliseconds 250
                $remainingOwned=@($ownedSnapshot | Where-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue })
                $remainingGodot=@($remainingOwned | Where-Object { (Get-Process -Id $_ -ErrorAction SilentlyContinue).ProcessName -match '^Godot' })
                Write-Host "OWNED PROCESS CLEANUP: $(if($remainingOwned.Count){'FAIL'}else{'PASS'}) | remaining owned PIDs: $($remainingOwned -join ',')"
                Write-Host "OWNED GODOT PROCESS LEFTOVERS: $($remainingGodot.Count) | PIDs: $($remainingGodot -join ',')"
                if ($remainingOwned.Count -gt 0) { throw "Owned process cleanup failed after timeout: $($entry.Name); PIDs=$($remainingOwned -join ',')" }
                if ($entry.ExpectedTimeout) {
                    $status='PASS'
                    Write-Host "EXPECTED TIMEOUT TEST PASS`nname: $($entry.Name)`nduration: $([math]::Round($watch.Elapsed.TotalSeconds,1))s`nowned_processes_left: 0" -ForegroundColor Green
                } else {
                    throw "Test timed out after $([math]::Round($watch.Elapsed.TotalSeconds,1))s: $($entry.Name) [$($entry.Group)]"
                }
            }
            if (-not ($timedOut -and $entry.ExpectedTimeout) -and $exitCode -ne 0) {
                $status='FAIL'
                Write-Host "FAIL TEST`nname: $($entry.Name)`nexit_code: $exitCode`nduration: $([math]::Round($watch.Elapsed.TotalSeconds,1))s" -ForegroundColor Red
                Write-Host 'stdout tail:'; Get-LogTail $stdoutPath 30 | ForEach-Object { Write-Host $_ }
                Write-Host 'stderr tail:'; Get-LogTail $stderrPath 30 | ForEach-Object { Write-Host $_ }
                Write-FailureContext $entry $testPid $watch.Elapsed.TotalSeconds $stdoutPath $stderrPath $false $ownedProcessIds
                throw "Test failed with exit ${exitCode}: $($entry.Name) [$($entry.Group)]"
            }
            if (-not $timedOut) {
                $status='PASS'
                Write-Host "PASS TEST`nname: $($entry.Name)`nduration: $([math]::Round($watch.Elapsed.TotalSeconds,1))s`nexit_code: 0" -ForegroundColor Green
            }
        } catch {
            if ($timedOut -or ($process -and -not $process.HasExited)) {
                if ($process) { Stop-OwnedPids $ownedProcessIds $testPid }
            }
            throw
        } finally {
            $watch.Stop()
            if ($process) {
                $process.Refresh()
                if (-not $process.HasExited) { Stop-OwnedPids $ownedProcessIds $testPid }
                if ($processHandleRefAdded -and $heldProcessHandle) { $heldProcessHandle.DangerousRelease() }
                $process.Dispose()
            }
            $records.Add([pscustomobject]@{
                Test=$entry.Name; Name=$entry.Name; Group=$entry.Group; Status=$status
                DurationSeconds=[math]::Round($watch.Elapsed.TotalSeconds,3); ExitCode=$exitCode
                Timeout=($timedOut -and -not $entry.ExpectedTimeout); ExpectedTimeout=([bool]$entry.ExpectedTimeout); Pid=$testPid
                StartedAt=$started.ToString('o'); EndedAt=[DateTime]::Now.ToString('o')
                Stdout=$stdoutPath; Stderr=$stderrPath
            })
            Write-CiSummary
        }
    }
} catch {
    $failed=$true
    if (-not (Test-Path -LiteralPath (Join-Path $ciRoot 'CI-FAILURE-CONTEXT.txt'))) {
        $fallbackEntry = if ($selected.Count) { $selected[[math]::Min($records.Count,$selected.Count-1)] } else { [pscustomobject]@{Name='suite';Group=$Group} }
        Write-FailureContext $fallbackEntry 0 $overallWatch.Elapsed.TotalSeconds 'test-output/ci/regression-summary.txt' 'test-output/ci/regression-summary.txt' $false
    }
    Write-CiSummary -AddStepSummary
    throw
} finally {
    $overallWatch.Stop()
    if ($null -eq $previousOnlineStats) { Remove-Item Env:SOLARIT_DISABLE_ONLINE_STATS -ErrorAction SilentlyContinue } else { $env:SOLARIT_DISABLE_ONLINE_STATS=$previousOnlineStats }
    if ($null -eq $previousAppData) { Remove-Item Env:APPDATA -ErrorAction SilentlyContinue } else { $env:APPDATA=$previousAppData }
    if ($null -eq $previousLocalAppData) { Remove-Item Env:LOCALAPPDATA -ErrorAction SilentlyContinue } else { $env:LOCALAPPDATA=$previousLocalAppData }
}

if (-not $failed) {
    Write-CiSummary -AddStepSummary
    Write-Host 'TEST TIMING SUMMARY' -ForegroundColor Cyan
    $all = if (Test-Path -LiteralPath $summaryPath) { @(Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json) } else { @($records) }
    $all | Sort-Object DurationSeconds -Descending | Select-Object -First 10 | Format-Table Group,Name,Status,DurationSeconds -AutoSize
    Write-Host "Full regression summary: $summaryPath"
}

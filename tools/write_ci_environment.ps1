$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root 'test-output\ci'
New-Item -ItemType Directory -Force $outDir | Out-Null
$os=$null; $cpu=$null; $video=@()
try { $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop } catch { Write-Warning "Windows inventory unavailable: $($_.Exception.Message)" }
try { $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1 } catch { Write-Warning "CPU inventory unavailable: $($_.Exception.Message)" }
try { $video = @(Get-CimInstance Win32_VideoController -ErrorAction Stop | ForEach-Object {
    [pscustomobject]@{ Name=$_.Name; DriverVersion=$_.DriverVersion; VideoMode=$_.VideoModeDescription }
}) } catch { Write-Warning "Video adapter inventory unavailable: $($_.Exception.Message)" }
$python = (Get-Command python -ErrorAction Stop).Source
$godot = Join-Path $root 'tools\Godot_v4.7.2-stable_win64_console.exe'
$driveName = [System.IO.Path]::GetPathRoot($root).TrimEnd(':\')
$drive=$null
try { $drive = Get-PSDrive -Name $driveName -ErrorAction Stop } catch { Write-Warning "Drive inventory unavailable: $($_.Exception.Message)" }
$data = [ordered]@{
    timestamp = [DateTime]::Now.ToString('o')
    workflow = $env:GITHUB_WORKFLOW
    run_id = $env:GITHUB_RUN_ID
    commit = $env:GITHUB_SHA
    branch = $env:GITHUB_REF_NAME
    machine = $env:COMPUTERNAME
    windows = [ordered]@{ caption=$os.Caption; version=$os.Version; build=$os.BuildNumber }
    cpu = $(if($cpu){$cpu.Name}else{$env:PROCESSOR_IDENTIFIER})
    logical_processors = $(if($cpu){$cpu.NumberOfLogicalProcessors}else{$env:NUMBER_OF_PROCESSORS})
    ram_gb = $(if($os){[math]::Round($os.TotalVisibleMemorySize / 1MB, 2)}else{$null})
    free_disk_gb = $(if($drive){[math]::Round($drive.Free / 1GB, 2)}else{$null})
    powershell = $PSVersionTable.PSVersion.ToString()
    python_path = $python
    python_version = (& $python --version 2>&1 | Out-String).Trim()
    godot_path = $godot
    godot_version = (& $godot --headless --version 2>&1 | Out-String).Trim()
    godot_renderer = 'Test-specific: each entry records whether it uses --headless; rendered tests use project default renderer.'
    renderer_project_setting = (Select-String -LiteralPath (Join-Path $root 'project.godot') -Pattern '^renderer/rendering_method=' -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Line)
    display_adapters = $video
}
$data | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $outDir 'environment.json') -Encoding utf8
Write-Host 'WINDOWS CI ENVIRONMENT' -ForegroundColor Cyan
$data | ConvertTo-Json -Depth 6 | Write-Host
if ($env:GITHUB_STEP_SUMMARY) {
    $table = @(
        '### Regression runner environment', '',
        '| Property | Value |','|---|---|',
        ('| Windows | {0} {1} (build {2}) |' -f $os.Caption,$os.Version,$os.BuildNumber),
        ('| CPU | {0} ({1} logical processors) |' -f $data.cpu,$data.logical_processors),
        ('| RAM / free disk | {0} GB / {1} GB |' -f $data.ram_gb,$data.free_disk_gb),
        ('| PowerShell | {0} |' -f $PSVersionTable.PSVersion),
        ('| Python | {0} |' -f ((& $python --version 2>&1 | Out-String).Trim())),
        ('| Godot | {0} |' -f ((& $godot --headless --version 2>&1 | Out-String).Trim())),
        ('| Video adapters | {0} |' -f (($video.Name) -join '; ')),
        ('| Renderer setting | {0} |' -f $data.renderer_project_setting)
    )
    Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value ($table -join [Environment]::NewLine) -Encoding utf8
}

$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$runner=Join-Path $root 'Test-Solarit.ps1'
$logDir=Join-Path $root 'test-output\ci\logs'
New-Item -ItemType Directory -Force $logDir | Out-Null
Remove-Item -LiteralPath (Join-Path $root 'test-output\ci\regression-summary.json'),(Join-Path $root 'test-output\ci\regression-summary.txt'),(Join-Path $root 'test-output\ci\CI-FAILURE-CONTEXT.txt') -Force -ErrorAction SilentlyContinue
$oldRun=$env:SOLARIT_CI_GROUP_RUN
$env:SOLARIT_CI_GROUP_RUN=[guid]::NewGuid().ToString()
$shell=(Get-Command pwsh -ErrorAction SilentlyContinue).Source
if(-not $shell){$shell=(Get-Command powershell -ErrorAction Stop).Source}

function Invoke-Probe([string]$Name,[int]$MaxSeconds,[bool]$ExpectedTimeout=$false){
    $stdout=Join-Path $logDir "supervisor-probe-$Name.stdout.log"
    $stderr=Join-Path $logDir "supervisor-probe-$Name.stderr.log"
    $args=@('-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $runner),'-SupervisorSelfTest','-Test',$Name,'-HeartbeatSeconds','2')
    $proc=Start-Process -FilePath $shell -ArgumentList ($args -join ' ') -WorkingDirectory $root -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $watch=[Diagnostics.Stopwatch]::StartNew()
    try{
        while(-not $proc.HasExited -and $watch.Elapsed.TotalSeconds -lt $MaxSeconds){Start-Sleep -Milliseconds 250;$proc.Refresh()}
        if(-not $proc.HasExited){
            try{ $child=Get-CimInstance Win32_Process -Filter "ParentProcessId = $($proc.Id)" -ErrorAction Stop; foreach($item in $child){Stop-Process -Id $item.ProcessId -Force -ErrorAction SilentlyContinue} }catch{}
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            throw "Supervisor test runner itself exceeded $MaxSeconds seconds: $Name"
        }
        $proc.Refresh(); $code=$proc.ExitCode
        if($ExpectedTimeout){
            if($code -eq 0){throw "Hanging probe unexpectedly succeeded: $Name"}
            $ctx=Get-Content (Join-Path $root 'test-output\ci\CI-FAILURE-CONTEXT.txt') -Raw
            if($ctx -notmatch "test=$Name" -or $ctx -notmatch 'pid=\d+'){throw "Timeout failure context did not identify $Name and PID."}
            $records=@(Get-Content (Join-Path $root 'test-output\ci\regression-summary.json') -Raw | ConvertFrom-Json)
            $record=$records | Where-Object Name -eq $Name | Select-Object -Last 1
            if($record.Status -ne 'FAIL' -or -not $record.Timeout){throw "Expected failed timeout record missing for $Name."}
            if($record.Pid -and (Get-Process -Id ([int]$record.Pid) -ErrorAction SilentlyContinue)){throw "Timed-out probe process $($record.Pid) still exists."}
            $timeoutLog=Get-Content (Join-Path $logDir "supervisor-probe-${Name}.stdout.log") -Raw
            if($timeoutLog -notmatch 'OWNED PROCESS CLEANUP: PASS' -or $timeoutLog -notmatch 'OWNED GODOT PROCESS LEFTOVERS: 0'){throw 'Timeout cleanup did not confirm owned-process cleanup and zero owned Godot leftovers.'}
        }elseif($code -ne 0){throw "Probe $Name returned exit code $code. See $stdout and $stderr."}
        if($Name -eq 'ci_runner_slow'){
            $log=Get-Content (Join-Path $logDir 'supervisor-probe-ci_runner_slow.stdout.log') -Raw
            if(($log -split '\[HEARTBEAT\]').Count -lt 3){throw 'The slow probe did not produce at least two heartbeat records.'}
        }
        Write-Host ('PASS supervisor probe {0} ({1:N1}s)' -f $Name,$watch.Elapsed.TotalSeconds)
    }finally{$watch.Stop();$proc.Dispose()}
}

try{
    Invoke-Probe 'ci_runner_slow' 35
    Invoke-Probe 'ci_runner_hang' 35 $true
    Invoke-Probe 'ci_runner_after_timeout' 20
    Write-Host 'PASS: heartbeat, named timeout, owned-process cleanup, and subsequent process start verified.'
}finally{
    if($null -eq $oldRun){Remove-Item Env:SOLARIT_CI_GROUP_RUN -ErrorAction SilentlyContinue}else{$env:SOLARIT_CI_GROUP_RUN=$oldRun}
}

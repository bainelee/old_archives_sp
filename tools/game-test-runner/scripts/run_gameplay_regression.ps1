param(
    [string]$ProjectRoot = "D:/GODOT_Test/old-archives-sp",
    [string]$PythonExe = "python",
    [string]$GodotBin = "",
    [string]$OutputJson = "",
    [int]$SilentTimeoutSec = 25,
    [int]$StepwiseTimeoutSec = 600,
    [int]$ReconcileTimeoutSec = 600,
    [switch]$OnlyPreflight,
    [switch]$SkipBasicDataReconcile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-StepOutput {
    param([string]$Text)
    $ts = [DateTime]::Now.ToString("HH:mm:ss")
    Write-Host ("[emit=" + $ts + "][event=" + $ts + "][game=]")
    Write-Host $Text
    $script:LastStepOutputAt = Get-Date
}

function Invoke-QuoteForProcessStart {
    param([string]$Argument)
    if ([string]::IsNullOrEmpty($Argument)) { return '""' }
    if ($Argument -notmatch '[\s"]') { return $Argument }
    '"' + (($Argument -replace '\\', '\\\\') -replace '"', '\"') + '"'
}

function Invoke-PythonWithHeartbeat {
    param(
        [Parameter(Mandatory = $true)][string[]]$CliArgs,
        [Parameter(Mandatory = $true)][string]$StepLabel
    )
    # 勿用 Start-Process -RedirectStandardOutput 写临时文件：结束前控制台看不到 Python 的 flush 播报。
    $script:_PyHeartbeatStdout = New-Object System.Text.StringBuilder
    $script:_PyHeartbeatStderr = New-Object System.Text.StringBuilder
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $PythonExe
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    $quoted = @('-u') + $CliArgs | ForEach-Object { Invoke-QuoteForProcessStart $_ }
    $psi.Arguments = [string]::Join(' ', $quoted)

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    $p.EnableRaisingEvents = $true

    $outDel = [System.Diagnostics.DataReceivedEventHandler] {
        param([object]$sender, [System.Diagnostics.DataReceivedEventArgs]$e)
        if ($null -eq $e.Data) { return }
        Write-Host $e.Data
        [void]$script:_PyHeartbeatStdout.AppendLine($e.Data)
        $script:LastStepOutputAt = Get-Date
        $script:LastChildLineAt = Get-Date
    }
    $errDel = [System.Diagnostics.DataReceivedEventHandler] {
        param([object]$sender, [System.Diagnostics.DataReceivedEventArgs]$e)
        if ($null -eq $e.Data) { return }
        Write-Host $e.Data
        [void]$script:_PyHeartbeatStderr.AppendLine($e.Data)
        $script:LastStepOutputAt = Get-Date
        $script:LastChildLineAt = Get-Date
    }
    $null = $p.add_OutputDataReceived($outDel)
    $null = $p.add_ErrorDataReceived($errDel)

    [void]$p.Start()
    $p.BeginOutputReadLine()
    $p.BeginErrorReadLine()

    $startedAt = Get-Date
    $lastBeatAt = Get-Date
    while (-not $p.WaitForExit(300)) {
        $now = Get-Date
        $elapsed = [int](($now - $startedAt).TotalSeconds)
        $sinceChild = ($now - $script:LastChildLineAt).TotalSeconds
        if ($sinceChild -ge 3.0 -and (($now - $lastBeatAt).TotalSeconds) -ge 3.0) {
            Write-StepOutput ($StepLabel + " 执行中（" + $elapsed + "s）")
            $lastBeatAt = $now
        }
        if ((($now - $script:LastStepOutputAt).TotalSeconds) -ge [Math]::Max(4, $SilentTimeoutSec)) {
            try { $p.Kill() } catch {}
            throw ("步骤输出静默超时（" + $SilentTimeoutSec + "s）： " + $StepLabel)
        }
    }
    $p.WaitForExit()
    Start-Sleep -Milliseconds 400

    $stdout = [string]$script:_PyHeartbeatStdout.ToString()
    $stderr = [string]$script:_PyHeartbeatStderr.ToString()
    return [ordered]@{
        exit_code = [int]$p.ExitCode
        stdout = $stdout
        stderr = $stderr
    }
}

function Invoke-McpTool {
    param(
        [Parameter(Mandatory = $true)][string]$Tool,
        [hashtable]$ExtraArgs = @{}
    )
    $serverPath = Join-Path $ProjectRoot "tools/game-test-runner/mcp/server.py"
    $cliArgs = @($serverPath, "--tool", $Tool, "--project-root", $ProjectRoot)
    foreach ($key in $ExtraArgs.Keys) {
        switch ($key) {
            "flow_file" { $cliArgs += @("--flow-file", [string]$ExtraArgs[$key]) }
            "run_id" { $cliArgs += @("--run-id", [string]$ExtraArgs[$key]) }
            "format" { $cliArgs += @("--format", [string]$ExtraArgs[$key]) }
            default { throw "Unsupported arg for MCP helper: $key" }
        }
    }
    $exec = Invoke-PythonWithHeartbeat -CliArgs $cliArgs -StepLabel ("MCP工具 " + $Tool)
    if ([int]$exec.exit_code -ne 0) {
        throw "MCP tool failed: $Tool`n$([string]$exec.stdout)`n$([string]$exec.stderr)"
    }
    $parsed = ([string]$exec.stdout) | ConvertFrom-Json
    if (-not $parsed.ok) {
        $err = $parsed.error | ConvertTo-Json -Depth 20
        throw "MCP tool returned error: $Tool`n$err"
    }
    return $parsed.result
}

$script:LastStepOutputAt = Get-Date
$script:LastChildLineAt = Get-Date

$stepwiseScript = Join-Path $ProjectRoot "tools/game-test-runner/scripts/run_gameplay_stepwise_chat.py"
$reconcileScript = Join-Path $ProjectRoot "tools/game-test-runner/core/resource_reconcile.py"

if (-not [string]::IsNullOrWhiteSpace($GodotBin)) {
    $env:GODOT_BIN = $GodotBin
}
elseif ([string]::IsNullOrWhiteSpace($env:GODOT_BIN)) {
    $cfgGodot = Join-Path $ProjectRoot "tools/game-test-runner/config/godot_executable.json"
    if (Test-Path -LiteralPath $cfgGodot) {
        try {
            $j = Get-Content -LiteralPath $cfgGodot -Raw -Encoding UTF8 | ConvertFrom-Json
            $c = [string]$j.godot_executable
            if ([string]::IsNullOrWhiteSpace($c)) { $c = [string]$j.godot_bin }
            if (-not [string]::IsNullOrWhiteSpace($c)) { $env:GODOT_BIN = $c }
        } catch {}
    }
}

$summary = [ordered]@{
    started_at = (Get-Date).ToString("o")
    project_root = $ProjectRoot
    only_preflight = [bool]$OnlyPreflight
    skip_basic_data_reconcile = [bool]$SkipBasicDataReconcile
    preflight = $null
    basic_template = $null
    basic_runs = @()
    basic_data_reconcile = $null
    status = "pending"
}

try {
    $preflight = Invoke-McpTool -Tool "check_test_runner_environment"
    $summary.preflight = $preflight
    Write-StepOutput "preflight 检查完成"
    if (-not $preflight.ci_ready) {
        $summary.status = "failed_preflight"
    }
    elseif (-not [bool]$OnlyPreflight) {
        $godotForRun = [string]$env:GODOT_BIN
        if ([string]::IsNullOrWhiteSpace($godotForRun)) {
            $godotForRun = ""
        }
        if (-not (Test-Path $stepwiseScript)) { throw "missing: $stepwiseScript" }

        Write-StepOutput "开始基础测试（stepwise + Chat 三句式）：run_gameplay_stepwise_chat.py --template"
        $swArgs = @(
            $stepwiseScript,
            "--project-root", $ProjectRoot,
            "--godot-bin", $godotForRun,
            "--template",
            "--timeout-sec", ([string]$StepwiseTimeoutSec),
            "--emit-shell-chat"
        )
        $swExec = Invoke-PythonWithHeartbeat -CliArgs $swArgs -StepLabel "stepwise_basic_template"
        $summary.basic_template = [ordered]@{
            exit_code = [int]$swExec.exit_code
            stdout_tail = ([string]$swExec.stdout).Substring(0, [Math]::Min(8000, ([string]$swExec.stdout).Length))
            stderr_tail = ([string]$swExec.stderr).Substring(0, [Math]::Min(4000, ([string]$swExec.stderr).Length))
        }
        $summaryPath = ""
        foreach ($line in ([string]$swExec.stdout) -split "`n") {
            $t = $line.Trim()
            if ($t.StartsWith("SUMMARY_JSON=")) {
                $summaryPath = $t.Substring("SUMMARY_JSON=".Length).Trim()
                break
            }
        }
        if ([string]::IsNullOrWhiteSpace($summaryPath) -or -not (Test-Path $summaryPath)) {
            throw "stepwise template did not emit valid SUMMARY_JSON path"
        }
        $sumObj = Get-Content -LiteralPath $summaryPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $summary.basic_template.summary_json = $summaryPath
        $summary.basic_template.chat_audit_summary = [string]$sumObj.chat_audit_summary
        $protocolOk = $false
        if ($null -ne $sumObj.chat_audit) {
            $protocolOk = [bool]$sumObj.chat_audit.protocol_all_ok
        }
        $summary.basic_template.protocol_all_ok = $protocolOk

        $phases = @()
        if ($null -ne $sumObj.phases) {
            $phases = @($sumObj.phases)
        }
        foreach ($p in $phases) {
            if ($null -eq $p) { continue }
            $rs = "failed"
            if ([string]$p.status -eq "passed") { $rs = "passed" }
            $summary.basic_runs += [ordered]@{
                label = [string]$p.phase
                flow_file = [string]$p.flow_file
                run_id = [string]$p.run_id
                flow_status = [string]$p.flow_status
                report_status = $rs
                artifact_root = [string]$p.artifact_root
            }
        }

        $basicOk = ([int]$swExec.exit_code -eq 0) -and ([string]$sumObj.status -eq "passed") -and $protocolOk
        if (-not $basicOk) {
            $summary.status = "failed"
        }
        elseif (-not [bool]$SkipBasicDataReconcile) {
            if (-not (Test-Path $reconcileScript)) { throw "missing script: $reconcileScript" }
            $reconcileOutDir = Join-Path $ProjectRoot "artifacts/test-runs"
            if (-not (Test-Path $reconcileOutDir)) {
                New-Item -ItemType Directory -Path $reconcileOutDir | Out-Null
            }
            $ts = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ")
            $reconcileJson = Join-Path $reconcileOutDir ("basic_data_reconcile_" + $ts + ".json")
            Write-StepOutput "开始执行基础数据对账（resource_reconcile，内为 stepwise + 共享 user_data）"
            $recArgs = @(
                $reconcileScript,
                "--project-root", $ProjectRoot,
                "--godot-bin", $godotForRun,
                "--timeout-sec", ([string]$ReconcileTimeoutSec),
                "--output-json", $reconcileJson
            )
            $recExec = Invoke-PythonWithHeartbeat -CliArgs $recArgs -StepLabel "resource_reconcile"
            $recOk = ([int]$recExec.exit_code -eq 0)
            $recParsed = $null
            try {
                $recParsed = ([string]$recExec.stdout) | ConvertFrom-Json
            } catch {
                $recParsed = $null
            }
            $summary.basic_data_reconcile = [ordered]@{
                exit_code = [int]$recExec.exit_code
                report_json = $reconcileJson
                stdout_tail = ([string]$recExec.stdout)
                stderr_tail = ([string]$recExec.stderr)
                parsed_status = $(if ($null -ne $recParsed) { [string]$recParsed.status } else { "" })
            }
            if (-not $recOk) {
                $summary.status = "failed"
            }
            else {
                $summary.status = "passed"
            }
        }
        else {
            $summary.status = "passed"
        }
    }
}
catch {
    $summary.status = "failed"
    $summary.error = $_.Exception.Message
}
finally {
    $summary.finished_at = (Get-Date).ToString("o")
    if ([string]::IsNullOrWhiteSpace($OutputJson)) {
        $dir = Join-Path $ProjectRoot "artifacts/test-runs"
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir | Out-Null
        }
        $ts = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ")
        $OutputJson = Join-Path $dir ("gameplay_regression_" + $ts + ".json")
    }
    $summary | ConvertTo-Json -Depth 25 | Out-File -FilePath $OutputJson -Encoding utf8
    Write-Output ("SUMMARY_JSON=" + $OutputJson)
    Write-StepOutput ("gameplay_regression 结束，状态=" + [string]$summary.status)
}

if ([string]$summary.status -eq "passed") {
    exit 0
}
if ([string]$summary.status -eq "failed_preflight") {
    exit 2
}
exit 3

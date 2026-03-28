param(
    [string]$ProjectRoot = "D:/GODOT_Test/old-archives-sp",
    [string]$PythonExe = "python",
    [string]$GodotBin = "",
    [string]$OutputJson = "",
    [int]$SilentTimeoutSec = 12,
    [switch]$OnlyPreflight
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

function Invoke-PythonWithHeartbeat {
    param(
        [Parameter(Mandatory = $true)][string[]]$CliArgs,
        [Parameter(Mandatory = $true)][string]$StepLabel
    )
    $stdoutFile = [System.IO.Path]::GetTempFileName()
    $stderrFile = [System.IO.Path]::GetTempFileName()
    $proc = Start-Process -FilePath $PythonExe -ArgumentList $CliArgs -NoNewWindow -PassThru -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
    $startedAt = Get-Date
    $lastBeatAt = Get-Date
    while (-not $proc.HasExited) {
        Start-Sleep -Milliseconds 500
        $now = Get-Date
        $elapsed = [int](($now - $startedAt).TotalSeconds)
        if ((($now - $lastBeatAt).TotalSeconds) -ge 3.0) {
            Write-StepOutput ($StepLabel + " 执行中（" + $elapsed + "s）")
            $lastBeatAt = $now
        }
        if ((($now - $script:LastStepOutputAt).TotalSeconds) -ge [Math]::Max(4, $SilentTimeoutSec)) {
            try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {}
            throw ("步骤输出静默超时（" + $SilentTimeoutSec + "s）： " + $StepLabel)
        }
    }
    $stdout = ""
    $stderr = ""
    if (Test-Path $stdoutFile) { $stdout = Get-Content -Path $stdoutFile -Raw -Encoding UTF8 }
    if (Test-Path $stderrFile) { $stderr = Get-Content -Path $stderrFile -Raw -Encoding UTF8 }
    Remove-Item $stdoutFile,$stderrFile -Force -ErrorAction SilentlyContinue
    return [ordered]@{
        exit_code = [int]$proc.ExitCode
        stdout = [string]$stdout
        stderr = [string]$stderr
    }
}

function Invoke-McpTool {
    param(
        [Parameter(Mandatory = $true)][string]$Tool,
        [hashtable]$ExtraArgs = @{}
    )
    $serverPath = Join-Path $ProjectRoot "tools/game-test-runner/mcp/server.py"
    $cliArgs = @($serverPath, "--tool", $Tool, "--project-root", $ProjectRoot)
    if ($Tool -eq "run_game_flow") {
        $cliArgs += "--allow-non-broadcast"
    }
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

function Resolve-ReportStatus {
    param([object]$ReportPayload)
    if ($null -eq $ReportPayload) { return "" }
    if ($null -ne $ReportPayload.result_status) { return [string]$ReportPayload.result_status }
    if ($null -ne $ReportPayload.status) { return [string]$ReportPayload.status }
    return ""
}

function Test-ContainsAllMarkers {
    param(
        [string]$Text,
        [string[]]$Markers
    )
    $missing = @()
    foreach ($marker in $Markers) {
        if (-not $Text.Contains($marker)) {
            $missing += $marker
        }
    }
    return [ordered]@{
        ok = ($missing.Count -eq 0)
        missing = $missing
    }
}

function Get-FileHashHex {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return "" }
    return (Get-FileHash -Algorithm SHA256 -Path $Path).Hash
}

function Invoke-LayerRun {
    param(
        [string]$LayerId,
        [string]$FlowFile
    )
    Write-StepOutput ("开始执行 " + $LayerId + ": " + $FlowFile)
    $run = Invoke-McpTool -Tool "run_game_flow" -ExtraArgs @{
        flow_file = $FlowFile
    }
    $runId = [string]$run.run_id
    $artifacts = Invoke-McpTool -Tool "get_test_artifacts" -ExtraArgs @{ run_id = $runId }
    $report = Invoke-McpTool -Tool "get_test_report" -ExtraArgs @{
        run_id = $runId
        format = "json"
    }
    $reportPayload = $report.report
    $artifactRoot = [string]$run.artifact_root
    $stdoutLog = Join-Path $artifactRoot "logs/stdout.log"
    $stdoutText = ""
    if (Test-Path $stdoutLog) {
        $stdoutText = Get-Content -Path $stdoutLog -Raw -Encoding UTF8
    }
    $status = Resolve-ReportStatus -ReportPayload $reportPayload
    return [ordered]@{
        layer = $LayerId
        flow_file = $FlowFile
        run_id = $runId
        flow_status = [string]$run.status
        report_status = $status
        artifact_root = $artifactRoot
        stdout_log = $stdoutLog
        stdout_text = $stdoutText
        artifacts = $artifacts
    }
}

$script:LastStepOutputAt = Get-Date

$flowL1 = "D:/GODOT_Test/old-archives-sp/flows/suites/regression/gameplay/exploration_validation_l1_scene_probe.json"
$flowL2 = "D:/GODOT_Test/old-archives-sp/flows/suites/regression/gameplay/exploration_validation_l2_smoke_invariants.json"
$flowL3 = "D:/GODOT_Test/old-archives-sp/flows/suites/regression/gameplay/exploration_validation_l3_overlay_input_block.json"
$flowL4 = "D:/GODOT_Test/old-archives-sp/flows/suites/regression/gameplay/topbar_cognition_bootstrap_l1.json"
$whitelistPath = Join-Path $ProjectRoot "flows/rules/exploration_assertion_whitelist_v1.json"
$manifestPath = Join-Path $ProjectRoot "flows/suites/regression/gameplay/exploration_validation_current_stage_manifest.json"

if (-not [string]::IsNullOrWhiteSpace($GodotBin)) {
    $env:GODOT_BIN = $GodotBin
}

$summary = [ordered]@{
    started_at = (Get-Date).ToString("o")
    project_root = $ProjectRoot
    whitelist_file = $whitelistPath
    manifest_file = $manifestPath
    only_preflight = [bool]$OnlyPreflight
    preflight = $null
    layers = @()
    gate = [ordered]@{
        status = "pending"
        blocked_by = @()
    }
    status = "pending"
}

try {
    $preflight = Invoke-McpTool -Tool "check_test_runner_environment"
    $summary.preflight = $preflight
    Write-StepOutput "preflight 检查完成"
    if (-not $preflight.ci_ready) {
        $summary.status = "failed_preflight"
        $summary.gate.status = "blocked"
        $summary.gate.blocked_by = @("environment_timeout")
    }
    elseif (-not [bool]$OnlyPreflight) {
        if (-not (Test-Path $whitelistPath)) {
            throw "whitelist file missing: $whitelistPath"
        }
        if (-not (Test-Path $manifestPath)) {
            throw "manifest file missing: $manifestPath"
        }

        $l1 = Invoke-LayerRun -LayerId "L1" -FlowFile $flowL1
        $markers = @(
            "[GameplayFlowV1] STEP bootstrap PASS",
            "[GameplayFlowV1] STEP enter_exploration_map PASS",
            "[GameplayFlowV1] STEP execute_exploration_action PASS",
            "[GameplayFlowV1] FLOW PASS"
        )
        $markerCheck = Test-ContainsAllMarkers -Text ([string]$l1.stdout_text) -Markers $markers
        $l1ArtifactRoot = [string]$l1.artifact_root
        $shots = @(
            (Join-Path $l1ArtifactRoot "screenshots/flow_exploration_step_01_bootstrap.png"),
            (Join-Path $l1ArtifactRoot "screenshots/flow_exploration_step_02_enter_map.png"),
            (Join-Path $l1ArtifactRoot "screenshots/flow_exploration_step_03_explore_action.png")
        )
        $missingEvidence = @()
        foreach ($path in $shots) {
            if (-not (Test-Path $path)) { $missingEvidence += $path }
        }
        $hashSet = @{}
        foreach ($path in $shots) {
            $h = Get-FileHashHex -Path $path
            if (-not [string]::IsNullOrWhiteSpace($h)) {
                $hashSet[$h] = $true
            }
        }
        $distinctOk = ($hashSet.Keys.Count -eq 3)
        $l1Blocked = @()
        if (@("finished", "passed") -notcontains ([string]$l1.report_status)) {
            $l1Blocked += "state_regression"
        }
        if (-not [bool]$markerCheck.ok) {
            $l1Blocked += "marker_missing"
        }
        if ($missingEvidence.Count -gt 0 -or -not $distinctOk) {
            $l1Blocked += "evidence_missing"
        }
        $summary.layers += [ordered]@{
            layer = "L1"
            run_id = [string]$l1.run_id
            report_status = [string]$l1.report_status
            marker_ok = [bool]$markerCheck.ok
            marker_missing = $markerCheck.missing
            evidence_missing = $missingEvidence
            screenshots_distinct = [bool]$distinctOk
            blocked_by = $l1Blocked
        }
        Write-StepOutput "L1 校验完成"

        $l2 = Invoke-LayerRun -LayerId "L2" -FlowFile $flowL2
        $smokePass = ([string]$l2.stdout_text).Contains("[ExplorationSmokeTest] PASS")
        $smokeFail = ([string]$l2.stdout_text).Contains("[ExplorationSmokeTest] FAIL")
        $l2Blocked = @()
        if ((@("finished", "passed") -notcontains ([string]$l2.report_status)) -or -not $smokePass -or $smokeFail) {
            $l2Blocked += "state_regression"
        }
        $summary.layers += [ordered]@{
            layer = "L2"
            run_id = [string]$l2.run_id
            report_status = [string]$l2.report_status
            smoke_pass_marker = [bool]$smokePass
            smoke_fail_marker = [bool]$smokeFail
            blocked_by = $l2Blocked
        }
        Write-StepOutput "L2 校验完成"

        $l3 = Invoke-LayerRun -LayerId "L3" -FlowFile $flowL3
        $l3Blocked = @()
        if (@("finished", "passed") -notcontains ([string]$l3.report_status)) {
            $l3Blocked += "state_regression"
        }
        $summary.layers += [ordered]@{
            layer = "L3"
            run_id = [string]$l3.run_id
            report_status = [string]$l3.report_status
            blocked_by = $l3Blocked
        }
        Write-StepOutput "L3 校验完成"

        $l4 = Invoke-LayerRun -LayerId "L4" -FlowFile $flowL4
        $l4Blocked = @()
        if (@("finished", "passed") -notcontains ([string]$l4.report_status)) {
            $l4Blocked += "state_regression"
        }
        $summary.layers += [ordered]@{
            layer = "L4"
            run_id = [string]$l4.run_id
            report_status = [string]$l4.report_status
            blocked_by = $l4Blocked
        }
        Write-StepOutput "L4 校验完成"

        $blocked = @()
        foreach ($item in $summary.layers) {
            if ($null -ne $item.blocked_by) {
                foreach ($cat in @($item.blocked_by)) {
                    if (-not [string]::IsNullOrWhiteSpace([string]$cat)) {
                        $blocked += [string]$cat
                    }
                }
            }
        }
        $blocked = @($blocked | Select-Object -Unique)
        if ($blocked.Count -gt 0) {
            $summary.gate.status = "blocked"
            $summary.gate.blocked_by = $blocked
            $summary.status = "failed"
        }
        else {
            $summary.gate.status = "passed"
            $summary.gate.blocked_by = @()
            $summary.status = "passed"
        }
    }
}
catch {
    $summary.status = "failed"
    $summary.gate.status = "blocked"
    $summary.gate.blocked_by = @("environment_timeout")
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
        $OutputJson = Join-Path $dir ("exploration_validation_" + $ts + ".json")
    }
    $summary | ConvertTo-Json -Depth 20 | Out-File -FilePath $OutputJson -Encoding utf8
    Write-Output ("SUMMARY_JSON=" + $OutputJson)
    Write-StepOutput ("exploration_validation 结束，状态=" + [string]$summary.status)
}

if ([string]$summary.status -eq "passed") {
    exit 0
}
if ([string]$summary.status -eq "failed_preflight") {
    exit 2
}
exit 3

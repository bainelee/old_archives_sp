param(
    [string]$ProjectRoot = "D:/GODOT_Test/old-archives-sp",
    [string]$PythonExe = "python",
    [string]$GodotBin = "",
    [string]$OutputJson = "",
    [switch]$IncludeContractRegression,
    [switch]$Fast,
    [switch]$OnlyPreflight
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-McpTool {
    param(
        [Parameter(Mandatory = $true)][string]$Tool,
        [hashtable]$ExtraArgs = @{}
    )
    $serverPath = Join-Path $ProjectRoot "tools/game-test-runner/mcp/server.py"
    $cliArgs = @($serverPath, "--tool", $Tool, "--project-root", $ProjectRoot)
    foreach ($key in $ExtraArgs.Keys) {
        switch ($key) {
            "flow_file" {
                $cliArgs += @("--flow-file", [string]$ExtraArgs[$key])
            }
            "run_id" {
                $cliArgs += @("--run-id", [string]$ExtraArgs[$key])
            }
            "format" {
                $cliArgs += @("--format", [string]$ExtraArgs[$key])
            }
            "dry_run" {
                if ([bool]$ExtraArgs[$key]) {
                    $cliArgs += "--dry-run"
                }
            }
            default {
                throw "Unsupported extra arg for CI helper: $key"
            }
        }
    }
    $raw = & $PythonExe @cliArgs
    if ($LASTEXITCODE -ne 0) {
        throw "MCP tool failed: $Tool`n$raw"
    }
    $parsed = $raw | ConvertFrom-Json
    if (-not $parsed.ok) {
        $err = $parsed.error | ConvertTo-Json -Depth 20
        throw "MCP tool returned error: $Tool`n$err"
    }
    return $parsed.result
}

function Invoke-ContractRegression {
    $contractScript = Join-Path $ProjectRoot "tools/game-test-runner/core/contract_regression.py"
    $raw = & $PythonExe $contractScript --project-root $ProjectRoot --godot-bin $env:GODOT_BIN
    if ($LASTEXITCODE -ne 0) {
        throw "Contract regression failed`n$raw"
    }
    return $raw | ConvertFrom-Json
}

if (-not [string]::IsNullOrWhiteSpace($GodotBin)) {
    $env:GODOT_BIN = $GodotBin
}
$skipAllRuns = [bool]$OnlyPreflight
$runContractRegression = [bool]$IncludeContractRegression
if ($Fast -and -not $runContractRegression -and -not $skipAllRuns) {
    # Fast mode defaults to running contract regression as guardrail.
    $runContractRegression = $true
}

$timestamp = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ")
$summary = [ordered]@{
    started_at = (Get-Date).ToString("o")
    project_root = $ProjectRoot
    godot_bin_env = $env:GODOT_BIN
    preflight = $null
    fast_mode = [bool]$Fast
    only_preflight = $skipAllRuns
    include_contract_regression = $runContractRegression
    runs = @()
    contract_regression = $null
}

# 1) Preflight for CI readiness
$preflight = Invoke-McpTool -Tool "check_test_runner_environment"
$summary.preflight = $preflight
if (-not $preflight.ci_ready) {
    $summary.finished_at = (Get-Date).ToString("o")
    $summary.status = "failed_preflight"
    $fallbackDir = Join-Path $ProjectRoot "artifacts/test-runs"
    if (-not (Test-Path $fallbackDir)) {
        New-Item -ItemType Directory -Path $fallbackDir | Out-Null
    }
    if ([string]::IsNullOrWhiteSpace($OutputJson)) {
        $OutputJson = Join-Path $fallbackDir ("acceptance_ci_" + $timestamp + ".json")
    }
    $summary | ConvertTo-Json -Depth 20 | Out-File -FilePath $OutputJson -Encoding utf8
    Write-Output ("PRECHECK_FAILED: " + $OutputJson)
    exit 2
}

# 2) Required acceptance flows (optional in fast mode)
if (-not $Fast -and -not $skipAllRuns) {
    $flows = @(
        "D:/GODOT_Test/old-archives-sp/flows/ui_room_detail_sync_acceptance.json",
        "D:/GODOT_Test/old-archives-sp/flows/build_clean_wait_linked_acceptance.json"
    )

    foreach ($flow in $flows) {
        $runRes = Invoke-McpTool -Tool "run_game_flow" -ExtraArgs @{
            flow_file = $flow
        }
        $artifacts = Invoke-McpTool -Tool "get_test_artifacts" -ExtraArgs @{
            run_id = $runRes.run_id
        }
        $report = Invoke-McpTool -Tool "get_test_report" -ExtraArgs @{
            run_id = $runRes.run_id
            format = "json"
        }
        $reportPayload = $report.report
        $effectiveExitCode = $null
        $processExitCode = $null
        $reportStatus = ""
        $reportResultStatus = ""
        if ($null -ne $reportPayload) {
            if ($null -ne $reportPayload.effective_exit_code) {
                $effectiveExitCode = $reportPayload.effective_exit_code
            }
            elseif ($null -ne $reportPayload.exitCode) {
                $effectiveExitCode = $reportPayload.exitCode
            }
            if ($null -ne $reportPayload.process_exit_code) {
                $processExitCode = $reportPayload.process_exit_code
            }
            $reportStatus = [string]$reportPayload.status
            $reportResultStatus = [string]$reportPayload.result_status
        }
        $summary.runs += [ordered]@{
            flow_file = $flow
            run_id = $runRes.run_id
            status = $runRes.status
            report_status = $reportStatus
            report_result_status = $reportResultStatus
            current_step = $runRes.current_step
            approval_required = $runRes.approval_required
            effective_exit_code = $effectiveExitCode
            process_exit_code = $processExitCode
            artifact_root = $runRes.artifact_root
            report_json = $artifacts.report_json
            report_md = $artifacts.report_md
            junit_xml = $artifacts.junit_xml
            flow_report_json = $artifacts.flow_report_json
            driver_flow_json = $artifacts.driver_flow_json
            key_files = $artifacts.key_files
            primary_failure = $runRes.primary_failure
        }
    }
}

if ($runContractRegression -and -not $skipAllRuns) {
    $contract = Invoke-ContractRegression
    $summary.contract_regression = [ordered]@{
        suite_id = $contract.suite_id
        status = $contract.status
        flow_file = $contract.flow_file
        cases = $contract.cases
    }
}

$allResolved = $true
foreach ($item in $summary.runs) {
    if ($item.status -ne "resolved") {
        $allResolved = $false
        break
    }
}
$contractPassed = $true
if ($runContractRegression -and $null -ne $summary.contract_regression) {
    $contractPassed = ([string]$summary.contract_regression.status -eq "passed")
}

$summary.finished_at = (Get-Date).ToString("o")
$summary.status = $(if ($allResolved -and $contractPassed) { "passed" } else { "failed" })

$defaultDir = Join-Path $ProjectRoot "artifacts/test-runs"
if (-not (Test-Path $defaultDir)) {
    New-Item -ItemType Directory -Path $defaultDir | Out-Null
}
if ([string]::IsNullOrWhiteSpace($OutputJson)) {
    $OutputJson = Join-Path $defaultDir ("acceptance_ci_" + $timestamp + ".json")
}
$summary | ConvertTo-Json -Depth 20 | Out-File -FilePath $OutputJson -Encoding utf8

Write-Output ("SUMMARY_JSON=" + $OutputJson)
if (-not $allResolved) {
    exit 3
}
if (-not $contractPassed) {
    exit 4
}
exit 0

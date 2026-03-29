param(
    [string]$ProjectRoot = "D:/GODOT_Test/old-archives-sp",
    [string]$PythonExe = "python",
    [string]$GodotBin = "",
    [string]$OutputJson = "",
    [switch]$IncludeContractRegression,
    [switch]$IncludeToolSurfaceCheck,
    [switch]$Fast,
    [switch]$OnlyPreflight,
    [int]$SilentTimeoutSec = 12
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
            "chat_mode" {
                $cliArgs += @("--chat-mode", [string]$ExtraArgs[$key])
            }
            "poll_interval_sec" {
                $cliArgs += @("--poll-interval-sec", [string]$ExtraArgs[$key])
            }
            "max_wait_sec" {
                $cliArgs += @("--max-wait-sec", [string]$ExtraArgs[$key])
            }
            "recent_steps_limit" {
                $cliArgs += @("--recent-steps-limit", [string]$ExtraArgs[$key])
            }
            "stream_limit" {
                $cliArgs += @("--stream-limit", [string]$ExtraArgs[$key])
            }
            default {
                throw "Unsupported extra arg for CI helper: $key"
            }
        }
    }
    $exec = Invoke-PythonWithHeartbeat -CliArgs $cliArgs -StepLabel ("MCP工具 " + $Tool)
    $raw = [string]$exec.stdout
    if ([int]$exec.exit_code -ne 0) {
        throw "MCP tool failed: $Tool`n$raw`n$([string]$exec.stderr)"
    }
    $parsed = $raw | ConvertFrom-Json
    if (-not $parsed.ok) {
        $err = $parsed.error | ConvertTo-Json -Depth 20
        throw "MCP tool returned error: $Tool`n$err"
    }
    return $parsed.result
}

function Invoke-ContractRegression {
    param(
        [string]$GodotBinForContract = ""
    )
    $contractScript = Join-Path $ProjectRoot "tools/game-test-runner/core/contract_regression.py"
    $godotToUse = $GodotBinForContract
    if ([string]::IsNullOrWhiteSpace($godotToUse)) {
        $godotToUse = [string]$env:GODOT_BIN
    }
    if ([string]::IsNullOrWhiteSpace($godotToUse)) {
        throw "Contract regression requires Godot path. Set GODOT_BIN or pass -GodotBin."
    }
    $suiteRoot = Join-Path $ProjectRoot "artifacts/test-suites"
    if (-not (Test-Path $suiteRoot)) {
        New-Item -ItemType Directory -Path $suiteRoot | Out-Null
    }
    $before = @{}
    foreach ($dir in (Get-ChildItem -Path $suiteRoot -Directory -ErrorAction SilentlyContinue)) {
        $before[$dir.FullName] = $true
    }

    $lineList = @()
    & $PythonExe $contractScript --project-root $ProjectRoot --godot-bin $godotToUse | ForEach-Object {
        $line = [string]$_
        $lineList += $line
        Write-Host $line
        $script:LastStepOutputAt = Get-Date
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Contract regression failed"
    }

    $targetDir = $null
    $dirs = Get-ChildItem -Path $suiteRoot -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    foreach ($dir in $dirs) {
        if (-not $before.ContainsKey($dir.FullName)) {
            $targetDir = $dir
            break
        }
    }
    if ($null -eq $targetDir -and $dirs.Count -gt 0) {
        $targetDir = $dirs[0]
    }
    if ($null -eq $targetDir) {
        throw "Contract regression output missing suite directory."
    }
    $suiteJson = Join-Path $targetDir.FullName "suite_report.json"
    if (-not (Test-Path $suiteJson)) {
        throw "Contract regression output missing suite_report.json."
    }
    return (Get-Content -Path $suiteJson -Raw -Encoding UTF8) | ConvertFrom-Json
}

function Invoke-ToolSurfaceSnapshot {
    $scriptPath = Join-Path $ProjectRoot "tools/game-test-runner/core/mcp_tool_surface_snapshot.py"
    $raw = & $PythonExe $scriptPath --project-root $ProjectRoot
    if ($LASTEXITCODE -ne 0) {
        throw "MCP tool surface snapshot failed`n$raw"
    }
    return $raw | ConvertFrom-Json
}

if (-not [string]::IsNullOrWhiteSpace($GodotBin)) {
    $env:GODOT_BIN = $GodotBin
}
$script:LastStepOutputAt = Get-Date
$skipAllRuns = [bool]$OnlyPreflight
$runContractRegression = [bool]$IncludeContractRegression
$runToolSurfaceCheck = [bool]$IncludeToolSurfaceCheck
if ($Fast -and -not $runContractRegression -and -not $skipAllRuns) {
    # Fast mode defaults to running contract regression as guardrail.
    $runContractRegression = $true
}
if ($Fast -and -not $runToolSurfaceCheck -and -not $skipAllRuns) {
    # Fast mode also enables MCP tool surface snapshot by default.
    $runToolSurfaceCheck = $true
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
    include_tool_surface_check = $runToolSurfaceCheck
    runs = @()
    contract_regression = $null
    mcp_tool_surface = $null
}

# 1) Preflight for CI readiness
$preflight = Invoke-McpTool -Tool "check_test_runner_environment"
$summary.preflight = $preflight
Write-StepOutput "preflight 检查完成"
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

# 2) GameplayFlow 已收敛为「基础测试 + 基础数据」，默认不在本脚本中串流执行；请用 run_gameplay_regression.ps1。

if ($runContractRegression -and -not $skipAllRuns) {
    Write-StepOutput "开始执行 contract_regression"
    $contract = Invoke-ContractRegression -GodotBinForContract ([string]$env:GODOT_BIN)
    $contractCases = @()
    if ($null -ne $contract.cases) {
        $contractCases = @($contract.cases)
    }
    $hasRunAndStreamCase = $false
    foreach ($c in $contractCases) {
        if ($null -ne $c -and [string]$c.name -eq "run_and_stream_flow_short_chat_contract") {
            $hasRunAndStreamCase = $true
            break
        }
    }
    $summary.contract_regression = [ordered]@{
        suite_id = $contract.suite_id
        status = $contract.status
        flow_file = $contract.flow_file
        cases = $contractCases
        has_run_and_stream_short_chat_case = $hasRunAndStreamCase
    }
    Write-StepOutput "contract_regression 完成"
}

if ($runToolSurfaceCheck -and -not $skipAllRuns) {
    Write-StepOutput "开始执行 mcp_tool_surface_snapshot"
    $toolSurface = Invoke-ToolSurfaceSnapshot
    $toolCases = @()
    if ($null -ne $toolSurface.cases) {
        $toolCases = @($toolSurface.cases)
    }
    $summary.mcp_tool_surface = [ordered]@{
        status = $toolSurface.status
        server_version = $toolSurface.server_version
        tool_count = $toolSurface.tool_count
        cases = $toolCases
    }
    Write-StepOutput "mcp_tool_surface_snapshot 完成"
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
    $contractPassed = (
        [string]$summary.contract_regression.status -eq "passed" `
        -and [bool]$summary.contract_regression.has_run_and_stream_short_chat_case
    )
}
$toolSurfacePassed = $true
if ($runToolSurfaceCheck -and $null -ne $summary.mcp_tool_surface) {
    $toolSurfacePassed = ([string]$summary.mcp_tool_surface.status -eq "passed")
}

$summary.finished_at = (Get-Date).ToString("o")
$summary.status = $(if ($allResolved -and $contractPassed -and $toolSurfacePassed) { "passed" } else { "failed" })

$defaultDir = Join-Path $ProjectRoot "artifacts/test-runs"
if (-not (Test-Path $defaultDir)) {
    New-Item -ItemType Directory -Path $defaultDir | Out-Null
}
if ([string]::IsNullOrWhiteSpace($OutputJson)) {
    $OutputJson = Join-Path $defaultDir ("acceptance_ci_" + $timestamp + ".json")
}
$summary | ConvertTo-Json -Depth 20 | Out-File -FilePath $OutputJson -Encoding utf8

Write-Output ("SUMMARY_JSON=" + $OutputJson)
Write-StepOutput ("acceptance_ci 结束，状态=" + [string]$summary.status)
if (-not $allResolved) {
    exit 3
}
if (-not $contractPassed) {
    exit 4
}
if (-not $toolSurfacePassed) {
    exit 5
}
exit 0

param(
    [Parameter(Mandatory = $true)][string]$FlowFile,
    [string]$ProjectRoot = "D:/GODOT_Test/old-archives-sp",
    [string]$PythonExe = "python",
    [string]$GodotBin = "",
    [double]$PollIntervalSec = 0.8,
    [double]$BroadcastMergeWindowSec = 1.5,
    [int]$MaxWaitSec = 900,
    [string]$ChatMode = "short",
    [int]$RecentStepsLimit = 1,
    [switch]$NoChatProgress
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
            "flow_file" { $cliArgs += @("--flow-file", [string]$ExtraArgs[$key]) }
            "run_id" { $cliArgs += @("--run-id", [string]$ExtraArgs[$key]) }
            "chat_mode" { $cliArgs += @("--chat-mode", [string]$ExtraArgs[$key]) }
            "recent_steps_limit" { $cliArgs += @("--recent-steps-limit", [string]$ExtraArgs[$key]) }
            default { throw "Unsupported arg for helper: $key" }
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($GodotBin)) {
        $cliArgs += @("--godot-bin", $GodotBin)
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

function Get-ChatField {
    param(
        $Obj,
        [string]$Name
    )
    if ($null -eq $Obj) { return "" }
    $p = $Obj.PSObject.Properties[$Name]
    if ($null -eq $p) { return "" }
    return [string]$p.Value
}

function Get-ObjField {
    param(
        $Obj,
        [string]$Name
    )
    if ($null -eq $Obj) { return "" }
    $p = $Obj.PSObject.Properties[$Name]
    if ($null -eq $p) { return "" }
    return [string]$p.Value
}

$showChat = -not [bool]$NoChatProgress
$startRes = Invoke-McpTool -Tool "start_game_flow_live" -ExtraArgs @{
    flow_file = $FlowFile
}

$runId = [string]$startRes.run_id
$artifactRoot = [string]$startRes.artifact_root
Write-Host ("[CHAT] 已启动 flow，run_id=" + $runId)

$startedAt = Get-Date
$lastStep = ""
$lastStepKey = ""
$lastStepProgress = ""
$lastBroadcastAt = [DateTime]::MinValue
$pollCount = 0
$timedOut = $false
$final = $null

while ($true) {
    $pollCount += 1
    $progress = Invoke-McpTool -Tool "get_live_flow_progress" -ExtraArgs @{
        run_id = $runId
        chat_mode = $ChatMode
        recent_steps_limit = $RecentStepsLimit
    }
    $final = $progress
    if ($showChat -and $null -ne $progress -and $null -ne $progress.chat_progress) {
        $chat = $progress.chat_progress
        $current = Get-ChatField -Obj $chat -Name "当前步骤"
        $progressText = Get-ChatField -Obj $chat -Name "进度"
        if ([string]::IsNullOrWhiteSpace($progressText) -and $null -ne $progress.summary) {
            $progressText = ([string]$progress.summary.passed + "/" + [string]$progress.summary.total_steps)
        }
        $displayStepId = ""
        $predictedStepId = Get-ObjField -Obj $progress.predicted_next_step -Name "step_id"
        if (-not [string]::IsNullOrWhiteSpace($predictedStepId)) {
            $displayStepId = $predictedStepId
        }
        else {
            $displayStepId = Get-ObjField -Obj $progress.current_step -Name "step_id"
        }

        $now = Get-Date
        $emitFull = $false
        $emitProgressOnly = $false
        if (-not [string]::IsNullOrWhiteSpace($current) -and $displayStepId -ne $lastStepKey) {
            $emitFull = $true
        }
        elseif (-not [string]::IsNullOrWhiteSpace($progressText) -and $progressText -ne $lastStepProgress) {
            if (($now - $lastBroadcastAt).TotalSeconds -ge $BroadcastMergeWindowSec) {
                $emitProgressOnly = $true
            }
        }
        if ([string]$progress.state -eq "finished" -and -not $emitFull -and -not $emitProgressOnly) {
            $emitFull = $true
        }

        if ($emitFull) {
            $lastStep = $current
            $lastStepKey = $displayStepId
            $lastStepProgress = $progressText
            $lastBroadcastAt = $now
            Write-Host ("[CHAT] 当前步骤: " + $current)
            if (-not [string]::IsNullOrWhiteSpace($progressText)) {
                Write-Host ("[CHAT] 进度: " + $progressText)
            }
            Write-Host ("[CHAT] 目的: " + (Get-ChatField -Obj $chat -Name "目的"))
            Write-Host ("[CHAT] 结果: " + (Get-ChatField -Obj $chat -Name "结果"))
            Write-Host ("[CHAT] 下一步: " + (Get-ChatField -Obj $chat -Name "下一步"))
        }
        elseif ($emitProgressOnly) {
            $lastStepProgress = $progressText
            $lastBroadcastAt = $now
            $stepLabel = $current
            if ([string]::IsNullOrWhiteSpace($stepLabel)) {
                $stepLabel = $lastStep
            }
            Write-Host ("[CHAT] 进度更新: " + $stepLabel + " | " + $progressText)
        }
    }

    $state = ""
    if ($null -ne $progress) {
        $state = [string]$progress.state
    }
    if ($state -eq "finished") {
        break
    }
    $elapsedSec = ((Get-Date) - $startedAt).TotalSeconds
    if ($elapsedSec -ge $MaxWaitSec) {
        $timedOut = $true
        break
    }
    Start-Sleep -Milliseconds ([int]([Math]::Max(100.0, $PollIntervalSec * 1000.0)))
}

$flowStatus = ""
$finalState = ""
if ($null -ne $final) {
    $flowStatus = [string]$final.flow_status
    $finalState = [string]$final.state
}
$status = $(if (-not $timedOut -and $finalState -eq "finished" -and $flowStatus -eq "passed") { "resolved" } else { "failed" })

$summary = [ordered]@{
    flow_file = $FlowFile
    run_id = $runId
    status = $status
    flow_status = $flowStatus
    state = $finalState
    timed_out = $timedOut
    poll_count = $pollCount
    artifact_root = $artifactRoot
}

Write-Output ($summary | ConvertTo-Json -Depth 20)
if ($status -ne "resolved") {
    exit 3
}
exit 0


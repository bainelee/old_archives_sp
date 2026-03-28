param(
    [string]$ProjectRoot = "D:/GODOT_Test/old-archives-sp",
    [string]$PythonExe = "python",
    [string]$GodotBin = "",
    [string]$OutputJson = "",
    [int]$TimeoutSec = 300,
    [int]$MaxBatch = 3,
    [double]$WaitScale = 0.2,
    [double]$ResumeSpeed = 6.0,
    [switch]$DisableThinkPause,
    [switch]$EmitShellChat,
    [double]$PollIntervalSec = 0.8,
    [double]$BroadcastMergeWindowSec = 1.5,
    [int]$MaxWaitSec = 900,
    [int]$StreamLimit = 120,
    [switch]$NoChatProgress
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# 兼容旧参数，当前默认路线为 cursor_chat_plugin。
$null = $PollIntervalSec
$null = $BroadcastMergeWindowSec
$null = $MaxWaitSec
$null = $StreamLimit
$null = $NoChatProgress

if ([string]::IsNullOrWhiteSpace($GodotBin)) {
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT_BIN)) {
        $GodotBin = $env:GODOT_BIN
    }
}
if ([string]::IsNullOrWhiteSpace($GodotBin)) {
    throw "GodotBin is required (or set GODOT_BIN env)."
}

$scriptPath = Join-Path $ProjectRoot "tools/game-test-runner/scripts/run_gameplay_stepwise_chat.py"
$argsList = @(
    $scriptPath,
    "--project-root", $ProjectRoot,
    "--godot-bin", $GodotBin,
    "--timeout-sec", [string]$TimeoutSec,
    "--max-batch", [string]$MaxBatch,
    "--wait-scale", [string]$WaitScale,
    "--resume-speed", [string]$ResumeSpeed,
    "--template"
)
if ($DisableThinkPause) {
    $argsList += "--disable-think-pause"
}
if ($EmitShellChat) {
    $argsList += "--emit-shell-chat"
}
if (-not [string]::IsNullOrWhiteSpace($OutputJson)) {
    $argsList += @("--output-json", $OutputJson)
}

& $PythonExe @argsList
exit $LASTEXITCODE

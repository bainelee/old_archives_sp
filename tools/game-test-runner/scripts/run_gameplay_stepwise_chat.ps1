param(
    [string]$ProjectRoot = "D:/GODOT_Test/old-archives-sp",
    [string]$PythonExe = "python",
    [string]$GodotBin = "",
    [string]$FlowFile = "",
    [int]$TimeoutSec = 300,
    [double]$MaxSilentSec = 10.0,
    [int]$MaxBatch = 1,
    [double]$WaitScale = 1.0,
    [double]$ResumeSpeed = 1.0,
    [switch]$DisableThinkPause,
    [switch]$EmitShellChat,
    [string]$OutputJson = "",
    [switch]$Template,
    [ValidateSet("three_phase","legacy_five_phase")]
    [string]$ChatProtocolMode = "three_phase",
    [ValidateSet("strict","legacy")]
    [string]$PausePolicy = "strict"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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
    "--max-silent-sec", [string]$MaxSilentSec,
    "--max-batch", [string]$MaxBatch,
    "--wait-scale", "1.0",
    "--resume-speed", [string]$ResumeSpeed,
    "--chat-protocol-mode", [string]$ChatProtocolMode,
    "--pause-policy", [string]$PausePolicy,
    "--emit-shell-chat"
)
if ($DisableThinkPause) {
    $argsList += "--disable-think-pause"
}
# Step output is mandatory; keep -EmitShellChat for backward-compatible CLI.
$null = $EmitShellChat
# Wait scale is fixed at 1.0; keep -WaitScale for backward-compatible CLI.
$null = $WaitScale
if ($Template) {
    $argsList += "--template"
}
else {
    if ([string]::IsNullOrWhiteSpace($FlowFile)) {
        throw "FlowFile is required when -Template is not set."
    }
    $argsList += @("--flow-file", $FlowFile)
}
if (-not [string]::IsNullOrWhiteSpace($OutputJson)) {
    $argsList += @("--output-json", $OutputJson)
}

& $PythonExe @argsList
exit $LASTEXITCODE

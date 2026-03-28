param(
    [string]$ProjectRoot = "D:/GODOT_Test/old-archives-sp",
    [string]$PythonExe = "python",
    [string]$GodotBin = "",
    [string]$FlowFile = "",
    [int]$TimeoutSec = 300,
    [int]$MaxBatch = 1,
    [double]$WaitScale = 0.2,
    [double]$ResumeSpeed = 6.0,
    [switch]$DisableThinkPause,
    [switch]$EmitShellChat,
    [string]$OutputJson = "",
    [switch]$Template
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
    "--max-batch", [string]$MaxBatch,
    "--wait-scale", [string]$WaitScale,
    "--resume-speed", [string]$ResumeSpeed
)
if ($DisableThinkPause) {
    $argsList += "--disable-think-pause"
}
if ($EmitShellChat) {
    $argsList += "--emit-shell-chat"
}
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

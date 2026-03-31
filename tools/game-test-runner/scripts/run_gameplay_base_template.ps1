param(
    [string]$ProjectRoot = "D:/GODOT_Test/old-archives-sp",
    [string]$PythonExe = "python",
    [string]$GodotBin = "",
    [string]$OutputJson = "",
    [int]$TimeoutSec = 300,
    [double]$MaxSilentSec = 10.0,
    [int]$MaxBatch = 3,
    [double]$WaitScale = 1.0,
    [double]$ResumeSpeed = 1.0,
    [switch]$DisableThinkPause,
    [switch]$EmitShellChat,
    [double]$PollIntervalSec = 0.8,
    [double]$BroadcastMergeWindowSec = 1.5,
    [int]$MaxWaitSec = 900,
    [int]$StreamLimit = 120,
    [switch]$NoChatProgress,
    [ValidateSet("three_phase","legacy_five_phase")]
    [string]$ChatProtocolMode = "three_phase",
    [ValidateSet("strict","legacy")]
    [string]$PausePolicy = "strict"
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
    $cfgGodot = Join-Path $ProjectRoot "tools/game-test-runner/config/godot_executable.json"
    if (Test-Path -LiteralPath $cfgGodot) {
        try {
            $j = Get-Content -LiteralPath $cfgGodot -Raw -Encoding UTF8 | ConvertFrom-Json
            $c = [string]$j.godot_executable
            if ([string]::IsNullOrWhiteSpace($c)) { $c = [string]$j.godot_bin }
            if (-not [string]::IsNullOrWhiteSpace($c)) { $GodotBin = $c }
        } catch {}
    }
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
    "--template",
    "--emit-shell-chat"
)
if ($DisableThinkPause) {
    $argsList += "--disable-think-pause"
}
# Step output is mandatory; keep -EmitShellChat for backward-compatible CLI.
$null = $EmitShellChat
# Wait scale is fixed at 1.0; keep -WaitScale for backward-compatible CLI.
$null = $WaitScale
if (-not [string]::IsNullOrWhiteSpace($OutputJson)) {
    $argsList += @("--output-json", $OutputJson)
}

& $PythonExe @argsList
exit $LASTEXITCODE

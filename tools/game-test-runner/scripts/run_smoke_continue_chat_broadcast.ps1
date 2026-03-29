param(
    [string]$ProjectRoot = "D:/GODOT_Test/old-archives-sp",
    [string]$PythonExe = "python",
    [string]$GodotBin = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$godot = [string]$GodotBin
if ([string]::IsNullOrWhiteSpace($godot)) {
    $godot = [string]$env:GODOT_BIN
}
if ([string]::IsNullOrWhiteSpace($godot)) {
    throw "请设置 GODOT_BIN 或传入 -GodotBin"
}

$flow = Join-Path $ProjectRoot "flows/suites/regression/gameplay/smoke_continue_chat_broadcast.json"
$runner = Join-Path $ProjectRoot "tools/game-test-runner/scripts/run_gameplay_stepwise_chat.py"
if (-not (Test-Path $flow)) { throw "missing flow: $flow" }
if (-not (Test-Path $runner)) { throw "missing runner: $runner" }

$env:GODOT_BIN = $godot
& $PythonExe -u $runner `
    --project-root $ProjectRoot `
    --godot-bin $godot `
    --flow-file $flow `
    --timeout-sec 120 `
    --emit-shell-chat

exit $LASTEXITCODE

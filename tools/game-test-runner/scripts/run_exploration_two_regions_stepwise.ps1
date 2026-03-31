param(
    [string]$ProjectRoot = "D:/GODOT_Test/old-archives-sp",
    [string]$PythonExe = "python",
    [string]$GodotBin = "",
    [int]$TimeoutSec = 600
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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

$gp = Join-Path $ProjectRoot "flows/suites/regression/gameplay"
$phase1 = Join-Path $gp "exploration_two_regions_slot0_phase1.json"
$phase2 = Join-Path $gp "exploration_two_regions_slot0_phase2.json"
$stepwisePs1 = Join-Path $ProjectRoot "tools/game-test-runner/scripts/run_gameplay_stepwise_chat.ps1"

foreach ($p in @($phase1, $phase2, $stepwisePs1)) {
    if (-not (Test-Path -LiteralPath $p)) { throw "missing: $p" }
}

Write-Host "=== exploration_two_regions phase1 ==="
& $stepwisePs1 -ProjectRoot $ProjectRoot -GodotBin $GodotBin -FlowFile $phase1 -TimeoutSec $TimeoutSec
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "=== exploration_two_regions phase2 ==="
& $stepwisePs1 -ProjectRoot $ProjectRoot -GodotBin $GodotBin -FlowFile $phase2 -TimeoutSec $TimeoutSec
exit $LASTEXITCODE

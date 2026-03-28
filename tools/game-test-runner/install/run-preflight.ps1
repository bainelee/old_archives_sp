param(
    [string]$PythonExe = "python",
    [string]$GodotBin = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "../../..")).Path
$ciScript = Join-Path $projectRoot "tools/game-test-runner/scripts/run_acceptance_ci.ps1"

$args = @(
    "-ExecutionPolicy", "Bypass",
    "-File", $ciScript,
    "-ProjectRoot", $projectRoot,
    "-PythonExe", $PythonExe,
    "-OnlyPreflight"
)
if (-not [string]::IsNullOrWhiteSpace($GodotBin)) {
    $args += @("-GodotBin", $GodotBin)
}

& powershell @args
exit $LASTEXITCODE

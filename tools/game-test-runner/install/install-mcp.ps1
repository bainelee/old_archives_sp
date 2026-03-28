param(
    [string]$ProjectRoot = "D:/GODOT_Test/old-archives-sp",
    [string]$PythonExe = "python",
    [string]$Channel = "stable",
    [switch]$CheckUpdateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$manifestPath = Join-Path $ProjectRoot "tools/game-test-runner/mcp/version_manifest.json"
$serverPath = Join-Path $ProjectRoot "tools/game-test-runner/mcp/server.py"

if (-not (Test-Path $manifestPath)) {
    throw "Missing version manifest: $manifestPath"
}
if (-not (Test-Path $serverPath)) {
    throw "Missing MCP server: $serverPath"
}

$manifest = Get-Content -Raw -Encoding UTF8 $manifestPath | ConvertFrom-Json
if (-not ($manifest.channels.PSObject.Properties.Name -contains $Channel)) {
    throw "Unknown channel: $Channel"
}
$channelMeta = $manifest.channels.$Channel
$version = [string]$channelMeta.version

if ($CheckUpdateOnly) {
    Write-Output ("[UPDATE] channel=" + $Channel + " latest=" + $version)
    Write-Output ("[UPDATE] notes=" + [string]$channelMeta.release_notes)
    exit 0
}

$preflight = & $PythonExe $serverPath --tool check_test_runner_environment --project-root $ProjectRoot
if ($LASTEXITCODE -ne 0) {
    throw "Environment preflight failed.`n$preflight"
}

Write-Output ("[INSTALL] game-test-runner-mcp " + $version + " (" + $Channel + ")")
Write-Output "[INSTALL] completed. Next step: run tools/game-test-runner/install/start-mcp.ps1"

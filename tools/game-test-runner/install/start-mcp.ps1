param(
    [string]$ProjectRoot = "D:/GODOT_Test/old-archives-sp",
    [string]$PythonExe = "python",
    [string]$Channel = "stable"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$serverPath = Join-Path $ProjectRoot "tools/game-test-runner/mcp/server.py"
$manifestPath = Join-Path $ProjectRoot "tools/game-test-runner/mcp/version_manifest.json"

if (-not (Test-Path $serverPath)) {
    throw "Missing MCP server entry: $serverPath"
}
if (-not (Test-Path $manifestPath)) {
    throw "Missing version manifest: $manifestPath"
}

$manifest = Get-Content -Raw -Encoding UTF8 $manifestPath | ConvertFrom-Json
$targetVersion = ""
if ($manifest.channels.PSObject.Properties.Name -contains $Channel) {
    $targetVersion = [string]$manifest.channels.$Channel.version
}
if ([string]::IsNullOrWhiteSpace($targetVersion)) {
    throw "Unknown update channel: $Channel"
}

$preflight = & $PythonExe $serverPath --tool check_test_runner_environment --project-root $ProjectRoot
if ($LASTEXITCODE -ne 0) {
    throw "Preflight failed before MCP start.`n$preflight"
}

Write-Output ("[MCP] channel=" + $Channel + " version=" + $targetVersion)
Write-Output ("[MCP] settings snippet:")
Write-Output '{'
Write-Output '  "mcpServers": {'
Write-Output '    "game-test-runner": {'
Write-Output '      "command": "python",'
Write-Output ('      "args": ["' + $serverPath.Replace("\", "/") + '"]')
Write-Output '    }'
Write-Output '  }'
Write-Output '}'

# Keep foreground for MCP client process supervision.
& $PythonExe $serverPath --tool list_test_scenarios --args "{}" | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "MCP smoke check failed."
}

Write-Output "[MCP] ready. Configure it in IDE Settings using snippet above."

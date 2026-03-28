param(
    [string]$ProjectRoot = "D:/GODOT_Test/old-archives-sp",
    [string]$PythonExe = "python",
    [string]$Channel = "stable",
    [string]$PackageDir = "",
    [switch]$SkipSmokeCheck,
    [switch]$ForceDownload
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$mcpRoot = Join-Path $ProjectRoot "tools/game-test-runner/mcp"
$manifestPath = Join-Path $mcpRoot "version_manifest.json"
$stateDir = Join-Path $ProjectRoot ".mcp-install"
$statePath = Join-Path $stateDir "state.json"
$backupRoot = Join-Path $stateDir "backups"

function Get-SafeString {
    param([object]$Value)
    if ($null -eq $Value) {
        return ""
    }
    return [string]$Value
}

function Resolve-PackageRoot {
    param(
        [string]$ExtractRoot,
        [string]$ZipLayout
    )
    $layout = (Get-SafeString $ZipLayout).Trim()
    if ([string]::IsNullOrWhiteSpace($layout) -or $layout -eq "mcp_root") {
        $candidate = Join-Path $ExtractRoot "server.py"
        if (Test-Path $candidate) {
            return $ExtractRoot
        }
    }
    if ($layout -eq "nested_mcp") {
        $nested = Join-Path $ExtractRoot "mcp"
        $candidate = Join-Path $nested "server.py"
        if (Test-Path $candidate) {
            return $nested
        }
    }
    $dirs = Get-ChildItem -LiteralPath $ExtractRoot -Directory -ErrorAction SilentlyContinue
    if ($dirs.Count -eq 1) {
        $single = $dirs[0].FullName
        $candidate = Join-Path $single "server.py"
        if (Test-Path $candidate) {
            return $single
        }
        $nested = Join-Path $single "mcp"
        $nestedCandidate = Join-Path $nested "server.py"
        if (Test-Path $nestedCandidate) {
            return $nested
        }
    }
    throw "Cannot resolve package root from zip layout: $layout"
}

function Get-DownloadPackageRoot {
    param(
        [object]$Artifact,
        [string]$WorkDir
    )
    $url = (Get-SafeString $Artifact.url).Trim()
    if ([string]::IsNullOrWhiteSpace($url)) {
        throw "Channel artifact.url is empty."
    }
    $filename = (Get-SafeString $Artifact.filename).Trim()
    if ([string]::IsNullOrWhiteSpace($filename)) {
        $filename = "game-test-runner-mcp.zip"
    }
    $zipPath = Join-Path $WorkDir $filename
    Write-Output ("[UPDATE] downloading package: " + $url)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing

    $expectedSizeRaw = (Get-SafeString $Artifact.size_bytes).Trim()
    if (-not [string]::IsNullOrWhiteSpace($expectedSizeRaw)) {
        try {
            $expectedSize = [int64]$expectedSizeRaw
            $actualSize = (Get-Item -LiteralPath $zipPath).Length
            if ($expectedSize -gt 0 -and $actualSize -ne $expectedSize) {
                throw "Download size mismatch. expected=$expectedSize actual=$actualSize"
            }
        }
        catch {
            throw "Invalid artifact.size_bytes value: $expectedSizeRaw"
        }
    }

    $expectedSha = (Get-SafeString $Artifact.sha256).Trim().ToLowerInvariant().Replace("sha256:", "")
    if (-not [string]::IsNullOrWhiteSpace($expectedSha)) {
        $actualSha = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash.ToLowerInvariant()
        if ($actualSha -ne $expectedSha) {
            throw "SHA256 mismatch. expected=$expectedSha actual=$actualSha"
        }
        Write-Output "[UPDATE] sha256 verification passed."
    }

    $extractDir = Join-Path $WorkDir "extract"
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force
    $zipLayout = (Get-SafeString $Artifact.zip_layout).Trim()
    return Resolve-PackageRoot -ExtractRoot $extractDir -ZipLayout $zipLayout
}

if (-not (Test-Path $manifestPath)) {
    throw "Missing version manifest: $manifestPath"
}

$manifest = Get-Content -Raw -Encoding UTF8 $manifestPath | ConvertFrom-Json
if (-not ($manifest.channels.PSObject.Properties.Name -contains $Channel)) {
    throw "Unknown channel: $Channel"
}
$channelInfo = $manifest.channels.$Channel
$targetVersion = [string]$channelInfo.version
if ([string]::IsNullOrWhiteSpace($targetVersion)) {
    throw "Missing version in channel: $Channel"
}
$artifact = $channelInfo.artifact
$artifactUrl = ""
if ($null -ne $artifact) {
    $artifactUrl = (Get-SafeString $artifact.url).Trim()
}

if (-not (Test-Path $stateDir)) {
    New-Item -ItemType Directory -Path $stateDir | Out-Null
}
if (-not (Test-Path $backupRoot)) {
    New-Item -ItemType Directory -Path $backupRoot | Out-Null
}

$currentVersion = "dev"
if (Test-Path $statePath) {
    try {
        $stateObj = Get-Content -Raw -Encoding UTF8 $statePath | ConvertFrom-Json
        if ($null -ne $stateObj.current_version) {
            $currentVersion = [string]$stateObj.current_version
        }
    }
    catch {
        $currentVersion = "dev"
    }
}

if (
    $currentVersion -eq $targetVersion `
    -and [string]::IsNullOrWhiteSpace($PackageDir) `
    -and [string]::IsNullOrWhiteSpace($artifactUrl) `
    -and -not $ForceDownload
) {
    Write-Output ("[UPDATE] already latest: " + $targetVersion)
    exit 0
}

$backupDir = Join-Path $backupRoot ("mcp_" + (Get-Date -Format "yyyyMMddTHHmmssfff") + "_" + $currentVersion)
New-Item -ItemType Directory -Path $backupDir | Out-Null
Copy-Item -Path $mcpRoot -Destination (Join-Path $backupDir "mcp") -Recurse -Force
Write-Output ("[UPDATE] backup created: " + $backupDir)

$updated = $false
$packageSource = "none"
$workRoot = Join-Path $stateDir ("work_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $workRoot | Out-Null
try {
    if (-not [string]::IsNullOrWhiteSpace($PackageDir)) {
        if (-not (Test-Path $PackageDir)) {
            throw "PackageDir not found: $PackageDir"
        }
        $candidateServer = Join-Path $PackageDir "server.py"
        if (-not (Test-Path $candidateServer)) {
            throw "PackageDir missing server.py: $candidateServer"
        }
        Copy-Item -Path (Join-Path $PackageDir "*") -Destination $mcpRoot -Recurse -Force
        Write-Output ("[UPDATE] package copied from: " + $PackageDir)
        $updated = $true
        $packageSource = "local"
    }
    elseif (-not [string]::IsNullOrWhiteSpace($artifactUrl)) {
        if ($currentVersion -eq $targetVersion -and -not $ForceDownload) {
            Write-Output ("[UPDATE] already latest by version: " + $targetVersion)
        }
        else {
            $downloadRoot = Get-DownloadPackageRoot -Artifact $artifact -WorkDir $workRoot
            $candidateServer = Join-Path $downloadRoot "server.py"
            if (-not (Test-Path $candidateServer)) {
                throw "Downloaded package missing server.py: $candidateServer"
            }
            Copy-Item -Path (Join-Path $downloadRoot "*") -Destination $mcpRoot -Recurse -Force
            Write-Output ("[UPDATE] package downloaded and applied from channel: " + $Channel)
            $updated = $true
            $packageSource = "remote"
        }
    }
    else {
        Write-Output "[UPDATE] no PackageDir or remote artifact. only version channel/state updated."
    }

    if (-not $SkipSmokeCheck) {
        $serverPath = Join-Path $mcpRoot "server.py"
        $smoke = & $PythonExe $serverPath --tool get_mcp_runtime_info --args "{}"
        if ($LASTEXITCODE -ne 0) {
            throw "Smoke check failed.`n$smoke"
        }
        Write-Output "[UPDATE] smoke check passed."
    }

    $statePayload = [ordered]@{
        current_version = $targetVersion
        channel = $Channel
        updated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
        package_applied = $updated
        package_source = $packageSource
    }
    $statePayload | ConvertTo-Json -Depth 10 | Out-File -FilePath $statePath -Encoding utf8
    Write-Output ("[UPDATE] success -> version " + $targetVersion)
}
catch {
    Write-Output ("[UPDATE] failed: " + $_.Exception.Message)
    Write-Output "[UPDATE] rolling back..."
    $backupMcp = Join-Path $backupDir "mcp"
    if (-not (Test-Path $backupMcp)) {
        throw "Rollback failed: backup mcp dir missing: $backupMcp"
    }
    Remove-Item -Path $mcpRoot -Recurse -Force
    Copy-Item -Path $backupMcp -Destination $mcpRoot -Recurse -Force
    Write-Output "[UPDATE] rollback completed."
    throw
}
finally {
    if (Test-Path $workRoot) {
        Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

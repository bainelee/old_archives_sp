param(
    [string]$ProjectRoot = "D:/GODOT_Test/old-archives-sp",
    [string]$MainBranch = "main",
    [string]$Topic = "gameplayflow-bug",
    [string]$FixBranch = "",
    [string]$RedoBranch = "",
    [string]$AllowlistFile = "tools/game-test-runner/config/gf_exp_allowlist.json",
    [string]$ValidationScript = "tools/game-test-runner/scripts/run_gameplay_exploration_validation.ps1",
    [string]$GodotBin = "",
    [string]$ExpNoteFile = "",
    [switch]$SkipValidation,
    [switch]$SkipRemoteSync,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Stage {
    param([string]$Text)
    Write-Host ("[GF-EXP] " + $Text)
}

function Normalize-RelPath {
    param([string]$Path)
    return (($Path -replace "\\", "/").TrimStart("./"))
}

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)][string[]]$Args,
        [switch]$Mutating
    )
    $cmdText = "git " + ($Args -join " ")
    if ($DryRun -and $Mutating) {
        Write-Stage ("DRY-RUN: " + $cmdText)
        return ""
    }
    Write-Stage $cmdText
    $output = (& git @Args 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw ("git command failed: " + $cmdText + "`n" + ($output -join "`n"))
    }
    return ($output -join "`n")
}

function Test-MatchAny {
    param(
        [string]$RelPath,
        [string[]]$Patterns
    )
    $p = Normalize-RelPath $RelPath
    foreach ($pattern in $Patterns) {
        $wild = (Normalize-RelPath $pattern)
        if ($p -like $wild) {
            return $true
        }
    }
    return $false
}

function Get-ChangedFilesFromBranch {
    param(
        [string]$BaseBranch,
        [string]$SourceBranch
    )
    $raw = Invoke-Git -Args @("diff", "--name-only", ($BaseBranch + "..." + $SourceBranch))
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @()
    }
    $rows = @()
    foreach ($line in ($raw -split "`n")) {
        $trim = $line.Trim()
        if (-not [string]::IsNullOrWhiteSpace($trim)) {
            $rows += (Normalize-RelPath $trim)
        }
    }
    return $rows
}

function Test-LocalBranchExists {
    param([string]$BranchName)
    $raw = (& git branch --list $BranchName 2>$null | Out-String)
    return (-not [string]::IsNullOrWhiteSpace($raw))
}

Push-Location $ProjectRoot
try {
    $dateTag = [DateTime]::UtcNow.ToString("yyyyMMdd")
    if ([string]::IsNullOrWhiteSpace($FixBranch)) {
        $FixBranch = "fix/gfexp-" + $Topic + "-" + $dateTag
    }
    if ([string]::IsNullOrWhiteSpace($RedoBranch)) {
        $RedoBranch = "fix/redo-" + $Topic + "-" + $dateTag
    }
    if ([string]::IsNullOrWhiteSpace($ExpNoteFile)) {
        $ExpNoteFile = "docs/testing/gf-exp-" + $Topic + "-" + $dateTag + ".md"
    }

    $allowPath = Join-Path $ProjectRoot $AllowlistFile
    if (-not (Test-Path $allowPath)) {
        throw ("allowlist not found: " + $allowPath)
    }
    $allowCfg = Get-Content -Path $allowPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $allowPatterns = @($allowCfg.allow)
    $denyPatterns = @($allowCfg.deny)

    $isRepo = Invoke-Git -Args @("rev-parse", "--is-inside-work-tree")
    if (-not $isRepo.Contains("true")) {
        throw "current directory is not a git repository"
    }

    $statusShort = Invoke-Git -Args @("status", "--porcelain")
    if ((-not $DryRun) -and (-not [string]::IsNullOrWhiteSpace($statusShort))) {
        throw "working tree is dirty. Please commit or stash first."
    }

    Write-Stage "Phase A: 创建修复分支并执行 GameplayFlow 验证"
    if (-not $SkipRemoteSync) {
        Invoke-Git -Args @("fetch", "origin") -Mutating
    }
    Invoke-Git -Args @("switch", $MainBranch) -Mutating
    if (-not $SkipRemoteSync) {
        Invoke-Git -Args @("pull", "--ff-only", "origin", $MainBranch) -Mutating
    }
    Invoke-Git -Args @("switch", "-c", $FixBranch) -Mutating

    if (-not $SkipValidation) {
        $validationPath = Join-Path $ProjectRoot $ValidationScript
        if (-not (Test-Path $validationPath)) {
            throw ("validation script missing: " + $validationPath)
        }
        $validationArgs = @("-ExecutionPolicy", "Bypass", "-File", $validationPath, "-ProjectRoot", $ProjectRoot)
        if (-not [string]::IsNullOrWhiteSpace($GodotBin)) {
            $validationArgs += @("-GodotBin", $GodotBin)
        }
        if ($DryRun) {
            Write-Stage ("DRY-RUN: powershell " + ($validationArgs -join " "))
        }
        else {
            Write-Stage "运行 exploration validation 入口脚本"
            & powershell @validationArgs
            if ($LASTEXITCODE -ne 0) {
                throw "validation failed in Phase A"
            }
        }
    }

    Write-Stage "Phase B: 生成或更新 EXP 文件"
    if ($DryRun) {
        Write-Stage ("DRY-RUN: ensure EXP note file " + $ExpNoteFile)
    }
    else {
        $expAbs = Join-Path $ProjectRoot $ExpNoteFile
        $expDir = Split-Path -Parent $expAbs
        if (-not (Test-Path $expDir)) {
            New-Item -ItemType Directory -Path $expDir | Out-Null
        }
        if (-not (Test-Path $expAbs)) {
            $content = @(
                "# GF-EXP 笔记",
                "",
                "## 现象",
                "- TODO",
                "",
                "## 定位路径",
                "- TODO",
                "",
                "## 修复策略",
                "- TODO",
                "",
                "## 回归结论",
                "- TODO"
            ) -join "`r`n"
            [System.IO.File]::WriteAllText($expAbs, $content, [System.Text.UTF8Encoding]::new($false))
        }
    }

    Write-Stage "Phase C: 仅同步 EXP 资产到 main"
    $changed = @()
    if ($DryRun -and -not (Test-LocalBranchExists -BranchName $FixBranch)) {
        $simulated = "docs/testing/gf-exp-" + $Topic + "-" + $dateTag + ".md"
        Write-Stage ("DRY-RUN: fix branch not present, simulate changed file: " + $simulated)
        $changed = @($simulated)
    }
    else {
        $changed = Get-ChangedFilesFromBranch -BaseBranch $MainBranch -SourceBranch $FixBranch
    }
    $allowedChanged = @()
    $outOfScope = @()
    foreach ($f in $changed) {
        $isAllowed = Test-MatchAny -RelPath $f -Patterns $allowPatterns
        $isDenied = Test-MatchAny -RelPath $f -Patterns $denyPatterns
        if ($isAllowed -and -not $isDenied) {
            $allowedChanged += $f
        }
        else {
            $outOfScope += $f
        }
    }

    if ($outOfScope.Count -gt 0) {
        throw ("audit failed: non-EXP files detected`n" + ($outOfScope -join "`n"))
    }
    if ((-not $DryRun) -and $allowedChanged.Count -eq 0) {
        throw "audit failed: no allowed EXP files changed"
    }

    Invoke-Git -Args @("switch", $MainBranch) -Mutating
    foreach ($path in $allowedChanged) {
        Invoke-Git -Args @("checkout", $FixBranch, "--", $path) -Mutating
    }
    Invoke-Git -Args @("add", "--") -Mutating
    $hasStaged = Invoke-Git -Args @("diff", "--cached", "--name-only")
    if (-not [string]::IsNullOrWhiteSpace($hasStaged)) {
        $msg = "chore: sync gf-exp assets from " + $FixBranch
        Invoke-Git -Args @("commit", "-m", $msg) -Mutating
    }

    Write-Stage "Phase D: 从 main 建立重修分支"
    Invoke-Git -Args @("switch", "-c", $RedoBranch) -Mutating

    Write-Stage "GF-EXP cycle completed."
    Write-Output ("GFEXP_FIX_BRANCH=" + $FixBranch)
    Write-Output ("GFEXP_REDO_BRANCH=" + $RedoBranch)
    Write-Output ("GFEXP_EXP_FILES=" + ($allowedChanged -join ","))
}
finally {
    Pop-Location
}

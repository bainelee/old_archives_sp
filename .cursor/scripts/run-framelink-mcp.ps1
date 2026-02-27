# Framelink MCP 启动脚本：从 .cursor/local/figma-token.txt 读取 token 并启动
# 该脚本可安全提交到 git；token 文件被 .gitignore 排除

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$tokenPath = Join-Path $projectRoot ".cursor" "local" "figma-token.txt"

$env:FIGMA_API_KEY = ""
if (Test-Path $tokenPath) {
    $env:FIGMA_API_KEY = (Get-Content $tokenPath -Raw).Trim()
}

& npx -y figma-developer-mcp --stdio

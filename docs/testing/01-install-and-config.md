# 安装与配置（v1）

## 0. 模式速查（先看这个）

| 场景 | 推荐命令 |
|---|---|
| 只检查环境（最快） | `powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp" -OnlyPreflight` |
| 快速门禁（环境 + 契约 + 工具面，默认） | `powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp" -Fast` |
| 完整验收（preflight + 汇总；**不**在此脚本串流 GameplayFlow） | `powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp"`；Gameplay 回归另见 `run_gameplay_regression.ps1`（[README.md](./README.md)） |
| 完整验收 + 显式契约回归 | `powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp" -IncludeContractRegression`（非 Fast 时默认不跑契约，需显式开关或 `-Fast`） |

## 1. 前置条件
- Godot 4.6 已安装并可命令行调用
- Python 3.10+ 可用（`python --version`）
- 项目根目录：`D:/GODOT_Test/old-archives-sp`

推荐（分发环境）：
- 使用环境变量 `GODOT_BIN` 指向 Godot 可执行文件，不依赖调用方传绝对路径参数

## 2. 快速验证（CLI）
在项目根目录执行：

```powershell
python "tools/game-test-runner/core/cli.py" --system exploration --project-root "." --scenario exploration_smoke --dry-run
```

期望：
- 控制台输出 JSON，包含 `run_id` 与 `status=finished`
- 生成目录：`artifacts/test-runs/<run_id>/`

## 3. MCP 适配验证

说明：
- 当前 `tools/game-test-runner/mcp/server.py` 为 CLI 适配入口（`--tool + --args`），用于统一工具面并被 IDE/脚本调用。
- 若在 Cursor Settings 里配置该命令，本质也是由客户端按工具调用参数启动该入口。

### 3.1 列场景
```powershell
python "tools/game-test-runner/mcp/server.py" --tool list_test_scenarios --args "{}"
```

### 3.1.1 查看 MCP 运行时信息
```powershell
python "tools/game-test-runner/mcp/server.py" --tool get_mcp_runtime_info --args "{}"
```

### 3.2 跑一次 dry-run
```powershell
python "tools/game-test-runner/mcp/server.py" --tool run_game_test --system exploration --dry-run
```

### 3.3 环境预检（建议接入 CI）
```powershell
python "tools/game-test-runner/mcp/server.py" --tool check_test_runner_environment --project-root "D:/GODOT_Test/old-archives-sp"
```

期望：
- 返回 `ok=true` 且 `ci_ready=true`
- `checks` 中 `godot_bin`、`project_root` 均为 `passed`

若 `godot_bin` 失败，先设置环境变量：
```powershell
setx GODOT_BIN "D:\GODOT\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe"
```
然后重开终端再执行 3.3。

### 3.4 单入口实时播报（推荐）
```powershell
python "tools/game-test-runner/mcp/server.py" --tool run_and_stream_flow --project-root "D:/GODOT_Test/old-archives-sp" --flow-file "D:/GODOT_Test/old-archives-sp/flows/suites/regression/gameplay/basic_gameplay_slot0_phase1.json" --godot-bin "$env:GODOT_BIN" --chat-mode short --poll-interval-sec 0.8 --max-wait-sec 600 --stream-limit 60
```

参数说明：
- `chat-mode`：`normal|short`（`short` 用于站会式简报）
- `poll-interval-sec`：轮询间隔
- `max-wait-sec`：最大等待秒数
- `stream-limit`：返回快照上限（防止输出过大）

### 3.5 Cursor 本地 MCP 配置（示例）
在 Cursor 的 MCP 配置中加入 game-test-runner 服务（命令示例）：

```json
{
  "mcpServers": {
    "game-test-runner": {
      "command": "python",
      "args": [
        "D:/GODOT_Test/old-archives-sp/tools/game-test-runner/mcp/server.py"
      ]
    }
  }
}
```

### 3.6 ChatRelay 强制门禁（推荐开启）

当希望“必须走 chat relay 主链路”时，在执行类调用参数中加入：

```json
{
  "chat_relay_required": true
}
```

此时仅允许：
- `start_cursor_chat_plugin`
- `pull_cursor_chat_plugin`
- 查询/取消类工具（状态、报告、产物、环境检查）

其它执行入口（如 `run_game_flow`、`start_stepwise_flow` 等）会被服务端拒绝。  
`run_gameplay_stepwise_chat.py` 默认已在终端镜像播报；包装脚本可显式传 `--emit-shell-chat` / `-EmitShellChat`（等价于默认）。仅当明确需要静默时可传 `--no-emit-shell-chat`（须符合产品对「允许静默」的前提）。

## 6. 一键 CI 命令模板（PowerShell）

脚本路径：
- `tools/game-test-runner/scripts/run_acceptance_ci.ps1`

执行：
```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" `
  -ProjectRoot "D:/GODOT_Test/old-archives-sp"
```

可选参数：
- `-GodotBin`：临时覆盖当前会话 `GODOT_BIN`
- `-PythonExe`：指定 Python 可执行文件
- `-OutputJson`：指定汇总报告输出路径
- `-IncludeContractRegression`：附加执行闭环契约回归（`contract_regression.py`）
- `-IncludeToolSurfaceCheck`：附加执行 MCP 工具面快照检查（`mcp_tool_surface_snapshot.py`）
- `-Fast`：快速门禁；在 preflight 通过后**默认**还会跑契约回归（`contract_regression.py`）与 MCP 工具面快照（与 [README.md](./README.md) 一致）。**不**在此脚本内串流历史 acceptance flow，也**不**替代 `run_gameplay_regression.ps1`。
- `-OnlyPreflight`：只做环境检查（不跑契约、不跑工具面）

脚本行为：
1. 调用 `check_test_runner_environment`（失败则退出码 **2**）
2. **不在本脚本内**执行 GameplayFlow 串流；基线 gameplay 请用 `tools/game-test-runner/scripts/run_gameplay_regression.ps1`（或 MCP + `run_gameplay_stepwise_chat.py` 等，见 [14-mcp-core-invariants.md](../design/99-tools/14-mcp-core-invariants.md)）
3. 若启用契约回归（`-IncludeContractRegression`，或 `-Fast` 默认启用）：执行 `contract_regression.py`（失败则退出码 **4**）
4. 若启用工具面检查（`-IncludeToolSurfaceCheck`，或 `-Fast` 默认启用）：执行 `mcp_tool_surface_snapshot.py`（失败则退出码 **5**）
5. 生成汇总 JSON（默认 `artifacts/test-runs/acceptance_ci_<timestamp>.json`）
6. 汇总里保留 `runs` 字段；当前实现不向其中写入 acceptance flow 结果。若未来重新接入 `runs`，「未 resolved」仍可能映射到退出码 **3**（现为兼容保留）

快速门禁示例：
```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" `
  -ProjectRoot "D:/GODOT_Test/old-archives-sp" `
  -Fast
```

说明：
- `-Fast` 默认会启用 contract regression（即使未显式传 `-IncludeContractRegression`）
- `-Fast` 也默认启用 MCP 工具面快照检查（即使未显式传 `-IncludeToolSurfaceCheck`）

仅环境预检示例（最快）：
```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" `
  -ProjectRoot "D:/GODOT_Test/old-archives-sp" `
  -OnlyPreflight
```

汇总 JSON（每个 run）包含关键字段：
- `status`（MCP 闭环状态）
- `report_status`（报告结果状态，来自 report.result_status，回退到 report.status）
- `effective_exit_code`（语义退出码）
- `process_exit_code`（真实进程退出码）

汇总 JSON 顶层关键字段：
- `status`
- `contract_regression`（启用契约回归时包含 `suite_id/status/cases`）

run 目录新增快速失败摘要：
- `failure_summary.json`（聚合 `primary_failure` + `key_files` + 退出码语义）

## 7. 闭环契约回归（fix-loop）

脚本：
- `tools/game-test-runner/core/contract_regression.py`

执行：
```powershell
python "tools/game-test-runner/core/contract_regression.py" --project-root "D:/GODOT_Test/old-archives-sp" --godot-bin "$env:GODOT_BIN"
```

覆盖点：
- waiting_approval 状态契约
- resume_fix_loop -> exhausted + stop_reason
- cancel_test_run -> cancelled
- resume_fix_loop 在 cancelled 后保持 cancelled

## 4. Godot 插件（Bridge Mode）
1. 打开项目。
2. 进入 `Project > Project Settings > Plugins`。
3. 启用 `Test Orchestrator`。
4. 右侧 Dock 仅显示桥接提示信息，不提供任何 flow 执行按钮。

说明：
- Godot 插件不再承担测试控制台职责。
- `gameplayflow` 的启动、执行、播报、验证、失败停止、报告查询全部在 IDE（如 Cursor）中通过 MCP 完成。
- 该设计用于避免“双入口”导致的时序与反馈分叉。

## 5. 可选：Godot 命令路径
若系统找不到 `godot4`，在调用参数中指定 `--godot-bin`，例如：

```powershell
python "tools/game-test-runner/core/cli.py" --system exploration --project-root "." --scenario exploration_smoke --godot-bin "C:/Tools/Godot/Godot_v4.6-stable_win64.exe"
```

## 8. Settings 安装与更新（Windows 试运行）

安装脚本：
- `tools/game-test-runner/install/install-mcp.ps1`
- `tools/game-test-runner/install/start-mcp.ps1`
- `tools/game-test-runner/install/update-mcp.ps1`
- 版本清单：`tools/game-test-runner/mcp/version_manifest.json`

安装：
```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/install/install-mcp.ps1" `
  -ProjectRoot "D:/GODOT_Test/old-archives-sp" `
  -Channel "stable"
```

仅检查更新：
```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/install/install-mcp.ps1" `
  -ProjectRoot "D:/GODOT_Test/old-archives-sp" `
  -Channel "stable" `
  -CheckUpdateOnly
```

启动并输出 Settings 片段：
```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/install/start-mcp.ps1" `
  -ProjectRoot "D:/GODOT_Test/old-archives-sp" `
  -Channel "stable"
```

执行更新（含备份与失败回滚）：
```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/install/update-mcp.ps1" `
  -ProjectRoot "D:/GODOT_Test/old-archives-sp" `
  -Channel "stable"
```

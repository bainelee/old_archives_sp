# Game Test Runner Quick Start

这是一份给团队成员的 5 分钟上手说明。

## 0) 先选执行模式（推荐）

| 你要做什么 | 用哪个模式 | 命令 |
|---|---|---|
| 只确认环境是否可跑（最快） | `OnlyPreflight` | `powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp" -OnlyPreflight` |
| 做快速门禁（环境 + 契约 + 工具面） | `Fast` | `powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp" -Fast` |
| 做完整验收（环境 + 2 条 acceptance） | 默认模式 | `powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp"` |
| 做完整验收 + 契约回归 | 默认 + 契约 | `powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp" -IncludeContractRegression` |
| 探索系统当前阶段专项验证（L1+L2+门禁） | `ExplorationValidation` | `powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_gameplay_exploration_validation.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp" -GodotBin "<GodotExePath>"` |

非技术同学建议先用这一条（仓库根目录执行）：
```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/install/run-preflight.ps1"
```

## 1) 启用插件（Bridge Mode）
- 打开项目后进入 `Project > Project Settings > Plugins`
- 启用 `Test Orchestrator`
- 该插件仅显示桥接提示，不提供 gameplayflow 按钮与本地执行入口
- 所有执行/播报/验证统一通过 IDE（如 Cursor）的 MCP 调用完成

## 2) 配置运行路径（推荐环境变量）
- 推荐设置环境变量 `GODOT_BIN` 指向 Godot 可执行文件
- 插件面板 `Godot Bin` 仍可手动覆盖
- 建议关闭 `Dry Run` 进行真实验证

示例（PowerShell）：
```powershell
setx GODOT_BIN "D:\GODOT\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe"
```

## 3) 常用 MCP 入口（IDE 内调用）
- `get_mcp_runtime_info`：查看当前版本、工具面、更新通道信息
- `run_and_stream_flow`：单入口启动 + 轮询 + 播报聚合
- `start_cursor_chat_plugin` + `pull_cursor_chat_plugin`：chat-first 五阶段逐步播报
- `get_flow_timeline`：读取步骤时间线与证据摘要

工具面快照脚本（CI 可用）：
- `tools/game-test-runner/core/mcp_tool_surface_snapshot.py`

## 4) 看结果
- 产物目录：`artifacts/test-runs/<run_id>/`
- 关键报告：`report.json`、`flow_report.json`、`step_timeline.json`、`failure_summary.json`
- 推荐读取方式：`get_test_artifacts` + `get_test_report` + `get_flow_timeline`

## 5) 产物目录
- 单次 run：`artifacts/test-runs/<run_id>/`
- 套件汇总：`artifacts/test-suites/<suite_id>/`
- CI 汇总：`artifacts/test-runs/acceptance_ci_<timestamp>.json`

## 6) 预期说明
- `visual_regression_probe` 当前是“故意带错位”的 canary 用例  
  因此视觉检查失败是预期行为，用于证明检测链路有效。
- flow 截图当前按前缀 `flow_exploration_` 过滤归档，不再混入 `visual_ui_button_*`。

## 7) 交接与继续开发
- 当前状态文档：`docs/testing/04-handoff-current-state.md`
- 下一对话提示词：`docs/testing/NEXT_CHAT_PROMPT.md`

## 8) 一键 CI（preflight + acceptance）
```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" `
  -ProjectRoot "D:/GODOT_Test/old-archives-sp"
```

说明：
- 脚本会先执行 `check_test_runner_environment`
- 然后串行执行：
  - `flows/ui_room_detail_sync_acceptance.json`
  - `flows/build_clean_wait_linked_acceptance.json`
- 输出汇总 JSON，核心字段命名统一为：
  - 顶层：`status`、`contract_regression`
  - 每个 run：`status`、`report_status`、`effective_exit_code`、`process_exit_code`
- flow run 额外输出：`step_timeline.json`（步骤执行时间线与 evidence_files）

可选：附加闭环契约回归
```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" `
  -ProjectRoot "D:/GODOT_Test/old-archives-sp" `
  -IncludeContractRegression
```

可选：快速门禁（仅 preflight + contract regression）
```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" `
  -ProjectRoot "D:/GODOT_Test/old-archives-sp" `
  -Fast
```

可选：仅环境预检（最快）
```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" `
  -ProjectRoot "D:/GODOT_Test/old-archives-sp" `
  -OnlyPreflight
```

对话窗口优先（Cursor Chat）：
- 新增 MCP 工具：`get_flow_timeline`
- 用途：让 AI 在对话窗口直接汇报 flow 步骤进度、当前步骤、验证说明与证据路径（不依赖插件面板）
- 参数：
  - `view=full`（默认，全量 steps）
  - `view=chat`（聊天友好卡片）
  - `recent_steps_limit`（仅 chat 视图，默认 3）
  - `view=chat` 会额外返回 `key_screenshots`（关键节点截图绝对路径，最多 3 张）
  - `view=chat` 还会返回 `key_screenshot_cards`（`path + label + source_step_id`）
  - `view=chat` 还会返回 `chat_progress`（`当前步骤/目的/结果/下一步/截图简报`）
- 实时轮询工具：
  - `start_game_flow_live`：启动 flow 并立即返回 `run_id`
  - `get_live_flow_progress`：按 `run_id` 轮询进度（推荐 `view=chat`）
  - `run_and_stream_flow`：单工具完成启动 + 轮询 + 最终播报聚合
- `run_and_stream_flow` 支持：
  - `chat_mode=normal|short`（`short` 为站会播报）
  - `poll_interval_sec`、`max_wait_sec`、`stream_limit`
- 示例：
```powershell
python "tools/game-test-runner/mcp/server.py" --tool get_flow_timeline --project-root "D:/GODOT_Test/old-archives-sp" --run-id "<run_id>"
```
```powershell
python "tools/game-test-runner/mcp/server.py" --tool start_game_flow_live --project-root "D:/GODOT_Test/old-archives-sp" --flow-file "D:/GODOT_Test/old-archives-sp/flows/ui_room_detail_sync_acceptance.json" --view chat
python "tools/game-test-runner/mcp/server.py" --tool get_live_flow_progress --project-root "D:/GODOT_Test/old-archives-sp" --run-id "<run_id>" --view chat --recent-steps-limit 3
```
```powershell
python "tools/game-test-runner/mcp/server.py" --tool run_and_stream_flow --project-root "D:/GODOT_Test/old-archives-sp" --flow-file "D:/GODOT_Test/old-archives-sp/flows/ui_room_detail_sync_acceptance.json" --godot-bin "D:/GODOT/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe" --chat-mode short --poll-interval-sec 0.8 --max-wait-sec 600 --stream-limit 60
```

GameplayFlow 通用默认实时播报（推荐）：
- 适用于任意 flow 文件，默认实时输出“当前步骤/目的/结果/下一步”
- 仅在明确要求时关闭播报（`-NoChatProgress`）
- 若在 Cursor 对话里由 AI 执行，优先使用 `start_game_flow_live + get_live_flow_progress` 逐轮回消息（对话内实时播报）；本脚本主要用于终端手工执行/排障。
```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_gameplay_flow_live_chat.ps1" `
  -FlowFile "D:/GODOT_Test/old-archives-sp/flows/build_clean_wait_linked_acceptance.json" `
  -ProjectRoot "D:/GODOT_Test/old-archives-sp" `
  -GodotBin "D:/GODOT/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe"
```

基础流程模板（推荐作为后续 flow 的基线）：
- 流程语义：新游戏覆盖存档0 -> 清理房间等待 -> 建设房间等待 -> 保存游戏 -> 退出 -> 继续游戏验证
- 实现方式：双阶段执行（phase1 + phase2）
  - phase1: `flows/base_validation_slot0_phase1.json`（按设计时长等待清理/建设，保存前强制 `setGameTimeSpeed speed=1.0`）
  - phase2: `flows/base_validation_slot0_phase2.json`（继续游戏后保持 `setGameTimeSpeed speed=1.0` 并验证状态）
- 一键脚本：
```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_gameplay_base_template.ps1" `
  -ProjectRoot "D:/GODOT_Test/old-archives-sp" `
  -GodotBin "D:/GODOT/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe"
```
- 说明：
  - 该脚本默认走 `cursor_chat_plugin` 主链路（`start_cursor_chat_plugin + pull_cursor_chat_plugin`）。
  - `WaitScale` 执行口径固定为 `1.0`，不得用于缩短等待；需调优时请修改 flow 的显式等待参数。
  - 每步固定前置延迟当前为 `0.1s`（`scripts/test/test_driver.gd`），用于减少无意义等待且保持动作稳定。
  - 每一步固定输出 3 段：`开始执行 -> 执行结果 -> 验证结论`。
  - 若验证失败会立即停止，不继续后续步骤。
  - 轮询支持 `max_batch`（默认 3）以减少往返调用，降低对话侧延迟。
  - `-NoChatProgress` 作为兼容参数保留（当前不再关闭 stepwise 的阶段播报）。
  - 播报文案映射可直接编辑：`tools/game-test-runner/mcp/chat_progress_templates.json`

单条 flow 的 chat-first stepwise 执行：
```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_gameplay_stepwise_chat.ps1" `
  -FlowFile "D:/GODOT_Test/old-archives-sp/flows/base_validation_slot0_phase2.json" `
  -ProjectRoot "D:/GODOT_Test/old-archives-sp" `
  -GodotBin "D:/GODOT/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe"
```

chat 审计字段（统一）：
- 每条事件：`phase / step_id / progress / event_utc / game_time / chat_emit_ts / delay_ms`
- 汇总字段：`protocol_all_ok / min_delay_ms / max_delay_ms / avg_delay_ms`

ChatRelay 强约束（必须）：
- 详情文档：`docs/testing/05-chat-relay-guardrails.md`
- 实现现状与用户硬约束总览：`docs/testing/06-chat-first-status-and-requirements.md`
- 故障排查手册：`docs/testing/07-shell-broadcast-troubleshooting.md`
- 执行工具链：`start_cursor_chat_plugin + pull_cursor_chat_plugin`
- MCP 可开启强制门禁：`chat_relay_required=true`（阻断非 relay 执行路径）
- 当启用 `--emit-shell-chat` / `-EmitShellChat` 时，shell 播报采用两行协议：`[emit=HH:MM:SS][event=HH:MM:SS][game=]` + 文本行（无 `[CHAT]` 前缀）

## 9) 安装与更新（Settings 友好）
- 安装脚本：`tools/game-test-runner/install/install-mcp.ps1`
- 启动脚本：`tools/game-test-runner/install/start-mcp.ps1`
- 更新脚本：`tools/game-test-runner/install/update-mcp.ps1`
- 版本清单：`tools/game-test-runner/mcp/version_manifest.json`

检查更新：
```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/install/install-mcp.ps1" `
  -ProjectRoot "D:/GODOT_Test/old-archives-sp" `
  -Channel "stable" `
  -CheckUpdateOnly
```

执行前/中/后 checklist（防偏离）：
- 执行前：确认已拿到 `run_id`，并进入 `pull_cursor_chat_plugin` 循环
- 执行中：按 `started -> result -> verify` 顺序播报，不补历史批次
- 执行后：输出 `protocol_all_ok`、`min/max/avg_delay_ms`、失败步骤与原因（若有）

## 10) 探索系统专项（未完整实现阶段）
- 入口脚本：`tools/game-test-runner/scripts/run_gameplay_exploration_validation.ps1`
- 分层定义：`docs/testing/09-exploration-gameplayflow-validation.md`
- L1 flow：`flows/suites/regression/gameplay/exploration_validation_l1_scene_probe.json`
- L2 flow：`flows/suites/regression/gameplay/exploration_validation_l2_smoke_invariants.json`
- 白名单规则：`flows/rules/exploration_assertion_whitelist_v1.json`

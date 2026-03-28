# Game Test Runner Quick Start

这是一份给团队成员的 5 分钟上手说明。

## 0) 先选执行模式（推荐）

| 你要做什么 | 用哪个模式 | 命令 |
|---|---|---|
| 只确认环境是否可跑（最快） | `OnlyPreflight` | `powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp" -OnlyPreflight` |
| 做快速门禁（环境 + 契约） | `Fast` | `powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp" -Fast` |
| 做完整验收（环境 + 2 条 acceptance） | 默认模式 | `powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp"` |
| 做完整验收 + 契约回归 | 默认 + 契约 | `powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp" -IncludeContractRegression` |

## 1) 启用插件
- 打开项目后进入 `Project > Project Settings > Plugins`
- 启用 `Test Orchestrator`

## 2) 配置运行路径（推荐环境变量）
- 推荐设置环境变量 `GODOT_BIN` 指向 Godot 可执行文件
- 插件面板 `Godot Bin` 仍可手动覆盖
- 建议关闭 `Dry Run` 进行真实验证

示例（PowerShell）：
```powershell
setx GODOT_BIN "D:\GODOT\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe"
```

## 3) 常用按钮
- `Run Exploration Smoke`：探索系统冒烟
- `Record Visual Baseline`：录制视觉基线图
- `Run Visual Check`：执行视觉比对（当前故意注入了 icon 错位，可用于验证检测链路）
- `Run Quick Regression Suite`：一次跑 exploration + visual canary 并输出汇总
- `Run Gameplay Debug Flow`：执行真实流程模板 `exploration_gameplay_flow_v1`

## 4) 看结果
- `Open Folder` 打开当前选中 run 的产物目录
- `Open report.json` 打开结构化报告
- `Open flow_report.json` 打开流程报告（仅 flow run 存在）
- `Open step_timeline.json` 打开步骤时间线（step 状态、说明、证据）
- `Flow Steps (Timeline)` 在插件内查看步骤状态、说明与截图预览（若有）
- flow 运行中会显示 `RUN current_step` 占位行，表示进程仍在推进下一步
- flow 运行前会先从 flow 文件读取步骤清单，并在运行中显示“预测下一步 step_id”
- `Open diff.png` / `Open diff_annotated.png` 打开视觉差异图
- `Copy Status` / `Copy Artifacts Path` 快速复制信息

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
  - phase1: `flows/base_validation_slot0_phase1.json`（进入游戏后设置 `setGameTimeSpeed speed=6.0`）
  - phase2: `flows/base_validation_slot0_phase2.json`（继续游戏后再次设置 `setGameTimeSpeed speed=6.0`）
- 一键脚本：
```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_gameplay_base_template.ps1" `
  -ProjectRoot "D:/GODOT_Test/old-archives-sp" `
  -GodotBin "D:/GODOT/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe"
```
- 说明：
  - 该脚本默认走 `cursor_chat_plugin` 主链路（`start_cursor_chat_plugin + pull_cursor_chat_plugin`）。
  - 每一步固定输出 5 段：`即将开始 -> 开始执行 -> 执行结果 -> 验证结论 -> 通过后进入下一步`。
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
- 执行工具链：`start_cursor_chat_plugin + pull_cursor_chat_plugin`
- MCP 可开启强制门禁：`chat_relay_required=true`（阻断非 relay 执行路径）
- shell `[CHAT]` 默认关闭；仅排障时显式启用 `--emit-shell-chat` / `-EmitShellChat`

执行前/中/后 checklist（防偏离）：
- 执行前：确认已拿到 `run_id`，并进入 `pull_cursor_chat_plugin` 循环
- 执行中：按 `about_to_start -> started -> result -> verify -> next` 顺序播报，不补历史批次
- 执行后：输出 `protocol_all_ok`、`min/max/avg_delay_ms`、失败步骤与原因（若有）

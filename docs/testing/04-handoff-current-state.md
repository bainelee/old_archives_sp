# 当前状态与交接（v6）

本文档用于交接当前“GameplayFlow + MCP + Cursor 对话窗口实时播报”能力，下一次对话可直接续做。

## 0) 交接后先跑哪条命令

| 场景 | 推荐命令 |
|---|---|
| 只确认环境（最快） | `powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp" -OnlyPreflight` |
| 快速门禁（环境 + 契约） | `powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp" -GodotBin "D:/GODOT/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe" -Fast` |
| 完整验收（环境 + 两条 acceptance） | `powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp" -GodotBin "D:/GODOT/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe"` |

最近一次快速门禁（通过）：
- `artifacts/test-runs/acceptance_ci_20260327T160943859Z.json`

## 已完成能力（重点）

### A. 测试产物与契约
- `failure_summary.json`、`flow_report.json`、`step_timeline.json` 已稳定产出。
- `get_test_artifacts` 已返回：
  - `failure_summary_json`
  - `step_timeline_json`
  - `key_files`（包含上述关键文件）
- 契约回归已覆盖：
  - `run_game_flow` 字段：`effective_exit_code/process_exit_code`
  - `artifacts_expose_failure_summary`
  - `artifacts_expose_step_timeline`
  - `run_and_stream_flow_short_chat_contract`
  - `chat_progress_human_structure_contract`

### B. 插件可视化（Godot 面板）
- 失败摘要：`step/category/actual`
- 关键文件快捷打开：
  - `report.json`
  - `flow_report.json`
  - `failure_summary.json`
  - `step_timeline.json`
- Flow Steps 区块：
  - 步骤列表（OK/FAIL/SKIP/RUN/TODO）
  - 详情（id/status/action/validation/expected/actual）
  - 证据打开
  - 截图预览
- 运行中轮询刷新与“预测下一步 step_id”已接入。

### C. Cursor 对话窗口优先（chat-first）
- MCP 新增工具：
  - `get_flow_timeline`（支持 `view=full|chat`）
  - `start_game_flow_live`（异步启动 flow）
  - `get_live_flow_progress`（按 run_id 轮询进度）
  - `run_and_stream_flow`（单入口：启动 + 轮询 + 聚合播报）
- `view=chat` 返回：
  - `chat_card`
  - `recent_steps`
  - `key_screenshots`
  - `key_screenshot_cards`（path + label + source_step_id）
  - `chat_progress`（当前步骤/目的/结果/下一步/截图简报）
  - `chat_progress_short`（短播报模式）
- 可在 Cursor 对话里实现“边跑边播报”。
- 通用默认播报脚本（任意 gameplay flow）：
  - `tools/game-test-runner/scripts/run_gameplay_flow_live_chat.ps1`
  - 默认实时播报，显式关闭用 `-NoChatProgress`
  - 对话内执行优先：AI 直接 MCP 轮询并逐条回复，不依赖 PowerShell 输出

### D. 基础流程模板（已定版）
- 基线语义：`新游戏覆盖存档0 -> 清理等待 -> 建设等待 -> 保存 -> 退出 -> 继续游戏验证`
- 采用双阶段模板固化：
  - `flows/base_validation_slot0_phase1.json`（游戏内六倍速）
  - `flows/base_validation_slot0_phase2.json`（继续游戏后六倍速）
- 一键执行脚本：
  - `tools/game-test-runner/scripts/run_gameplay_base_template.ps1`
  - 已切换为 `chat-first + strict stepwise` 主路径
  - 每步固定 5 段：即将开始 / 开始执行 / 执行结果 / 验证结论 / 通过后进入下一步
  - 验证失败立即停止并收尾会话（不继续下一步）
  - `-NoChatProgress` 为兼容参数（当前不会关闭 stepwise 阶段播报）
  - 播报文案映射：`tools/game-test-runner/mcp/chat_progress_templates.json`（可直接改）

## 关键路径（更新后）
- 插件主入口：`addons/test_orchestrator/plugin.gd`
- 插件时间线工具：`addons/test_orchestrator/flow_timeline_utils.gd`
- MCP 服务：`tools/game-test-runner/mcp/server.py`
- MCP 时间线读取：`tools/game-test-runner/mcp/flow_timeline_reader.py`
- 流程执行器：`tools/game-test-runner/core/flow_runner.py`
- 运行器：`tools/game-test-runner/core/runner.py`
- 契约回归：`tools/game-test-runner/core/contract_regression.py`
- CI 脚本：`tools/game-test-runner/scripts/run_acceptance_ci.ps1`

## 已验证的 live 会话样例

1) build/clean 验收 live：
- run_id：`20260327T161244541970Z_build_clean_wait_linked_acceptance_live`
- 轮询结果：`running -> finished`，最终 `flow_status=passed`，`25/25` 通过

2) UI 房间详情 live：
- run_id：`20260327T161600083813Z_ui_room_detail_sync_acceptance_live`
- 轮询结果：`running -> finished`，最终 `flow_status=passed`，`10/10` 通过
- 关键截图示例：`.../screenshots/room_detail_opened.png`

## 仍需继续推进（下阶段建议）
1. 继续拆分超大文件（第二轮）：
   - `addons/test_orchestrator/plugin.gd`
2. 增加 `chat_progress_short` 的多语言模板（zh/en）切换。
3. 在对话侧支持“截图路径 -> 直接内联展示”桥接（目前已稳定返回绝对路径）。

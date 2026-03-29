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

### B. Godot 插件（Bridge Mode）
- `addons/test_orchestrator/plugin.gd` 已收敛为桥接提示面板，不再提供任何 gameplayflow 执行按钮。
- 流程编排、步骤播报、验证结论、报告读取统一由 IDE 侧 MCP 调用完成；**人类与 Agent 的主观测渠道为 shell（终端）逐步输出**（见 `06-chat-first-status-and-requirements.md`、`.cursor/rules/chat-first-stepwise-core.mdc`）。Cursor 对话窗可为可选并行消费同一事件流。
- 目标是避免 Godot 与 IDE 双入口并行导致的时序偏差与反馈分叉。

### C. Chat-First / 逐步播报（chat-first）
- 口径说明：**shell（终端）为默认主观测与审计面**（`run_gameplay_stepwise_chat.py` 等对 MCP 事件的 print）；IDE 对话可作为并行回传面。
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
  - `flows/suites/regression/gameplay/basic_gameplay_slot0_phase1.json` / `basic_gameplay_slot0_phase2.json`（两房清理建设回归）
- 一键执行脚本：
  - `tools/game-test-runner/scripts/run_gameplay_base_template.ps1`
  - 已切换为 `chat-first + strict stepwise` 主路径
  - 每步固定 3 段：开始执行 / 执行结果 / 验证结论
  - 验证失败立即停止并收尾会话（不继续下一步）
  - `-NoChatProgress` 为兼容参数（当前不会关闭 stepwise 阶段播报）
  - 播报文案映射：`tools/game-test-runner/mcp/chat_progress_templates.json`（可直接改）

### E. MCP 统一接线与安装更新链路
- `tools/game-test-runner/mcp/server.py` 已统一工具面（core/fixloop/live/stepwise/cursor plugin）。
- 新工具：`get_mcp_runtime_info`（返回 server_version、tools、relay_allowed_tools、manifest/update_policy）。
- 已实现 `chat_relay_required=true` 服务端强门禁：非 relay 执行入口会返回 `CHAT_RELAY_REQUIRED`。
- 新增安装运维脚本：
  - `tools/game-test-runner/install/install-mcp.ps1`
  - `tools/game-test-runner/install/start-mcp.ps1`
  - `tools/game-test-runner/install/update-mcp.ps1`
- 版本清单：`tools/game-test-runner/mcp/version_manifest.json`
  - 支持 stable/beta 通道与 artifact 元数据（url/sha256/size/zip_layout）。
- `update-mcp.ps1` 已支持：本地包更新、远端 artifact 下载（若配置 URL）、sha256 校验、失败回滚、smoke check。

## 关键路径（更新后）
- 插件主入口：`addons/test_orchestrator/plugin.gd`
- MCP 服务：`tools/game-test-runner/mcp/server.py`
- MCP 时间线读取：`tools/game-test-runner/mcp/flow_timeline_reader.py`
- 流程执行器：`tools/game-test-runner/core/flow_runner.py`
- 运行器：`tools/game-test-runner/core/runner.py`
- 契约回归：`tools/game-test-runner/core/contract_regression.py`
- 工具面快照：`tools/game-test-runner/core/mcp_tool_surface_snapshot.py`
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
1. 将 `version_manifest.json` 的 `artifact.url/sha256` 接入真实发布源（当前字段已预留）。
2. 增加 `chat_progress_short` 的多语言模板（zh/en）切换。
3. 在对话侧支持“截图路径 -> 直接内联展示”桥接（目前已稳定返回绝对路径）。

## TODO（待补充，后续实现）
- [ ] 接入真实发布源：为 `version_manifest.json` 填充可用 `artifact.url/sha256/size_bytes`，并形成发布更新清单。
- [ ] 明确接入模型：在 `docs/testing/01-install-and-config.md` 增加“CLI 适配入口与 IDE 调用方式”统一说明，避免误解为常驻协议服务。
- [ ] 文档结构整理：统一 `docs/testing/01-install-and-config.md` 章节顺序与编号，减少阅读跳转成本。
- [ ] 跨平台安装补齐：增加 `install` 的 shell 版本（如 `.sh`）或明确 Windows-only 支持边界。
- [ ] 常量去重：将工具面快照中的 relay 白名单改为复用服务端单一来源，避免双处维护漂移。

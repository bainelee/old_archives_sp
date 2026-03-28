# 下一对话执行提示词（可直接复制）

你现在接手 `old-archives-sp` 项目的 GameplayFlow 自动化测试体系。当前目标是**Cursor 对话窗口优先**：用户在聊天里发自然语言，你负责实时执行并持续播报步骤与关键截图，不依赖插件面板。

## 0) 第一件事（必须先做）
先跑快速门禁并贴 summary 路径：
```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" `
  -ProjectRoot "D:/GODOT_Test/old-archives-sp" `
  -GodotBin "D:/GODOT/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe" `
  -Fast
```

判断规则：
- `status=passed`：继续开发
- `status=failed_preflight`：先修环境（优先 `GODOT_BIN`）
- `status=failed` 且 `contract_regression` 失败：先修契约

## 1) 当前已具备能力（不要重复造轮子）

### MCP
- `run_game_flow`
- `get_flow_timeline`（`view=full|chat`）
- `start_game_flow_live`
- `get_live_flow_progress`
- `get_test_artifacts`
- `get_test_run_status` / `resume_fix_loop` / `cancel_test_run`

### chat 视图字段（已可直接用于播报）
- `chat_progress`：`当前步骤/目的/结果/下一步/截图简报`
- `key_screenshot_cards`：`path + label + source_step_id`
- `key_screenshots`

## 2) 实时播报执行规范（严格）
当用户要求“开始跑并持续播报”时（默认行为）：
1. 先调 `start_game_flow_live`
2. 再循环调 `get_live_flow_progress --view chat`
3. 每轮按固定格式回报：
   - 当前步骤
   - 目的
   - 结果
   - 下一步
4. 有截图时必须附“关键节点截图（n/m）：<label> -> <path>”
5. 直到 `state=finished` 才结束

补充默认规则：
- 只要在运行 GameplayFlow，就默认进行实时播报
- 仅当用户明确要求“不要播报/静默运行”时才关闭
- 在 Cursor 对话中执行时，实时播报必须以“助手消息”连续回传；不得仅输出到 PowerShell。
- 如需硬约束，启用 `chat_relay_required=true`：阻断非 `start_cursor_chat_plugin/pull_cursor_chat_plugin` 执行路径。

## 3) 推荐命令模板（用于排障/手工验证）
```powershell
python "tools/game-test-runner/mcp/server.py" --tool start_game_flow_live `
  --project-root "D:/GODOT_Test/old-archives-sp" `
  --flow-file "D:/GODOT_Test/old-archives-sp/flows/ui_room_detail_sync_acceptance.json" `
  --godot-bin "D:/GODOT/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe"
```

```powershell
python "tools/game-test-runner/mcp/server.py" --tool get_live_flow_progress `
  --project-root "D:/GODOT_Test/old-archives-sp" `
  --run-id "<run_id>" `
  --view chat `
  --recent-steps-limit 3
```

```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_gameplay_flow_live_chat.ps1" `
  -FlowFile "D:/GODOT_Test/old-archives-sp/flows/build_clean_wait_linked_acceptance.json" `
  -ProjectRoot "D:/GODOT_Test/old-archives-sp" `
  -GodotBin "D:/GODOT/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe"
```
> 备注：上面脚本用于终端手工运行；对话内任务请优先直接用 MCP 轮询并逐条回消息。

## 4) 下阶段建议目标（优先级）
1. 封装单入口 `run_and_stream_flow`（内部自动 start + poll + chat_progress 输出）
2. 继续拆分超大文件：
   - `addons/test_orchestrator/plugin.gd`
   - `tools/game-test-runner/mcp/server.py`
3. 给 `chat_progress` 增加短版模板（站会播报模式）

## 5) 交付要求
- 不破坏现有契约字段与脚本行为
- 每次改动后给最小验证证据路径
- 输出中文简体

## 6) 防偏离 checklist（每次执行都要做）
- 执行前：
  - 已拿到 `run_id`
  - 明确使用 `start_cursor_chat_plugin + pull_cursor_chat_plugin`
  - 默认关闭 shell `[CHAT]` 输出（除非排障）
- 执行中：
  - 严格按 5 段顺序播报
  - 禁止批量补发历史步骤
- 执行后：
  - 输出 `protocol_all_ok`
  - 输出 `min/max/avg_delay_ms`
  - 输出失败步骤与原因（若失败）

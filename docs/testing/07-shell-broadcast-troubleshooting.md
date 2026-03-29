# Shell 播报故障排查手册

适用范围：`start_cursor_chat_plugin + pull_cursor_chat_plugin` 主链路，以及 `run_gameplay_stepwise_chat.py` 的 shell 镜像播报。

## 1) 快速自检顺序

1. 先确认入口：是否走了 `start_cursor_chat_plugin`，而不是直接执行 `run_game_flow/start_stepwise_flow`。
2. 再确认轮询：是否持续调用 `pull_cursor_chat_plugin`，并带上递增 `ack_seq`。
3. 再看格式：启用 shell 镜像时，是否为两行协议：
   - 元信息行：`[emit=HH:MM:SS][event=HH:MM:SS][game=]`
   - 文本行：步骤文本（无 `[CHAT]` 前缀）
4. 最后看审计：检查 `protocol_all_ok`、`line_length_ok`、`min/max/avg_delay_ms`。

## 2) 常见错误码与处理

- `CHAT_RELAY_REQUIRED`
  - 含义：当前调用启用了 `chat_relay_required=true`，但你调用了非 relay 执行工具。
  - 处理：改为 `start_cursor_chat_plugin` + `pull_cursor_chat_plugin`。

- `CHAT_RELAY_SESSION_REQUIRED`
  - 含义：该 `run_id` 已进入 relay 会话锁，后续调用不可降级到非 relay 工具。
  - 处理：继续使用 `pull_cursor_chat_plugin` 消费事件，不要改走 `execute_step/step_once`。

- `BROADCAST_ENTRY_REQUIRED`
  - 含义：该执行工具默认被禁用（防止“有执行无播报”旁路）。
  - 处理：优先改走 `start_cursor_chat_plugin`；仅在排障明确需要时再显式旁路。

- `TEST_RUNTIME_ACTIVE`
  - 含义：已有测试游戏实例在运行，触发单实例保护。
  - 处理：等待当前 run 结束或取消；不要并发启动第二个测试游戏实例。

## 3) 常见现象定位

- 现象：完全无播报
  - 检查 `chat_audit_entries` 是否为空；为空通常说明未走 relay 主链或轮询中断。

- 现象：播报缺段（不是 3 段）
  - 检查 `protocol_all_ok`；若为 `false`，查看对应 `step_id/progress` 的阶段缺失点。

- 现象：文本难读或过长
  - 检查 `line_length_ok`；若为 `false`，看 `line_length_violations` 里的具体行与长度。

- 现象：看起来“先执行后播报”
  - 检查事件中的 `event_utc` 与 `chat_emit_ts`，并对照 `delay_ms` 是否异常增大。

## 4) 最小验证命令

```powershell
python "tools/game-test-runner/core/mcp_tool_surface_snapshot.py" --project-root "D:/GODOT_Test/old-archives-sp"
```

```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_gameplay_stepwise_chat.ps1" `
  -ProjectRoot "D:/GODOT_Test/old-archives-sp" `
  -GodotBin "D:/GODOT/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe" `
  -FlowFile "D:/GODOT_Test/old-archives-sp/flows/suites/regression/gameplay/basic_gameplay_slot0_phase2.json" `
  -EmitShellChat
```

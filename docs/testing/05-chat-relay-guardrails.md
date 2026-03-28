# Chat Relay Guardrails

目标：避免“步骤已执行但只在 shell 可见”的偏离，确保 Cursor 聊天窗口是唯一主播报面。

## 偏离入口清单

| 入口 | 偏离触发条件 | 风险 |
|---|---|---|
| `run_gameplay_stepwise_chat.py` | 默认打印 `[CHAT]` 到 stdout | 用户误以为这是聊天播报 |
| `run_gameplay_base_template.ps1` | 只看终端输出不做聊天 relay | 聊天无连续步骤播报 |
| `start_stepwise_flow/step_once/autopilot` | 被直接调用且未通过 plugin relay | 执行与展示耦合到 shell |

## 强制门禁

- MCP 参数：`chat_relay_required=true`
- 当该参数启用时，只允许：
  - `start_cursor_chat_plugin`
  - `pull_cursor_chat_plugin`
  - 查询/取消类工具（报告、状态、环境）
- 任何其它执行工具调用将被拒绝。

## 运行规范

1. 启动：`start_cursor_chat_plugin`
2. 拉取：循环 `pull_cursor_chat_plugin`（`max_batch=1~3`）
3. 播报：按 `phase` 顺序逐条发送到聊天窗口
4. 收尾：输出 `chat_audit` 摘要（协议完整率 + 延迟）

## shell 输出策略

- 默认不输出 `[CHAT]` 到 shell。
- 仅在排障场景显式启用：`--emit-shell-chat` / `-EmitShellChat`。


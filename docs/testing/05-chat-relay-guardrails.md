# Chat Relay Guardrails

目标：避免“步骤已执行但没有稳定播报”的偏离，确保 shell 播报协议稳定可审计。

## 偏离入口清单

| 入口 | 偏离触发条件 | 风险 |
|---|---|---|
| `run_gameplay_stepwise_chat.py` | 直接走旧格式单行输出 | 文本过长、可读性差 |
| `run_gameplay_base_template.ps1` | 只看终端且未回传 pull 事件结果 | 容易误判为“无连续播报” |
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
3. 播报：主流程按 `phase` 顺序通过 `pull_cursor_chat_plugin` 回传；需要终端镜像时再输出到 shell（两行制）
4. 收尾：输出 `chat_audit` 摘要（协议完整率 + 延迟）

## shell 输出策略

- shell 播报是可选镜像（`--emit-shell-chat` / `-EmitShellChat`），默认可关闭。
- 格式固定为两行：
  - 元信息行：`[emit=HH:MM:SS][event=HH:MM:SS][game=]`
  - 文本行：步骤播报文本（中文单行<=30，英文单行<=60）


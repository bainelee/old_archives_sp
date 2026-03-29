# 14 - MCP 核心不变量（Chat + 三句式 + Flow 播报文案）

本文档为 **game-test-runner MCP** 的产品级硬约束，与实现细节见 [06-chat-first-status-and-requirements.md](../../testing/06-chat-first-status-and-requirements.md)。

## 1. 逐步播报为默认强制（主观测 = shell）

- 凡 **自动化测试**（脚本、Agent、未来外部触发），**默认必须有可审计的逐步播报**；**人类与 Agent 的主观测渠道为 shell（终端）**（`run_gameplay_stepwise_chat.py` 等对 MCP 事件的 `print`），须满足 [06-chat-first-status-and-requirements.md](../../testing/06-chat-first-status-and-requirements.md) 中的三段顺序与两行协议。
- MCP 实现上事件仍经 **ChatRelay**（`start_cursor_chat_plugin` + `pull_cursor_chat_plugin`）产生；**不得**把「仅 IDE 对话窗可见、终端无逐步输出」当作已满足默认约定。
- **除非用户明确说**本次不要播报 / 允许静默，否则 **不得** 采用「静默跑完」或 **仅用** `flow_runner.py` 跑带 `flow_steps` 的 gameplay flow 作为默认路径。
- 仓库 **第一方脚本**（如 `run_gameplay_regression.ps1`）必须使用 **`start_cursor_chat_plugin` + `pull_cursor_chat_plugin`** 链路（或 `run_gameplay_stepwise_chat.py` 等等价包装），不得依赖 `run_game_flow` + `allow_non_broadcast` 作为主回归。

## 2. 三句式结构（默认 `three_phase`）

- 每一步在**对外可见事件**中须按顺序出现：**开始执行 → 执行结果 → 验证结论**（`started` / `result` / `verify`）；失败即停；时序与游戏操作一致（先出现 `开始执行` 再触发该步动作）。
- 审计字段与契约见 `tools/game-test-runner/scripts/run_gameplay_stepwise_chat.py` 与 `contract_regression.py`。

## 3. Flow 步骤与播报文案一体

- **新增或变更 flow 步骤**（含 `step_id` 或语义变化）时，须 **同一变更** 内更新 [chat_progress_templates.json](../../../tools/game-test-runner/mcp/chat_progress_templates.json)（或项目约定的等价映射）。
- 文案须 **易懂、明确**：避免仅暴露内部 id；读 Chat 的人应能理解当前在做什么、验证什么。
- **Agent 强制规则**：`.cursor/rules/gameplay-flow-chat-templates.mdc`（编辑 `flows/**/*.json` 或该 JSON 时加载），确保任意新流程步骤均有 `doing` / `goal` 模板命中。

## 4. `allow_non_broadcast` 与 CLI 门禁

- 经 `server.invoke` / `server.py --tool` 调用 `run_game_flow` 等 **广播门禁工具** 时，若传 `allow_non_broadcast=true`，**必须**同时设置环境变量 **`MCP_ALLOW_NON_BROADCAST=1`**，否则返回 `BROADCAST_BYPASS_DENIED`。
- 用途：**排障/契约特殊场景**，非产品默认。`get_mcp_runtime_info` 会返回 `broadcast_bypass_requires_env` 提示。

## 5. 基础数据对账

- `resource_reconcile` 内 phase1/phase2 须通过 **`run_gameplay_stepwise_chat.py`**（含 `--user-data-dir` 共享存档目录），与主路径共享 **Chat 三句式** 语义，禁止长期直调 `GameTestRunner` 且无 Chat。

## 6. 关联文档与入口

- [11-godot-mcp-gameplay-flow-architecture.md](./11-godot-mcp-gameplay-flow-architecture.md)
- [docs/testing/README.md](../../testing/README.md)

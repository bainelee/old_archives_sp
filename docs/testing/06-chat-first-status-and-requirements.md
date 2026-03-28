# Chat-First 强约束与实现现状

本文用于固化当前 MCP / 插件 / Cursor 插件的已实现能力，并明确用户的不可退让要求。后续所有测试与改动均以本文件为准。

## 用户硬性要求（必须长期满足）

1. 所有测试步骤必须显示在聊天窗口，不允许以 shell 作为主播报渠道。
2. 步骤播报必须严格按 5 段顺序执行，且不能倒序、不能补发历史批次：
   - 即将开始
   - 开始执行
   - 执行结果
   - 验证结论（通过/失败）
   - 仅验证通过才进入下一步
3. 任一步验证失败必须立即停止流程，不允许继续后续步骤。
4. 聊天播报必须与游戏内操作时序一致，禁止出现“先执行动作、后播报开始”的偏离。
5. 必须支持对齐审计：可对照聊天事件时间戳与游戏操作时间戳。
6. 需要降低逐步执行中的等待与思考影响：
   - 通过 `wait_scale` 压缩流程内等待。
   - 在 AI 思考间隙启用全局暂停，避免游戏时间偷跑。

## 已实现内容（MCP / 插件 / Cursor 插件）

### 1) Cursor Chat 插件主路径（默认）

- 主执行链路：`start_cursor_chat_plugin` + `pull_cursor_chat_plugin`
- 强制门禁：`chat_relay_required=true` 时，MCP 会阻断非 ChatRelay 路径。
- 默认不输出 shell `[CHAT]`，仅排障时显式开启 `--emit-shell-chat`。

### 2) 严格逐步协议与失败即停

- 单步协议阶段固定：`about_to_start -> started -> result -> verify -> next`
- 验证失败时，`next` 阶段输出“验证失败，立即停止”，流程终止。
- 不允许“整条 flow 结束后一次性转发”作为主路径。

### 3) 播报时序修复（关键）

- Cursor 插件拉取逻辑已改为相位状态机（prepare/started/execute/verify 分离）。
- 已保证：先发聊天 `即将开始/开始执行`，再触发实际执行动作。
- 已覆盖用户关注点：`click_continue` 前必须先出现聊天播报。

### 4) 游戏时间与聊天时间审计

- 事件字段统一：`event_utc`, `game_time`, `chat_emit_ts`, `delay_ms`
- 审计汇总：`protocol_all_ok`, `min_delay_ms`, `max_delay_ms`, `avg_delay_ms`
- 可用于核对聊天窗口与游戏内时序一致性。

### 5) 思考期暂停与速度恢复

- 在 pull 间隙支持 `pause_during_think`（默认开启）。
- 通过 `setGlobalPause` 控制 `tree.paused` 的完全暂停。
- 执行前按 `resume_speed` 恢复速度，执行后再次暂停。

### 6) 生命周期收尾与一致性

- 覆盖正常完成、验证失败、中断取消的会话收尾。
- 结果以 `run_meta/report/flow_report` 一致状态为准。
- 记录 `pid_exit_verified`，用于确认无僵尸进程。

### 7) 截图步骤稳定性

- screenshot 步骤可产出稳定证据路径。
- verify 阶段支持截图存在性校验（按 flow 与 verify 规则执行）。
- 当前优先保证“路径稳定与可访问”，聊天内直接图片展示可在下一阶段增强。

## 关联文件（核心）

- `tools/game-test-runner/mcp/server.py`
- `tools/game-test-runner/mcp/server_handlers_cursor_chat_plugin.py`
- `tools/game-test-runner/mcp/server_handlers_stepwise_ops.py`
- `tools/game-test-runner/mcp/server_handlers_stepwise_support.py`
- `scripts/test/test_driver.gd`
- `tools/game-test-runner/scripts/run_gameplay_stepwise_chat.py`
- `tools/game-test-runner/scripts/run_gameplay_base_template.ps1`
- `docs/testing/05-chat-relay-guardrails.md`

## 执行准则（后续每次测试都必须遵守）

1. 只用 ChatRelay 主路径执行。
2. 每个 step 必须按 5 阶段顺序逐条播报。
3. 禁止补发历史阶段、禁止在步骤流中夹杂无关叙述。
4. 失败即停并立即汇报失败步骤与原因。
5. 测试结束后输出进程退出验证结果（`pid_exit_verified`）。

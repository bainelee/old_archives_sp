# 下一对话接力 Prompt（基础数据测试收口版）

你现在接手 `old-archives-sp` 的“基础数据测试（资源双轨对账）”收尾工作。  
当前优先级不是新增框架，而是基于已落地设计把 **5 房间流程打通**，并保留现有可解释失败体系。

## 1) 先确认的既有事实（不要回退）

- 双轨时间与 A-B 口径已固定：
  - `runtime_buckets.valid_runtime_hours`
  - `runtime_buckets.ab_gap_ignored_hours`
  - `resource_buckets.expected_no_comm_delay_final_resources = actual_final_resources - ab_unrecorded_by_resource`
- 报告可解释失败体系已固定：
  - `gate_explanations`（含 `gate_code`）
  - `next_actions`
  - `status_explanation`（含 `failed_gates`、`failed_gate_codes`）
- 关键实现在：
  - `tools/game-test-runner/core/resource_reconcile.py`
  - `scripts/test/test_driver.gd`
  - `tools/game-test-runner/mcp/server_handlers_cursor_chat_plugin.py`

## 2) 当前阻塞（本轮要解决）

- 5 房间测试最近一次失败：`E_PHASE1_FLOW_FAILED`（并连锁 `E_PHASE2_FLOW_FAILED`）
- phase1 失败点：`select_cleanup_room_e`
- 现场症状：`ROOM_SELECTION_FAILED`（room click did not enter confirm state）
- 已识别根因：前序流程把 `info` 消耗到 0，触发经济约束，导致 room_e 无法进入清理确认态

## 3) 本轮目标（必须同时满足）

1. 设计并实现“5 房间可通过版本”（调整房间序列/中途回补策略/阶段拆分均可）
2. 再跑一次基础数据测试并给出证据路径
3. 不得破坏既有对账口径与报告契约字段
4. 输出：
   - 总资源：`total_actual_resources`
   - 无通讯延迟理论总资源：`total_expected_no_comm_delay_resources`
   - 延迟影响总量：`total_delay_impact`
   - 若失败：必须附 `failed_gate_codes` 与可执行 next actions

## 4) 建议执行步骤

1. 先跑一次当前基线（确认失败复现一致）
2. 针对 `info` 约束修改 5 房间 flow（优先最小改动）
3. 跑 `resource_reconcile.py` 完整流程
4. 检查报告中的：
   - `runtime_buckets`
   - `resource_buckets`
   - `gate_explanations` / `status_explanation`
5. 更新文档：`docs/testing/08-resource-reconcile-flow.md`（只补本轮增量）

## 5) 验收标准

- `phase1_passed=true`
- `phase2_passed=true`
- `save_resources_loaded=true`
- `unrecorded_resource_by_type` 为空（或仅浮点噪声 `<=1e-6`）
- `failed_gate_codes` 字段仍可用（通过时可为空，失败时必须有值）

## 6) 运行命令（按需替换路径）

```powershell
python "tools/game-test-runner/core/resource_reconcile.py" `
  --project-root "D:/GODOT_Test/old-archives-sp" `
  --godot-bin "D:/GODOT/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe" `
  --timeout-sec 540 `
  --output-json "D:/GODOT_Test/old-archives-sp/artifacts/test-runs/basic_data_test_5rooms_once.json"
```

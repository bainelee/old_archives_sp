# 基础数据测试（资源双轨对账）

目标：验证“流程衔接延迟”是否导致资源计算与存档落盘不一致。

## 流程概览

- phase1：新游戏 -> 依次清理并建设 `room_01`、`room_03`、`room_07` -> 保存
- phase2：继续游戏 -> 复核三房间状态与资源快照
- 对账快照：
  - `R0`：新游戏入场后
  - `room_a_cleaned` / `room_a_built`
  - `room_b_cleaned` / `room_b_built`
  - `room_c_cleaned` / `R2`（第三房间建设完成后，保存前）
  - `Rs`：`slot_0.json` 存档资源
  - `R3`：继续游戏后资源

## 时间双轨

- 游戏内时间：`game_total_hours`
- 真实时间：来自 `driver_flow_events.jsonl` 的 `step_completed.ts`
- 输出窗口：`cleanup` / `build` / `operation_total` / `reopen`
- 新增归因字段：
  - `ignored_runtime_hours`：结算时钟与观测时钟差值（按窗口与总计）
  - `unrecorded_resource_by_type`：真实未记录资源（`actual - expected_discrete`）
  - `attribution_breakdown`：按窗口输出 `expected_continuous` / `expected_discrete` / `delay_window` / `discrete_rounding` / `true_mismatch`

## 通过条件

- phase1/phase2 均通过
- `R2 == Rs`
- `Rs == R3`
- `R2 == R3`
- `unrecorded_resource_by_type` 为空（无真实漏记）

## 核心公式

- `expected_continuous = one_off + rate_per_hour * observed_game_hours`
- `expected_discrete = one_off + rate_per_hour * settled_game_hours`
- `ignored_runtime_hours = settled_game_hours - observed_game_hours`
- `delay_window = rate_per_hour * ignored_runtime_hours`
- `true_mismatch = actual_delta - expected_discrete`

## A-B 延迟口径（固定规则）

- `valid_runtime`：应计入的游戏内合理流逝（包括显式 `wait/sleep`、清理、建设、正常运行）。
- `ab_gap`：测试通讯/验证衔接窗口（A=决定输出并验证；B=验证完成并返回操作）内被忽略的游戏运行时长。
- `expected_no_comm_delay_final` 计算规则：
  - `expected_no_comm_delay_final = actual_final - ab_unrecorded_by_resource`
  - 即：保留 `valid_runtime`，仅剔除 `A-B` 窗口导致的额外资源变化。
- 报告固定输出：
  - `runtime_buckets.valid_runtime_hours`
  - `runtime_buckets.ab_gap_ignored_hours`
  - `resource_buckets.actual_final_resources`
  - `resource_buckets.expected_no_comm_delay_final_resources`
  - `resource_buckets.ab_unrecorded_by_resource`
  - `resource_buckets.total_actual_resources / total_expected_no_comm_delay_resources / total_delay_impact`

## A-B 抑制处理（已落地）

- 在高风险节点启用暂停门控：
  - phase1 保存窗口：`pause_before_save_window` -> `snapshot/save/snapshot` -> `resume_after_save_window`
  - phase2 继续后验证窗口：`pause_before_verify_window` -> `snapshot/check` -> `resume_after_verify_window`
- `test_driver` 预延迟策略收敛：
  - `_before_step` 仅对 `click/dragCamera` 保留可视预延迟
  - `getState/saveGame/check/setGlobalPause` 等非交互步骤不再引入额外预延迟
- 目标：把“通讯衔接导致的资源未记录”压到 0；允许存在极小 `ab_gap_ignored_hours`（若未跨结算边界则 `ab_unrecorded_by_resource=0`）。

## 门禁失败解释（避免误解）

- 报告即使 `status=failed`，也会输出：
  - `gate_explanations`：逐个 gate 的失败原因与修复建议
  - `gate_explanations[*].gate_code`：机器可读错误码（如 `E_PHASE1_FLOW_FAILED`）
  - `next_actions`：下一步排查路径
  - `status_explanation`：失败摘要与 `failed_gates/failed_gate_codes` 列表
- 设计目的：避免后续 agent 仅看到 `failed` 就误判为“资源模型错误”，而忽略具体 gate 失败来源（执行失败/存档读取失败/验证超时等）。

## 执行命令

```powershell
python "tools/game-test-runner/core/resource_reconcile.py" `
  --project-root "D:/GODOT_Test/old-archives-sp" `
  --godot-bin "D:/GODOT/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe"
```

## 关键文件

- `flows/suites/regression/gameplay/basic_data_slot0_phase1.json`
- `flows/suites/regression/gameplay/basic_data_slot0_phase2.json`
- `tools/game-test-runner/core/resource_reconcile.py`

## 当前状态（2026-03-28 收口）

- 设计与实现已稳定：
  - 双轨时间口径（`valid_runtime` / `ab_gap`）已固化到报告字段与计算策略
  - 归因模型已输出 `attribution_breakdown`，可区分离散结算误差与真实未记录资源
  - 失败可解释体系已落地：`gate_explanations` + `next_actions` + `status_explanation` + `gate_code`
- 基础数据测试已从 3 房间扩展到 5 房间流程，但最近一次执行未打通：
  - 失败码：`E_PHASE1_FLOW_FAILED`（并触发 `E_PHASE2_FLOW_FAILED` 连锁）
  - phase1 失败点：`select_cleanup_room_e`
  - 直接现象：`ROOM_SELECTION_FAILED`（room click did not enter confirm state）
  - 已识别原因：前序建设后 `info=0`，触发经济约束，无法进入 room_e 清理确认态

## 失败解释边界（避免误判）

- 上述失败属于“流程经济约束触发”，不是“资源对账模型失效”。
- 若出现 `E_PHASE1_FLOW_FAILED` 且失败步骤是房间选择/确认态进入失败，优先检查：
  - 该步骤前的 `info`/关键资源是否满足进入条件
  - 房间序列是否使早期房间消耗压垮后续步骤
- 只有当 `R2 == Rs` 或 `Rs == R3` 出现异常且 `phase1/phase2` 均通过时，才优先怀疑存档一致性或对账模型。

## 5 房间可通过版本（待实施）

- 目标：不改坏现有双轨对账与门禁解释体系，仅让 5 房间流程在经济约束下可稳定通过。
- 允许策略（任选其一或组合）：
  - 调整 5 房间顺序，降低前半程 `info` 峰值消耗
  - 在第 4/5 房间前插入“可持续 info 回补窗口”（显式等待或可重复收益动作）
  - 拆分阶段并在关键节点保存/继续，避免一次性资源压力
- 验收：
  - `phase1_passed=true` 且 `phase2_passed=true`
  - `unrecorded_resource_by_type` 仍为空或仅浮点噪声（`<=1e-6`）
  - 继续保留并输出 `failed_gate_codes`（即使本轮通过，也要保证字段契约不回退）

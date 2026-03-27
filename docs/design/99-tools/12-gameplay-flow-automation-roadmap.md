# 12 - GameplayFlow 自动化路线图与验收标准

## 1. 路线图目标

本路线图用于把研究结论转成执行计划，优先服务两个闭环场景：
- 场景A：Figma 同步 UI 严格验收闭环（房间详情界面）
- 场景B：等待驱动视觉+逻辑联动闭环（清理/建设）

总体策略：先打通最小闭环，再强化稳定性与可观测性，最后规模化接入 CI。

---

## 2. 分阶段实施（Phase 0 ~ Phase 4）

## Phase 0：研究固化（1 周）
- 产出：
  - [10-maestro-research-deep-dive.md](docs/design/99-tools/10-maestro-research-deep-dive.md)
  - [11-godot-mcp-gameplay-flow-architecture.md](docs/design/99-tools/11-godot-mcp-gameplay-flow-architecture.md)
- 退出标准：
  - 能清晰说明“直接借鉴/需改造/不适用”。
  - 两个闭环场景有标准 flow 规格参考。

## Phase 1：MVP 跑通（2 周）
- 目标：实现本地可执行闭环（不依赖复杂云能力）。
- 范围：
  - DSL MVP + 子流机制
  - MCP 最小工具链（运行、状态、产物、报告）
  - 场景A 首次端到端可执行
- 退出标准：
  - 场景A 在本地可一键跑通，失败有截图和日志。
  - （已达成）MCP 闭环工具可用：`run_game_flow/get_test_run_status/cancel_test_run/resume_fix_loop`。

## Phase 2：稳定性增强（2 周）
- 目标：让流程“可长期回归”。
- 范围：
  - 等待策略分层（polling/extended/stable）
  - 失败分类与有限重试
  - 运行时自愈（错误读取与可恢复重试）
  - 场景B 三阶段断言落地
- 退出标准：
  - 同一场景连续运行 10 次通过率达到目标阈值（见 KPI）。

## Phase 3：CI 集成与报告治理（1~2 周）
- 目标：将结果纳入 PR 质量门禁。
- 范围：
  - JUnit/HTML/JSON 报告落地
  - 产物目录标准化与归档策略
  - `smoke` 同步门禁 + `strict_ui/regression` 异步回归
- 退出标准：
  - PR 可直接看到失败用例、截图链接、错误摘要。
  - （已达成）提供一键 CI 脚本：
    - `tools/game-test-runner/scripts/run_acceptance_ci.ps1`
    - 内置 preflight + 两条 acceptance flow + 汇总 JSON 产出。

## Phase 4：产品化与规模化（持续）
- 目标：形成团队可持续使用的测试产品能力。
- 范围：
  - 模板库、最佳实践、故障排查手册
  - 分片并行、趋势分析、高频根因看板
  - 规则持续迭代（UI 强约束策略）

---

## 3. CI 与报告规范（Todo: ci-artifacts）

## 3.1 产物目录规范

```text
artifacts/test-runs/<run_id>/
  screenshots/
  logs/
  save_snapshots/
  report.json
  report.md
  junit.xml
  flow_report.json
  fix_loop_state.json
```

命名规则：
- 截图：`<step_id>_<phase>_<pass|fail>.png`
- 状态快照：`state_<step_id>.json`
- 归因摘要：`reason_<step_id>.md`

## 3.2 报告分层
- `junit.xml`：CI 门禁与测试统计。
- `report.json`：机器可读，供 MCP 与 Agent 二次分析。
- `report.md`：给开发/策划快速阅读。
- `flow_report.json`：流程步骤与 driver step 视图。
- `logs/driver_flow.json`：driver 执行序列与每步响应。

## 3.3 报告最小字段

```json
{
  "run_id": "string",
  "runId": "string",
  "scenario": "string",
  "status": "passed|failed",
  "result_status": "passed|failed",
  "summary_v2": {
    "total_assertions": 0,
    "passed": 0,
    "failed": 0
  },
  "summary": {
    "totalAssertions": 0,
    "passed": 0,
    "failed": 0
  },
  "primary_failure": {
    "step": "string",
    "category": "string",
    "expected": "string",
    "actual": "string",
    "artifacts": ["string"]
  },
  "failures": [
    {
      "stepId": "string",
      "code": "VISUAL_LAYOUT_MISMATCH",
      "expected": "string",
      "actual": "string",
      "artifacts": ["string"]
    }
  ]
}
```

## 3.4 CI 执行分层策略
- `smoke`：每次 PR 同步执行，超时短，阻断合并。
- `strict_ui`：PR 异步 + 主干同步执行，用于 UI 高严格验证。
- `regression`：每日或版本冻结前执行，覆盖广但不拖慢开发反馈。

---

## 4. 量化 KPI 与验收阈值（Todo: roadmap-and-acceptance）

## 4.1 稳定性 KPI
- 场景A：最近 10 次运行通过率 >= 90%（非代码变更情况下）。
- 场景B：最近 10 次运行通过率 >= 85%（含等待阶段）。
- 超时失败占比 < 10%。

## 4.2 诊断效率 KPI
- 每次失败都能定位到 `step_id` 且有至少 1 张截图证据。
- 90% 失败可在 `report.md` 中直接读到“建议修复方向”。

## 4.3 闭环效率 KPI
- `bounded_auto_fix` 平均轮次 <= 2.0。
- 需要人工打断的占比 < 20%。

---

## 5. 两个闭环场景的落地里程碑

## 5.1 场景A 里程碑
- M1：完成 flow 编排（新游戏 -> 进世界 -> 弹详情 UI）
- M2：硬规则校验接入
- M3：语义校验接入
- M4：自动修复审批闭环打通

## 5.2 场景B 里程碑
- M1：清理流程 `T0/Tmid/Tdone` 断言打通
- M2：建设流程 `T0/Tmid/Tdone` 断言打通
- M3：视觉+逻辑联合失败归因打通
- M4：等待相关 flaky 降至可控阈值

---

## 6. 风险与回滚策略

| 风险 | 触发信号 | 处理策略 |
|---|---|---|
| 自动修复引入连锁问题 | 连续 2 轮同类失败无改善 | 自动停止修复并请求人工决策 |
| strict_ui 执行耗时过高 | PR 队列明显增长 | strict_ui 改异步，smoke 保持同步门禁 |
| 报告体积膨胀 | CI 存储占用超阈值 | 仅长期保留失败样本，全量样本短期归档 |
| 场景定义漂移 | 业务改动后 flow 频繁失效 | 子流模板化，统一入口维护 |

---

## 7. 开始执行前检查清单

- 已有统一 `flowId` 命名规范。
- 场景A/B 的前置数据与测试地图固定。
- 产物目录与报告字段符合规范。
- `bounded_auto_fix` 默认值设为 3。
- PR 规则明确：哪些 profile 阻断、哪些异步。

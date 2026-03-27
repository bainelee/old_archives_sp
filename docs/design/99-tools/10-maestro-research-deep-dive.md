# 10 - Maestro 对标深度研究（面向 Godot + MCP GameplayFlow）

## 1. 研究范围与结论摘要

本文围绕 Maestro 的可迁移能力进行系统拆解，目标不是复刻移动端工具链，而是提炼可落地到《旧日档案馆》`Godot + MCP + Agent` 自动化验收闭环的设计原则。

核心结论：
- Maestro 的最大价值不在“点按命令本身”，而在“可维护 Flow 抽象 + 稳定等待策略 + 证据化产物 + CI 编排”。
- 对本项目最可迁移的是：Flow/子流复用、条件等待、失败归因、分层报告、有限自治修复。
- 直接不可迁移点主要来自平台差异：Maestro 依赖系统无障碍树；Godot 需自建可查询的 UI/场景语义层。

---

## 2. 官方能力矩阵（对标视角）

| Maestro 能力 | 价值 | Godot 迁移方式 | 迁移等级 |
|---|---|---|---|
| YAML Flow（声明式旅程） | 可读、可复用、便于协作 | 定义 GameplayFlow DSL（YAML/JSON） | 直接借鉴 |
| `runFlow` + `env` | 子流程复用、参数注入 | 主流程调用子流，支持变量覆盖 | 直接借鉴 |
| `when` / `repeat` / `optional` | 控制流与韧性 | 在 Runner 中实现条件执行与安全上限循环 | 直接借鉴 |
| 断言即等待（polling） | 降低 flaky | 统一 `assertUntil` 语义替代裸 `sleep` | 直接借鉴 |
| `extendedWaitUntil` / 动画等待 | 处理长耗时与过渡动画 | 设计 `wait.until` 与 `wait.stable` | 直接借鉴 |
| 选择器策略（text/id/关系） | 提升脚本稳健性 | Godot 自建 `nodePath/testId/relational` 选择器 | 需改造 |
| 报告与产物（JUnit/HTML/截图） | CI 追踪、排错证据 | 输出 `junit.xml` + `report.json/md` + 截图日志 | 直接借鉴 |
| 分片执行（split/all） | 缩短回归时间 | 在 CI 层支持分片调度与产物隔离 | 直接借鉴 |
| Cloud 托管设备矩阵 | 多设备并发验证 | 当前用本地/CI Runner，后续再评估云执行 | 需改造 |
| 系统级黑盒（权限弹窗等） | 跨应用操作能力 | Godot 主要在游戏内，系统层能力弱相关 | 不适用/弱相关 |

---

## 3. 术语映射（Maestro -> GameplayFlow）

| Maestro | GameplayFlow 建议术语 | 说明 |
|---|---|---|
| Flow | flow | 一条可执行玩法旅程 |
| Command | step | flow 的原子步骤 |
| Nested Flow | subflow | 可重用步骤组 |
| Selector | target | 节点/控件定位规则 |
| Assertion | check | 视觉/逻辑断言 |
| Artifact | artifact | 证据文件 |
| Test Output Dir | run artifact root | 每次执行产物根目录 |
| Shard | shard | 并行执行分片 |

---

## 4. 方案优势与边界（结合本项目）

### 4.1 借鉴后可获得的优势
- **可维护性**：从“脚本拼接”升级为“可复用 flow 资产”。
- **稳定性**：等待策略标准化后，减少随机失败与误报。
- **可审计性**：每个失败都能追溯到步骤、截图、日志、状态快照。
- **可协作性**：设计、策划、开发可围绕 flow 与验收报告协同。

### 4.2 必须承认的边界
- Godot 无系统无障碍树，需自行提供“测试语义树”。
- 大量自定义绘制 UI 需要补充节点标签与可查询元数据。
- 动画、帧同步、输入注入会引入时序差异，必须以等待策略兜底。

---

## 5. 对两个闭环场景的指导价值

## 场景A：Figma 同步 UI 严格验收闭环
- 借鉴点：`Flow + 子流` 编排“新游戏到详情弹窗”固定路径。
- 借鉴点：构建“硬规则 + 语义规则”双轨判定，失败给出证据和归因。
- 借鉴点：按步骤保存关键截图（打开前/弹窗后/修复后）作为对比基线。

## 场景B：等待驱动的视觉+逻辑联动闭环（清理/建设）
- 借鉴点：以 `T0/Tmid/Tdone` 三段断言替代一次性静态比对。
- 借鉴点：使用 `assertUntil` + `extendedWait`，只把 `wait 2s` 用于中段采样证据。
- 借鉴点：失败分类拆分视觉、逻辑、时序，避免“全归因到 UI”。

---

## 6. 我们应重点学习与改进的 12 项能力

1. Flow 作为第一公民（不是临时脚本）。
2. 子流模板化（新游戏、清档、进入目标场景）。
3. 统一步骤 ID 与命名规范（便于报告引用）。
4. 条件等待默认化（减少固定 sleep）。
5. 失败分类标准化（visual/logic/runtime/timeout/infra）。
6. 运行产物结构标准化（截图、日志、状态快照、报告）。
7. 关键节点语义标注（`test_id`、状态字段）。
8. 有界自动修复策略（最多 N 轮）。
9. 高风险变更自动请求人工审批。
10. 分层执行策略（smoke vs strict-ui vs regression）。
11. 并行分片与产物隔离策略。
12. 失败趋势统计与高频根因沉淀。

---

## 7. 风险清单与规避策略

| 风险 | 表现 | 规避策略 |
|---|---|---|
| 仅做视觉比对 | 逻辑 bug 漏检 | 场景B 强制三阶段逻辑断言 |
| 仅做逻辑断言 | UI 偏差上线 | 场景A 强制硬规则视觉校验 |
| 固定 sleep 过多 | 测试慢且不稳 | 默认 polling，sleep 只用于采样 |
| 自动修复过度 | 引入次生问题 | `bounded_auto_fix` + 高风险审批门 |
| 并行写同一产物 | 报告相互覆盖 | `run_id/shard_id/step_id` 隔离目录 |

---

## 8. 研究输出的验收口径

本研究视为完成，需满足：
- 能明确回答“哪些 Maestro 能力可直接借鉴、需改造、不适用”。
- 两个闭环场景都有标准化 flow 规格参考（步骤、断言、失败码、产物）。
- 可直接指导 `11`（架构与契约）和 `12`（路线图）落地。

---

## 9. 参考来源

- [Maestro Docs](https://docs.maestro.dev/)
- [How Maestro works](https://docs.maestro.dev/get-started/how-maestro-works)
- [Maestro Flows](https://docs.maestro.dev/maestro-flows)
- [Wait commands](https://docs.maestro.dev/maestro-flows/flow-control-and-logic/wait-commands)
- [Nested flows](https://docs.maestro.dev/maestro-flows/flow-control-and-logic/nested-flows)
- [Selectors guide](https://docs.maestro.dev/maestro-flows/flow-control-and-logic/how-to-use-selectors)
- [Test reports and artifacts](https://docs.maestro.dev/maestro-flows/workspace-management/test-reports-and-artifacts)
- [Maestro Cloud + GitHub Actions](https://docs.maestro.dev/maestro-cloud/ci-cd-integration/github-actions)

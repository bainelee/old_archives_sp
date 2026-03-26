# 下一对话执行提示词（可直接复制）

你现在接手 `old-archives-sp` 项目的自动测试工具链。当前 `exploration_gameplay_flow_v1` 已落地，请在**不破坏现有功能**前提下继续推进 v2/v3。

## 先阅读（按顺序）
1. `docs/testing/README.md`
2. `docs/testing/01-install-and-config.md`
3. `docs/testing/04-handoff-current-state.md`
4. `addons/test_orchestrator/plugin.gd`
5. `tools/game-test-runner/core/runner.py`
6. `tools/game-test-runner/core/scenario_registry.py`
7. `tools/game-test-runner/core/flow_runner.py`
8. `tools/game-test-runner/core/flows/exploration_gameplay_flow_v1.py`
9. `tools/game-test-runner/core/regression_suite.py`

## 已知约束
- `visual_regression_probe` 是 canary（故意错位），视觉检查失败是预期。
- 插件已经有运行/基线/比对/回归套件/结果打开功能，请保留。
- 产物目录已约定：
  - `artifacts/test-runs/<run_id>/`
  - `artifacts/test-suites/<suite_id>/`
- 现有 flow 步骤截图前缀过滤已启用：`flow_exploration_`
- visual canary 前缀过滤已启用：`visual_ui_button_`

## 本次目标（建议）
1. 将 `exploration_gameplay_flow_v1` 的探索动作从“模拟状态迁移”升级为真实业务入口调用。
2. 增加 flow 模板选择能力（至少支持 2 个 flow）。
3. 插件新增 flow 选择 UI，并维持现有按钮功能不回归。

## 期望交付
1. 新 flow 模板（如 `save_roundtrip_flow_v1`）及对应步骤断言。
2. 插件支持选择要跑的 flow（默认仍为 `exploration_gameplay_flow_v1`）。
3. `flow_report.json` 继续可定位失败步骤和证据文件。
4. 保证原有 run/visual/suite 相关能力继续可用。

## 验收标准
- 在插件中可选择并执行 flow，输出可读报告。
- flow 失败时可定位到具体步骤和证据文件。
- 不引入新的 linter 错误。

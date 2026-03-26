# 当前状态与交接（v2）

本文档用于快速交接“游戏自动测试插件 + 运行器”当前状态，供下一次对话直接继续开发。

## 已完成能力
- 运行器（`runner.py` + `cli.py`）可执行真实 Godot 流程，产出统一 run 报告。
- MCP 接口可用：`list_test_scenarios`、`run_game_test`、`get_test_artifacts`、`get_test_report`。
- 插件 `Test Orchestrator` 可完成：
  - 运行 `exploration_smoke`
  - 录制视觉基线（`Record Visual Baseline`）
  - 执行视觉检查（`Run Visual Check`）
  - 运行快速回归套件（`Run Quick Regression Suite`）
  - 运行真实流程（`Run Gameplay Debug Flow`）
  - 打开 run/suite 报告与视觉差异图
  - 打开 flow 报告（`Open flow_report.json`）
  - 复制状态与产物路径
- 视觉回归能力：
  - 生成 `baseline/current/diff/diff_annotated` 四类图片
  - 在 `report.json` 中写入 `diff` 与 `threshold`
  - canary 用例默认故意失败，用于证明视觉检测链路有效
- 流程编排能力（已落地）：
  - flow 执行器：`tools/game-test-runner/core/flow_runner.py`
  - flow 模板：`tools/game-test-runner/core/flows/exploration_gameplay_flow_v1.py`
  - 流程报告：`flow_report.json`（`flow_id`、`run_id`、步骤断言与证据）
  - 步骤类型：`run_scenario`、`wait_for_file`、`assert_files`、`assert_log_markers`、`assert_files_distinct`
- 真实流程测试场景（已落地）：
  - 场景：`scenes/test/exploration_gameplay_flow_test.tscn`
  - 脚本：`scripts/test/exploration_gameplay_flow_test.gd`
  - 输出 marker、步骤截图、探索状态校验（含“模拟一次探索动作提交”）
- 截图归档隔离（已落地）：
  - `RunRequest` 支持 `screenshot_prefix`
  - 场景注册支持默认前缀（`scenario_registry.py` 中 `screenshot_prefix`）
  - `exploration_gameplay_flow_test` 使用 `flow_exploration_`
  - `visual_regression_probe` 使用 `visual_ui_button_`

## 关键路径
- 插件：`addons/test_orchestrator/plugin.gd`
- 运行器：`tools/game-test-runner/core/runner.py`
- 场景注册：`tools/game-test-runner/core/scenario_registry.py`
- 回归套件：`tools/game-test-runner/core/regression_suite.py`
- flow 执行器：`tools/game-test-runner/core/flow_runner.py`
- flow 模板：`tools/game-test-runner/core/flows/exploration_gameplay_flow_v1.py`
- flow 测试场景：`scenes/test/exploration_gameplay_flow_test.tscn`
- flow 测试脚本：`scripts/test/exploration_gameplay_flow_test.gd`
- 视觉探针场景：`scenes/test/visual_regression_probe_test.tscn`
- 视觉探针脚本：`scripts/test/visual_regression_probe_test.gd`

## 重要行为说明
- `visual_regression_probe` 是 canary，当前逻辑故意包含 icon 错位，`Run Visual Check` 失败为预期。
- `Run Quick Regression Suite` 的通过条件是：
  - exploration 通过
  - baseline 录制通过
  - visual canary 失败且分类为 `visual_regression`
- 测试产物：
  - 单 run：`artifacts/test-runs/<run_id>/`
  - 套件：`artifacts/test-suites/<suite_id>/`
- `exploration_gameplay_flow_v1` 当前步骤：
  1) 运行 `exploration_gameplay_flow_test`
  2) 断言 stdout marker
  3) 等待 run 报告
  4) 校验证据文件（日志 + 三张步骤图）
  5) 断言三张步骤图互不相同（hash）
- flow 步骤截图可视化已修复：不再是纯灰图，画面含步骤标题、状态和关键信息。
- 旧产物可能包含历史 run 的遗留截图；若需干净验证，先清 `artifacts/test-runs/`。

## 现阶段主要缺口（下一步建议）
1. 流程动作目前仍是“服务层状态迁移 + 断言”，尚未接入真正 UI/游戏入口操作链。
2. flow 模板目前仅有 `exploration_gameplay_flow_v1`，缺少模板选择与多 flow 管理。
3. 插件尚未提供 flow 下拉选择（当前固定跑 `exploration_gameplay_flow_v1`）。
4. 回归套件还未纳入 gameplay flow（可新增“quick + gameplay flow”组合）。
5. 可增加 flow 失败摘要视图（例如插件中直接显示失败 step 与关键 artifact）。

## 下个对话建议目标（v3）
1. 把 `exploration_gameplay_flow_v1` 的“探索动作”从模拟迁移改为真实业务入口调用。
2. 增加第二个 flow 模板（如 `save_roundtrip_flow_v1`）。
3. 插件新增 flow 选择器，并把 `Run Gameplay Debug Flow` 改为按选择执行。

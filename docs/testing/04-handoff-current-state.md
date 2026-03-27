# 当前状态与交接（v3）

本文档用于快速交接“游戏自动测试插件 + 运行器”当前状态，供下一次对话直接继续开发。

## 0. 交接后先跑哪条命令（先确认再开发）

| 场景 | 推荐命令 |
|---|---|
| 只确认环境（最快） | `powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp" -OnlyPreflight` |
| 快速门禁（环境 + 契约） | `powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp" -Fast` |
| 完整验收（环境 + 两条 acceptance） | `powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp"` |
| 完整验收 + 契约回归 | `powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp" -IncludeContractRegression` |

结果判断：
- `status=passed`：继续开发目标
- `status=failed_preflight`：先修环境（优先 `GODOT_BIN`）
- `status=failed` 且 `contract_regression` 失败：先修闭环契约

## 已完成能力
- 运行器（`runner.py` + `cli.py`）可执行真实 Godot 流程，产出统一 run 报告。
- MCP 接口可用：
  - `list_test_scenarios`
  - `run_game_test`
  - `run_game_flow`
  - `check_test_runner_environment`
  - `get_test_run_status`
  - `cancel_test_run`
  - `resume_fix_loop`
  - `get_test_artifacts`
  - `get_test_report`
- `run_game_flow` 已支持闭环状态字段统一：
  - `run_id/status/current_step/fix_loop_round/approval_required`
- `bounded_auto_fix` 已升级为可审计闭环：
  - `analyzing -> waiting_approval -> rerun -> resolved/exhausted`
  - 连续两轮同类失败且 `actual` 无改善自动停止
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
- MCP 服务：`tools/game-test-runner/mcp/server.py`
- CI 脚本：`tools/game-test-runner/scripts/run_acceptance_ci.ps1`

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
- 环境变量策略：
  - 推荐使用 `GODOT_BIN`，非 dry-run 未解析时会快速失败并提示配置。
- 报告退出码语义已对齐：
  - `effective_exit_code`：测试语义退出码（passed 时为 0）
  - `process_exit_code`：真实进程退出码（可能为 1）

## 现阶段主要缺口（下一步建议）
1. 将 `check_test_runner_environment` 接入正式 CI 流水线 YAML（当前仅提供本地/CI 通用脚本）。
2. 增加“失败快照摘要”产物（例如 `failure_summary.json`），减少人工翻 report 成本。
3. 插件面板可增加“当前 latest run 的 primary_failure 摘要展示”。
4. 补一组针对 `resume_fix_loop/cancel_test_run` 的自动化回归用例（契约防回归）。
5. 将 acceptance 脚本输出汇总进一步上传为 CI artifact（平台相关配置待接入）。

## 下个对话建议目标（v4）
1. 增加 `failure_summary.json` 产物，并把 `primary_failure + stop_reason + key_files` 聚合输出。
2. 为闭环契约补自动化测试（至少覆盖 waiting_approval、resume、cancel、exhausted stop_reason）。
3. 在插件中展示“最近一次 flow 的 primary failure 摘要与关键文件快捷打开”。

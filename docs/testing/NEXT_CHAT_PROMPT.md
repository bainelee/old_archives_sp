# 下一对话执行提示词（可直接复制）

你现在接手 `old-archives-sp` 项目的自动测试工具链。当前 GameplayFlow v2 闭环与 CI 一键脚本已落地，请在**不破坏现有功能**前提下继续推进 v3+。

## 0) 先选执行模式（必须先做）
根据本次任务目标，先选一条命令执行并贴出汇总 JSON 路径：

1. 仅检查环境（最快）
```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp" -OnlyPreflight
```

2. 快速门禁（环境 + 契约）
```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp" -Fast
```

3. 完整验收（环境 + 两条 acceptance）
```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp"
```

4. 完整验收 + 契约回归
```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp" -IncludeContractRegression
```

执行结果判断：
- `status=passed`：继续开发目标
- `status=failed_preflight`：先修环境（优先 `GODOT_BIN`）
- `status=failed` 且 `contract_regression` 失败：先修闭环契约，再推进功能

## 先阅读（按顺序）
1. `docs/testing/README.md`
2. `docs/testing/01-install-and-config.md`
3. `docs/testing/04-handoff-current-state.md`
4. `addons/test_orchestrator/plugin.gd`
5. `tools/game-test-runner/mcp/server.py`
6. `tools/game-test-runner/core/runner.py`
7. `tools/game-test-runner/scripts/run_acceptance_ci.ps1`
8. `tools/game-test-runner/core/scenario_registry.py`
9. `tools/game-test-runner/core/flow_runner.py`

## 已知约束
- `visual_regression_probe` 是 canary（故意错位），视觉检查失败是预期。
- 插件已经有运行/基线/比对/回归套件/结果打开功能，请保留。
- 产物目录已约定：
  - `artifacts/test-runs/<run_id>/`
  - `artifacts/test-suites/<suite_id>/`
- 现有 flow 步骤截图前缀过滤已启用：`flow_exploration_`
- visual canary 前缀过滤已启用：`visual_ui_button_`
- 环境变量推荐 `GODOT_BIN`；非 dry-run 若未解析 Godot 可执行文件会快速失败（`MISSING_GODOT_BIN`）。
- 闭环状态字段已统一：`run_id/status/current_step/fix_loop_round/approval_required`。
- 报告与 CI 汇总已区分：
  - `effective_exit_code`（语义退出码）
  - `process_exit_code`（真实进程退出码）

## 本次目标（建议）
1. 新增 `failure_summary.json` 产物（聚合 primary failure、stop_reason、key_files）。
2. 为 `resume_fix_loop/cancel_test_run` 增加自动化回归用例，避免契约回归。
3. 插件面板增加最近一次 flow 的失败摘要展示（step/category/actual）。

## 期望交付
1. `failure_summary.json` 写入 `artifacts/test-runs/<run_id>/`，并在 `get_test_artifacts` 返回索引。
2. 至少 2 条回归用例覆盖：
   - waiting_approval -> resume -> exhausted/resolved
   - waiting_approval -> cancel -> cancelled
3. 插件 UI 可直接看到最新失败摘要并快速打开关键证据。
4. 保证原有 run/visual/suite/flow 能力继续可用。

## 验收标准
- 在插件中可选择并执行 flow，输出可读报告。
- flow 失败时可定位到具体步骤和证据文件。
- 不引入新的 linter 错误。

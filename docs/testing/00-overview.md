# 游戏自动测试总览（v1）

本目录用于团队协作交付一套可复用的游戏自动测试链路，目标是：
- AI（MCP）可调用
- Godot 插件仅做桥接提示（不在编辑器内执行 flow）
- 结果可追溯（日志/截图/存档索引/报告）

快速入口：[`README`](README.md)

## 当前已落地能力
- 核心运行器（Python）
  - `tools/game-test-runner/core/runner.py`
  - `tools/game-test-runner/core/cli.py`
  - `tools/game-test-runner/core/contract_regression.py`
- 场景注册表
  - `tools/game-test-runner/core/scenario_registry.py`
- MCP 统一入口
  - `tools/game-test-runner/mcp/server.py`
  - tools: `get_mcp_runtime_info`、`list_test_scenarios`、`run_game_test`、`run_game_flow`、`check_test_runner_environment`、`get_test_run_status`、`cancel_test_run`、`resume_fix_loop`、`get_test_artifacts`、`get_test_report`、`get_flow_timeline`、`start_game_flow_live`、`get_live_flow_progress`、`run_and_stream_flow`、`start_stepwise_flow`、`prepare_step`、`execute_step`、`verify_step`、`step_once`、`run_stepwise_autopilot`、`start_cursor_chat_plugin`、`pull_cursor_chat_plugin`
- Godot 编辑器插件（Bridge Mode）
  - `addons/test_orchestrator/plugin.cfg`
  - `addons/test_orchestrator/plugin.gd`
- 安装与版本清单（Windows）
  - `tools/game-test-runner/install/install-mcp.ps1`
  - `tools/game-test-runner/install/start-mcp.ps1`
  - `tools/game-test-runner/install/update-mcp.ps1`
  - `tools/game-test-runner/mcp/version_manifest.json`
- 首个探索 smoke 场景
  - `scenes/test/exploration_smoke_test.tscn`
  - `scripts/test/exploration_smoke_test.gd`

## 产物目录约定
- `artifacts/test-runs/<run_id>/`
  - `logs/`
  - `screenshots/`
  - `save_snapshots/`
  - `run_meta.json`
  - `report.json`
  - `report.md`

## 版本策略（SemVer）
- `runner-core`：`MAJOR.MINOR.PATCH`
- `runner-mcp`：`MAJOR.MINOR.PATCH`
- `godot-plugin`：`MAJOR.MINOR.PATCH`

约定：
- `MAJOR`：接口不兼容（参数名变更、报告字段破坏性变更）
- `MINOR`：向后兼容新增能力（新增场景、新增字段）
- `PATCH`：修复 bug，不改接口语义

## 兼容矩阵（当前）
- Godot：4.6（项目主版本）
- OS：Windows 10/11（当前验证环境）
- Python：3.10+（用于 runner 与 MCP 适配）

## 建议使用顺序
1. 先按 `01-install-and-config.md` 完成环境与验证。
2. 先跑 dry-run，确认链路与产物目录可用。
3. 再逐步切换到非 dry-run 与真实场景执行。

# 游戏自动测试总览（v1）

本目录用于团队协作交付一套可复用的游戏自动测试链路，目标是：
- AI（MCP）可调用
- 开发者（Godot 插件）可点击运行
- 结果可追溯（日志/截图/存档索引/报告）

快速入口：[`README`](README.md)

## 当前已落地能力
- 核心运行器（Python）
  - `tools/game-test-runner/core/runner.py`
  - `tools/game-test-runner/core/cli.py`
- 场景注册表
  - `tools/game-test-runner/core/scenario_registry.py`
- MCP 最小入口
  - `tools/game-test-runner/mcp/server.py`
  - tools: `list_test_scenarios`、`run_game_test`、`get_test_artifacts`、`get_test_report`
- Godot 编辑器插件（MVP）
  - `addons/test_orchestrator/plugin.cfg`
  - `addons/test_orchestrator/plugin.gd`
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

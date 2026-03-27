# Game Test Runner Contract v1

本文档定义自动化测试能力的首版契约，目标是让以下两类调用方共享同一能力内核：
- AI 调用（MCP）
- 人工调用（Godot 插件）

## 1. 范围
- 命令入口：`运行游戏并测试<系统名>`
- 执行环境：优先 `vm`，可扩展 `local` / `headless`
- 验证层级：`visual`、`logic`、`data`、`logs`
- 产物：截图、日志、存档快照、结构化报告

## 2. 统一术语
- `system`：业务系统名，如 `exploration`
- `scenario`：可执行测试场景，如 `exploration_smoke`
- `profile`：运行档位，`smoke` / `regression` / `soak`
- `run_id`：单次执行唯一标识
- `artifact`：测试证据文件（截图、日志、快照）

## 3. 目录约定（建议）
- `tools/game-test-runner/core/`
- `tools/game-test-runner/mcp/`
- `addons/test_orchestrator/`
- `artifacts/test-runs/<run_id>/`
  - `screenshots/`
  - `logs/`
  - `save_snapshots/`
  - `report.json`
  - `report.md`

## 4. MCP 工具契约（v1）

### 4.1 `list_test_scenarios`
- 输入：空
- 输出：
  - `scenarios[]`
    - `name`
    - `system`
    - `profiles[]`
    - `supported_modes[]`
    - `preconditions[]`

### 4.2 `run_game_test`
- 输入：
  - `system`（必填）
  - `scenario`（可选，缺省走 system 默认场景）
  - `profile`（可选，默认 `smoke`）
  - `environment.mode`（`vm`/`local`/`headless`）
  - `execution.timeoutSec`、`execution.retry`、`execution.cleanSaveSlots`
  - `assertions.visual|logic|data|logs`（bool）
  - `artifacts.level`（`failure_only`/`all`）
- 输出：
  - `run_id`
  - `status`（`queued`/`running`/`finished`/`failed`/`cancelled`）
  - `started_at`

### 4.3 `get_test_artifacts`
- 输入：`run_id`
- 输出：
  - `artifact_root`
  - `screenshots[]`
  - `logs[]`
  - `save_snapshots[]`

### 4.4 `get_test_report`
- 输入：`run_id`、`format`（`json`/`md`）
- 输出：
  - `status`（`passed`/`failed`）
  - `summary.totalAssertions|passed|failed`
  - `failures[]`（含 `step_id`、`category`、`expected`、`actual`、`artifacts[]`）

### 4.5 当前 MCP 实现状态
- 已实现：
  - `list_test_scenarios`
  - `run_game_test`
  - `run_game_flow`
  - `check_test_runner_environment`
  - `get_test_run_status`
  - `cancel_test_run`
  - `resume_fix_loop`
  - `get_test_artifacts`
  - `get_test_report`
- 说明：当前实现可通过 `run_id` 查询状态、产物列表与报告内容（json/md）。

### 4.6 错误返回与路径规范（当前）
- 错误返回统一结构：
  - `{ "ok": false, "error": { "code": "...", "message": "...", "details": {...?} } }`
- 常见错误码：
  - `INVALID_ARGUMENT`
  - `NOT_FOUND`
  - `UNKNOWN_SCENARIO`
  - `UNKNOWN_SYSTEM`
  - `UNSUPPORTED_TOOL`
  - `MISSING_GODOT_BIN`
  - `INTERNAL_ERROR`
- 路径规范：
  - MCP 返回路径统一使用 `/` 分隔符，避免平台差异导致解析问题。

## 5. `run_game_test` 输入 schema（草案）
```json
{
  "system": "exploration",
  "scenario": "exploration_smoke",
  "profile": "smoke",
  "environment": {
    "mode": "vm",
    "resolution": "1920x1080",
    "locale": "zh_CN"
  },
  "execution": {
    "timeoutSec": 300,
    "retry": 1,
    "cleanSaveSlots": true
  },
  "assertions": {
    "visual": true,
    "logic": true,
    "data": true,
    "logs": true
  },
  "artifacts": {
    "level": "failure_only"
  }
}
```

## 6. `report.json` 输出 schema（草案）
```json
{
  "run_id": "2026-03-27T12-00-00Z_exploration_smoke",
  "runId": "2026-03-27T12-00-00Z_exploration_smoke",
  "result_status": "failed",
  "status": "failed",
  "scenario": "exploration_smoke",
  "environment_v2": {
    "mode": "vm",
    "godot_version": "4.6"
  },
  "summary_v2": {
    "total_assertions": 12,
    "passed": 10,
    "failed": 2
  },
  "primary_failure": {
    "step": "step_open_exploration",
    "step_id": "step_open_exploration",
    "category": "visual_regression",
    "expected": "探索按钮可见",
    "actual": "按钮被遮挡",
    "artifacts": [
      "screenshots/step_open_exploration_fail.png",
      "logs/godot.log"
    ]
  },
  "environment": {
    "mode": "vm",
    "godotVersion": "4.6"
  },
  "summary": {
    "totalAssertions": 12,
    "passed": 10,
    "failed": 2
  },
  "failures": [
    {
      "stepId": "step_open_exploration",
      "category": "visual_regression",
      "expected": "探索按钮可见",
      "actual": "按钮被遮挡",
      "artifacts": [
        "artifacts/test-runs/<run_id>/screenshots/step_open_exploration_fail.png",
        "artifacts/test-runs/<run_id>/logs/godot.log"
      ]
    }
  ]
}
```

## 6.1 闭环状态扩展（v2）
- 统一状态字段：`run_id/status/current_step/fix_loop_round/approval_required`
- 闭环轮次：`fix_loop.rounds[*]` 固定输出
  - `round/run_id/status/reason/primary_failure`
- 停止策略：连续两轮同类失败且 `actual` 无改善，置 `status=exhausted` 并写入 `stop_reason`。

## 7. 失败分类枚举（v1）
- `visual_regression`
- `logic_regression`
- `data_integrity`
- `runtime_error`
- `timeout`

## 8. 场景映射最小集（v1）
- `exploration` -> `exploration_smoke`
- `save` -> `save_roundtrip`
- `pause_input` -> `pause_input_stability`

### 8.1 已落地映射（当前）
- `exploration_smoke` -> `res://scenes/test/exploration_smoke_test.tscn`
- `debug_frame_print_smoke` -> `res://scenes/test/debug_frame_print_test.tscn`

## 9. 非目标（v1 暂不做）
- 不在 v1 引入复杂视觉 AI 判图
- 不在 v1 覆盖全系统长时 soak 测试
- 不在 v1 支持多项目共享云调度

## 10. 插件最小入口（当前落地）
- 路径：`res://addons/test_orchestrator/`
- 能力：在编辑器 Dock 点击按钮触发 `exploration_smoke` dry-run，并显示 `run_id/status`。
- 说明：历史报告浏览与多场景选择属于下一阶段增强项。

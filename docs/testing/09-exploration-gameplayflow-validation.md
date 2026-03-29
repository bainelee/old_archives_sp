# 探索系统 GameplayFlow 测试方案（未完整实现阶段）

本文档对应当前探索系统（P1）自动化验证落地，目标是：
- 在“能力尚未完整”阶段保持稳定回归，不做越界断言；
- 用分层门禁覆盖可验证能力，并为后续完整玩法预留升级入口。

## 1) 分层与入口

### L0 环境门禁
- 入口：`check_test_runner_environment`
- 目标：在执行探索验证前，先判定 Godot/MCP/runner/driver 是否可运行。

### L1 场景探针层（证据主线）
- flow：`flows/suites/regression/gameplay/exploration_validation_l1_scene_probe.json`
- 场景：`res://scenes/test/exploration_gameplay_flow_test.tscn`
- 断言：
  - 进程成功退出；
  - stdout 包含 `[GameplayFlowV1]` 四个 PASS marker；
  - 三张步骤截图存在且内容不完全相同。

### L2 纯逻辑不变量层
- flow：`flows/suites/regression/gameplay/exploration_validation_l2_smoke_invariants.json`
- 场景：`res://scenes/test/exploration_smoke_test.tscn`
- 断言：
  - `ExplorationSmokeTest` 输出 PASS；
  - 无 FAIL marker；
  - run report 为 `finished`。

### 探索存档往返（专项，可选于 CI / 本地）

- flow：`flows/suites/regression/gameplay/exploration_two_regions_save_verify.json`
- 行为：新游戏槽 0 → `exploreRegion` 白崖镇与杜尔金矿区并完成计时 → `saveGame` → 读 `slot_0.json` 校验 `exploration.explored_region_ids` → `loadGameMainFromSlot` 再断言内存中 `exploration_explored_ids` 与存档一致。
- 依赖 TestDriver 动作：`exploreRegion`、`advanceGameHours`、`verifySaveSlotExploration`、`loadGameMainFromSlot`（见 `scripts/test/test_driver.gd`）。
- 运行示例：`python tools/game-test-runner/core/flow_runner.py --flow-file flows/suites/regression/gameplay/exploration_two_regions_save_verify.json --project-root "<ROOT>" --godot-bin "<GodotExe>"`

### L3 Overlay 防穿透层
- flow：`flows/suites/regression/gameplay/exploration_validation_l3_overlay_input_block.json`
- 场景：`res://scenes/ui/start_menu.tscn`（进入 `game_main` 后打开探索 overlay）
- 断言：
  - 探索 overlay 已打开；
  - 点击地图区（`OverlayRoot/MapArea/MapStack`）后，overlay 仍保持可见（不得触发底层按钮/世界输入）。

### L4 守护门禁层
- manifest：`flows/suites/regression/gameplay/exploration_validation_current_stage_manifest.json`
- whitelist：`flows/rules/exploration_assertion_whitelist_v1.json`
- 目标：
  - 阻断“假通过”（进程成功但 marker/证据缺失）；
  - 阻断“越界断言”（对未实现能力做强断言）。

### L5 TopBar 认知开局校验层
- flow：`flows/suites/regression/gameplay/topbar_cognition_bootstrap_l1.json`
- 场景：`res://scenes/ui/start_menu.tscn`（进入 `game_main` 后立即检查）
- 断言：
  - `cognition_amount == 6000`（开局契约值）；
  - 快照包含 `cognition_amount` 与 `resources`，用于回归比对。

## 2) 一键执行

```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_gameplay_exploration_validation.ps1" `
  -ProjectRoot "D:/GODOT_Test/old-archives-sp" `
  -GodotBin "D:/GODOT/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe"
```

仅做环境预检：

```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_gameplay_exploration_validation.ps1" `
  -ProjectRoot "D:/GODOT_Test/old-archives-sp" `
  -OnlyPreflight
```

## 3) 失败分类（当前）

- `environment_timeout`：环境检查失败、调用链静默超时、MCP 调用异常。
- `marker_missing`：`[GameplayFlowV1]` 关键 marker 缺失。
- `evidence_missing`：关键截图/日志/报告缺失，或截图未产生可区分变化。
- `state_regression`：L1/L2/L3 运行状态失败，或 smoke/overlay 断言失败。
- `assertion_scope_violation`：断言越过 whitelist 定义的当前实现边界。

## 4) 当前断言白名单

见：`flows/rules/exploration_assertion_whitelist_v1.json`

可断言：
- 场景成功退出；
- marker 与证据文件完整；
- smoke 不变量通过；
- overlay 点击不会穿透并触发底层输入。

暂不强断言：
- 探索中计时与完成状态机；
- 真实资源扣减与调查员占用；
- 探索后邻接解锁；
- 调查点事件链与后续分支。

## 5) 升级路径（服务层补齐后）

当满足以下任一触发条件，可升级断言集到 v2：
- `ExplorationService` 提供真实 `explore_region` 动作接口；
- runtime state 引入 `in_progress` 及完成迁移；
- 邻接解锁规则从 UI 占位常量迁移到服务层规则。

升级建议：
- 在 L2 增加状态机断言（未发现 -> 已解锁未探索 -> 探索中 -> 已探索）；
- 在 L1 增加资源/调查员占用与时间推进断言；
- 把“模拟 save_blob 提交”替换为真实探索动作驱动。

## 6) GF-EXP 流程（分支化沉淀）

当你说“执行 EXP 流程 / 执行 GF-EXP 流程 / 进行一次带有 exp 的 gameplayflow”时，目标流程是：

- 在修复分支完成 GameplayFlow 修复与验证；
- 提炼 EXP 资产（方法论、排查路径、验收要点）；
- 仅把 EXP allowlist 资产同步回 `main`；
- 再从 `main` 拉起重修分支做正式代码修复。

核心文件：

- 触发规则：`.cursor/rules/gf-exp-trigger.mdc`
- 工作流技能：`.cursor/skills/gf-exp-workflow/SKILL.md`
- allowlist：`tools/game-test-runner/config/gf_exp_allowlist.json`
- 编排脚本：`tools/game-test-runner/scripts/run_gf_exp_cycle.ps1`

### 一次 dry-run（不改 git 状态）

```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_gf_exp_cycle.ps1" `
  -ProjectRoot "D:/GODOT_Test/old-archives-sp" `
  -Topic "exploration-overlay" `
  -DryRun `
  -SkipValidation
```

### 正式执行（会创建分支并提交 EXP 同步）

```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_gf_exp_cycle.ps1" `
  -ProjectRoot "D:/GODOT_Test/old-archives-sp" `
  -Topic "exploration-overlay"
```

执行前提：

- 工作区必须干净（无未提交改动）；
- 若审计到 allowlist 外文件变更，流程会中断；
- `main` 分支建议保持可 fast-forward 更新。

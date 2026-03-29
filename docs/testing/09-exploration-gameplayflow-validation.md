# 探索系统 GameplayFlow（收敛说明）

仓库内 **不再**维护历史上探索 L1–L4 等多层专项套件；探索能力仍由运行时与 `scripts/test/test_driver.gd`（`exploreRegion`、`advanceGameHours`、`verifySaveSlotExploration` 等）支持。

## 当前保留的探索向 GameplayFlow

- **两地区并行探索 + 存档0 + 重启继续校验**：  
  - `flows/suites/regression/gameplay/exploration_two_regions_slot0_phase1.json`  
  - `flows/suites/regression/gameplay/exploration_two_regions_slot0_phase2.json`  
- **一键 stepwise（含 shell 播报）**：`tools/game-test-runner/scripts/run_exploration_two_regions_stepwise.ps1`  
- 须满足 **三段协议**与 **shell 主观测** 时，请走 `run_gameplay_stepwise_chat.py` / 上述 ps1，不要用 `tools/game-test-runner/core/flow_runner.py` 作为默认入口（见 `.cursor/rules/chat-first-stepwise-core.mdc`）。

**默认全量回归**仍以 `tools/game-test-runner/scripts/run_gameplay_regression.ps1`（基础两房 + 基础数据对账）为主；探索 flow 按需单独跑。说明见 [README.md](./README.md)。

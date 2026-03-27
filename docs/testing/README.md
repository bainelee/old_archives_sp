# Game Test Runner Quick Start

这是一份给团队成员的 5 分钟上手说明。

## 0) 先选执行模式（推荐）

| 你要做什么 | 用哪个模式 | 命令 |
|---|---|---|
| 只确认环境是否可跑（最快） | `OnlyPreflight` | `powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp" -OnlyPreflight` |
| 做快速门禁（环境 + 契约） | `Fast` | `powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp" -Fast` |
| 做完整验收（环境 + 2 条 acceptance） | 默认模式 | `powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp"` |
| 做完整验收 + 契约回归 | 默认 + 契约 | `powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp" -IncludeContractRegression` |

## 1) 启用插件
- 打开项目后进入 `Project > Project Settings > Plugins`
- 启用 `Test Orchestrator`

## 2) 配置运行路径（推荐环境变量）
- 推荐设置环境变量 `GODOT_BIN` 指向 Godot 可执行文件
- 插件面板 `Godot Bin` 仍可手动覆盖
- 建议关闭 `Dry Run` 进行真实验证

示例（PowerShell）：
```powershell
setx GODOT_BIN "D:\GODOT\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe"
```

## 3) 常用按钮
- `Run Exploration Smoke`：探索系统冒烟
- `Record Visual Baseline`：录制视觉基线图
- `Run Visual Check`：执行视觉比对（当前故意注入了 icon 错位，可用于验证检测链路）
- `Run Quick Regression Suite`：一次跑 exploration + visual canary 并输出汇总
- `Run Gameplay Debug Flow`：执行真实流程模板 `exploration_gameplay_flow_v1`

## 4) 看结果
- `Open Folder` 打开当前选中 run 的产物目录
- `Open report.json` 打开结构化报告
- `Open flow_report.json` 打开流程报告（仅 flow run 存在）
- `Open diff.png` / `Open diff_annotated.png` 打开视觉差异图
- `Copy Status` / `Copy Artifacts Path` 快速复制信息

## 5) 产物目录
- 单次 run：`artifacts/test-runs/<run_id>/`
- 套件汇总：`artifacts/test-suites/<suite_id>/`
- CI 汇总：`artifacts/test-runs/acceptance_ci_<timestamp>.json`

## 6) 预期说明
- `visual_regression_probe` 当前是“故意带错位”的 canary 用例  
  因此视觉检查失败是预期行为，用于证明检测链路有效。
- flow 截图当前按前缀 `flow_exploration_` 过滤归档，不再混入 `visual_ui_button_*`。

## 7) 交接与继续开发
- 当前状态文档：`docs/testing/04-handoff-current-state.md`
- 下一对话提示词：`docs/testing/NEXT_CHAT_PROMPT.md`

## 8) 一键 CI（preflight + acceptance）
```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" `
  -ProjectRoot "D:/GODOT_Test/old-archives-sp"
```

说明：
- 脚本会先执行 `check_test_runner_environment`
- 然后串行执行：
  - `flows/ui_room_detail_sync_acceptance.json`
  - `flows/build_clean_wait_linked_acceptance.json`
- 输出汇总 JSON，包含 `run_id`、关键产物路径、`effective_exit_code/process_exit_code`

可选：附加闭环契约回归
```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" `
  -ProjectRoot "D:/GODOT_Test/old-archives-sp" `
  -IncludeContractRegression
```

可选：快速门禁（仅 preflight + contract regression）
```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" `
  -ProjectRoot "D:/GODOT_Test/old-archives-sp" `
  -Fast
```

可选：仅环境预检（最快）
```powershell
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" `
  -ProjectRoot "D:/GODOT_Test/old-archives-sp" `
  -OnlyPreflight
```

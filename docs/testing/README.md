# Game Test Runner Quick Start

这是一份给团队成员的 5 分钟上手说明。

## 1) 启用插件
- 打开项目后进入 `Project > Project Settings > Plugins`
- 启用 `Test Orchestrator`

## 2) 配置运行路径
- 在插件面板 `Godot Bin` 填你的 Godot 可执行文件路径
- 建议关闭 `Dry Run` 进行真实验证

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

## 6) 预期说明
- `visual_regression_probe` 当前是“故意带错位”的 canary 用例  
  因此视觉检查失败是预期行为，用于证明检测链路有效。
- flow 截图当前按前缀 `flow_exploration_` 过滤归档，不再混入 `visual_ui_button_*`。

## 7) 交接与继续开发
- 当前状态文档：`docs/testing/04-handoff-current-state.md`
- 下一对话提示词：`docs/testing/NEXT_CHAT_PROMPT.md`

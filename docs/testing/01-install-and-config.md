# 安装与配置（v1）

## 1. 前置条件
- Godot 4.6 已安装并可命令行调用
- Python 3.10+ 可用（`python --version`）
- 项目根目录：`D:/GODOT_Test/old-archives-sp`

## 2. 快速验证（CLI）
在项目根目录执行：

```powershell
python "tools/game-test-runner/core/cli.py" --system exploration --project-root "." --scenario exploration_smoke --dry-run
```

期望：
- 控制台输出 JSON，包含 `run_id` 与 `status=finished`
- 生成目录：`artifacts/test-runs/<run_id>/`

## 3. MCP 适配验证

### 3.1 列场景
```powershell
python "tools/game-test-runner/mcp/server.py" --tool list_test_scenarios --args "{}"
```

### 3.2 跑一次 dry-run
```powershell
python "tools/game-test-runner/mcp/server.py" --tool run_game_test --system exploration --dry-run
```

期望：
- 返回 `ok=true`
- `result` 包含 `run_id`、`status`、`artifact_root`

## 4. Godot 插件启用
1. 打开项目。
2. 进入 `Project > Project Settings > Plugins`。
3. 启用 `Test Orchestrator`。
4. 右侧 Dock 出现 `Test Orchestrator` 面板。
5. （可选）在 `Godot Bin` 填入可执行文件绝对路径，例如：
   - `D:/GODOT/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe`
6. 勾选或取消 `Dry Run`：
   - 勾选：演练模式（不真正启动 Godot）
   - 取消：真实运行模式
7. 点击 `Run Exploration Smoke`。
8. 视觉基线相关按钮：
   - `Record Visual Baseline`：录制视觉基线图（需要 `Dry Run` 关闭）
   - `Run Visual Check`：按基线执行视觉比对（需要 `Dry Run` 关闭）
9. 回归套件按钮：
   - `Run Quick Regression Suite`：一键执行 exploration + visual canary，并输出 suite 报告
   - `Open suite_report.json`：打开最近一次 suite 的汇总报告
10. 流程调试按钮：
   - `Run Gameplay Debug Flow`：运行 `exploration_gameplay_flow_v1`
   - `Open flow_report.json`：打开流程步骤报告

期望：
- 面板显示 `Status: ..., run_id=...`
- 面板显示 `Artifacts: <artifact_root>`
- `Recent Runs` 列表出现新记录（最新在最上）
- 可使用：
  - `Open Folder` 打开选中 run 的产物目录
  - `Open report.json` 直接查看报告
  - `Open flow_report.json` 查看流程步骤报告（flow run 有）
  - `Open diff.png` 打开视觉差异热力图（仅视觉检查失败 run 有）
  - `Open diff_annotated.png` 打开可读版差异图（仅视觉检查失败 run 有）
  - `Copy Status` 复制当前状态文本
  - `Copy Artifacts Path` 复制当前产物目录路径
- 插件会自动记住上次的 `Godot Bin` 与 `Dry Run` 选择

视觉测试提示：
- 若未先录制基线，`Run Visual Check` 会失败并提示 baseline 缺失。
- 可先点 `Record Visual Baseline` 再点 `Run Visual Check`。
- `Run Quick Regression Suite` 也需要 `Dry Run` 关闭，且必须配置有效 `Godot Bin`。
- 插件会记住最近一次 suite 的目录，可跨重启打开 `suite_report.json`。

流程调试提示：
- `Run Gameplay Debug Flow` 需要 `Dry Run` 关闭，且需要有效 `Godot Bin`。
- flow 会输出 `flow_report.json`，包含每个步骤的断言与证据文件路径。
- flow 运行时仅归档前缀 `flow_exploration_` 的截图，避免混入视觉 canary 图片。

## 5. 可选：Godot 命令路径
若系统找不到 `godot4`，在调用参数中指定 `--godot-bin`，例如：

```powershell
python "tools/game-test-runner/core/cli.py" --system exploration --project-root "." --scenario exploration_smoke --godot-bin "C:/Tools/Godot/Godot_v4.6-stable_win64.exe"
```

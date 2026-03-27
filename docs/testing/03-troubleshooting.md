# 常见问题排查（v1）

## 0. 看不懂时先做这一步（最快）
- 先跑：
  - `powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp" -OnlyPreflight`
- 结果判断：
  - `status=passed`：环境可跑，问题多半在业务 flow 或断言
  - `status=failed_preflight`：先修环境（通常是 `GODOT_BIN` 或项目路径）

## 1. `missing cli.py`
- 现象：插件显示 `Status: fail - missing cli.py`
- 原因：`res://tools/game-test-runner/core/cli.py` 不存在或路径错误
- 处理：确认文件存在并刷新项目

## 2. `python exit code != 0`
- 现象：插件显示 python 非 0 退出
- 原因：本机 Python 未安装或未在 PATH
- 处理：命令行执行 `python --version`，必要时安装 Python 并重启编辑器

## 3. `unknown scenario`
- 现象：MCP/CLI 返回未知场景
- 原因：`scenario_registry.py` 未注册该场景
- 处理：新增 `ScenarioDef` 并重试

## 4. 未生成 `artifacts/test-runs`
- 现象：命令执行后找不到产物目录
- 原因：项目根目录传错，或进程未真正执行
- 处理：检查 `--project-root`，查看终端输出 JSON 中的 `artifact_root`

## 5. 找不到 Godot 命令
- 现象：非 dry-run 时失败，提示找不到 `godot4`
- 原因：Godot 可执行文件不在 PATH
- 处理：调用时显式传 `--godot-bin "<GodotExePath>"`

## 6. 日志未拷贝到 artifacts
- 现象：`artifactIndex.copiedLogs` 为空
- 原因：当前运行没有生成日志，或 APPDATA 路径不可用
- 处理：
  - 确认 `project.godot` 已开启 `debug.file_logging`
  - 检查 `%APPDATA%/Godot/app_userdata/<config/name>/logs/`

## 7. 如何确认链路可用
按顺序执行：
1. CLI dry-run 成功
2. MCP `list_test_scenarios` 成功
3. MCP `run_game_test --dry-run` 成功
4. 插件按钮触发成功并显示 `run_id`

## 8. MCP 错误码说明
- 返回结构：`{"ok":false,"error":{"code":"...","message":"..."}}`
- 常见 code：
  - `INVALID_ARGUMENT`：参数缺失或格式不对（如 `run_id` 为空）
  - `NOT_FOUND`：run 目录或报告文件不存在
  - `UNKNOWN_SCENARIO` / `UNKNOWN_SYSTEM`：场景或系统未注册
  - `UNSUPPORTED_TOOL`：调用了未实现工具
  - `INTERNAL_ERROR`：未归类异常（需看 message 定位）

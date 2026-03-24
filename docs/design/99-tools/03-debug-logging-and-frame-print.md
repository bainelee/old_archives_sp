# 调试日志与逐帧 Debug 输出（Godot 4.6）

本文档汇总**引擎文件日志**、**DebugFramePrint**、**Debug 面板集成**及 **Agent/CI 读取路径**，供开发与进入 debug 流程时查阅。速查仍见根目录 `AGENTS.md`。

---

## 1. 两套输出，用途不同

| 机制 | 内容 | 典型用途 |
|------|------|----------|
| **引擎 `file_logging`** | `print` / `push_error` / `push_warning` 等追加写入 `godot.log` | 传统日志、崩溃与引擎告警 |
| **DebugFramePrint** | 按**帧**聚合、`line("键",文本)` 同键覆盖；**不**默认走 `print` | 逐帧调试、避免 Output 刷屏；与 UE 蓝图 suppress 类似 |

二者互补：**不要**指望 `DebugFramePrint.line` 出现在编辑器「输出」面板，除非开启 `mirror_to_output`。

---

## 2. 引擎文件日志（`project.godot`）

- 配置段：`[debug]` → `file_logging/enable_file_logging=true`，`log_path="user://logs/godot.log"`，`max_log_files=5`。
- **Windows 路径**：`%APPDATA%\Godot\app_userdata\Old Archives\logs\godot.log`（应用名来自 `config/name`）。
- **轮转**：同目录下 `godot2026-*.log`；当前会话可能较短时以 `godot.log` 为主，排查时一并查看**最新时间戳**的轮转文件。
- **Agent**：用 `Read` 读上述绝对路径；大文件用 `Get-Content -Tail 200`（PowerShell 对含空格路径用 `-LiteralPath`）。

---

## 3. DebugFramePrint（Autoload）

- **脚本**：`scripts/core/debug_frame_print.gd`
- **注册**：`project.godot` → `[autoload]` → `DebugFramePrint`
- **API**：
  - `line(key: String, text: Variant)`：本帧登记一行，同 `key` 后者覆盖前者。
  - `MARKER` 常量 `##F>`；`capture_if_marked(message)` 解析 `##F>|键|正文` 或 `##F>键|正文`。
- **刷新时机**：`process_priority = 100000`，在同帧多数 `_process` 之后再聚合刷新。
- **信号**：`debug_display_text_changed(display_text: String)` — 展示用全文（可含状态行），**不写**入 `debug_frame_overlay.txt`。

### 3.1 开关（运行时可在脚本上改）

| 变量 | 默认 | 说明 |
|------|------|------|
| `enabled` | true | 总开关 |
| `emit_to_debug_panel` | true | 向 Debug 面板滚动区发信号 |
| `show_floating_overlay` | false | 左上角浮动 CanvasLayer（layer=10000） |
| `show_overlay_status` | true | 展示文本中带帧号、本帧行数提示（不进日志文件） |
| `write_file` | true | 每帧覆盖 `user://logs/debug_frame_overlay.txt`（**仅 user 行**，不含状态行） |
| `mirror_to_output` | false | 非空块时 `print` 到编辑器「输出」 |

### 3.2 日志文件（Agent）

- 路径：`user://logs/debug_frame_overlay.txt`
- Windows 与 `godot.log` 同目录：`...\Old Archives\logs\debug_frame_overlay.txt`
- 语义：**整文件覆盖**；无 `line()` 时多为空。

### 3.3 与游戏 UI 的集成

- **面板**：`UIMain/DebugInfoPanel`（`scenes/ui/ui_main.tscn`）
- **尺寸**：面板约 **400×600**；标题栏下 **DebugLogScroll**（`ScrollContainer`）固定高度 **160**，内为 **DebugLogLabel**。
- **脚本**：`scripts/ui/ui_main_debug_panel.gd` — `call_deferred` 连接 `DebugFramePrint.debug_display_text_changed`。
- **游戏内打开**：热键 **`**（Tab 上方），逻辑见 `scripts/game/game_main_input.gd`。

### 3.4 项目内当前使用点（示例）

- `scripts/ui/room_detail_panel_figma.gd`：庇护条布局调试通过 `/root/DebugFramePrint` 的 `call("line", ...)` 写入 `shelter_check` / `shelter_data`（需打开房间详情等才会触发）。

---

## 4. 自动化测试

- 场景：`scenes/test/debug_frame_print_test.tscn`
- 脚本：`scripts/test/debug_frame_print_test.gd`
- 运行（示例）：`Godot --headless --path <项目根> res://scenes/test/debug_frame_print_test.tscn --quit-after 400`
- 测试中关闭 `emit_to_debug_panel`，避免依赖 UIMain。

---

## 5. 可选：编辑器 stdout 镜像

- **VS Code/Cursor 任务**：`.vscode/tasks.json` → **Godot: Editor (tee to .godot/terminal_godot.log)**（是否与编辑器 Output 完全一致因环境而异）。

---

## 6. Debug 流程速查（给人与 Agent）

1. **传统 print/error**：读 `godot.log`（及最新轮转文件）。
2. **逐帧聚合调试**：游戏中打开 Debug 面板看 **DebugLogScroll**，或读 `debug_frame_overlay.txt`。
3. **必须在「输出」面板看到**：`mirror_to_output = true`（注意频率）。
4. **左上角浮动层**：`show_floating_overlay = true`。

---

## 相关文档

- [主 UI 概览](../3-ui/02-ui-main-overview.md)（DebugInfoPanel 引用）
- [Debug 因子与庇护 UI 经验](../2-gameplay/09-debug-factor-shelter-ui-lessons.md)
- [UI 布局调试说明](../ui-layout-debugging-guide.md)

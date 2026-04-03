# 旧日档案馆 - Agent 速查

Godot 4.6 项目：场景编辑器 + 2D 基地建设游戏。

- **核心目录**：`scripts/editor/`、`scripts/game/`、`scripts/ui/`、`datas/`、`docs/design/`
- **核心文件**：`map_editor.gd`、`room_info.gd`、`room_info.json`、`save_manager.gd`、`ui_main.gd`、`time_panel.gd`、`shelter_erosion_panel.gd`、`researcher_hover_panel.gd`、`cleanup_hover_panel.gd`
- **馆内布局格与清理解锁**：真源为 `datas/room_info.json` 的 `layout_cells`（馆内坐标，原点为 `room_00` 左下角格）；`RoomLayoutHelper.compute_adjacency` 按格曼哈顿距离派生 `adjacent_ids`。维护流程：`python tools/scripts/sync_room_info_layout_cells.py` → `python tools/scripts/validate_room_layout_cells.py`。说明见 [docs/design/4-archives_rooms/04-room-unlock-adjacency.md](docs/design/4-archives_rooms/04-room-unlock-adjacency.md)（`scripts/core/room_info.gd` 为 `ArchivesRoomInfo` 定义）。
- **探索（P1）**：`datas/exploration_config.json`（`regions_placeholder` 可选 `brief_before_explore_zh` / `brief_after_explore_zh`）、`datas/exploration_investigations.json`；`scripts/game/exploration/`（`exploration_service.gd`、`exploration_tick.gd`、`exploration_rules.gd`、`exploration_state_codec.gd`）；`scenes/ui/` 下 `exploration_map_overlay`、`exploration_region_info_panel`（右栏 **480px**）、`exploration_investigation_event_panel` 及对应 `scripts/ui/*.gd`；存档根键 `exploration`（v3 含 `completed_investigation_site_ids`）；`scripts/test/test_driver.gd` 仍提供 `exploreRegion`、`advanceGameHours`、`verifySaveSlotExploration`、`loadGameMainFromSlot` 等。说明见 `docs/design/2-gameplay/10-exploration-region-map.md`
- **存档规则**：清空存档 = 仅 `user://saves/`，绝不动 `user://maps/`（见 `.cursor/rules/save-system.mdc`）
- **Godot 调试控制台（文件日志）**：`project.godot` 已启用 `[debug]` → `file_logging`；`print` / `push_error` / `push_warning` 等写入 `user://logs/godot.log`。Windows：`%APPDATA%\Godot\app_userdata\Old Archives\logs\godot.log`（将 `%APPDATA%` 展开为当前用户路径）。Agent 调试时用 `Read` 读该绝对路径即可；日志很大时用终端 `Get-Content -Tail 200 '<路径>'`。可选：运行任务 **Godot: Editor (tee to .godot/terminal_godot.log)** 尝试把进程 stdout/stderr 追加到 `.godot/terminal_godot.log`（是否与编辑器 Output 面板完全一致因环境而异，以 `godot.log` 为准）。
- **逐帧调试（替换而非刷屏）**：Autoload `DebugFramePrint`（`scripts/core/debug_frame_print.gd`）。`line("键", "文本")` 每帧末聚合；默认经信号 `debug_display_text_changed` 显示在 **`InteractiveUiRoot/UIMain/DebugInfoPanel`**（`game_main.tscn` 下）标题栏下方的 **DebugLogScroll**（高 160px）；另写入 `user://logs/debug_frame_overlay.txt`。可选左上角浮动层：`show_floating_overlay = true`。**默认不会**刷编辑器「输出」；需要时 `mirror_to_output = true`。`MARKER`=`##F>`，`capture_if_marked()`。开关：`enabled`、`emit_to_debug_panel`、`write_file`、`show_overlay_status`。**完整说明**：[docs/design/99-tools/03-debug-logging-and-frame-print.md](docs/design/99-tools/03-debug-logging-and-frame-print.md)。
- **规范**：`.cursor/rules/`（按 globs 加载，编辑相关文件时自动匹配）
  - **全局沟通**：不争辩；用户指出问题时先彻查事实与己方推理，禁止优先归咎用户误解；**由 AI 负责实现**的表述用「我」不用「你」——见 `.cursor/rules/communication-no-argue-trust-user.mdc`（`alwaysApply`）
  - Godot 通用：`godot-gdscript.mdc`（.gd）、`godot-scenes-performance.mdc`（.tscn/.gd）
  - **3D 场景编辑器**：正常方向 Z 朝外/X 朝右/Y 朝上；3d_actor root 须 (0,0,0)，偏移在引用场景中设置；ActorBox 黑色、RoomReferenceGrid 灰白，见 `.cursor/rules/3d-scene-editor.mdc`
  - **Figma 导入**：从 Figma 读取→下载→导入 Godot 时，按 `.cursor/rules/figma-import.mdc` 执行
  - **UI 字体**：绑定检查见 `.cursor/skills/ui-font-import-check/SKILL.md`；动态字体导入须 **MSDF**（`multichannel_signed_distance_field=true`，见 [ResourceImporterDynamicFont](https://docs.godotengine.org/en/stable/classes/class_resourceimporterdynamicfont.html)）
  - **预制作 UI**：非游戏开始后生成的 UI 设计，不得将编辑器可见逻辑写在 `_ready()`；须支持编辑器中动态调整、效果立即可见；见 `.cursor/rules/ui-editor-live.mdc`
  - **数值同步**：用户说「调整数值」「我调整了数值」等时，按 `.cursor/subagents/game-values-sync.md` 全量同步 `datas/game_values.json`、`game_base.json`、`docs/design/*.md` 及脚本硬编码
- **术语对照**：[docs/settings/00-project-keywords.md](docs/settings/00-project-keywords.md)
- **详情**：[docs/design/00-project-overview.md](docs/design/00-project-overview.md)
- **test_figma_page UI 组件**：`ResourceProgressBar`、`ResourceBlock`、`CorrosionNumber`、`ForecastWarning`；ForecastWarning 侵蚀预警条：252×20，3px=1天、84天；仅侵蚀变化点生成 handle，恶化→红标、好转→绿标；handle 每日右移 3px 至今日消失；handle 池与侵蚀 schedule 写入存档；handle 与 warning_sign 贴图用 `tex.get_size()` 动态尺寸、防拉伸，清除子节点须先 `remove_child` 再 `queue_free`

# Memorix — Automatic Memory Rules

You have access to Memorix memory tools. Follow these rules to maintain persistent context across sessions.

## Session Start — Load Context

At the **beginning of every conversation**, before responding to the user:

1. Call `memorix_search` with a query related to the user's first message or the current project
2. If results are found, use `memorix_detail` to fetch the most relevant ones
3. Reference relevant memories naturally in your response — the user should feel you "remember" them

This ensures you already know the project context without the user re-explaining.

## During Session — Capture Important Context

**Proactively** call `memorix_store` whenever any of the following happen:

### Architecture & Decisions
- Technology choice, framework selection, or design pattern adopted
- Trade-off discussion with a clear conclusion
- API design, database schema, or project structure decisions

### Bug Fixes & Problem Solving
- A bug is identified and resolved — store root cause + fix
- Workaround applied for a known issue
- Performance issue diagnosed and optimized

### Gotchas & Pitfalls
- Something unexpected or tricky is discovered
- A common mistake is identified and corrected
- Platform-specific behavior that caused issues

### Configuration & Environment
- Environment variables, port numbers, paths changed
- Docker, nginx, Caddy, or reverse proxy config modified
- Package dependencies added, removed, or version-pinned

### Deployment & Operations
- Server deployment steps (Docker, VPS, cloud)
- DNS, SSL/TLS certificate, domain configuration
- CI/CD pipeline setup or changes
- Database migration or data transfer procedures
- Server topology (ports, services, reverse proxy chain)
- SSH keys, access credentials setup (store pattern, NOT secrets)

### Project Milestones
- Feature completed or shipped
- Version released or published to npm/PyPI/etc.
- Repository made public, README updated, PR submitted

Use appropriate types: `decision`, `problem-solution`, `gotcha`, `what-changed`, `discovery`, `how-it-works`.

## Session End — Store Summary

When the conversation is ending or the user says goodbye:

1. Call `memorix_store` with type `session-request` to record:
   - What was accomplished in this session
   - Current project state and any blockers
   - Pending tasks or next steps
   - Key files modified

This creates a "handoff note" for the next session (or for another AI agent).

## Guidelines

- **Don't store trivial information** (greetings, acknowledgments, simple file reads, ls/dir output)
- **Do store anything you'd want to know if you lost all context**
- **Do store anything a different AI agent would need to continue this work**
- **Use concise titles** (~5-10 words) and structured facts
- **Include file paths** in filesModified when relevant
- **Include related concepts** for better searchability
- **Prefer storing too much over too little** — the retention system will auto-decay stale memories

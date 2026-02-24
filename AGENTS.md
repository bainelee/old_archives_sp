# 旧日档案馆 - Agent 速查

Godot 4.6 项目：场景编辑器 + 2D 基地建设游戏。

- **核心目录**：`scripts/editor/`、`scripts/game/`、`scripts/ui/`、`datas/`、`docs/design/`
- **核心文件**：`map_editor.gd`、`room_info.gd`、`room_info.json`、`save_manager.gd`、`ui_main.gd`、`time_panel.gd`、`shelter_erosion_panel.gd`
- **存档规则**：清空存档 = 仅 `user://saves/`，绝不动 `user://maps/`（见 `.cursor/rules/save-system.mdc`）
- **规范**：`.cursor/rules/`（按 globs 加载，编辑相关文件时自动匹配）
  - Godot 通用：`godot-gdscript.mdc`（.gd）、`godot-scenes-performance.mdc`（.tscn/.gd）
- **术语对照**：[docs/settings/00-project-keywords.md](docs/settings/00-project-keywords.md)
- **详情**：[docs/design/00-project-overview.md](docs/design/00-project-overview.md)

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

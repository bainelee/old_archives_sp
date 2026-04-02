# 旧日档案馆 (Old Archives)

基于 Godot 4.6 引擎开发的 2D 基地建设、模拟经营、资源管理类游戏，视角类似《缺氧》《司辰之书》。

## 游戏介绍

你成为了旧日档案馆的管理员，依靠这座档案馆提供的「文明的庇佑」以阻隔来自暴君莱卡昂的神秘侵蚀。

- 招募研究员与调查员，解锁并建设房间，获取四种因子与更多信息
- 派遣调查员外出调查，推进案件与真相线索
- 抵抗莱卡昂暗影，最终引导革命

## 玩法简介

玩家需要在废弃档案馆中清理并建设房间，将区域逐步发展为：

- **研究区**
- **造物区**
- **事务所区**
- **生活区**

建设后的房间会产出不同资源。四种因子（认知、计算、意志、权限）对应食物、燃料、素材、建材。  
档案馆核心可消耗计算因子提供庇护，玩家需要持续强化核心来扩大覆盖范围并抵御侵蚀。

## 技术栈

- **引擎**：Godot 4.6
- **物理**：Jolt Physics
- **渲染**：Forward Plus（Windows 渲染驱动 D3D12）
- **本地化**：`zh_CN`（默认）、`en`

## 项目结构（盘查后更新）

```
old-archives-sp/
├── project.godot                    # 项目配置（主场景、Autoload、插件、调试等）
├── README.md                        # 本文件
├── AGENTS.md                        # Agent 协作速查与约束
├── scenes/                          # 场景（editor/game/ui/rooms/actors）
├── scripts/                         # 脚本（core/game/editor/ui/rooms/actors/test）
├── datas/                           # 游戏数据 JSON（含 schemas）
│   ├── game_values.json
│   ├── game_base.json
│   ├── room_info.json
│   ├── exploration_config.json
│   ├── exploration_investigations.json
│   └── schemas/
├── flows/                           # GameplayFlow 定义（回归/片段/规则）
├── tools/
│   ├── game-test-runner/            # 自动化测试与 MCP 脚本入口
│   └── scripts/                     # 数据同步/校验脚本（如 room_info layout）
├── docs/                            # 设计、测试、设置文档
├── translations/                    # 翻译源与编译文件
├── addons/                          # 插件（room_items_grid_snap/snappy/test_orchestrator）
├── artifacts/                       # 自动化测试产物目录（默认不提交）
└── assets/                          # 美术与字体资源
```

## 运行方式

- **F5 运行项目**：主场景为 `scenes/ui/start_menu.tscn`
- **F6 运行当前场景**：用于单场景调试（编辑器、主游戏、UI 等）

## Autoload 单例（以 `project.godot` 为准）

| 名称 | 用途 |
|------|------|
| `LocaleManager` | 语言切换与 locale 持久化 |
| `GameValues` | 加载 `datas/game_values.json` 数值 |
| `GameTime` | 游戏时间推进 |
| `ErosionCore` | 全局侵蚀等级与预测 |
| `PersonnelErosionCore` | 人员侵蚀相关逻辑 |
| `SaveManager` | 存档读写（`user://saves/`） |
| `DataProviders` | 数据提供器聚合 |
| `DebugFramePrint` | 逐帧调试信息聚合与面板输出 |
| `TestDriver` | 自动化测试动作与状态查询入口 |

## 自动化测试与回归入口

推荐先阅读：[`docs/testing/README.md`](docs/testing/README.md)

常用命令（仓库根目录执行）：

```powershell
# 最快环境预检
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/install/run-preflight.ps1"

# 快速门禁（preflight + contract）
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_acceptance_ci.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp" -Fast

# GameplayFlow 基础回归（基础测试两房 + 基础数据）
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_gameplay_regression.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp" -GodotBin "<GodotExePath>"

# 探索两地区存读档（stepwise shell 播报）
powershell -ExecutionPolicy Bypass -File "tools/game-test-runner/scripts/run_exploration_two_regions_stepwise.ps1" -ProjectRoot "D:/GODOT_Test/old-archives-sp" -GodotBin "<GodotExePath>"
```

说明：

- 核心 MCP CLI 入口：`tools/game-test-runner/mcp/server.py`
- GameplayFlow 逐步播报遵循三阶段：`started -> result -> verify`
- 需要逐步播报时，应优先使用 stepwise 脚本；不要把 `flow_runner.py` 作为人工/Agent 主入口

## 存档与调试日志

- **游戏存档**：`user://saves/`
- **地图数据**：`user://maps/`（与游戏存档分离；清空存档时不应删除）
- **Godot 文件日志**：`user://logs/godot.log`
  - Windows 默认路径：`%APPDATA%\Godot\app_userdata\Old Archives\logs\godot.log`

## 相关文档

- [项目概览](docs/design/00-project-overview.md)
- [测试快速入口](docs/testing/README.md)
- [术语对照](docs/settings/00-project-keywords.md)
- [数据文件说明](datas/README.md)
- [设计文档目录](docs/design/)

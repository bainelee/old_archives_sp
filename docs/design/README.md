# 设计文档

本目录用于记录《旧日档案馆》的游戏系统与功能设计讨论。

## 文档索引

| 文档 | 说明 |
|------|------|
| [00 - 项目概览与新系统准备](00-project-overview.md) | 项目定位、结构、已实现功能、数据流、新系统开发建议 |
| [01 - 地图编辑器](01-map-editor.md) | 网格系统、底板编辑、房间划分 |
| [02 - 房间信息与 room_info.json 同步](02-room-info-and-json-sync.md) | RoomInfo 结构、JSON 格式、同步逻辑 |
| [03 - 游戏主场景](03-game-main.md) | 主运行入口、slot_0 展示、编辑器隔离 |
| [04 - 时间流逝系统](04-time-system.md) | GameTime Autoload、TimePanel UI、时间比例与倍速 |
| [07 - 存档系统](07-save-system.md) | 存档架构、数据模型、保存/加载流程、与地图槽位关系 |
| [08 - 游戏数值系统](08-game-values.md) | 研究员认知消耗、核心庇护/范围、房间清理、建设区域、生活区住房、研究区/造物区产出、空房间改造 |
| [09 - 研究员侵蚀机制](09-researcher-erosion.md) | 侵蚀风险、被侵蚀状态、灾厄值、死亡、治愈 |
| [10 - 房间清理系统](10-room-cleanup-system.md) | 选择未清理房间、确认清理、多房间并行、进度与遮罩、研究员占用 |

---

## 开发变更（近期）

**2025-02-25 房间清理与研究员 UI**

- 清理悬停面板：消耗显示「信息 X (拥有 Y)」；新增研究员占用「X 人（可用 Y）」
- 清理完成：房间 `resources` 授予玩家，`_sync_resources_to_topbar()` 刷新显示
- 研究员 TopBar：左侧仅显示**空闲**数（总数 − 被侵蚀 − 清理中 − 建设中 − 房间工作）
- 研究员悬停：悬停「研究员：空闲/总数」→ 左侧面板显示总数、被侵蚀、清理中、建设中、房间工作、空闲
- 输入排除：CheatShelterPanel 加入 `_is_click_over_ui_buttons` 与 `_is_click_over_cleanup_allowed_ui`，修复 debug 庇护等级按钮点击无效

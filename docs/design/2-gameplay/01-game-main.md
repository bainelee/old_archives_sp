# 01 - 游戏主场景

## 概述

游戏主场景为项目的主运行入口（F5）。进入后展示 slot_0 地图，游戏运行期间无法唤出场景编辑器。主逻辑已按功能域拆分为多个 RefCounted 辅助类，主文件保留状态与编排。

---

## 入口与隔离

- **进入方式**：打开 `game_main.tscn` 后使用「运行当前场景」(F6)
- **数据来源**：`SaveManager` 加载 `user://saves/slot_N.json` 或 `user://maps/slot_0.json`（新游戏）
- **编辑器隔离**：主场景已留空，运行入口由当前打开的场景决定；进入游戏后无法唤出编辑器

---

## 功能

- 加载 slot_0 存档（底板 + 房间 + 时间 + 资源 + 人员）
- 渲染底板（空/墙壁/房间底板）、房间底图、房间遮罩与边框
- 摄像机：中键拖拽平移、滚轮缩放、点击房间聚焦
- 清理模式：选择未清理房间、确认、多房间并行清理
- 建设模式：选择区域、选择房间、确认、多房间并行建设
- 已建设房间：研究区/造物区持续产出

---

## 模块结构

| 文件 | 职责 |
|------|------|
| `scenes/game/game_main.tscn` | 场景根节点 |
| `scripts/game/game_main.gd` | 主逻辑、状态、编排、共享工具方法 |
| `scripts/game/game_main_draw.gd` | 底板、房间、遮罩、边框绘制 |
| `scripts/game/game_main_save.gd` | 存档收集、加载应用（map/time/resources） |
| `scripts/game/game_main_cleanup.gd` | 清理模式：进入/退出、确认、进度 tick、左键处理 |
| `scripts/game/game_main_construction.gd` | 建设模式：进入/退出、确认、进度 tick、左键处理 |
| `scripts/game/game_main_built_room.gd` | 已建设房间：研究区/造物区每小时产出 |
| `scripts/game/game_main_camera.gd` | 镜头初始化、聚焦、平移、缩放 |
| `scripts/game/game_main_input.gd` | 输入分发、UI 点击检测、模式路由 |

---

## 调用关系

```
game_main.gd (_ready/_process/_input/_draw)
    ├── GameMainSaveHelper (collect_game_state, apply_map/time/resources)
    ├── GameMainDrawHelper (draw_all)
    ├── GameMainCleanupHelper (process_overlay, on_button_pressed, on_confirm_pressed)
    ├── GameMainConstructionHelper (process_overlay, on_confirm_pressed, ...)
    ├── GameMainBuiltRoomHelper (process_production)
    ├── GameMainCameraHelper (setup_camera, focus_camera_on_room, apply_pan/zoom)
    └── GameMainInputHelper (process_input)
```

---

## 相关文档

- [00 - 项目概览](../00-project-overview.md)
- [01 - 地图编辑器](../1-editor/01-map-editor.md)（地图编辑与保存）
- [03 - 存档系统](03-save-system.md)
- [04 - 房间清理系统](04-room-cleanup-system.md)
- [05 - 区域建设功能](05-zone-construction.md)
- [06 - 已建设房间系统](06-built-room-system.md)

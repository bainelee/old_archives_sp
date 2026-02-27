# 04 - 房间清理系统

## 概述

本文档描述《旧日档案馆》中**房间清理**的完整交互流程、UI 设计与实现，包括选择未清理房间、确认清理、多房间同时清理及进度推进。术语对照见 [00-project-keywords](../../settings/00-project-keywords.md)。

---

## 1. 状态与流程

### 1.1 清理模式枚举

| 模式 | 说明 |
|------|------|
| NONE | 正常游戏，房间可选中查看详情 |
| SELECTING | 选择未清理房间，时间暂停，房间遮罩切换 |
| CONFIRMING | 已点击某房间，等待点击确认按钮 |

### 1.2 状态流转

```
NONE
  │ 点击「清理」按钮
  ▼
SELECTING（时间暂停，TopBar 显示暂停态）
  │ 左键点击未清理房间（资源足够）
  ▼
CONFIRMING（房间中心显示 ✓ 确认按钮）
  │ 点击 ✓ → 消耗资源，加入清理队列，回到 SELECTING
  │ 右键 / 点击空白 / 再次点击「清理」→ 退出选择
  ▼
SELECTING（可继续选择其他房间；多房间同时清理）
  │ 点击「清理」按钮
  ▼
NONE（恢复时间）
```

### 1.3 时间与清理

- **进入选择模式**：若时间正在流逝，则暂停；TopBar 的 TimePanel 同步为暂停图标
- **退出选择模式**：若进入前时间在流动，则恢复
- **确认清理后**：立即恢复时间（若曾流动），以便进度按游戏时间推进
- **清理进度**：完全按游戏内时间规则，暂停则停、加速则加速（见 [02 - 时间流逝系统](02-time-system.md)）

---

## 2. 房间遮罩规则

### 2.1 选择模式（SELECTING / CONFIRMING）

| 房间状态 | 遮罩 | 是否可选中 |
|----------|------|------------|
| 未清理且未在清理中 | 白色 40% 透明 | 是 |
| 已清理 | 黑色 60% 透明 | 否 |
| 正在清理中 | 黑色 60% 透明 | 否 |
| 尚未解锁 | 黑色 60% 透明 | 否 |

### 2.2 正常模式（NONE）

| 房间状态 | 遮罩 |
|----------|------|
| 未清理 | 黑色 40% 透明 |
| 已清理 | 无 |

---

## 3. 交互与输入

### 3.1 选择模式下禁用

- 左键点击房间**不再**打开房间详情面板
- 房间边框高亮（悬停/选中）不显示

### 3.2 悬停面板（鼠标左侧）

仅在**未清理且未在清理中**的房间上悬停时显示，内容包括：

- 房间名称
- 可建设区域（尺寸，如 5×3）
- 资源储量（房间产出资源列表）
- 清理花费（资源类型与数量）
- 研究员占用（本房间需占用人数 + 当前可用人数）
- 清理时间（游戏内小时）
- **资源不足时**：底部显示「当前资源不足」，且左键点击无效

### 3.3 确认与资源不足

- 左键点击未清理房间：资源足够（信息 + 可用研究员）→ 进入 CONFIRMING，房间中心显示 ✓ 按钮
- 资源不足（信息或研究员不足）：点击无效，悬停时显示「当前资源不足」
- 点击 ✓：消耗资源，房间加入清理队列，进度环显示于房间中心

### 3.4 退出方式

- 再次点击「清理」按钮
- 右键
- 在 CONFIRMING 时点击空白或其他房间（取消当前确认）

---

## 4. 多房间同时清理

### 4.1 设计

- 资源足够时可**并行**清理多个房间
- 确认清理后保持 SELECTING 模式，可继续选择其他未清理房间
- 正在清理中的房间视为不可选，使用黑色 60% 遮罩

### 4.2 数据结构

```gdscript
# game_main.gd
var _cleanup_rooms_in_progress: Dictionary = {}  # room_index -> {"elapsed": float, "total": float}
```

- `elapsed`：已推进的游戏内小时数
- `total`：该房间清理所需总小时数

### 4.3 进度推进

- 按 `GameTime.REAL_SECONDS_PER_GAME_HOUR` 与 `GameTime.speed_multiplier` 计算每帧推进量
- 公式：`game_hours_delta = (delta / REAL_SECONDS_PER_GAME_HOUR) * speed_multiplier`
- 暂停时 `GameTime.is_flowing == false`，不推进
- 每房间完成后：`room.clean_status = CLEANED`，从 `_cleanup_rooms_in_progress` 移除

### 4.4 研究员占用

- 清理进行中：研究员被**临时占用**，清理结束后返还
- TopBar 人员区显示「未侵蚀/总数」；悬停研究员区可查看详细占用（总数、被侵蚀、清理中、建设中、房间工作、空闲）

---

## 5. 清理花费与时间

### 5.1 RoomInfo 扩展

| 字段 | 类型 | 说明 |
|------|------|------|
| cleanup_cost | Dictionary | 可选，如 `{"info": 20}` |
| cleanup_time_hours | float | 可选，-1 表示用默认公式 |

| 方法 | 说明 |
|------|------|
| get_cleanup_researcher_count() | 清理需占用研究员数（3～5 单位 2 人，6～7 单位 3 人） |

### 5.2 默认公式（未配置时，见 08-game-values 4.1）

| 项目 | 公式 |
|------|------|
| 信息消耗 | 3～5 单位 20 信息；6～7 单位 40 信息 |
| 研究员占用 | 3～5 单位 2 人；6～7 单位 3 人 |
| 时间 | 3～5 单位 3 小时；6～7 单位 5 小时 |

房间单位：`ceil(面积/5)`，面积 = `rect.size.x × rect.size.y`

### 5.3 支持的资源键

- 因子：`cognition`, `computation`, `willpower`, `permission`
- 货币：`info`, `truth`

### 5.4 持久化

`cleanup_cost`、`cleanup_time_hours` 写入 `to_dict()` / 从 `from_dict()` 读取，兼容旧存档（缺省时使用默认公式）。

### 5.5 清理完成与资源授予

- 清理进度达到 100% 时：`room.clean_status = CLEANED`
- **可建设区域房间**（图书室、机房、资料库、教学室、实验室、推理室）：房间 `resources` **不**授予玩家，存量保留供 [06 - 已建设房间系统](06-built-room-system.md) 持续消耗
- **其余房间**：`_grant_room_resources_to_player()` 将 `room.resources` 累加至 UIMain
- 消耗/授予后均调用 `_sync_resources_to_topbar()` 刷新 TopBar

---

## 6. UI 组件

### 6.1 清理按钮

| 项目 | 说明 |
|------|------|
| 位置 | 主界面右下角 BottomRightBar，与灾厄值按钮独立 |
| 场景 | `scenes/ui/ui_main.tscn` |
| 路径 | `UIMain/BottomRightBar/BtnCleanup` |
| 尺寸 | 130×130（与灾厄按钮一致） |
| 悬停 | 外边缘高亮（2px 边框） |

### 6.2 CleanupOverlay（CanvasLayer layer=11）

| 组件 | 说明 |
|------|------|
| CleanupHoverPanel | 悬停面板，显示在鼠标左侧 |
| ConfirmContainer | 确认按钮（✓）容器，可定位到房间中心 |
| ProgressRingsContainer | 多房间进度环容器，动态创建/回收 |

**场景**：`scenes/ui/cleanup_overlay.tscn`  
**脚本**：`scripts/ui/cleanup_overlay.gd`

### 6.3 悬停面板

| 项目 | 说明 |
|------|------|
| 场景 | `scenes/ui/cleanup_hover_panel.tscn` |
| 脚本 | `scripts/ui/cleanup_hover_panel.gd` |
| 定位 | 鼠标左侧，垂直居中对齐视口 |
| 最小宽度 | 220px |

### 6.4 进度环

| 项目 | 说明 |
|------|------|
| 脚本 | `scripts/ui/cleanup_progress_ring.gd` |
| 尺寸 | 80×80 |
| 绘制 | 背景环 + 进度弧（从顶部顺时针） |

---

## 7. 核心脚本与职责

| 文件 | 职责 |
|------|------|
| `scripts/game/game_main.gd` | 状态机、遮罩绘制、输入处理、进度推进、资源消耗 |
| `scripts/ui/cleanup_overlay.gd` | 悬停/确认/多进度环的显示与定位 |
| `scripts/ui/cleanup_hover_panel.gd` | 悬停面板内容与定位 |
| `scripts/ui/cleanup_progress_ring.gd` | 环形进度条绘制 |
| `scripts/editor/room_info.gd` | `get_cleanup_cost()`、`get_cleanup_time_hours()` |

---

## 8. 输入与 GUI 分离

全部鼠标逻辑统一在 `_input` 中处理（参考 00cfade），通过 `_is_click_over_ui_buttons()` 排除需交给 GUI 的区域，仅对游戏世界点击进行房间选择/确认；中键平移和鼠标移动也在 `_input` 中。

**需排除的区域**：TopBar、BottomRightBar、CalamityBar、ConfirmContainer、CheatShelterPanel/Panel（debug 庇护等级）

**清理模式**：`_is_click_over_cleanup_allowed_ui()` 允许点击 BtnCleanup、ConfirmContainer、CheatShelterPanel；其余 UI 点击被拦截。

---

## 9. 经验小结（开发中遇到的坑）

以下问题在实现多房间同步清理时反复出现，已写入 Memorix 供后续类似功能参考。

| 现象 | 根因 | 解决 |
|------|------|------|
| 点击房间无反应 | `_unhandled_input` 被覆盖层 Control 抢先消费 | 改用 `_input` 抢先处理，并显式排除 UI 区域 |
| 确认按钮闪现即灭 | `hide_progress()` / `update_progress_rooms()` 每帧将 `_confirm_container.visible = false` | 周期性逻辑不触碰非其负责的 overlay 控件 |
| 暂停、变速、灾厄条无法点击 | 只排除了 BottomRightBar，未排除 TopBar、CalamityBar | 扩展 `_is_click_over_ui_buttons` 覆盖所有交互 UI |
| 清理中无法点选第二房间 | 进度环 Control 默认 `mouse_filter=STOP` 阻挡点击 | 创建进度环时设 `mouse_filter = MOUSE_FILTER_IGNORE` |
| 第二房间确认按钮不显示 | `update_progress_rooms` 在 `rooms_data` 非空时隐藏 ConfirmContainer | 进度环与确认可并存，确认显隐只由 show/hide_confirm 控制 |

---

## 10. 参考

- [02 - 房间信息与 room_info.json 同步](../1-editor/02-room-info-and-json-sync.md)
- [02 - 时间流逝系统](02-time-system.md)
- [02 - 主 UI 设计概览](../3-ui/02-ui-main-overview.md)
- [01 - 游戏数值系统](../0-values/01-game-values.md)（含建设、清理的规划数值，当前实现采用简化公式）

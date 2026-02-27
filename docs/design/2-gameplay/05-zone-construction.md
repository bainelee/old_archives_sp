# 05 - 区域建设功能

## 概述

区域建设是《旧日档案馆》的核心玩法之一：玩家在**已清理**的房间上选择并启动对应类型的区域建设，完成后该房间开始产出因子、提供住房或承载造物/事务所功能。本文档描述区域建设的流程、数据模型、UI 与系统边界。

**前置条件**：房间必须处于**已清理**状态方可建设（见 [04 - 房间清理系统](04-room-cleanup-system.md)）。

---

## 1. 区域类型与房间对应关系

### 1.1 完整对应表

| 区域类型 | 可建设于的房间类型 | 备注 |
|----------|-------------------|------|
| 研究区 | 图书室、机房、资料库、教学室 | 消耗房间存量产出因子，数值见 [01](../0-values/01-game-values.md) 第 6 节 |
| 造物区 | 实验室、推理室 | 消耗意志产出权限/信息，数值见 08 第 7 节 |
| 事务所区 | 事务所遗址 | |
| 生活区 | 宿舍 | 提供住房 |
| 医疗区 | 医疗室 | 新房间类型，数值待定 |
| 娱乐区 | 放映厅、院子 | 新房间类型，数值待定 |
| 宗教区 | 教堂、冥想室 | 新房间类型，数值待定 |
| 奇观区 | 遗迹、奇观 | 新房间类型，数值待定 |

### 1.2 设计约束

- 每个房间至多建设**一种**区域
- 档案馆核心：不参与区域建设，由单独逻辑管理
- 空房间：需先通过**改造**变为造物区房间，再建设造物区

---

## 2. 建设流程

### 2.1 整体流程

```
选择区域 → 选择房间（建设目标） → 确认建设 → 支付资源 + 占用研究员 → 开始建设 → 计时完成 → 房间生效
```

### 2.2 状态流转（与清理类似）

```
NONE
  │ 点击「建设」按钮
  ▼
选择区域（分类 tag + 区域按钮显示）
  │ 点击某区域按钮
  ▼
建设目标选择（房间遮罩切换：可建设=蓝色，不可=黑色）
  │ 左键点击可建设房间（资源足够）
  ▼
CONFIRMING（房间中心显示 ✓ 确认按钮）
  │ 点击 ✓ → 消耗资源，开始建设，显示环形进度条，退出建设选择状态
  │ 右键 / 点击空白 / 再次点击「建设」→ 退出选择
  ▼
NONE（遮罩隐藏，tag 和区域按钮消失，灾厄 UI 恢复）
```

### 2.3 前置条件

1. **清理状态**：`clean_status = 已清理`（1）
2. **房间类型匹配**：房间类型与该区域类型对应表中允许的类型一致
3. **未已建设**：该房间当前未建设任何区域
4. **资源充足**：信息、权限（若需要）足够
5. **研究员可用**：空闲研究员数量满足建设需求

### 2.4 建设进行中

- **多房间并行**：与清理相同，可多个房间同时处于建设中，各自独立计时
- 研究员自建设开始**长期占用**，建设完成后**不返还**（继续留在房间工作）
- **研究员状态区分**：建设进行中时，研究员携带「建设中」状态；建设完成后转为「房间工作」状态。两者在 TopBar 悬停菜单中分别计入「建设中」「房间工作」。
- 建设时长 = 房间单位数 × 每单位耗时（见 [01 - 游戏数值系统](../0-values/01-game-values.md)）
- 建设期间房间不可进行其他建设或改造操作

### 2.5 建设完成与持续运作

建设完成后，房间标记为「已建设」，绑定区域类型，并进入持续运作状态：

- **消耗房间储备、产出因子**：根据该房间的产出逻辑，持续消耗房间原本的资源储备，不断产出因子（如研究区消耗房间存量产出认知/计算/意志/权限）
- **消耗玩家资源**：若该区域需消耗玩家资源（如造物区消耗意志），则持续从玩家处扣除相应因子
- **生活区**：提供住房
- **事务所**：解锁事务所相关功能

**后续逻辑**：已建设房间的详细运作、产出节奏、存量耗尽与停工等，见 [06 - 已建设房间系统](06-built-room-system.md)。

### 2.6 资源授予约束（本系统必须遵守）

**建设完成时，绝不将房间资源储存量一次性授予玩家。**

- 房间的 `room.resources`（存量）在建设完成后**保留在房间内**，由「已建设房间系统」在持续运作中按产出速率逐步消耗并转化为玩家因子
- 研究区：消耗房间存量 → 产出因子；造物区：消耗玩家意志 → 产出权限/信息（不消耗 room.resources）
- 该约束属于**区域建设系统**的职责边界：建设逻辑本身不触发任何一次性资源授予；若清理系统在清理完成时授予了可建设房间的存量，应与本系统协调，确保建设流程中**无论何时**都不会发生一次性授予

---

## 3. 数值设计（引用）

建设消耗、耗时等数值详见 [01 - 游戏数值系统](../0-values/01-game-values.md) 第 5 节「建设区域」，此处仅作引用。

| 区域类型 | 研究员占用 | 信息 | 权限 | 每单位耗时（小时） |
|----------|------------|------|------|-------------------|
| 研究区 | 2 | 100 | 60 | 2 |
| 造物区 | 2 | 100 | 60 | 2 |
| 事务所 | 2 | 100 | 120 | 2 |
| 生活区 | 1 | 50 | 0 | 1 |

---

## 4. 数据模型（待定）

### 4.1 房间扩展字段

建设状态需在存档/地图数据中持久化，可选方案：

| 方案 | 说明 |
|------|------|
| 扩展 RoomInfo | 新增 `zone_type`（区域类型）、`zone_building_progress`（建设进度 0～1）、`zone_building_end_time`（完成时刻）等字段 |
| 独立 ZoneInfo | 房间引用 ZoneInfo，建设状态单独管理 |
| 存档层扩展 | RoomInfo 保持地图用；存档中额外维护每个房间的建设状态 |

**待定**：与 [03 - 存档系统](03-save-system.md) 和 `room_info.json` 同步规则结合后确定。

### 4.2 区域类型枚举

建议在 `room_info.gd` 或新建 `zone_type.gd` 中定义，与 UI 分类对应：

- 无
- **工作类**：研究区、造物区、事务所区
- **后勤类**：生活区、医疗区、娱乐区
- **秘迹类**：宗教区、奇观区

---

## 5. UI 与交互

### 5.1 建设选择状态（与清理选择状态一致的模式）

建设选择状态与 [04 - 房间清理系统](04-room-cleanup-system.md) 的清理选择状态采用**相同交互模式**：

| 行为 | 说明 |
|------|------|
| **暂停** | 进入选择状态时暂停时间，TopBar 显示暂停态；退出后恢复 |
| **遮罩** | 进入建设目标选择后切换，蓝色=可建设、黑色=不可（见 5.5） |
| **禁用其他 UI** | 左键点击房间不再打开详情面板；房间边框高亮不显示；仅保留建设相关交互 |
| **多房间并行** | 与清理相同，可**多个房间同时建设**；确认后退出本流程，需建设其它房间时再次点击「建设」进入 |

点击「建设」按钮后进入此状态，额外表现：

- **底部中央灾厄 UI**：隐藏
- **新增两组 UI**：建设分类 tag + 区域选择按钮（见 5.2、5.3）
- **退出此状态**（确认建设、或右键/空白/再次点击「建设」）：灾厄 UI 恢复显示，建设 UI 隐藏，遮罩隐藏，恢复时间与其它 UI

### 5.2 第一组：建设分类 tag

| 属性 | 说明 |
|------|------|
| 位置 | 底部，水平居中 |
| 高度 | 与「建设」按钮一致 |
| 内容 | 若干 tag 按钮，水平排布 |
| 当前分类 | 工作类、后勤类、秘迹类（类别之后会扩充） |

点击某个 tag 后，上方区域选择按钮切换为该分类下的区域选项。

### 5.3 第二组：区域选择按钮

| 属性 | 说明 |
|------|------|
| 位置 | 建设分类 tag **上方** |
| 高度 | 建设分类 tag 高度的 **2 倍** |
| 字体 | 比分类 tag 更大 |
| 按钮宽度 | 比分类 tag 更宽 |
| 内容 | 根据当前选中的分类 tag **动态切换** |

**当前分类与区域对应**：

| 分类 tag | 区域选项 |
|----------|----------|
| 工作类 | 研究区、造物区、事务所区 |
| 后勤类 | 生活区、医疗区、娱乐区 |
| 秘迹类 | 宗教区、奇观区 |

选择某个区域按钮后，进入**建设目标选择状态**（见 5.5）。

### 5.4 区域按钮悬停提示

鼠标移动到区域按钮上时，显示 tooltip 或悬浮窗，内容来源 [01 - 游戏数值系统](../0-values/01-game-values.md) 第 5 节：

| 内容 | 说明 |
|------|------|
| 建设消耗 | 信息、权限（若需要）、研究员占用 |
| 每单位耗时 | 小时/单位 |
| 材料不足 | 若当前信息/权限/研究员不足，显示「材料不足」 |

### 5.5 建设目标选择状态（选择区域后）

选择相应区域后进入此状态，房间遮罩切换：

| 房间状态 | 遮罩 | 是否可选中 |
|----------|------|------------|
| 已清理、未建设、房间类型可建设该区域 | **蓝色** | 是 |
| 已清理但房间类型不匹配 / 已建设 / 建设中 / 未清理 | **黑色** | 否 |

房间类型与区域对应见 [1.1 完整对应表](#11-完整对应表)。

### 5.6 房间悬停面板（建设目标选择状态下）

将鼠标移动到**符合条件**的房间里，在鼠标左侧显示悬浮窗口：

| 内容 | 说明 |
|------|------|
| 房间名称 | |
| 房间类型 | |
| 建设后每小时产出 | 研究区/造物区等产出数据，见 [01](../0-values/01-game-values.md) 第 6、7 节 |
| 建设后每小时消耗 | 若有（如造物区消耗意志），一并显示 |

数据来源：08-game-values.md。

### 5.7 确认与退出

- **点击可建设房间**：资源足够时，房间中心显示 ✓ 确认按钮（与清理类似）
- **资源不足**：材料/研究员不足时点击无效，悬停时显示「材料不足」
- **点击 ✓**：消耗资源、占用研究员，房间开始建设；显示**环形进度条**；**退出建设选择状态**
- **退出时**：遮罩隐藏，分类 tag 与区域按钮消失，灾厄 UI 重新显示，时间恢复
- **退出方式**：点击 ✓ 确认后自动退出；或右键 / 点击空白 / 再次点击「建设」主动退出

### 5.8 建设进度反馈

- 建设进行中的房间：显示**环形进度条**
- 研究员 TopBar 悬停菜单：建设进行中计入「建设中」，建设完成并开始产出后计入「房间工作」。两种状态分别统计，互不重叠。

### 5.9 与清理 UI 的关系

- 清理悬停面板已有「研究员占用」「信息消耗」等模式，建设面板可复用类似布局
- 同一房间在「未清理」时显示清理选项，「已清理未建设」时显示建设选项

---

## 6. 系统边界

### 6.1 依赖系统

| 系统 | 依赖内容 |
|------|----------|
| 房间清理 | 仅已清理房间可建设 |
| 游戏数值 | 消耗、耗时、产出公式 |
| 时间系统 | 建设时长计时 |
| 存档系统 | 建设状态持久化 |
| TopBar / 资源 | 研究员占用、因子消耗与产出同步 |

### 6.2 与改造的关系

- **改造**：空房间 → 实验室/推理室等（见 08 第 8 节）
- **建设**：已清理房间 → 研究区/造物区/生活区/事务所
- 两者为同级操作，互斥于同一房间的同一时刻

---

## 7. 待定事项

- [ ] 数据模型：RoomInfo 扩展 vs 独立 ZoneInfo vs 存档层扩展
- [ ] 医疗区、娱乐区、宗教区、奇观区：建设消耗、产出/消耗数值设计
- [ ] 新房间类型（医疗室、放映厅、院子、教堂、冥想室、遗迹、奇观）加入 room_info 与地图编辑器
- [ ] 建设取消：是否支持中途取消，取消后资源/研究员如何处理
- [ ] 房间拆除：已建设房间的拆除逻辑与研究员返还
- [ ] 事务所具体功能：建设完成后解锁的内容
- [ ] 建设分类 tag 扩充：后续新增分类的 UI 扩展方式

---

## 8. 技术实现流程（供 Agent 执行）

本节根据 [04 - 房间清理系统](04-room-cleanup-system.md) 的设计、已实现代码及其中遇到的坑，给出区域建设的技术实现步骤与注意事项。实现时**务必参考清理系统的实现模式**，复用相同架构。

### 8.1 实现阶段拆解

| 阶段 | 内容 | 依赖 |
|------|------|------|
| 1 | 数据模型：RoomInfo 扩展 + ZoneType 枚举 | 无 |
| 2 | 建设 Overlay 场景与脚本（分类 tag、区域按钮、悬停、确认、进度环） | 阶段 1 |
| 3 | game_main 状态机与输入处理 | 阶段 2 |
| 4 | 遮罩绘制（蓝/黑）、研究员占用同步 | 阶段 3 |
| 5 | 存档持久化 | 阶段 1～4 |

### 8.2 阶段 1：数据模型

**RoomInfo 扩展**（`scripts/editor/room_info.gd`）：

- 新增 `zone_type: int`，默认 0（无）
- 新增 `ZoneType` 枚举（或新建 `scripts/core/zone_type.gd`），与 1.1 对应表一致
- 新增 `get_construction_cost() -> Dictionary`、`get_construction_researcher_count() -> int`、`get_construction_time_hours() -> float`（参考 `get_cleanup_*` 模式，数值见 08 第 5 节）
- 新增 `can_build_zone(zone_type: int) -> bool`：根据 room_type 与 1.1 对应表判断
- `to_dict()` / `from_dict()` 中序列化 `zone_type`，兼容旧存档（缺省=0）

**房间类型→区域映射**：在 `room_info.gd` 或 `zone_type.gd` 中实现 `get_rooms_for_zone(zone: int) -> Array[int]`，返回可建设该区域的 RoomType 枚举值数组。注意 `room_info.gd` 中：`LIBRARY`=图书室、`LAB`=机房、`ARCHIVE`=资料库、`CLASSROOM`=教学室、`SERVER_ROOM`=实验室、`REASONING`=推理室、`OFFICE_SITE`=事务所遗址、`DORMITORY`=宿舍。

### 8.3 阶段 2：建设 Overlay

**新建场景** `scenes/ui/construction_overlay.tscn`（可参考 `cleanup_overlay.tscn`）：

- CanvasLayer layer=11（与 CleanupOverlay 同层，建设与清理互斥显示，无冲突）
- 子节点结构：
  - `DimOverlay` / `BlockedUIOverlay`：与清理相同的遮罩模式（建设时禁用其他 UI）
  - `ConstructionCategoryTags`：HBoxContainer，底部居中，高度与 BtnBuild 一致
  - `ConstructionZoneButtons`：HBoxContainer，在 Tags 上方，高度 2×、字大、按钮更宽
  - `ConstructionHoverPanel`：房间悬停面板（复用 cleanup_hover_panel 布局思路）
  - `ConfirmContainer` + `ConfirmButton`（✓）：与清理一致
  - `ProgressRingsContainer`：多房间进度环容器

**新建脚本** `scripts/ui/construction_overlay.gd`：

- 信号：`confirm_construction_pressed`
- 方法：`show_construction_selecting_ui()`、`hide_construction_selecting_ui()`、`show_hover_for_room(room, zone_type, resources, can_afford, …)`、`hide_hover()`、`update_hover_position()`、`show_confirm_at()`、`update_confirm_position()`、`hide_confirm()`、`update_progress_rooms()`、`hide_progress()`
- **进度环**：创建时 `mouse_filter = Control.MOUSE_FILTER_IGNORE`，避免阻挡房间点击（清理系统坑点）

**新建** `scripts/ui/construction_hover_panel.gd`（可参考 `cleanup_hover_panel.gd`）：

- 显示：房间名称、房间类型、建设后每小时产出/消耗、建设消耗、研究员占用、材料不足提示

**新建** `scripts/ui/construction_progress_ring.gd`：可直接复用 `cleanup_progress_ring.gd` 或继承。

**区域按钮悬停**：每个区域按钮需 Tooltip 或独立悬浮逻辑，显示消耗、每单位耗时、「材料不足」；数据来自 `get_construction_cost()` 等。

**灾厄 UI 隐藏**：建设选择状态下，UIMain 的 CalamityBar 需隐藏；可复用 cleanup 的 `set_cleanup_blocking` 思路，扩展为 `set_construction_blocking`，或单独控制 CalamityBar.visible。

### 8.4 阶段 3：game_main 状态机与输入

**状态枚举**（`scripts/game/game_main.gd`）：

```gdscript
enum ConstructionMode { NONE, SELECTING_ZONE, SELECTING_TARGET, CONFIRMING }
var _construction_mode: ConstructionMode = ConstructionMode.NONE
var _construction_selected_zone: int = 0      # ZoneType
var _construction_confirm_room_index := -1
var _construction_rooms_in_progress: Dictionary = {}  # room_index -> {elapsed, total}
var _time_was_flowing_before_construction := false
```

**流程**：

1. 点击 BtnBuild → `_enter_construction_selecting_zone_mode()`：暂停时间、显示 ConstructionOverlay、隐藏灾厄、`set_construction_blocking(true)`
2. 点击某区域按钮 → `_construction_selected_zone = zone`，切换遮罩（进入建设目标选择）
3. 左键点击房间 → `_handle_construction_left_click(rid)`：可建设且资源足够 → CONFIRMING，显示 ✓
4. 点击 ✓ → `_on_construction_confirm_pressed()`：消耗资源、加入 `_construction_rooms_in_progress`、退出建设状态
5. 右键/空白/再次点击 BtnBuild → `_exit_construction_mode()`

**输入处理**（与清理一致）：

- 全部鼠标逻辑在 `_input` 中处理，**不用** `_unhandled_input`（否则会被 Overlay 的 Control 抢先消费，导致点击房间无反应）
- 新增 `_is_click_over_construction_allowed_ui()`：允许 BtnBuild、ConstructionOverlay 的 CategoryTags、ZoneButtons、ConfirmContainer
- 建设模式下调用 `_is_click_over_construction_allowed_ui()` 放行建设相关 UI，其余走 `_is_click_over_ui_buttons()` 拦截（TopBar、BottomRightBar、CalamityBar、ConfirmContainer 等）

**需排除/放行的 UI**（参考 [04 - 房间清理系统](04-room-cleanup-system.md) 第 8 节）：

- TopBar、CalamityBar、BottomRightBar、CheatShelterPanel 在非建设允许列表中需拦截点击
- 建设允许：BtnBuild、ConstructionCategoryTags、ConstructionZoneButtons、ConfirmContainer

### 8.5 阶段 4：遮罩与研究员

**遮罩绘制**（`game_main._draw()`）：

- 仅在 `_construction_mode == SELECTING_TARGET` 或 `CONFIRMING` 时，按 5.5 规则绘制：
  - 已清理 + 未建设 + 房间类型可建设当前选中区域 → 蓝色 40% 透明
  - 其余 → 黑色 60% 透明
- 建设进行中的房间：显示进度环，不参与遮罩逻辑（已不可选）

**研究员占用**：

- `_get_construction_researchers_occupied()`：遍历 `_construction_rooms_in_progress`，累加各房间 `get_construction_researcher_count()`
- `_sync_construction_researchers_to_ui()`：设置 `UIMain.researchers_in_construction`
- 建设完成后研究员**不返还**，后续由「已建设房间系统」计入 `researchers_working_in_rooms`

**资源消耗**：

- `_can_afford_construction(room, zone_type, resources) -> bool`
- `_consume_construction_cost(room, zone_type) -> void`，调用 `_sync_resources_to_topbar()`

### 8.6 阶段 5：存档持久化

- `_construction_rooms_in_progress` 为运行时状态，**不**直接存档
- 建设进度按 `elapsed/total` 与游戏时间推进，存档时若房间在建设中，需保存 `elapsed`、`zone_type`、`total`
- 建设完成的房间：`room.zone_type` 持久化到 `rooms` 数组
- 参考 `collect_game_state()`、`_apply_map()` 的现有结构，在 rooms 的 dict 中增加 `zone_type`、可选 `zone_building_elapsed`、`zone_building_total`

### 8.7 易出 bug 点与注意事项（参考清理实现）

| 现象 | 根因 | 解决 |
|------|------|------|
| 点击房间无反应 | `_unhandled_input` 被 Overlay Control 抢先消费 | 使用 `_input` 并显式排除 UI 区域 |
| 确认按钮闪现即灭 | 周期性逻辑（如 update_progress_rooms）误隐藏 ConfirmContainer | 进度环与确认显隐分离，确认仅由 show/hide_confirm 控制 |
| 暂停、变速、灾厄等无法点击 | 排除区域不完整 | 扩展 `_is_click_over_ui_buttons` 覆盖 TopBar、CalamityBar、BottomRightBar |
| 多房间建设时第二房间确认不显示 | 进度环逻辑与确认逻辑耦合 | 进度环与确认可并存，确认显隐独立于 progress |
| 进度环阻挡房间点击 | Control 默认 mouse_filter=STOP | 创建进度环时设 `mouse_filter = MOUSE_FILTER_IGNORE` |
| UIMain 节点路径在 _ready 时未就绪 | CleanupOverlay 等为兄弟节点 | 用 `call_deferred("_setup_construction_mode")` 连接信号 |
| 建设/清理同时激活 | 两套 Overlay 可能重叠 | 进入建设时确保 cleanup 未激活；`set_cleanup_blocking` 已禁用 BtnBuild，需对应增加 `set_construction_blocking` 禁用 BtnCleanup |

### 8.8 核心文件清单

| 操作 | 文件 |
|------|------|
| 新建 | `scenes/ui/construction_overlay.tscn` |
| 新建 | `scripts/ui/construction_overlay.gd` |
| 新建 | `scripts/ui/construction_hover_panel.gd` |
| 复用或新建 | `scripts/ui/construction_progress_ring.gd`（可复用 cleanup_progress_ring） |
| 新建 | `scripts/core/zone_type.gd`（或扩展 room_info.gd） |
| 修改 | `scripts/editor/room_info.gd`（zone_type、建设相关方法） |
| 修改 | `scripts/game/game_main.gd`（状态机、输入、遮罩、进度、资源） |
| 修改 | `scripts/ui/ui_main.gd`（新增 `build_button_pressed` 信号并连接 BtnBuild、`set_construction_blocking` 禁用 BtnCleanup/BtnRenovate、CalamityBar 显隐） |
| 修改 | `scenes/game/game_main.tscn`（挂载 ConstructionOverlay） |

### 8.9 与清理的差异

| 项目 | 清理 | 建设 |
|------|------|------|
| 确认后 | 当前实现为退出模式 | 退出模式（一致） |
| 遮罩颜色 | 可选=白，不可选=黑 | 可选=蓝，不可选=黑 |
| 研究员 | 建设/清理中临时占用，结束后返还 | 建设中占用，完成后转为房间工作（不返还） |
| 多阶段 | SELECTING → CONFIRMING | SELECTING_ZONE → SELECTING_TARGET → CONFIRMING |

### 8.10 预测性问题与预防方案

实现时可能遇到以下问题，建议提前采用对应预防措施。

| 预测问题 | 场景/根因 | 预防方案 |
|----------|-----------|----------|
| **区域按钮点击被 game_main 拦截** | `_input` 中 set_input_as_handled 过早，ZoneButtons 收不到点击 | `_is_click_over_construction_allowed_ui` 包含 CategoryTags、ZoneButtons 的全局 Rect；若点击在其内则 `return` 且**不**调用 set_input_as_handled，交由 GUI 处理 |
| **分类 tag 切换后遮罩残留** | 从 SELECTING_TARGET 切回 SELECTING_ZONE（点击另一 tag）时，遮罩应消失 | 点击 tag 时重置 `_construction_selected_zone = 0`，`_construction_mode = SELECTING_ZONE`；`_draw` 仅在 SELECTING_TARGET/CONFIRMING 时绘制建设遮罩 |
| **选中区域后无可用房间** | 用户选研究区但无已清理图书室等，全黑遮罩、无反馈 | 进入 SELECTING_TARGET 时检查 `_count_valid_rooms_for_zone()`；若为 0，在 HintPanel 显示「当前没有可建设此区域的房间」，或对 ZoneButtons 做可用性预检并置灰 |
| **医疗区等新区域无 RoomType** | RoomType 枚举尚无医疗室、放映厅等，`can_build_zone` 报错或返回空 | 分阶段实现：先只支持研究区/造物区/事务所/生活区；`get_rooms_for_zone` 对未实现区域返回空数组；后续再扩展 RoomType |
| **建设完成研究员统计错误** | 建设完成应减 researchers_in_construction、增 researchers_working_in_rooms，但后者系统未实现 | 建设完成时：`researchers_in_construction -= N`，`researchers_working_in_rooms += N`；即使「房间工作」逻辑未做，先保证人数守恒、TopBar 正确 |
| **存档时建设中房间丢失** | 仅保存 zone_type，未保存 elapsed/total，读档后进度归零 | 在 room dict 中增加 `zone_building_elapsed`、`zone_building_total`；读档时若存在则恢复进 `_construction_rooms_in_progress` |
| **读档后进度环不显示** | `_apply_map` 未恢复 `_construction_rooms_in_progress` | 在 `_apply_map` 或单独 `_apply_construction_progress` 中，遍历 rooms，若 `zone_building_elapsed` 存在且 < total，写入 `_construction_rooms_in_progress` |
| **区域按钮悬停「材料不足」难实现** | Tooltip 需动态资源数据，Overlay 无 UIMain 引用 | 方案 A：Overlay 发射 `zone_button_hovered(zone_type)`，game_main 用 `_get_player_resources` 回调传入资源并显示 Tooltip；方案 B：悬停时仅显示静态消耗，不足时用按钮置灰或红框提示 |
| **CalamityBar 与 BtnBuild 同区域** | 建设时需隐藏灾厄、显示建设 UI，两者可能布局重叠 | 明确布局：灾厄在底部正中，建设 tag/按钮在其上方或替代位置；`set_construction_blocking(true)` 时 `CalamityBar.visible = false`，确保不重叠 |
| **退出建设时房间在建设中** | 确认后退出，`_construction_rooms_in_progress` 非空，进度环需持续显示 | `hide_construction_selecting_ui` 只隐藏 tag/zone 按钮/dim，**不**隐藏 ProgressRingsContainer；与清理一致，`_process` 每帧调用 `update_progress_rooms` |
| **权限消耗未从 UIMain 扣除** | `_consume_construction_cost` 只处理 info，遗漏 permission | 参考 `_consume_cleanup_cost`，对 cost dict 中每个 key（info、permission 等）调用对应 UIMain 属性并扣减 |
| **RoomInfo 与 ZoneType 循环依赖** | room_info 引用 zone_type，zone_type 引用 RoomType | 将映射放在 `zone_type.gd`，room_info 通过 `ZoneType.get_rooms_for_zone()` 调用，避免 room_info 依赖 zone_type 的完整定义 |
| **空房间误选造物区** | EMPTY_ROOM 未先改造，但被允许建设 | `get_rooms_for_zone(造物区)` 仅返回 [SERVER_ROOM, REASONING]，不包含 EMPTY_ROOM；`can_build_zone` 严格按此表 |
| **默认分类与首次进入** | 进入 SELECTING_ZONE 时未选中 tag，区域按钮为空 | 进入时默认选中「工作类」：`_construction_selected_category = 工作类`，ZoneButtons 显示对应区域 |
| **镜头移动时确认按钮错位** | CONFIRMING 时镜头被中键拖拽，确认按钮未跟随 | 与清理一致：`_process` 中若 CONFIRMING，每帧调用 `overlay.update_confirm_position(_room_center_to_screen(rid))` |
| **退出后进度环不更新** | 确认后 mode=NONE，若 `_process` 仅在选择模式下更新 construction 进度，则进度环静止 | 进度推进与 `update_progress_rooms` 应与 mode 无关：只要 `_construction_rooms_in_progress` 非空就每帧更新，与清理一致 |

---

## 9. 相关文档

- [00 - 项目概览](../00-project-overview.md)
- [01 - 游戏数值系统](../0-values/01-game-values.md)（建设消耗、耗时、研究区/造物区产出）
- [04 - 房间清理系统](04-room-cleanup-system.md)（清理前置、研究员占用模式、经验小结）
- [02 - 时间流逝系统](02-time-system.md)
- [03 - 存档系统](03-save-system.md)
- [关键词对照](../../settings/00-project-keywords.md)（区域类型、房间类型）
- [06 - 已建设房间系统](06-built-room-system.md)：已建设房间的持续运作、产出节奏、存量耗尽、停工等详细逻辑

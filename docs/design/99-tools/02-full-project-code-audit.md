# 全项目架构审查报告

> 审查日期：2026-03-19
> 覆盖范围：85 个 GDScript 文件、94 个场景、12+ JSON 数据文件、11 个 Schema、40+ 设计文档
> 审查模块：Core (10) / Editor (9) / Game (14) / UI-TopBar (12) / UI-Panels+Overlays (28) / 3D-Rooms+Actors (9) / Data+Docs

---

## 一、全局问题统计

| 严重度 | 数量 | 分布 |
|--------|------|------|
| **Critical** | 7 | Core ×2, Game ×2, UI-TopBar ×1, UI-Panels ×3 |
| **Warning** | 25 | Core ×7, Editor ×5, Game ×6, UI-TopBar ×7, UI-Panels ×8, 3D ×8, Data ×2 |
| **Info** | 30+ | 各模块均有 |

---

## 二、Critical 问题汇总（必须立即修复）

### C1. Autoload 初始化顺序错误 — GameTime 在 GameValues 之前
- **模块**：Core
- **文件**：`project.godot`, `scripts/core/game_time.gd:82-85`
- **影响**：GameTime._ready() 尝试读取 GameValues 配置但此时 GameValues 尚未注册。导致 `REAL_SECONDS_PER_GAME_HOUR` 始终使用硬编码默认值 3.0 而非 JSON 配置的 1.0。**游戏运行速度是设计值的 1/3**。config_reloaded 信号也从未连接。
- **修复**：在 project.godot 中将 GameValues 移到 GameTime 之前：`LocaleManager → GameValues → GameTime → ErosionCore → PersonnelErosionCore → SaveManager → DataProviders`

### C2. `_shelter_helper` 未在 game_main.gd 中声明
- **模块**：Game
- **文件**：`scripts/game/game_main_shelter.gd:20-24`, `scripts/game/game_main.gd`
- **影响**：`game_main.set("_shelter_helper", helper)` 对未声明属性静默无效。每帧都创建新的 ShelterHelper 实例，`_room_shelter_energy` 永远为空。**庇护能量分配对游戏实际无效**——计算因子被扣除但房间庇护等级从未提升。
- **修复**：在 game_main.gd 变量区添加 `var _shelter_helper: RefCounted = null`

### C3. 清理模式未检查建设模式互斥
- **模块**：Game
- **文件**：`scripts/game/game_main_cleanup.gd:15-25`
- **影响**：cleanup 未检查 construction_mode，可能同时进入两种模式，导致时间流恢复逻辑冲突。
- **修复**：在 `on_button_pressed` 开头加 `if game_main.get("_construction_mode") != 0: return`

### C4. DataProviders._calculate_factor_status 死分支
- **模块**：Core
- **文件**：`scripts/core/data_providers.gd:199-204`
- **影响**：`"lacking"` 状态永远不会被返回（被 `"dried_up"` 条件完全覆盖）。
- **修复**：重新审视条件逻辑，推测应为 `dried_up: current <= 0 and daily_net < 0`，`lacking: current <= 0 and daily_net == 0`

### C5. detail_shelter_progress_bar 残留调试日志写文件
- **模块**：UI-Panels
- **文件**：`scripts/ui/detail_shelter_progress_bar.gd:57-81, 91-167`
- **影响**：6 处 `FileAccess.open("res://debug-ada89e.log")` 在每次属性变化时写磁盘，编辑器中也执行。
- **修复**：删除所有 `# region agent log` 块和 `debug-ada89e.log` 文件

### C6. ui_main 每帧重建详情面板所有条目
- **模块**：UI-Panels
- **文件**：`scripts/ui/ui_main.gd:199-213`
- **影响**：`_refresh_visible_detail_panel` 在面板可见时每帧调 `show_panel(data)`，触发清空+重建全部动态条目的大量节点操作。
- **修复**：改为脏标记模式——DataProviders 信号触发时标记脏，_process 仅在脏时刷新一次

### C7. room_detail_panel 每帧 queue_free 所有子节点
- **模块**：UI-Panels
- **文件**：`scripts/ui/room_detail_panel.gd:30-33, 59`
- **影响**：每帧销毁重建区域操作节点。
- **修复**：引入脏标记或数据对比，仅在数据变化时重建

---

## 三、跨模块架构问题

### 架构问题 1：RoomInfo 跨模块逆向依赖

`RoomInfo` 类定义在 `scripts/editor/room_info.gd`，但被 **20+ 个文件**跨模块引用：

```
scripts/editor/ → RoomInfo（本地）
scripts/game/ → RoomInfo（12+ 文件反向依赖 editor 模块）
scripts/core/ → RoomInfo（SaveManager, DataProviders, ZoneType）
```

`RoomInfoLoader` 甚至需要 `preload("res://scripts/editor/room_info.gd")` 来访问枚举。

**建议**：将 `room_info.gd` 迁移到 `scripts/core/`。它是核心数据结构，不应归属 editor 模块。

### 架构问题 2：Helper 通过字符串反射访问主类私有状态

**Editor 模块**和 **Game 模块**的 Helper 均通过 `editor.get("_tiles")` / `game_main.get("_rooms")` / `game_main.call("_find_room_node_in_archives")` 方式访问主类私有字段。

- **影响**：无类型安全、无 IDE 补全、字段重命名后静默中断
- **覆盖范围**：Editor 5 个 Helper + Game 9 个 Helper = ~14 个文件
- **建议**：
  - Editor：将 Helper 参数类型从 `Node` 改为 `MapEditor`
  - Game：在 GameMain 上暴露 public getter 方法，Helper 调用公开 API

### 架构问题 3：模式枚举硬编码复制

`CleanupMode` 和 `ConstructionMode` 在 `game_main.gd` 中定义为 `enum`，但 4 个 Helper 文件各自以 `const CLEANUP_SELECTING := 1` 方式手动复制。枚举顺序变化时不会自动更新。

**建议**：提取枚举到独立文件 `game_mode_enums.gd`，所有 Helper 引用同一来源。

### 架构问题 4：资源扣除/增加逻辑大量重复

`match resource_key → ui.xxx_amount` 模式在以下位置完全重复：
- `game_main_cleanup.gd` consume_cleanup_cost
- `game_main_construction.gd` consume_construction_cost
- `game_main.gd` _grant_room_resources_to_player
- `game_main_built_room.gd` _add_factor_to_player
- `game_main_factor_breakdown.gd` _resource_key_to_type
- `game_main_shelter.gd` _resource_key_to_type

**建议**：提取到 `RoomInfo` 或新建 `resource_helper.gd`。

### 架构问题 5：因子详情面板 ~400 行克隆代码

cognition / computation / willpower / permission / shelter 五个面板中，`_force_layout_refresh`、`_update_title_state`、`_update_storage_progress` 系列、`_update_warning_text`、`_update_total_burn`、`_update_surplus_shortage` 等方法完全相同。

**建议**：创建 `FactorDetailPanelBase extends DetailPanelBase` 中间类，各面板只需声明 `FACTOR_KEY` 和差异化配置。

### 架构问题 6：23 个房间缺少 v2 翻译键

3D 游戏中使用 `room_00` 格式的 ID，但 translations.csv 中大量缺失 `room_XX_NAME/DESC/PRE_CLEAN` 键（69 个翻译键缺失）。切换到英文 locale 时这些房间名/描述/清理文案均无翻译。

---

## 四、分模块 Warning 级问题精选

### Core
| 问题 | 文件 | 建议 |
|------|------|------|
| PersonnelErosionCore 硬编码 24.0 hours/day | personnel_erosion_core.gd:217,408 | 使用 GameTime.GAME_HOURS_PER_DAY |
| get_forecast_at_hours 参数名误导 | erosion_core.gd:142 | 重命名为 game_hour |
| SaveManager._load_game_base 重复读取无缓存 | save_manager.gd:242 | 加 _game_base_cache |
| _room_size_data 未校验 | game_values.gd:150-180 | 添加校验 |
| GameValuesRef 间接层与直接 GameValues 混用 | 全模块 | 统一一种方式 |

### Editor
| 问题 | 文件 | 建议 |
|------|------|------|
| TILE_COLORS 重复定义 | map_editor.gd:11 + map_editor_draw.gd:7 | 统一为一处 |
| CleanStatus 选项硬编码为 2 | map_editor_room_ui.gd:54 | 改为 CleanStatus.size() |
| ResourceType 选项硬编码为 7 | map_editor_room_ui.gd:369 | 改为 ResourceType.size() |
| apply_floor_move 后不重建 room_ids | map_editor_grid.gd:136-170 | 移动后调 _rebuild_room_ids |
| load() 失败不缓存每帧重试 | map_editor_draw.gd:85 | 缓存 null 值 |

### Game
| 问题 | 文件 | 建议 |
|------|------|------|
| _wanderable_room_ids 计算后未使用 | researcher_lifecycle.gd:74 | 传给研究员或移除 |
| queue_free 未先 remove_child | game_main.gd:255 | 符合项目规范先 remove_child |
| 因子分解硬编码认知消耗率 | game_main_factor_breakdown.gd:87 | 引用 PersonnelErosionCore 常量 |
| handle_left_click 参数 rid 实为 index | cleanup/construction | 重命名为 room_index |
| 可闲逛房间列表重复构建 | game_main.gd + researcher_lifecycle.gd | 统一为一个方法 |

### UI-TopBar
| 问题 | 文件 | 建议 |
|------|------|------|
| resource_progress_bar @tool 在 _ready 缓存节点 | resource_progress_bar.gd:103 | 移到 _enter_tree |
| corrosion_number @tool 在 _ready 缓存节点 | corrosion_number.gd:24 | 同上 |
| forecast_warning @tool 在 _ready 缓存节点 | forecast_warning.gd:42 | 同上 |
| topbar_figma 与 test_figma_page 仍有 ~30 行重复 | 两个文件 | 提取到 TopbarDataHelper |
| time_panel 与 time_control_bar 功能重叠 | 两个文件 | 确认是否废弃 time_panel |

### UI-Panels
| 问题 | 文件 | 建议 |
|------|------|------|
| 4 个因子面板 show_panel 忽略传入 data | factor_details_panel_*.gd | 统一数据流 |
| detail_entries_pool spacer 泄漏 | detail_entries_pool.gd:42 | release 时处理非 Label 子节点 |
| information/investigator/truth clear_container 销毁预制节点 | 3 个文件 | 使用专用动态容器 |
| ui_main 属性 setter 触发多次 _refresh_all | ui_main.gd:428 | 用 call_deferred 去重 |
| start_menu 和 pause_menu 槽位代码高度重复 | 两个文件 | 提取 SlotSelectPanel 组件 |

### 3D 组件
| 问题 | 文件 | 建议 |
|------|------|------|
| room_name_sign edited_root_scene 拼写错误 | room_name_sign.gd:25 | 改为 edited_scene_root |
| 3 个文件 get_parent() 无空检查 | highlight/outblock/grid | 添加 parent null 检查 |
| researcher_3d 调用 game_main 私有方法 | researcher_3d.gd:74,272,555 | 公开 API 或去掉 _ 前缀 |
| 倍速变更 Timer 调整公式错误 | researcher_3d.gd:154-159 | 需记录 old_speed |
| 房间边界计算重复 3 次 ~60 行 | researcher_3d.gd | 抽取为 calc_room_bounds |
| 网格绘制代码 actor_box/reference_grid 重复 ~80 行 | 两个文件 | 提取 GridDrawHelper |

### Data & Docs
| 问题 | 文件 | 建议 |
|------|------|------|
| actor_table.json 缺少 Schema | datas/ | 创建 actor_table.schema.json |
| 时间系统文档过期 (3s→1s, 30d→28d) | docs/design/2-gameplay/02-time-system.md | 更新文档 |
| game_main_shelter MAX_HOURS_PER_FRAME 未接入配置 | game_main_shelter.gd:152 | 使用 GameValues getter |
| GameValues getter fallback 默认值与 JSON 不一致 | game_values.gd:511,523 | 更新默认值 |

---

## 五、全局重复代码热点

| 重复模式 | 涉及文件数 | 估计重复行数 | 优先级 |
|----------|------------|-------------|--------|
| 因子面板方法克隆 | 5 | ~400 行 | P1 |
| 行构建辅助方法 (info/investigator/truth/housing) | 4 | ~300 行 | P1 |
| 资源扣除/增加 match 逻辑 | 6 | ~200 行 | P1 |
| 模式枚举常量复制 | 4 | ~40 行 | P2 |
| 房间边界计算 | 1(内部×3) | ~60 行 | P2 |
| 网格绘制方法 | 2 | ~80 行 | P3 |
| 弹窗定位逻辑 | 1(内部×2) | ~30 行 | P3 |
| TILE_COLORS / PATH 常量 | 2-4 | ~20 行 | P3 |
| 可闲逛房间列表 | 2 | ~30 行 | P3 |
| 槽位面板代码 (start_menu/pause_menu) | 2 | ~100 行 | P3 |

---

## 六、Autoload 依赖关系（修正后建议）

```
当前顺序（有 bug）：
  LocaleManager → GameTime → ErosionCore → GameValues → PersonnelErosionCore → SaveManager → DataProviders

建议顺序：
  LocaleManager → GameValues → GameTime → ErosionCore → PersonnelErosionCore → SaveManager → DataProviders
```

修正后的依赖图：

```
LocaleManager (无依赖)
    ↓
GameValues (无依赖，纯 JSON 加载)
    ↓
GameTime ──→ GameValues (读取时间配置)
    ↓
ErosionCore ──→ GameTime (时间信号) + GameValues (侵蚀配置)
    ↓
PersonnelErosionCore ──→ GameTime + ErosionCore + GameValues
    ↓
SaveManager ──→ RoomInfoLoader + RoomLayoutHelper (外部工具类)
    ↓
DataProviders ──→ GameValues + ZoneType + 运行时场景查找
```

---

## 七、@tool / ui-no-ready 合规汇总

| 文件 | 违反 | 当前位置 | 应在 |
|------|------|----------|------|
| resource_progress_bar.gd | 节点缓存在 _ready | _ready:103-116 | _enter_tree |
| corrosion_number.gd | 节点+贴图缓存在 _ready | _ready:24-37 | _enter_tree |
| forecast_warning.gd | 节点缓存在 _ready | _ready:42-54 | _enter_tree |
| detail_storage_progress_bar.gd | 节点缓存在 _ready | _ready:32-38 | _enter_tree |
| detail_shelter_progress_bar.gd | 节点缓存在 _ready | _ready (含调试日志) | _enter_tree |
| room_name_sign.gd | _ready 无守卫 + 无 _process 轮询 | _ready:8 | 添加 _process 轮询 |

---

## 八、时间流暂停合规汇总

所有时间驱动的产出、消耗、研究员生命周期均正确使用 `GameTime.is_flowing` 守卫。清理/建设模式的 `SimulationRoot.process_mode = DISABLED` + `is_flowing = false` 双重保障有效。

**唯一遗漏**：`game_main.gd:833` 的 debug ray marker _process 无 is_flowing 检查，但这是纯视觉调试功能，不影响游戏状态，可接受。

---

## 九、优先修复路线图

### Phase 0：紧急修复（影响游戏正确性）

1. 修正 Autoload 顺序（C1）— 游戏速度错误
2. 声明 `_shelter_helper` 变量（C2）— 庇护系统无效
3. 清理模式互斥检查（C3）— 状态冲突风险
4. 删除调试日志写文件（C5）— 性能/安全隐患
5. 修正 _calculate_factor_status 死分支（C4）

### Phase 1：性能修复

6. ui_main 详情面板改为脏标记刷新（C6）
7. room_detail_panel 条件重建（C7）
8. ui_main 属性 setter 去重刷新（call_deferred）
9. resource_progress_bar / corrosion_number / forecast_warning 节点缓存移至 _enter_tree

### Phase 2：代码质量重构

10. RoomInfo 迁移到 scripts/core/（架构问题 1）
11. 提取 FactorDetailPanelBase 中间类（架构问题 5，~400 行去重）
12. 提取资源操作工具方法（架构问题 4，~200 行去重）
13. 提取行构建工具方法到 DetailPanelBase（~300 行去重）
14. 模式枚举提取到独立文件（架构问题 3）
15. Helper 参数类型化（架构问题 2）

### Phase 3：数据与文档同步

16. 补全 23 个房间的 v2 翻译键（69 个键）
17. 更新时间系统文档（3s→1s, 30d→28d）
18. 创建 actor_table.schema.json
19. 更新 Schema 默认值
20. game_main_shelter MAX_HOURS_PER_FRAME 接入配置

### Phase 4：长期架构改善

21. 评估废弃 GameValuesRef
22. 统一面板数据流模式
23. 提取 SlotSelectPanel 共享组件
24. 提取 GridDrawHelper 网格绘制工具
25. 房间尺寸一致性断言验证
26. 统一 GRID_CELL_SIZE 等项目级常量

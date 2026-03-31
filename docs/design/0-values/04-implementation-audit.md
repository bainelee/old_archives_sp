# 04 - 数据驱动实现审计与问题预测

## 1. 已实现内容总览

| 阶段 | 模块 | 状态 | 接入点 |
|------|------|------|--------|
| **Phase 1** | 时间 | ✅ | `game_time.gd` 从 `time_system.json` 读取 |
| | 清理 | ✅ | `room_info.gd` 从 `cleanup_system.json` 读取 |
| | 建设 | ✅ | `zone_type.gd`、`game_main_built_room.gd` 从 `construction_system.json` 读取 |
| | 研究员 | ✅ | `personnel_erosion_core.gd`、`game_main_shelter.gd` 从 `researcher_system.json` 读取 |
| | 研究员信息日结 `info_daily` | ✅ | `game_values.gd` getter；`personnel_erosion_core.gd` 日结入账；`game_main.gd` `register_info_grant`；`DataProviders` 信息详情展示 |
| | 侵蚀 | ✅ | `personnel_erosion_core.gd` 从 `erosion_system.json` 读取 |
| | 庇护 | ✅ | `game_main_shelter.gd` 从 `shelter_system.json` 读取 |
| **Phase 2.5** | recruitment | ✅ getter | `game_values.gd` 提供只读接口 |
| | housing_linkage | ✅ getter | `game_values.gd` 提供只读接口 |
| | zone_extensions | ✅ getter | `game_values.gd` 提供只读接口 |
| **Phase 2.6** | zone_extensions.enabled | ✅ | `construction_overlay.gd` 按配置过滤 5–8 区按钮 |
| | housing_linkage | ✅ | `personnel_erosion_core.gd` 侵蚀倍率、治愈跳过 |
| | recruitment.enabled | ❌ 待接入 | 招募 UI 未实现 |

---

## 2. 当前架构判断

### 2.1 配置读取模式

- **按需读取**：`zone_type.gd`、`construction_hover_panel.gd`、`room_detail_panel.gd` 等每次调用时通过 GameValues getter 取数，热重载后能即时生效。
- **启动缓存**：`game_time.gd`、`personnel_erosion_core.gd`、`construction_overlay.gd` 等在 `_ready()` 中一次性读取并缓存，运行中不再刷新。

### 2.2 校验覆盖

- `game_values.gd` 对 `researcher_system` 校验：`version`、`cognition`、`housing`、`info_daily`、`housing_linkage`、`recruitment`。
- `construction_system` 校验：`version`、`construction`、`production`。
- `zone_extensions` 未纳入必填校验。

---

## 3. 潜在问题与影响

### 问题 A：热重载与缓存不一致（已解决）

**原表现**：PersonnelErosionCore、GameTime、construction_overlay 等在 `_ready()` 中缓存配置，热重载后仍用旧值。

**解决**：GameValues 发出 `config_reloaded` 信号，上述模块已连接并刷新缓存。

---

### 问题 B：Phase 2 契约字段未校验（已解决）

**原表现**：`housing_linkage`、`recruitment`、`zone_extensions` 缺失时无 warning。

**解决**：`_validate_loaded_configs()` 已增加上述字段的必填与类型校验。

---

### 问题 C：`no_housing_skip_cure` 触发条件（已确认为符合预期）

- **条件**：`has_no_housing` = 有工作分配且无住房分配；需住房槽 \< 工作槽时才会出现。
- **设计判断**：住房短缺是游戏中可能出现的常见情况，逻辑通顺，符合预期。

---

### 问题 D：construction_overlay 不随重载更新（已解决）

**表现**：建设区域 UI 在 `_ready()` 中调用 `_build_category_zones()` 一次，之后不随 GameValues 重载或场景变化而更新。

**影响**：~~在游戏内修改 `zone_extensions.enabled` 后，建设 UI 不会反映最新配置~~  
**解决**：`show_construction_selecting_ui()` 时重新调用 `_build_category_zones()`；并连接 `config_reloaded` 热重载时刷新。

---

### 问题 E：Autoload 依赖顺序（已文档化）

**表现**：PersonnelErosionCore 的 `_apply_config()` 依赖 GameValues；若 GameValues 尚未完成 `_load()`，可能读到空数据。

**现状**：project.godot 中 GameValues 先于 PersonnelErosionCore 加载；已记录于 `02-game-values-runtime.md` §1.3。

---

## 4. 建议方案

### 方案 A1：热重载时通知缓存模块刷新（已实现）

**做法**：GameValues 已增加 `config_reloaded` 信号；PersonnelErosionCore、GameTime、ConstructionOverlay 已连接，重载时各自调用 `_apply_config()` 或 `_on_config_reloaded()`。

```gdscript
# game_values.gd
signal config_reloaded()
func reload() -> bool:
    # ... existing logic ...
    config_reloaded.emit()
    return true

# personnel_erosion_core.gd
func _ready():
    _apply_config()
    var gv = _GameValuesRef.get_singleton()
    if gv and gv.has_signal("config_reloaded"):
        gv.config_reloaded.connect(_apply_config)
```

**优点**：热重载后所有模块保持一致，无需重启。  
**成本**：需为 GameTime、construction_overlay 增加同类连接和刷新逻辑。

---

### 方案 A2：文档说明热重载范围

**现状**：已实现 A1，缓存型模块亦会随热重载刷新；`02-game-values-runtime.md` §3.3 已说明 `config_reloaded` 与连接方。

---

### 方案 B：扩展 Phase 2 校验（已实现）

**做法**：已在 `_validate_loaded_configs()` 中增加 `housing_linkage`、`recruitment`、`zone_extensions` 必填及类型校验。

---

### 方案 C：澄清 `no_housing_skip_cure` 的 design（已确认为符合预期）

**结论**：住房短缺为设计内常见情况，逻辑通顺，符合预期。

---

### 方案 D：construction_overlay 按需刷新（已实现）

**做法**：已在 `show_construction_selecting_ui()` 中调用 `_build_category_zones()` 并刷新区域按钮。

---

### 方案 E：文档记录 Autoload 顺序（已实现）

**做法**：已在 `02-game-values-runtime.md` §1.3 中写明依赖顺序。

---

## 5. 实施状态

| 方案 | 状态 |
|------|------|
| A1（热重载信号 config_reloaded） | ✅ 已实现 |
| A2（文档说明热重载） | ✅ 已实现 |
| B（扩展 Phase 2 校验） | ✅ 已实现 |
| C（no_housing_skip_cure 澄清） | ✅ 已确认为符合预期 |
| D（construction_overlay 按需刷新） | ✅ 已实现 |
| E（记录 Autoload 顺序） | ✅ 已实现 |

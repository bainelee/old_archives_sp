# 09 - 因子/庇护/UI Debug 技术问题总结

本文档记录一次漫长的 Debug 会话中遇到的所有技术问题、根因与解决方案，供后续开发参考。涉及模块：因子细则显示、庇护消耗、UI 刷新、数值同步。

---

## 1. 因子细则中库存显示异常（权限显示为 1）

### 现象

TopBar 因子悬停面板中，权限因子库存显示为 **1**，实际应为 6000。

### 根因

**Godot `Node.get("property_name")` 对带 setter/getter 的自定义属性解析异常**。

- `ui_main.gd` 中 `permission_amount`、`cognition_amount`、`willpower_amount`、`computation_amount` 均为自定义属性（带 get/set）
- 外部通过 `ui.get("permission_amount")` 读取时，可能返回错误值（如 1），而非真实库存
- 可能与 Godot 对 property getter 的反射行为有关，或与属性名/类型解析有关

### 解决方案

1. **显式后备变量**：在 `ui_main.gd` 中为认知、意志、权限增加私有后备变量（如 `_cognition_amount`、`_will_amount`、`_permission_amount`），getter 返回后备变量，setter 写入后备变量并刷新 Label
2. **显式 getter 方法**：提供 `get_cognition()`、`get_willpower()`、`get_permission()`、`get_computation()`，直接返回后备变量
3. **统一调用约定**：所有需要读取因子库存的代码（`game_main_factor_breakdown.gd`、`game_main_shelter.gd`、`game_main_built_room.gd` 等）优先使用 `ui.get_cognition()` 等形式，避免 `ui.get("xxx_amount")`

### 代码规范

```gdscript
# 错误：可能返回异常值
var amt: int = int(ui.get("permission_amount") or 0)

# 正确：使用显式 getter
var amt: int = ui.get_permission() if ui.has_method("get_permission") else int(ui.get("permission_amount") or 0)
```

---

## 2. 计算因子细则显示不准确（统一显示「档案馆核心」）

### 现象

建设档案馆正厅后，细则应显示**各房间**的真实庇护消耗（如「研究区-档案馆正厅 X/天」），却统一显示为「档案馆核心」消耗。

### 根因

细则逻辑原先按「核心总消耗」汇总，未与庇护分配器的**实际按房分配结果**对齐。庇护分配是逐房间、按需进行的，细则应反映各房间获得的能量 × 24 = 该房导致的 CF 日消耗。

### 解决方案

1. **优先使用上次 tick 结果**：`game_main_shelter.gd` 的 `get_shelter_consumption_breakdown()` 优先读取 `_shelter_helper._room_shelter_energy`（上次 `process_shelter_tick` 的实际分配）
2. **无结果时模拟**：若 `_room_shelter_energy` 为空，则按与 `_compute_and_apply` 相同的逻辑模拟（侵蚀、目标每房能量、`energy_per_room_max` 等）
3. **细则按房间拆分**：每条细则包含 `zone_name`、`room_name`、`per_day`，分别对应各需要庇护的房间及其导致的 CF 消耗

### 数据流

```
process_shelter_tick → _room_shelter_energy 写入
       ↓
get_shelter_consumption_breakdown() 读取 _room_shelter_energy
       ↓
factor_hover_panel 展示细则
```

---

## 3. 单房庇护消耗数值不符（144/天 vs 设计 48～120）

### 现象

细则中单房消耗显示 144/天，按设计应在 48～120 范围内（取决于侵蚀）。

### 根因

- 1 级核心：30 CF/h = 720 CF/d，能量上限 30
- 若按「每房 6 能量」分配，则 6×24=144 CF/d，超出设计「每房最多 5 能量」
- 设计文档要求 `energy_per_room_max: 5`，即单房庇护能量最多 5，对应最多 5×24=120 CF/d

### 解决方案

1. **`game_values.json`**：新增 `energy_per_room_max: 5`，在分配逻辑中限制单房最大能量
2. **分配逻辑**：`target_per_room = min(max(0, 2 - raw_erosion), energy_per_room_max)`，确保不超过 5
3. **1 级核心**：移除错误的 `cf_per_day`，统一为 30/h、720/d、能量上限 30

---

## 4. PersonnelErosionCore 与 UI 认知读写

### 现象

`PersonnelErosionCore` 需要读写玩家认知因子以进行研究员认知消耗。若通过 `ui.cognition_amount` 或 `ui.get("cognition_amount")` 读写，可能遇到与问题 1 类似的解析异常。

### 解决方案

- **写**：使用 `ui.cognition_amount = value`（setter 正常）
- **读**：通过 `_cognition_getter` 回调，由 GameMain 注入 `func() -> int: return ui.get_cognition()`
- 认知提供器通过 `ui.get_cognition()` 与 `ui.cognition_amount =` 读写，避免 `Node.get()`

---

## 5. 因子细则逻辑耦合在 GameMain

### 现象

细则计算逻辑散落在 `game_main.gd`，职责过重，难以维护。

### 解决方案

- **新建** `scripts/game/game_main_factor_breakdown.gd`：集中处理因子细则计算
- `GameMainFactorBreakdownHelper.get_breakdown()` 负责聚合 consume/produce、stock、cap
- `game_main.get_factor_breakdown()` 委托给该 helper，GameMain 仅做桥接

---

## 6. 因子字符串解析异常（"60000/60000"）

### 现象

从存档或外部数据加载时，因子值可能为 `"60000/60000"` 等字符串（UI 显示格式），直接 `int()` 解析会失败。

### 解决方案

- **`ui_main._safe_factor_int()`**：安全转换，若为字符串且含 `/`，则取斜杠前的部分再 `int()`
- `set_resources()` 加载时统一经过 `_safe_factor_int()`，避免浮点/类型错误

---

## 7. 数值与文档/脚本不一致

### 现象

意志/权限初始值、储藏上限等在 `game_base.json`、`game_values.json`、`save_manager.gd`、设计文档之间不一致。

### 解决方案

- **数据源**：`game_base.json`（初始）、`game_values.json`（上限与速率）
- **兜底**：`save_manager.gd` 中缺省补齐用与 `game_base.json` 相同的值
- **文档**：`01-game-values.md`、`datas/README.md` 与 JSON 保持同步
- **规则**：涉及「调整数值」时，按 `.cursor/subagents/game-values-sync.md` 全量同步

---

## 8. Debug 输出残留

### 现象

开发过程中遗留 `[CF消耗]`、`[Cleanup]` 等 `print` 语句，影响日志可读性。

### 解决方案

- 移除 `game_main_shelter.gd`、`game_main.gd`、`game_main_construction.gd`、`game_main_cleanup.gd`、`game_main_input.gd` 中的 debug `print`
- 若需调试，使用 `push_warning()` 或条件编译

---

## 9. 细则与 tick 数据不同步

### 现象

细则展示的消耗/产出与实际 tick 结算不一致，导致玩家困惑。

### 解决方案

- **庇护细则**：优先使用 `_shelter_helper._room_shelter_energy`，与上次 tick 一致
- **造物区细则**：排除 `is_creation_zone_paused` 的房间，与 `process_production` 逻辑一致
- **研究区细则**：仅统计 `_research_room_has_reserve` 的房间，与产出逻辑一致

---

## 涉及文件速查

| 模块 | 文件 |
|------|------|
| 因子 UI | `scripts/ui/ui_main.gd` |
| 因子细则 | `scripts/game/game_main_factor_breakdown.gd` |
| 庇护 | `scripts/game/game_main_shelter.gd` |
| 产出 | `scripts/game/game_main_built_room.gd` |
| 数值 | `datas/game_values.json`、`datas/game_base.json` |
| 存档 | `scripts/core/save_manager.gd` |
| 侵蚀 | `scripts/core/personnel_erosion_core.gd` |

---

## 相关文档

- [01 - 游戏数值系统](../0-values/01-game-values.md)
- [06 - 已建设房间系统](06-built-room-system.md)
- [07 - 研究员侵蚀](07-researcher-erosion.md)

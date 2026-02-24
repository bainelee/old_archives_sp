# 07 - 存档系统

## 概述

本文档描述《旧日档案馆》项目中**存档系统**的系统设计，包括当前实现、目标架构、数据模型、保存/加载流程，以及与场景编辑器地图槽位的关系。

---

## 1. 当前实现与现状

### 1.1 已有能力

| 组件 | 存储内容 | 路径 | 说明 |
|------|----------|------|------|
| 场景编辑器 | 底板 + 房间 | `user://maps/slot_0.json` ~ `slot_4.json` | 5 个地图槽位，仅地图数据 |
| 游戏主场景 | 同上（读取） | 固定加载 slot_0 | 无完整游戏状态 |
| room_info.json | 房间模板库 | `datas/room_info.json` | 共享模板，非存档 |

### 1.2 未持久化的游戏状态

| 状态源 | 数据 | 说明 |
|--------|------|------|
| GameTime | `_total_game_hours`, `is_flowing`, `speed_multiplier` | 游戏时间与倍速 |
| ErosionCore | `raw_mystery_erosion`, `shelter_bonus`，未来 3 个月侵蚀预测 | 侵蚀等级（部分由时间推导）；预测由 `get_forecast_segments` 生成 |
| UIMain / 游戏逻辑 | 四种因子、信息/真相、研究员/劳动力（暂未使用）/被侵蚀/调查员 | 当前为 UI mock，无数据源 |

### 1.3 设计目标

1. **完整存档**：地图 + 时间 + 资源 + 人员 + 侵蚀/庇护状态
2. **复用槽位**：与现有 `user://maps/slot_N.json` 概念兼容或可迁移
3. **向后兼容**：支持从纯地图 JSON 升级为完整存档
4. **版本管理**：通过 `version` 字段支持未来迁移

---

## 2. 系统架构

### 2.1 分层示意

```
┌─────────────────────────────────────────────────────────────────────┐
│  游戏层（GameMain / UI）                                              │
│  - 触发保存/加载                                                      │
│  - 展示存档列表、槽位信息                                              │
└────────────────────────────┬────────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────────┐
│  SaveManager（Autoload 或静态工具类）                                  │
│  - save_to_slot(slot, game_state)                                     │
│  - load_from_slot(slot) -> GameState                                  │
│  - get_slot_metadata(slot) -> { name, time, version }                  │
│  - validate_save(data) -> bool                                        │
└────────────────────────────┬────────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────────┐
│  GameState（可序列化数据结构）                                         │
│  - map: { grid, tiles, rooms, map_name }                              │
│  - time: { total_hours, is_flowing, speed }                          │
│  - resources: { 四种因子, 货币, 人员 }                                 │
│  - erosion: { raw_mystery, shelter_bonus, forecast }                  │
│  - version: int                                                       │
└────────────────────────────┬────────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────────┐
│  存储层（FileAccess + JSON）                                           │
│  - user://saves/slot_N.json（游戏存档，与 maps 完全分离）                │
│  - user://maps/slot_0.json（地图编辑器起始地图，新游戏读取）              │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 与场景编辑器的关系

- **场景编辑器**：保存地图到 `user://maps/`，为项目级地图资源，与游戏存档无直接关系。
- **游戏存档**：仅读写 `user://saves/`，存储完整游戏状态；`map` 部分与场景编辑器格式兼容。
- **新游戏初始化**：使用地图编辑器编号第一张（`user://maps/slot_0.json`）作为起始场景，叠加 game_base 默认值后写入选定存档槽位。
- **明确分离**：游戏存档与地图编辑器存档完全独立；地图是引擎/项目信息，存档是玩家进度。

---

## 3. 数据模型

### 3.1 存档 JSON 根结构

```json
{
  "version": 1,
  "map_name": "档案馆正厅",
  "saved_at_game_hour": 72,
  "map": {
    "grid_width": 80,
    "grid_height": 60,
    "cell_size": 20,
    "tiles": [ [0,0,1,...], ... ],
    "rooms": [ {...}, ... ],
    "next_room_id": 10
  },
  "time": {
    "total_game_hours": 72,
    "is_flowing": true,
    "speed_multiplier": 2.0
  },
  "resources": {
    "factors": { "cognition": 100, "computation": 200, "willpower": 50, "permission": 80 },
    "currency": { "info": 500, "truth": 10 },
    "personnel": { "researcher": 5, "labor": 2, "eroded": 0, "investigator": 1 }
  },
  "erosion": {
    "raw_mystery_erosion": 0,
    "shelter_bonus": 0,
    "forecast": [ {"value": 0}, {"value": -2}, {"value": -2}, ... ]
  }
}
```

### 3.2 必存数据清单

存档必须保存以下游戏状态。字段中英对照见 [00-project-keywords](../settings/00-project-keywords.md)。

| 类别 | 字段 | 说明 |
|------|------|------|
| **四种因子** | `cognition`, `computation`, `willpower`, `permission` | 认知、计算、意志、权限的当前数量 |
| **货币** | `info`, `truth` | 拥有的信息、真相的数量 |
| **人员** | `researcher`, `labor`, `eroded`, `investigator` | 研究员人数、劳动力（暂未使用）、被侵蚀的人数、调查员数量 |
| **侵蚀预测** | `erosion.forecast` | 未来三个月的侵蚀情况（约 90 段，每段对应一天） |

### 3.3 字段说明

| 字段 | 类型 | 必需 | 说明 |
|------|------|------|------|
| `version` | int | 是 | 存档格式版本，用于迁移 |
| `map_name` | string | 是 | 存档显示名称 |
| `saved_at_game_hour` | int | 否 | 保存时的游戏时间（小时数），用于预览 |
| `map` | object | 是 | 与 `MapEditorMapIO` 格式兼容 |
| `time` | object | 否 | 缺省则从 0 开始、1x、流动；`total_game_hours` 为 int（小时） |
| `resources` | object | 否 | 缺省时从 `datas/game_base.json` 读取开局值；需含 factors / currency / personnel |
| `erosion` | object | 否 | 缺省则由 ErosionCore 按时间推导 |
| `erosion.forecast` | array | 否 | 未来 3 个月侵蚀预测，每元素 `{"value": int}`；缺省则按 `total_game_hours` 重新生成 |

### 3.4 侵蚀预测格式

- **段数**：90 段（3 个月 ≈ 90 天，与 `ErosionCycleBar.SEGMENT_COUNT` 一致）
- **每段**：`{"value": int}`，value 为侵蚀等级（+1 隐性 / 0 轻度 / -2 显性 / -4 涌动阴霾 / -8 莱卡昂的暗影）
- **顺序**：从保存时刻起，第 1 天、第 2 天、…、第 90 天
- **生成**：保存时调用 `ErosionCore.get_forecast_segments(90, GameTime.get_total_hours())`；加载时若有 `forecast` 则直接使用，否则按恢复后的 `total_game_hours` 重新生成

### 3.5 数据类型约定

所有存档内的数值采用**整数**存储，避免浮点误差与跨平台不一致。

| 类别 | 字段 | 类型 | 说明 |
|------|------|------|------|
| **四种因子** | `cognition`, `computation`, `willpower`, `permission` | int | ≥ 0 |
| **货币** | `info`, `truth` | int | ≥ 0 |
| **人员** | `researcher`, `labor`, `eroded`, `investigator` | int | ≥ 0 |
| **时间** | `total_game_hours`, `saved_at_game_hour` | int | 游戏内小时数，最小单位为 1 小时；不含小数 |
| **时间倍速** | `speed_multiplier` | float | 1.0 / 2.0 / 6.0 / 96.0 等，用于运行时 |
| **侵蚀** | `raw_mystery_erosion`, `shelter_bonus`, `forecast[].value` | int | 侵蚀等级为整数 |

**时间记录规则**：游戏内时间的最小单位为 1 小时，所有与时间相关的计数（如 `total_game_hours`、`saved_at_game_hour`）均为整数小时数。

---

### 3.6 版本与迁移

| version | 说明 | 迁移策略 |
|---------|------|----------|
| 0（隐式） | 旧版纯地图：仅有 grid/tiles/rooms | 补全 time/resources/erosion 默认值，version 设为 1 |
| 1 | 完整存档 | 当前格式（含 factors/currency/personnel/erosion_forecast） |

---

## 4. 保存流程

### 4.1 触发点

- **手动保存**：主菜单或快捷键（如 F5 / Ctrl+S）
- **自动保存**（可选）：定时或关键事件后写入固定槽位（如 slot_0 或 `user://saves/autosave.json`）

### 4.2 保存步骤

1. 收集游戏状态：从 GameMain、GameTime、ErosionCore、资源/人员管理器读取
   - **四种因子**：cognition / computation / willpower / permission
   - **货币**：info、truth
   - **人员**：researcher、labor、eroded、investigator
   - **侵蚀预测**：`ErosionCore.get_forecast_segments(90, GameTime.get_total_hours())`
2. 构建 `GameState` 字典
3. 写入 `user://saves/slot_N.json`（或兼容路径）
4. 更新槽位元数据缓存（供存档列表 UI 使用）

### 4.3 地图与 room_info.json

- 存档中的 `map.rooms` 为完整房间数据，**不**自动同步回 `datas/room_info.json`
- `room_info.json` 仅作为场景编辑器的模板库；游戏存档为独立快照

---

## 5. 加载流程

### 5.1 触发点

- 主菜单「继续」或「加载存档」
- 游戏启动时可选「从上次存档恢复」

### 5.2 加载步骤

1. 读取 JSON，解析为 Dictionary
2. 校验 `version`，执行迁移（若需要）
3. 恢复地图：写入 GameMain 的 `_tiles`、`_rooms`，触发重绘
4. 恢复时间：`GameTime._total_game_hours`、`is_flowing`、`speed_multiplier`
5. 恢复侵蚀：`ErosionCore.raw_mystery_erosion`、`shelter_bonus`（若存档含独立快照）
6. 恢复侵蚀预测：若存档含 `erosion.forecast` 则注入 ErosionCycleBar；否则按恢复后的 `total_game_hours` 重新生成
7. 恢复资源/人员：因子、货币、人员通过 `UIMain.set_resources()` 或未来 GameState 单例

### 5.3 错误处理

- 文件不存在：提示「该槽位无存档」
- JSON 解析失败：提示「存档已损坏」
- 版本过新：提示「需要更新游戏版本」

---

## 6. 路径与槽位策略

### 6.1 路径与职责分离

| 用途 | 路径 | 说明 |
|------|------|------|
| 游戏存档 | `user://saves/slot_0.json` ~ `slot_4.json` | 玩家进度，完整游戏状态 |
| 自动存档 | `user://saves/autosave.json` | 可选，不占槽位 |
| 地图编辑器 | `user://maps/slot_N.json` | 项目级地图资源，与存档无关 |
| 新游戏起始地图 | `user://maps/slot_0.json` | 游戏初始化时读取编号第一张地图 |

### 6.2 槽位数量

- 游戏存档：5 个槽位（slot 0~4）
- 地图编辑器：5 个槽位（slot 0~4），槽位号独立，与存档无对应关系

### 6.3 新游戏初始化

1. 玩家选择存档槽位
2. 读取 `user://maps/slot_0.json` 作为起始地图（若不存在则空白）
3. 叠加 game_base 默认资源/时间
4. 写入 `user://saves/slot_N.json`
5. 进入游戏加载该存档

---

## 7. UI 与交互

### 7.1 存档列表

- 显示 5 个槽位：槽位号、地图名、保存时间（游戏内）、是否有存档
- 空槽位显示「空」
- 点击槽位：加载 / 覆盖保存

### 7.2 保存确认

- 覆盖已有存档时弹窗确认
- 保存成功：简短提示（如 Toast）

### 7.3 主菜单入口

- 「继续」：加载第一个有存档的槽位（或上次槽位，需 `user://saves/last_slot`）
- 「新游戏」：选择存档槽位 → 以 maps/slot_0 为起始地图创建新存档 → 进入游戏
- 「加载存档」：打开存档选择界面

---

## 8. 关键文件（规划）

| 文件 | 职责 |
|------|------|
| `datas/game_base.json` | 游戏基础数据：开局资源/人员/时间默认值，供新游戏及存档缺省补齐 |
| `scripts/core/save_manager.gd` | SaveManager Autoload：保存/加载、元数据、迁移 |
| `scripts/core/game_state.gd` | GameState 数据结构、序列化/反序列化 |
| `scripts/game/game_main.gd` | 扩展：提供状态收集接口，接收加载结果 |
| `scripts/ui/save_load_panel.gd` | 存档列表 UI（待实现） |
| `project.godot` | SaveManager Autoload 配置 |

---

## 9. 与现有系统的集成

### 9.1 GameTime

- 需暴露 `set_total_hours(h: float)` 或内部可写接口，供加载时恢复
- 加载后调用 `time_updated.emit()` 通知订阅者

### 9.2 ErosionCore

- `raw_mystery_erosion`、`shelter_bonus` 可由时间推导，也可从存档恢复
- 若存档含 `erosion`，优先使用存档值；否则保持当前按时间推导逻辑
- **侵蚀预测**：保存时写入 `get_forecast_segments(90, total_game_hours)` 的结果；加载时若有 `forecast` 则直接提供给 ErosionCycleBar，否则按恢复后的时间重新生成

### 9.3 场景编辑器

- 继续使用 `MapEditorMapIO` 写入 `user://maps/`
- 游戏存档使用 `user://saves/`，两者路径分离，互不覆盖
- 可选：场景编辑器「导出到游戏槽位」时，调用 SaveManager 写入完整存档（时间等用默认值）

---

## 10. 实现优先级建议

| 阶段 | 内容 |
|------|------|
| P0 | SaveManager 基础框架，GameState 结构，纯地图兼容加载 |
| P1 | 完整保存/加载（含 time、resources、erosion） |
| P2 | 存档列表 UI、覆盖确认、主菜单「继续」 |
| P3 | 自动存档、上次槽位记忆 |

---

## 11. 相关文档

- [00 - 项目概览](00-project-overview.md)
- [02 - 房间信息与 room_info.json 同步](02-room-info-and-json-sync.md)
- [03 - 游戏主场景](03-game-main.md)
- [04 - 时间流逝系统](04-time-system.md)

---


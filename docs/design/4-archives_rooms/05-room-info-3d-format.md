# 05 - 3D 房间数据格式（room_info.json）

## 概述

本文档描述 **3D 游戏主场景** 中「房间信息」的**字段含义、数据类型与数据来源分层**（静态配置 / 存档运行时 / 全局常量 / 派生计算）。数据文件为 `datas/room_info.json`，区别于 2D 地图编辑器的 `room_info_legacy.json`（见 [1-editor/02-room-info-and-json-sync.md](../1-editor/02-room-info-and-json-sync.md)）。

**代码载体**：运行时房间实例为 `ArchivesRoomInfo`（`scripts/core/room_info.gd`）；区域建设枚举为 `ZoneType.Type`（`scripts/core/zone_type.gd`）。

---

## 1. 数据分层

| 分层 | 含义 | 典型存放位置 |
|------|------|----------------|
| **A. 静态配置** | 开局模板，随 `room_info.json` 分发；新游戏据此生成房间 | `datas/room_info.json` |
| **B. 存档运行时** | 每存档槽位、每房间实例会变化的状态 | `user://saves/slot_N.json` 内房间字典 |
| **C. 全局常量** | 全项目统一数值，不随单房间配置 | `datas/game_values.json` 等 |
| **D. 派生/计算** | 由 A+B+C 与其它系统计算得出，一般不单独持久化为一列 | 代码内 getter 或临时变量 |

下文「房间信息」表中的 **来源** 列使用 **A / B / C / D** 标记。

---

## 2. 数据流

| 组件 | 文件 | 用途 |
|------|------|------|
| RoomInfoLoader | `datas/room_info.json` | 新游戏加载房间列表、邻接计算 |
| SaveManager | 存档内房间快照 | 开局与读档后的房间状态 |
| 本地化 | `translations/translations.csv` | `{id}_NAME`、`{id}_PRE_CLEAN`、`{id}_DESC` |

---

<a id="room-info-field-table"></a>

## 3. 房间信息字段总表（设计 ↔ 类型 ↔ 来源）

以下为设计用语与实现字段的对照；**JSON 键名**以 3D 模板与 `ArchivesRoomInfo` 为准。

| 设计概念 | 建议/现有字段名 | 数据类型 | 来源 | 说明 |
|----------|-----------------|----------|------|------|
| **房间名称** | `room_name` | `String` | A（文案原文）；显示走本地化 **D** | 配置用中文名，如「档案馆正厅」。运行时优先 `tr("{id}_NAME")`，无 key 时回退 `room_name`。 |
| **房间类型** | `room_type` | `String`（JSON）→ 运行时 `RoomType` **enum（int）** | A | 如资料库、图书室。与 [03-room-types](03-room-types.md) 一致；加载时由 `room_info_loader` 解析为枚举。 |
| **房间解锁状态** | `unlocked` | `bool` | B | `true` 可被清理流程选中；`false` 为未解锁（邻接/开篇逻辑）。默认 `true` 兼容旧档。 |
| **房间清理状态** | `clean_status` | `int`（`CleanStatus`：0=未清理，1=已清理） | A 为初始值，**以 B 为准** | 与「是否已清理」玩法一致。 |
| **房间建设状态** | `zone_type` | `int`（`ZoneType.Type`） | B 为主 | `0` = 未建设任何区域；非 `0` = 已建设，值为区域类型（见下表）。与 `can_build_zone()` 等逻辑一致。 |
| **房间建设区域**（已建成时） | 同 `zone_type` | `int`（`ZoneType.Type`） | B | 研究区、造物区、事务所区、生活区、医疗区、娱乐区、宗教区、奇观区对应 `ZoneType` 枚举；部分区域**玩法待扩展**（见 `zone_type.gd`）。 |
| **房间 desc** | `desc` | `String` **或** `Array[String]` | A | 多行描述；数组项之间在运行时用 `\n` 拼接（`parse_text_field`）。本地化 key `{id}_DESC`。 |
| **房间清理前 desc** | `pre_clean_text` | `String` **或** `Array[String]` | A | 清理前展示；格式约定同 `desc`。本地化 key `{id}_PRE_CLEAN`。 |
| **房间尺寸** | `3d_size`（JSON 键 **`"3d_size"`**）；运行时 `size_3d` | `String`（枚举：`base` / `tall` / `small` / `small_tall` / `long`） | A | 游戏开始后**不变化**；与网格占位、单位数、体量对照见 [02-room-dimensions-and-specs](02-room-dimensions-and-specs.md)。 |
| **房间改造槽位** | *待定*，如 `remodel_slot_count` | `int`，默认 `1`，可增长 | B（增长部分） | 初始为 1，游戏中可增加；**若落地需写入存档与加载逻辑**。 |
| **房间分配庇护值上限** | *待定*，或常量引用 | `int`，设计示例 **5**（固定） | **C** | 表示**可被玩家分配**到该房间的庇护上限，**不是**房间庇护总值上限；房间还可通过其它系统获得庇护。 |
| **房间额外庇护值** | *待定* | `int`，默认 `0` | B 或 A，视设计 | 与「分配庇护」区分；具体是否进 JSON 由玩法定稿。 |
| **房间被分配庇护值** | *待定* | `int`，≥ 0 | **B** | 仅运行/存档存在，表示当前已分配到该房的庇护量。 |
| **房间改造组** | *待定* | `Array`（元素如改造 id 或结构体） | **B** | 已解锁/已拥有的改造列表。 |
| **房间技能组** | *待定* | `Array`（技能 id 或配置引用） | A 或 B | 若随模板固定则为 A；若局内解锁则为 B。 |
| **房间固有消耗** | *待定* | `Dictionary` 或结构化数组（资源类型 → 数值或公式 id） | A 或 C | 与「固定每周期/每次」消耗相关；可能与 `game_values` 联动。 |
| **房间资源储备** | `room_resources` | `Array[{ "type": int, "amount": int }]`（JSON） | A 初值，**B 为当前库存** | 研究区等房间的因子存量；`type` 对应 `ResourceType`。 |
| **房间动态消耗** | *无单一 JSON 列* | 由规则与状态算出的消耗 | **D** | 例如按人员、侵蚀、临时 buff 变化；不等同于 `room_resources` 的减少。 |
| **房间总产出** | *无单一 JSON 列* | 可汇总为数值或按因子拆分 | **D** 或 配置引用 **A/C** | 由房间类型、区域、技能、改造等共同决定；文档层可记「设计目标」，实现为公式或表驱动。 |

**说明**：

- 表中「待定」字段为当前设计方向，**落地时需同步**：`room_info.schema.json`、`room_info_loader.gd`、`ArchivesRoomInfo.from_dict` / `to_dict` 与存档版本迁移。
- **建设区域** 与 **房间类型** 不同：类型是「资料库/图书室」等建筑语义；`zone_type` 是「在该房间上建设了哪一类功能区」（研究区、造物区等）。

---

## 4. `ZoneType.Type` 与中文「建设区域」

| 中文（设计） | 枚举值（概念） | 备注 |
|--------------|----------------|------|
| （无） | `NONE` = 0 | 未建设 |
| 研究区 | `RESEARCH` | 已实现映射房间类型 |
| 造物区 | `CREATION` | 已实现 |
| 事务所区 | `OFFICE` | 已实现 |
| 生活区 | `LIVING` | 已实现 |
| 医疗区 | `MEDICAL` | 枚举已有，玩法映射可空 |
| 娱乐区 | `ENTERTAINMENT` | 同上 |
| 宗教区 | `RELIGION` | 同上 |
| 奇观区 | `WONDER` | 同上 |

详见 `scripts/core/zone_type.gd` 与 [05-zone-construction](../2-gameplay/05-zone-construction.md)。

---

## 5. JSON 结构示例（现有字段）

```json
{
  "source": "新版本档案馆房间 (3D)",
  "version": 3,
  "rooms": [
    {
      "id": "room_00",
      "room_name": "档案馆核心",
      "3d_size": "tall",
      "grid_x": -1,
      "grid_y": 1,
      "layout_cells": [[0,0],[1,0],[0,1],[1,1]],
      "room_type": "核心",
      "clean_status": 0,
      "room_resources": [{"type": 2, "amount": 0}],
      "pre_clean_text": "默认清理前描述",
      "desc": ["描述段落1", "描述段落2"],
      "items_in_room": []
    }
  ]
}
```

**存档中**（非 `room_info.json`）同一房间还会包含 `unlocked`、`zone_type`、`adjacent_ids`、`json_room_id`（通常等于 `id`）、`resources` 结构等，见 `ArchivesRoomInfo.to_dict()` / `from_dict()`。

---

## 6. 字段说明（精简，与 §3 互补）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `String` | 唯一标识，如 `room_00`、`room_hall_00`。 |
| `room_name` | `String` | 见 §3「房间名称」。 |
| `3d_size` | `String` | 见 §3「房间尺寸」。 |
| `grid_x` / `grid_y` | `int` | 与 3D/工具链对齐的锚点格。 |
| `layout_cells` | `Array`（`[gx,gy]`） | **清理解锁邻接的真源**：馆内坐标下各占 1×1 格；见 [04 - 房间解锁与邻接](04-room-unlock-adjacency.md)。 |
| `room_type` | `String` | 见 §3「房间类型」。 |
| `clean_status` | `int` | 0=未清理，1=已清理。 |
| `room_resources` | `Array` | 资源储备，见 §3。 |
| `pre_clean_text` | `String` 或 `Array` | 清理前描述。 |
| `desc` | `String` 或 `Array` | 房间描述，数组时按换行拼接。 |
| `items_in_room` | `Array` | 预留，3D 物件列表。 |

---

## 7. 本地化 Key 约定

3D 游戏通过 `id` 查找翻译：

- `{id}_NAME`：房间名称  
- `{id}_PRE_CLEAN`：清理前描述  
- `{id}_DESC`：房间描述  

当 `translations.csv` 中无对应 key 时，回退到 JSON/存档中的原文。

---

## 8. 相关文档

- [01 - 档案馆房间信息](01-archive_rooms_info.md)：按房间的设计文案表  
- [02 - 房间尺寸与设计规范](02-room-dimensions-and-specs.md)：`3d_size` 与 volum  
- [03 - 房间类型](03-room-types.md)：`room_type` 与枚举  
- [04 - 房间解锁与邻接](04-room-unlock-adjacency.md)：`layout_cells`、`unlocked`、`adjacent_ids`  
- [02 - 房间信息与 room_info 同步（2D）](../1-editor/02-room-info-and-json-sync.md)

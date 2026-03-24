# 06 - room_info 3D 字段实现核对清单

## 目的

对齐 `05-room-info-3d-format.md` 与当前代码实现，避免“文档已定义但运行未落地”的偏差。

核对范围：

- `datas/room_info.json`
- `scripts/game/room_info_loader.gd`
- `scripts/core/room_info.gd`
- `scripts/game/game_main_save.gd`

---

## 字段核对（A/B/C/D）

| 字段 | 文档分层 | 实现状态 | 说明 |
|------|----------|----------|------|
| `id` | A/B | 已实现 | Loader 读入；运行时/存档沿用。 |
| `room_name` | A | 已实现 | 显示优先本地化 key 回退原文。 |
| `room_type` | A | 已实现 | Loader 由字符串映射到 `RoomType`。 |
| `clean_status` | A->B | 已实现 | 存档覆盖运行时状态。 |
| `unlocked` | B | 已实现 | `to_dict/from_dict` 与开篇逻辑联动。 |
| `zone_type` | B | 已实现 | 建设完成后持久化。 |
| `room_resources` | A->B | 已实现 | Loader 解析为 `resources`。 |
| `pre_clean_text` | A | 已实现 | 支持字符串/数组拼接。 |
| `desc` | A | 已实现 | 支持字符串/数组拼接。 |
| `3d_size` | A | 已实现 | 兼容 `size_3d/3d_size`。 |
| `grid_x/grid_y` | A | 已实现 | 用于布局与邻接。 |
| `adjacent_ids` | B/D | 已实现 | 新游戏计算，存档持久化。 |
| `remodel_slot_count` | B | 已实现 | 已接入 `room_info` 模型、Loader、存档、详情面板显示。 |
| `items_in_room` | A | 待实现 | JSON/schema 已有，运行时模型未接入。 |
| 被分配庇护值 | B | 待实现 | 当前为运行时计算链，未落地单字段。 |
| 额外庇护值 | A/B | 待实现 | 尚未进入模型与存档。 |
| 改造组 | B | 待实现 | 尚未进入模型与存档。 |
| 技能组 | A/B | 待实现 | 详情面板已有技能按钮，底层技能数据结构待统一。 |
| 固有消耗结构化字段 | A/C | 待实现 | 目前由数值系统与房间类型派生。 |

---

## 本轮已落地同步项

1. `remodel_slot_count` 已贯通：
   - `room_info.json`（可选字段，默认 1）
   - `room_info.schema.json`（1~3）
   - `RoomInfoLoader` 解析
   - `ArchivesRoomInfo.to_dict/from_dict`
   - `RoomDetailPanelFigma` 改造槽显示
2. 房间“强制关停”运行时状态已接入存档：
   - `map.forced_shutdown_room_ids` 持久化与恢复

---

## 回归检查

- 新游戏：`remodel_slot_count` 缺省时 UI 显示 1 个槽位。
- 存档->读档：`remodel_slot_count`、`zone_type`、`forced_shutdown_room_ids` 恢复一致。
- 房间详情：改造槽数量变化时不需重开场景即可刷新。

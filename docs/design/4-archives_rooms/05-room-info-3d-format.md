# 05 - 3D 房间数据格式（room_info.json）

## 概述

本文档描述 **3D 游戏主场景** 使用的 `datas/room_info.json` 结构与约定，区别于 2D 地图编辑器的 `room_info_legacy.json`（见 [1-editor/02-room-info-and-json-sync.md](../1-editor/02-room-info-and-json-sync.md)）。

---

## 1. 数据流

| 组件 | 文件 | 用途 |
|------|------|------|
| RoomInfoLoader | `datas/room_info.json` | 新游戏加载房间列表、邻接计算 |
| SaveManager | `room_info.json` | 开局房间状态 |
| 本地化 | `translations/translations.csv` | `{id}_NAME`、`{id}_PRE_CLEAN`、`{id}_DESC` |

---

## 2. JSON 结构

```json
{
  "source": "新版本档案馆房间 (3D)",
  "version": 2,
  "rooms": [
    {
      "id": "room_00",
      "room_name": "档案馆核心",
      "3d_size": "tall",
      "grid_x": -1,
      "grid_y": 1,
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

### 2.1 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String | 唯一标识，格式 `room_00`、`room_01`、`room_hall_00`、`room_pass_0` 等 |
| room_name | String | 房间名称（中文，供编辑器/调试；运行时可翻译为 `{id}_NAME`） |
| 3d_size | String | 尺寸类型：`base`、`tall`、`small`、`small_tall`、`long` |
| grid_x | int | 布局网格 X |
| grid_y | int | 布局网格 Y |
| room_type | String | 房间类型中文名，与 `03-room-types.md` 对应 |
| clean_status | int | 0=未清理，1=已清理 |
| room_resources | Array | `[{type, amount}, ...]`，研究区房间的存量 |
| pre_clean_text | String/Array | 清理前描述 |
| desc | String/Array | 房间描述，数组时按 `\n` 拼接 |
| items_in_room | Array | 预留，3D 道具列表 |

### 2.2 与 2D 的差异

| 项目 | room_info_legacy.json (2D) | room_info.json (3D) |
|------|----------------------------|----------------------|
| id 格式 | ROOM_001 | room_00 |
| 尺寸 | size: "5×3", rect | 3d_size, grid_x/y |
| 读取方 | map_editor_map_io.gd | room_info_loader.gd |

---

## 3. 本地化 Key 约定

3D 游戏通过 `room.json_room_id`（= `id`）查找翻译：

- `{id}_NAME`：房间名称，如 `room_00_NAME`
- `{id}_PRE_CLEAN`：清理前描述
- `{id}_DESC`：房间描述

当 `translations.csv` 中无对应 key 时，回退到 `room_name` / `pre_clean_text` / `desc` 原始值。

---

## 4. 相关文档

- [01 - 档案馆房间信息](01-archive_rooms_info.md)：房间文案与设计说明
- [02 - 房间尺寸与设计规范](02-room-dimensions-and-specs.md)：3d_size 与 volum 对照
- [04 - 房间解锁与邻接](04-room-unlock-adjacency.md)：grid、解锁逻辑
- [02 - 房间信息与 room_info 同步（2D）](../1-editor/02-room-info-and-json-sync.md)

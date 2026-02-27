# 02 - 房间信息编辑与 room_info.json 同步

## 概述

场景编辑器的房间信息通过 `RoomInfo` 结构体承载，既保存到地图槽位 JSON（`user://maps/slot_N.json`），也与 `datas/room_info.json` 双向同步。本文档描述设计、实现及各项限制，供后续开发参考。

---

## 数据结构

### RoomInfo（`scripts/editor/room_info.gd`）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String | 房间内部唯一 ID（如 room_0），由编辑器生成，不写入 room_info.json |
| room_name | String | 房间名称 |
| rect | Rect2i | 房间在网格中的范围 (x, y, w, h) |
| room_type | int | 房间类型（枚举见 RoomInfo.RoomType） |
| clean_status | int | 清理状态（0=未清理, 1=已清理） |
| resources | Array | 资源列表，每项 `{"resource_type": int, "resource_amount": int}` |
| base_image_path | String | 底图路径，相对于 res:// |
| pre_clean_text | String | 清理前文本 |
| json_room_id | String | 关联的 room_info.json 模板 id（如 ROOM_001），空表示新建未同步 |
| desc | String | 房间描述，与 room_info.json 的 desc 对应 |

### room_info.json 路径与编码

- **路径**：`datas/room_info.json`（相对项目根目录）
- **编码**：UTF-8
- **说明**：`datas/` 通过 `.gdignore` 未被 Godot 导入，仅作数据文件

### room_info.json 结构

```json
{
  "source": "数据来源说明",
  "rooms": [
    {
      "id": "ROOM_001",
      "room_name": "房间名称",
      "size": "5×3",
      "room_type": "房间类型名称",
      "room_type_id": 3,
      "clean_status": 0,
      "base_image_path": "res://assets/...",
      "resources": [{"resource_type": 4, "resource_amount": 5000}],
      "pre_clean_text": "默认清理前文本",
      "desc": "房间背景描述"
    }
  ]
}
```

- `id`：唯一编号，格式 `ROOM_XXX`（XXX 为三位数字）
- `size`：房间尺寸字符串，如 `"5×3"`，由 rect 计算
- `room_type`：人类可读类型名，由 `RoomInfo.get_room_type_name()` 生成
- `room_type_id`：数值类型 ID，用于程序解析

### 长文本数组格式（desc / pre_clean_text）

为方便阅读和修改，长文本可采用**字符串数组**形式书写，每行一个元素，换行符保留在续行元素开头：

```json
"desc": [
  "第一段文字，",
  "\n第二段文字。"
]
```

- **读取**：数组会按顺序拼接为字符串（`RoomInfo.parse_text_field`）
- **写入**：保存地图同步时，超过约 30 字或含换行的文本会自动转为数组格式（`RoomInfo.format_text_for_json`）
- **兼容**：字符串与数组两种格式均支持

---

## 房间编辑 UI

### 面板结构（`_build_room_edit_panel`）

编辑顺序自上而下：

1. **名称**：`LineEdit`，实时写入 `room.room_name`
2. **类型**：`OptionButton`，选项对应 `RoomInfo.RoomType` 枚举
3. **清理状态**：`OptionButton`，0=未清理，1=已清理
4. **清理前文本**：`LineEdit`，单行
5. **描述**：`TextEdit`，多行，支持 `\n` 换行
6. **资源**：可添加/删除，每行：类型下拉 + 储量数字 + 删除
7. **底图**：只读展示 + 选择 / 清除按钮
8. **从模板导入**：按钮，打开模板选择弹窗
9. **删除房间**：按钮

### 行为与约束

- 未选中房间时，面板内控件禁用并清空
- 选中房间后，`_refresh_room_panel()` 将当前房间数据同步到各控件
- 描述使用 `TextEdit`，保证与 JSON 中 `desc` 的换行一致

---

## 从模板导入

### 流程

1. 选中房间 → 点击「从模板导入」
2. 读取 `datas/room_info.json`，解析 `rooms` 数组
3. 弹窗列表展示 `id` + `room_name`，用户选择一项并确认
4. 将模板字段写入当前房间：  
   `json_room_id`, `room_name`, `room_type`, `clean_status`, `pre_clean_text`, `base_image_path`, `desc`, `resources`

### 关联规则

- 导入后 `room.json_room_id` 设为模板的 `id`
- 后续保存地图时，该房间会按 `json_room_id` 更新或新增 room_info.json 中的条目

---

## 地图保存与 JSON 同步

### 地图槽位保存（`_save_map`）

- 保存到 `user://maps/slot_N.json`
- 使用 `room.to_dict()`，包含 `json_room_id`、`desc` 等
- 保存完成后调用 `_sync_rooms_to_json()`

### 同步逻辑（`_sync_rooms_to_json`）

1. **读取现有 room_info.json**  
   - 文件存在则解析，保留 `source`、`rooms` 等顶层字段  
   - 不存在则新建 `{"source": "场景编辑器同步", "rooms": []}`

2. **遍历当前地图中所有房间**  
   - `json_room_id` 为空：  
     - 分配新 id，格式 `ROOM_%03d`，编号从现有 rooms 中最大编号 +1 开始  
     - 写入 `room.json_room_id`，并向 `rooms` 追加条目  
   - `json_room_id` 非空：  
     - 在现有 `rooms` 中查找 `id == json_room_id` 的条目  
     - 若找到则覆盖，否则追加

3. **写回 JSON**  
   - 使用 `JSON.stringify(json_data, "  ", false)` 输出带 2 空格缩进、保持 key 顺序的格式

### 同步时机

- 仅在地图保存成功（`_save_map` 成功）后执行

---

## JSON 格式规范

###  Pretty-print 要求

为便于在 Cursor 等编辑器中阅读和维护：

- 使用 `JSON.stringify(data, "  ", false)`
- 每级缩进 2 空格
- `sort_keys = false` 保持字段顺序

### desc 中的换行

- `desc` 支持多行，使用 `\n` 表示换行
- 编辑器中用 `TextEdit` 编辑，与 JSON 中的换行一一对应

---

## 数据流向概览

```
地图槽位 JSON (slot_N.json)          room_info.json
        │                                    │
        │  load                              │  import
        ▼                                    │
    _rooms (RoomInfo[])  ◄───────────────────┘
        │
        │  save + _sync_rooms_to_json
        ▼
    room.to_dict() → slot   +   room.to_json_room_dict() → rooms[]
```

---

## 限制与约束

### 1. json_room_id 的生命周期

- 新建房间默认 `json_room_id = ""`
- 首次保存时自动分配 `ROOM_XXX`，并写入 room_info.json
- 从模板导入会直接设置 `json_room_id`，不触发自动分配

### 2. room_info.json 为单一数据源

- 所有地图槽位的房间在保存时都写入同一 `room_info.json`
- 不同槽位若有相同 `json_room_id`，会覆盖同一模板条目
- 不适合作为「每个槽位一套模板」的存储，当前设计为共享模板库

### 3. 同步方向

- 地图 → room_info.json：每次保存地图时自动同步
- room_info.json → 地图：仅通过「从模板导入」手动应用，无自动回写

### 4. 编辑冲突

- 若在外部直接修改 room_info.json，下次保存地图会覆盖这些修改
- 建议以场景编辑器为主要编辑入口，JSON 作为导出/模板数据

### 5. 地图槽位 JSON 与 room_info.json 的差异

- 槽位 JSON 使用 `room.to_dict()`，包含 `rect_x/y/w/h`、`id` 等地图专用字段
- room_info.json 使用 `room.to_json_room_dict()`，包含 `size`、`room_type` 名称等模板字段
- 二者通过 `json_room_id` 关联

### 6. 底图路径

- 仅支持 `res://` 下的资源路径
- 通过 `FileDialog` 选择，`ACCESS_RESOURCES` 模式

---

## 相关文件

| 文件 | 说明 |
|------|------|
| `scripts/editor/room_info.gd` | RoomInfo 定义，to_dict / from_dict / to_json_room_dict |
| `scripts/editor/map_editor.gd` | 编辑器主逻辑，房间 UI、导入、同步 |
| `datas/room_info.json` | 房间模板数据 |
| `datas/README.md` | datas 目录说明 |

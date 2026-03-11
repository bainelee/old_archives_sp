# newroom：根据 room_id 新建档案馆房间场景

## 概述

根据用户提供的 `room_id`（如 `room_01`、`room_hall_00`、`room_pass_0`），在 `scenes/rooms/archives_rooms/` 下生成对应的 3D 房间场景。数据来源于 `datas/room_info.json`。

## 触发方式

用户输入 `/newroom <room_id>`，例如：
- `/newroom room_01`
- `/newroom room_hall_03`
- `/newroom room_pass_2`

## 执行步骤

### 1. 解析 room_id

从用户输入中提取 `room_id`（`/newroom` 后的第一个非空 token）。若 `room_id` 为空或用户仅输入 `/newroom` 未附带参数，则：

**回复**：`房间id为空无法生成`，**立即停止**，不再执行后续步骤。

### 2. 校验 room_id 是否存在

1. 读取 `datas/room_info.json`
2. 在 `rooms` 数组中查找 `id` 与 `room_id` 完全匹配的条目
3. 若**未找到**：

**回复**：`房间id为空无法生成`，**立即停止**，不再执行后续步骤。

### 3. 获取房间数据并选择 preset

从匹配的 room 条目中读取：
- `room_name`
- `3d_size`（base / long / tall / small / small_tall）

按 `3d_size` 选择对应 preset 场景：

| 3d_size     | preset 场景路径                                                  |
|-------------|------------------------------------------------------------------|
| base        | `res://scenes/rooms/preset_rooms/preset_room_frame.tscn`         |
| long        | `res://scenes/rooms/preset_rooms/preset_room_frame_long.tscn`   |
| tall        | `res://scenes/rooms/preset_rooms/preset_room_frame_tall.tscn`   |
| small       | `res://scenes/rooms/preset_rooms/preset_room_frame_small.tscn`  |
| small_tall  | `res://scenes/rooms/preset_rooms/preset_room_frame_small_tall.tscn` |

### 4. 生成房间场景

1. 读取选定的 preset 场景 `.tscn` 全文
2. 基于其内容生成新场景文件 `scenes/rooms/archives_rooms/<room_id>.tscn`，修改：
   - **根节点名**：将 `node name="PresetRoomFrame"` 改为 `node name="<room_id>"`
   - **RoomInfo.room_id**：设为 `room_id`
   - **RoomInfo.room_name**：设为 `room_name`
   - **RoomInfo.room_volume**：保持与 preset 一致（勿改）
3. 生成新的 `uid`（格式 `uid://xxxx`，避免与现有场景重复）
4. 写入文件

### 5. 完成

回复：`已生成房间场景：scenes/rooms/archives_rooms/<room_id>.tscn`，并简要列出配置（room_id、room_name、3d_size）。

## 参考

- `docs/design/4-archives_rooms/02-room-dimensions-and-specs.md`：房间尺寸与 preset 对应
- `docs/design/1-editor/04-preset-room-frame.md`：preset 场景结构说明
- `scenes/rooms/archives_rooms/room_00.tscn`：已有房间示例

# 04 - 预设 3D 房间框架

## 概述

**preset_room_frame** 是可复用的 3D 房间预设场景模板，用于在 3D 场景编辑器中定义房间的体积、参考网格、外轮廓、外墙及室内道具布局。

---

## 1. 场景结构

```
preset_room_frame (Node3D, root)
├── RoomInfo (房间信息组件)
├── RoomReferenceGrid (房间参考网格，三面网格)
├── RoomOutBlock (房间外轮廓，四个黑色 Box)
│   ├── room_out_block_down
│   ├── room_out_block_up
│   ├── room_out_block_left
│   └── room_out_block_right
├── RoomWallLand (Node3D)     # 放置房间外墙模型
└── RoomItems (Node3D)        # 放置房间内道具
    ├── items
    ├── lights
    └── doors
```

---

## 2. 房间信息（RoomInfo）

可配置组件，供编辑器与游戏逻辑识别房间。

| 属性 | 类型 | 说明 |
|------|------|------|
| `room_volume` | `Vector3` | 房间体积，xyz 分别为长(xR)、高(yR)、宽(zR) 的格子数，例：基础房间 20×10×10 |
| `room_id` | String | 房间 ID，用于从房间表查询游戏内名称等 |
| `room_name` | String | 房间名称（中文），**仅用于编辑器**；游戏内名称通过 `room_id` 从房间表获得 |

---

## 3. 房间参考网格（RoomReferenceGrid）

根据房间体积、由**三个面**构成的组件，每个面拥有符合此房间体积的网格（每格 0.5m），线框颜色为**灰白色**。

**正常方向**：Z 轴朝屏幕外，X 轴朝右，Y 轴朝上。

| 属性 | 说明 |
|------|------|
| 组成 | 底面（XZ）、左墙侧面（YZ，X 负值）、后方墙面（XY，Z 负值） |
| 网格尺寸 | 每格 0.5m |
| 中心点 | 位于底面中心 |
| 在 preset_room_frame 中的 position | **(0, 0.6, 0)** |
| 分解 | 0.5 = 底部外轮廓厚度；0.1 = 房间地板厚度 |

---

## 4. 房间外轮廓（RoomOutBlock）

根据房间体积生成的黑色外轮廓，由四个 3D Box 构成，Material 为**完全黑色**。

> **+0.2 的由来**：wall_and_land 模型的地板厚度与天花板厚度均为 0.1m，故公式中常用 0.2（0.1+0.1）表示地板+天花板厚度之和。

### 4.1 Box 尺寸

| 方向 | Box 尺寸 (x, y, z) | 说明 |
|------|-------------------|------|
| 左、右 | (0.5, 0.5×yR+1.2, 0.5×zR+1.2) | 厚度 0.5，高度与纵深覆盖房间并留边 |
| 上、下 | (0.5×xR+1.2, 0.5, 0.5×zR+1.2) | 厚度 0.5，长宽覆盖房间并留边 |

其中 xR、yR、zR 为 RoomInfo 中的房间体积格子数。

以 20×10×10 房间为例：

| 方向 | Box 尺寸 | 说明 |
|------|----------|------|
| 左、右 | (0.5, 5+1.2, 5+1.2) | 即 (0.5, 6.2, 6.2) |
| 上、下 | (10+1.2, 0.5, 5+1.2) | 即 (11.2, 0.5, 6.2) |

### 4.2 position

| 节点 | position |
|------|----------|
| room_out_block_down | (0, 0.25, 0) |
| room_out_block_up | (0, 0.5×yR+0.2+0.5+0.25, 0) |
| room_out_block_left | (-(xR×0.5+0.2)/2 - 0.25, (0.5×yR+1.2)/2, 0) |
| room_out_block_right | (+(xR×0.5+0.2)/2 + 0.25, (0.5×yR+1.2)/2, 0) |

- **down**：厚度 0.5 的 Box，中心 y=0.25，底面贴地
- **up**：0.2 = wall_and_land 模型的地板+天花板厚度，0.5 = room_out_block_down 的厚度，0.25 = room_out_block_up 的中心偏移

以 20×10×10 房间为例：

| 节点 | position |
|------|----------|
| room_out_block_down | (0, 0.25, 0) |
| room_out_block_up | (0, 5.95, 0) |
| room_out_block_left | (-5.35, 3.1, 0) |
| room_out_block_right | (5.35, 3.1, 0) |

---

## 5. 房间外墙（RoomWallLand）

用于放置房间外墙模型的节点。

| 属性 | 值 |
|------|-----|
| 类型 | Node3D |
| 默认子节点 | wall_and_land_0 |
| position | (0, 0.5, 0) |

---

## 6. 房间道具（RoomItems）

放置房间内道具的容器。

| 属性 | 值 |
|------|-----|
| position | (0, 0.6, 0) |
| 子节点 | items、lights、doors |

### 6.1 默认门（doors）

3d_actor 场景 root 必须为 (0,0,0)，位置在 preset_room_frame 的实例中设置：

| 节点 | 在 preset_room_frame 中的 position | actor_box |
|------|-----------------------------------|-----------|
| 3ditem_door_left_0 | (-4.75, 0, 1.25) | volume (1,5,3) |
| 3ditem_door_right_0 | (4.75, 0, 1.25) | volume (1,5,3) |


---

## 7. 待实现

- [ ] preset_room_frame 场景模板
- [ ] RoomInfo 组件（room_volume、room_id、room_name）
- [ ] RoomReferenceGrid 组件（基于 room_volume 的三面网格）
- [ ] RoomOutBlock 组件（四个黑色 Box 的生成与 position）
- [ ] 房间表（room_id → 游戏内名称等，可与 room_info.json 或 3D 专用表联动）

---

## 相关文档

- [03 - 3D 场景编辑器](03-3d-scene-editor.md)
- [02 - 房间信息与 room_info.json 同步](02-room-info-and-json-sync.md)
- [01 - 地图编辑器](01-map-editor.md)

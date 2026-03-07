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
| 在 preset_room_frame 中的 position | **(0, 0.5, 0)** |
| 分解 | 0.5 = thickness_out(0.4) + thickness_in/2(0.1)，即地板顶面高度 |

---

## 4. 房间外轮廓（RoomOutBlock）

根据房间体积生成的黑色外轮廓，由四个 3D Box 构成，Material 为**完全黑色**。

### 4.0 规范化常量

```
grid_size = 0.5
room_volume = (xR, yR, zR)

// room_out_block_thickness
// 旧版本为 0.5，加上墙壁厚度后难以与格子尺寸对应，改为 0.4
thickness_out = 0.4

// room_wall_or_floor_thickness
// 实际为 2 倍：左侧墙+右侧墙厚度之和（各 0.1），或天花板+地板厚度之和（各 0.1）
thickness_in = 0.2
```

### 4.1 Box 尺寸与 position

| 节点 | scale | position |
|------|-------|----------|
| room_out_block_left | (thickness_out, grid_size×yR + thickness_in + thickness_out×2, grid_size×zR + thickness_in/2) | (-grid_size×xR/2 - thickness_in/2 - thickness_out/2, (grid_size×yR + thickness_in + thickness_out×2)/2, 0) |
| room_out_block_right | (thickness_out, grid_size×yR + thickness_in + thickness_out×2, grid_size×zR + thickness_in/2) | (+(grid_size×xR + thickness_in + thickness_out)/2, (grid_size×yR + thickness_in + thickness_out×2)/2, 0) |
| room_out_block_down | (grid_size×xR + thickness_in + thickness_out×2, thickness_out, grid_size×zR + thickness_in/2) | (0, thickness_out/2, 0) |
| room_out_block_up | (grid_size×xR + thickness_in + thickness_out×2, thickness_out, grid_size×zR + thickness_in/2) | (0, grid_size×yR + thickness_in + thickness_out + thickness_out/2, 0) |

- **down**：底面贴地，中心 y = thickness_out/2
- **up**：位于房间顶部之上，中心 y = 房间顶 + thickness_in + thickness_out/2

### 4.2 验证：20×10×10 房间 (xR=20, yR=10, zR=10)

| 节点 | scale | position |
|------|-------|----------|
| room_out_block_left | (0.4, 6, 5.1) | (-5.3, 3, 0) |
| room_out_block_right | (0.4, 6, 5.1) | (5.3, 3, 0) |
| room_out_block_down | (11, 0.4, 5.1) | (0, 0.2, 0) |
| room_out_block_up | (11, 0.4, 5.1) | (0, 5.8, 0) |

**验算**：
- left scale: (0.4, 0.5×10+0.2+0.8, 0.5×10+0.1) = (0.4, 6, 5.1) ✓
- left position x: -5 - 0.1 - 0.2 = -5.3 ✓；y: (5+0.2+0.8)/2 = 3 ✓
- right position x: (10+0.2+0.4)/2 = 5.3 ✓
- down scale: (10+0.2+0.8, 0.4, 5.1) = (11, 0.4, 5.1) ✓；position y: 0.4/2 = 0.2 ✓
- up position y: 5+0.2+0.4+0.2 = 5.8 ✓

---

## 5. 房间外墙（RoomWallLand）

用于放置房间外墙模型的节点。

| 属性 | 值 |
|------|-----|
| 类型 | Node3D |
| 默认子节点 | wall_and_land_0 |
| position | (0, 0.4, 0) |
| 说明 | 0.4 = thickness_out，外墙模型底面与 room_out_block_down 顶面齐平 |

---

## 6. 房间道具（RoomItems）

放置房间内道具的容器。

| 属性 | 值 |
|------|-----|
| position | (0, 0.5, 0) |
| 说明 | 0.5 = thickness_out + thickness_in/2，底面位于地板顶面 |
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
- [05 - RoomItems 网格对齐](05-room-items-grid-snap.md)
- [02 - 房间信息与 room_info.json 同步](02-room-info-and-json-sync.md)
- [01 - 地图编辑器](01-map-editor.md)

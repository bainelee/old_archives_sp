# 04 - 房间解锁与邻接系统

## 概述

本系统为房间清理功能提供**解锁状态**与**邻接关系**，实现：游戏开篇仅部分房间可清理；清理完成后解锁相邻房间。基于 3D 房间系统（room_info.json + archives_base_0），不再依赖旧版 2D 地图。

## 1. 功能需求

### 1.1 解锁状态

| 状态 | 说明 |
|------|------|
| 已解锁 | 可被清理功能选中 |
| 未解锁 | 不可选中，显示黑色 60% 遮罩 |

### 1.2 初始状态（新游戏）

- **开篇房间**（如档案馆核心 room_00）：已清理 + 已解锁
- **开篇房间的邻接房间**：已解锁、未清理
- **其余房间**：未解锁

### 1.3 解锁规则

房间被清理完成后，其邻接房间中处于未解锁状态的变为已解锁。

## 2. 布局网格与邻接

### 2.1 尺寸 → 网格占位

| 3d_size | 网格占位 (长×高) |
|---------|------------------|
| base | 2×1 |
| small | 1×1 |
| tall | 2×2 |
| small_tall | 1×2 |
| long | 4×1 |

### 2.2 邻接判定

两房间邻接 ⇔ 在布局网格上占位矩形**共边**（共享一条边，非仅对角）。

### 2.3 布局冻结

场景在设计时可变动，故在游戏开始时**预先计算并储存**邻接关系于存档；游戏开始后布局不再变更。

## 3. 数据模型

### 3.1 RoomInfo 扩展

| 字段 | 类型 | 说明 |
|------|------|------|
| unlocked | bool | 是否可被清理选中 |
| adjacent_ids | Array[String] | 邻接房间 id 列表 |
| grid_x | int | 布局网格 X |
| grid_y | int | 布局网格 Y |

### 3.2 配置

**game_base.json**
```json
"prologue_room_ids": ["room_00"]
```

**room_info.json**（每房间）
```json
"grid_x": 0,
"grid_y": 2
```

## 4. 存档

- `unlocked`、`adjacent_ids` 写入 rooms_data
- 新游戏：计算 adjacent_ids 后写入
- 读档：直接从存档恢复，不重算

## 5. 验证用例

### 5.1 游戏开始

| 房间 | 状态 |
|------|------|
| 档案馆核心 (room_00) | 已清理 + 已解锁 |
| 终端操作台、核心检修室、档案馆正厅、哲学文献室、制药研究室 | 已解锁、未清理 |
| 其余 | 未解锁 |

### 5.2 清理档案馆正厅后

新解锁：F1东侧楼梯间 (room_pass_0)

### 5.3 清理哲学文献室后

新解锁：F1东侧楼梯间 (room_pass_0)、异常基理教习室 (room_07)

## 6. 实现文件

| 文件 | 职责 |
|------|------|
| `scripts/editor/room_info.gd` | unlocked、adjacent_ids、grid_x、grid_y、size_3d |
| `scripts/game/room_layout_helper.gd` | 尺寸映射、邻接计算、开篇应用 |
| `scripts/game/room_info_loader.gd` | 从 room_info.json 加载 RoomInfo 数组 |
| `scripts/game/game_main_save.gd` | 持久化、ensure_layout_and_prologue |
| `scripts/game/game_main_cleanup.gd` | unlocked 判断、清理完成时解锁邻接 |
| `scripts/game/game_main_draw.gd` | 未解锁房间遮罩 |

## 7. grid 与 3D 场景同步

`scripts/tools/compute_grid_from_3d.py` 从 `archives_base_0.tscn` 读取各房间的 3D 位置，
按 room_volume 计算 grid_x、grid_y 并写回 `datas/room_info.json`。

调整 3D 场景布局后，运行该脚本可重新计算全部房间的 grid 坐标：

```
python scripts/tools/compute_grid_from_3d.py
```

## 8. 参考

- [01 - 档案馆房间信息](./01-archive_rooms_info.md)
- [02 - 房间尺寸与规范](./02-room-dimensions-and-specs.md)
- [04 - 房间清理系统](../2-gameplay/04-room-cleanup-system.md)

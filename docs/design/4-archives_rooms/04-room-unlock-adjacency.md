# 04 - 房间解锁与邻接系统

## 概述

本系统为房间清理功能提供**解锁状态**与**邻接关系**：开篇仅部分房间可清理；清理完成后解锁相邻房间。数据与运行时基于 **馆内布局格**（`room_info.json` 中的 `layout_cells` + 原点约定），与 3D 场景、UI 展示配合；**不**依赖历史上已废弃的「2D 大地图格」玩法。

## 1. 功能需求

### 1.1 解锁状态

| 状态 | 说明 |
|------|------|
| 已解锁 | 可被清理功能选中 |
| 未解锁 | 不可选中，显示黑色 60% 遮罩 |

### 1.2 初始状态（新游戏）

- **开篇房间**（如档案馆核心 `room_00`）：已清理 + 已解锁
- **开篇房间的邻接房间**：已解锁、未清理
- **其余房间**：未解锁

### 1.3 解锁规则

房间被清理完成后，其邻接房间中处于未解锁状态的变为已解锁。

## 2. 布局格与邻接（真源）

### 2.1 真源：`layout_cells`

- 每间房占用若干 **1×1 整数格**，在 **馆内坐标** 下列在 `layout_cells` 中，形如 `[[gx,gy], ...]`。
- **全局原点**：`room_00`（档案馆核心）**左下角**所占格为 `(0,0)`。JSON 中存的就是该坐标系下的格（由同步脚本从 `grid_x`/`grid_y`/`3d_size` 生成并平移得到）。
- **邻接判定**：两房相邻 **当且仅当** 存在各自格集中一格 `a`、`b`，满足 **曼哈顿距离为 1**（`|Δx|+|Δy|=1`）。**不**维护单独的「边列表」作为设计输入。
- **运行时缓存**：`adjacent_ids` 由上述规则 **计算** 后写入存档，便于现有清理逻辑；不得与 `layout_cells` 矛盾地当作第二真源。

### 2.2 无 `layout_cells` 时的回退

若某条数据暂无 `layout_cells`（例如极旧存档），运行时用 `grid_x`、`grid_y` 与 `3d_size` 按矩形展开占位，规则与下表一致。**新数据应以 `layout_cells` 为准。**

### 2.3 `3d_size` → 矩形展开尺寸（与 `RoomLayoutHelper.SIZE_TO_GRID` 一致）

| 3d_size | 占位 (宽×高，格) |
|---------|------------------|
| base | 2×1 |
| small | 1×1 |
| tall | 2×2 |
| small_tall | 1×2 |
| long | 4×1 |

### 2.4 布局冻结

游戏开始时若尚无邻接缓存，则根据 `layout_cells` **计算** `adjacent_ids` 并写入存档；读档时优先使用存档中的 `unlocked` / `adjacent_ids`，**不重算**邻接，以免覆盖进度。

## 3. 数据模型

### 3.1 `ArchivesRoomInfo` 相关字段（`scripts/core/room_info.gd`）

| 字段 | 类型 | 说明 |
|------|------|------|
| `layout_cells` | `Array`（`Vector2i` / 存盘为 `[[x,y],...]`） | 馆内布局格真源 |
| `grid_x`, `grid_y` | int | 与 3D/工具链对齐的锚点格；清理解锁以 `layout_cells` 优先 |
| `size_3d` | String | 与 3D 体量一致，用于回退展开 |
| `unlocked` | bool | 是否可被清理选中 |
| `adjacent_ids` | `Array[String]` | 由格相邻派生的邻接 id 列表（缓存） |

### 3.2 配置

**game_base.json**

```json
"prologue_room_ids": ["room_00"]
```

**room_info.json**（每房间，节选）

```json
"grid_x": -1,
"grid_y": 1,
"3d_size": "tall",
"layout_cells": [[0,0],[1,0],[0,1],[1,1]]
```

当前文件版本见顶层 `"version"`（布局格引入后为 3）。

## 4. 工具与校验

| 脚本 | 作用 |
|------|------|
| `tools/scripts/sync_room_info_layout_cells.py` | 按 `grid_x`/`grid_y`/`3d_size` 生成 `layout_cells`（馆内原点），并写入西侧竖井与西翼的网格修正 |
| `tools/scripts/validate_room_layout_cells.py` | 从 `layout_cells` 派生邻接，自 `room_00` BFS，断言全部带网格房间同一连通分量；失败时打印可读错误 |

仓库根目录执行示例：

```bash
python tools/scripts/sync_room_info_layout_cells.py
python tools/scripts/validate_room_layout_cells.py
```

## 5. 存档

- `unlocked`、`adjacent_ids`、`layout_cells`（若存在）等随 `rooms` 写入存档。
- 新游戏：`ensure_layout_and_prologue` 在邻接为空时调用 `RoomLayoutHelper.compute_adjacency`（格集语义）再应用开篇。
- 读档：直接恢复存档字段，不重算邻接。

## 6. 验证用例（玩法层）

### 6.1 游戏开始

| 房间 | 状态 |
|------|------|
| 档案馆核心 (room_00) | 已清理 + 已解锁 |
| 与 room_00 格相邻的房间 | 已解锁、未清理 |
| 其余 | 未解锁 |

### 6.2 清理档案馆正厅后

新解锁：与正厅格相邻的房间（含 F1 东侧楼梯间等，以当前 `layout_cells` 派生为准）。

## 7. 实现文件

| 文件 | 职责 |
|------|------|
| `scripts/core/room_info.gd` | `ArchivesRoomInfo`：`layout_cells`、持久化字段 |
| `scripts/editor/room_info.gd` | 兼容重导出，定义在 `core/room_info.gd` |
| `scripts/game/room_layout_helper.gd` | 占位展开、格相邻、`compute_adjacency`、`apply_prologue` |
| `scripts/game/room_info_loader.gd` | 从 `room_info.json` 加载（含 `layout_cells`） |
| `scripts/game/game_main_save.gd` | `ensure_layout_and_prologue`、存档 |
| `scripts/game/game_main_cleanup.gd` | 解锁邻接 |
| `scripts/core/save_manager.gd` | 从 `room_info` 生成新地图时的邻接计算 |

## 8. 历史附录（已非真源）

早期实现曾用 **`grid_x`/`grid_y` + `3d_size` 隐式矩形** 做 **矩形共边** 邻接判定。当前 **真源** 为 **`layout_cells` + 曼哈顿相邻**；矩形叙述仅用于理解回退路径或与旧脚本对照。

`scripts/tools/compute_grid_from_3d.py` 可从 3D 场景估算 `grid_x`/`grid_y`；生成馆内 `layout_cells` 的维护入口以 **`tools/scripts/sync_room_info_layout_cells.py`** 为准（调整网格后运行同步与校验）。

## 9. 参考

- [01 - 档案馆房间信息](./01-archive_rooms_info.md)
- [02 - 房间尺寸与规范](./02-room-dimensions-and-specs.md)
- [04 - 房间清理系统](../2-gameplay/04-room-cleanup-system.md)

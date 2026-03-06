# 03 - 3D 场景编辑器

## 概述

3D 场景编辑器（3D Scene Editor）是用于在 3D 空间中编辑档案馆室内场景的模块。与 2D 地图编辑器不同，本编辑器以 3D 格子为基本单位，支持放置、编辑 3D 元件（actor），并最终服务于建造模式与游戏运行时的场景呈现。

---

## 1. 基础设计：3D 格子

### 1.1 格子尺寸

在本 3D 场景编辑器的逻辑中，**一个 3D 格子**作为基础单位：

| 属性 | 值 | 说明 |
|------|-----|------|
| 格子尺寸 | 0.5m × 0.5m × 0.5m | 每格边长 0.5 米 |
| 体积换算 | 1 格子 = 0.125 m³ | 0.5³ |

### 1.2 坐标系约定（正常方向，须牢记）

| 轴 | 方向 | 说明 |
|----|------|------|
| **Z** | 朝屏幕外 | 纵深，负值为靠近相机（后方） |
| **X** | 朝右 | 长度 |
| **Y** | 朝上 | 高度 |

---

## 2. 元件盒（actor_box）组件

### 2.1 定位

- **用途**：可复用组件，挂载于「3D 元件」（3D actor）场景
- **职责**：定义元件的占用体积，并在编辑器中以网格线框形式可视化

### 2.2 体积值（volume）

| 属性 | 类型 | 说明 |
|------|------|------|
| `volume` | `Vector3` | 占用格子数 |
| `volume.x` | xR | 长（length），X 方向格子数 |
| `volume.y` | yR | 高（height），Y 方向格子数 |
| `volume.z` | zR | 宽（width），Z 方向格子数 |

### 2.3 尺寸换算

体积值（格子数）与等效 Cube 的 `scale` 关系：

```
scale = volume / 2
```

**示例**：体积 `(20, 10, 10)` → 等效 Cube `scale = (10, 5, 5)` → 实际尺寸 **10m × 5m × 5m**

| 体积 (xR, yR, zR) | scale (x, y, z) | 实际尺寸 (m) |
|-------------------|-----------------|--------------|
| (20, 10, 10)      | (10, 5, 5)      | 10 × 5 × 5   |
| (2, 2, 2)         | (1, 1, 1)       | 1 × 1 × 1    |

### 2.4 视觉呈现

填入体积值后，元件盒在视口中呈现为由**三个面**组成的**黑色**网格线框：

| 面 | 说明 |
|----|------|
| 底面 | 底部平面（XZ） |
| 左墙侧面 | YZ 平面，X 为负值 |
| 后方墙面 | XY 平面，Z 为负值 |

用于直观表示元件的占用范围，便于编辑时对齐与碰撞预判。

### 2.5 位置自动调整

元件盒在 root 节点下的 `position` 需随体积值自动调整，使底面贴合地面（Y=0）：

```
position = (x: 0, y: yR * 0.5 / 2, z: 0)
         = (x: 0, y: yR * 0.25, z: 0)
```

- **含义**：将元件盒几何中心抬升至高度的一半，使底面落在 Y=0
- **时机**：在编辑器中**实时**完成，调整体积值后立即生效

### 2.6 可见性

| 模式 | 元件盒是否显示 |
|------|----------------|
| 编辑器 | ✓ 显示 |
| 建造模式 | ✓ 显示 |
| 游戏进程（非建造） | ✗ 不显示 |

---

## 3. 实现要点

### 3.1 组件结构

```
actor_box (Node3D 或继承)
├── 体积属性 @export volume: Vector3
├── 网格 MeshInstance3D（底面 + 侧面 + 后面）
└── _update_from_volume()  # 体积变化时调用
```

### 3.2 编辑器实时更新

- 使用 `@export` 暴露 `volume`，在 Inspector 中修改时触发 `_property_list_changed` 或 `_validate_property`
- 或在 `_process` / `_physics_process` 中检测 `volume` 变化并调用 `_update_from_volume()`
- Godot 4 可使用 `set("volume", value)` 配合 `property_list_changed` 通知

### 3.3 挂载约定

- 元件盒作为子节点挂载于「3D 元件」场景的 root
- 3D 元件的 root 负责整体位移与旋转；元件盒仅负责自身 `position.y` 的自动抬升

---

## 4. 3D 元件场景模板（3d_actor）

### 4.1 定位

**3d_actor** 是可复用的 3D 元件场景模板。目标 workflow：

1. **复制**：在文件夹中复制 3d_actor 场景文件
2. **改名**：按元件命名（如 `table_wood_desk.tscn`）
3. **打开**：在编辑器中打开该场景
4. **编辑**：填入元件信息、体积、模型等
5. **使用**：即可作为可用 3D 元件参与场景编辑、建造与游戏逻辑

### 4.2 root 节点 transform

- **root 必须为 (0,0,0)**：3d_actor 场景内 root 的 transform 保持 identity
- **偏移在放置处设置**：在 preset_room_frame 或其它引用场景中，通过实例的 position 设置摆放位置

### 4.3 场景结构

```
3d_actor (Node3D, root, transform= identity)
├── ActorInfo (元件信息组件，可配置)
├── ActorBox (元件盒，自带)
└── ModelContainer (Node3D)     # 放置元件模型的容器
    ├── MeshInstance3D         # 元件模型（可选多个）
    ├── Light3D                # 元件自带光源（可选）
    └── AnimationPlayer        # 元件动画（可选）
```

### 4.4 元件信息（ActorInfo）

可配置组件，供编辑器与游戏逻辑识别元件。

| 属性 | 类型 | 说明 |
|------|------|------|
| `actor_id` | String | 元件 ID，格式 `type_name1_name2_..._index`，例：`table_wood_desk_0` |
| `display_name` | String | 元件名称（中文），**仅用于编辑器**；游戏内名称通过 `actor_id` 从元件表查询 |

**示例**：

| actor_id | display_name |
|----------|--------------|
| `table_wood_desk_0` | 木制书桌 |
| `lamp_floor_1` | 落地灯 |
| `bookshelf_metal_2` | 金属书架 |

### 4.5 模型容器（ModelContainer）

- **类型**：`Node3D`
- **用途**：放置元件的可视化内容，作为变换锚点
- **可挂载子节点**：
  - **MeshInstance3D**：元件 3D 模型（一个或多个）
  - **Light3D**：元件自带光源（如台灯、落地灯的光）
  - **AnimationPlayer**：元件动画（如开门、开关灯等）

### 4.6 元件盒（ActorBox）

- **来源**：3d_actor 模板**自带** actor_box 组件
- **位置**：挂载于 root 下，与 ActorInfo、ModelContainer 同级
- **线框颜色**：黑色
- **职责**：定义体积、网格线框、position 自动调整，见 [§2 元件盒（actor_box）](#2-元件盒actor_box组件)

### 4.7 工作流示意

```
scenes/actors/（或 resources/actors/）
├── 3d_actor.tscn          # 模板（勿直接使用）
├── table_wood_desk.tscn   # 复制 + 改名 + 编辑
├── lamp_floor.tscn
└── ...
```

### 4.8 与 2D 房间的类比

| 2D 地图编辑器 | 3D 场景编辑器 |
|---------------|----------------|
| room_info.json 中的房间模板 | 3d_actor 场景即元件模板 |
| 房间 ID（json_room_id） | 元件 ID（actor_id） |
| 房间名称 | display_name（仅编辑）/ 元件表名称（游戏内） |
| 房间底板占格 | actor_box 体积占格 |

---

## 5. 待实现

- [x] actor_box 组件脚本（`scripts/actors/actor_box.gd`）
- [x] 三面网格（底面、侧面、后面）的 Mesh 生成
- [x] 编辑器内 volume 变化时的实时 position 更新
- [x] 游戏运行时按模式控制可见性（建造模式显示，否则隐藏；默认游戏内不可见）
- [x] 3d_actor 场景模板（`scenes/actors/3d_actor.tscn`）
- [x] ActorInfo 组件（`scripts/actors/actor_info.gd`，actor_id、display_name）
- [x] 元件表（`datas/actor_table.json`，actor_id → name_zh/name_en）

---

## 相关文档

- [01 - 地图编辑器](01-map-editor.md)
- [02 - 房间信息与 room_info.json 同步](02-room-info-and-json-sync.md)
- [04 - 预设 3D 房间框架](04-preset-room-frame.md)
- [00 - 项目概览](../00-project-overview.md)

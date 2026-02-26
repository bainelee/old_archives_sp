# 13 - 游戏数值运行时系统

## 概述

本文档描述《旧日档案馆》中游戏数值的**运行时架构**：数据来源、加载方式、引用约定、热重载机制及同步工作流。设计层面的数值定义见 [08 - 游戏数值系统](08-game-values.md)。

---

## 1. 数据源与加载

### 1.1 权威数据源

| 文件 | 内容 | 加载器 |
|------|------|--------|
| `datas/game_values.json` | 消耗、产出、建设、清理、住房、改造 | GameValues (Autoload) |
| `datas/game_base.json` | 新游戏开局资源默认值 | SaveManager |

`docs/design/08-game-values.md` 为设计文档，**不打包进游戏**，游戏逻辑以 `game_values.json` 为唯一运行时数据源。

### 1.2 GameValues Autoload

- **路径**：`scripts/core/game_values.gd`
- **时机**：`_ready()` 时加载 JSON，之后所有 `get_*` 从内存读取
- **接口**：提供 `get_researcher_cognition_per_hour()`、`get_construction_cost()`、`get_cleanup_for_units()` 等

---

## 2. 数值引用方式

### 2.1 避免直接使用 GameValues 标识符

GDScript 语言服务器对 autoload 存在「未声明」误报。为消除 LSP 报错，使用 `GameValuesRef` + `preload`：

```gdscript
const _GameValuesRef = preload("res://scripts/core/game_values_ref.gd")

var gv: Node = _GameValuesRef.get_singleton()
if gv:
    var cost: Dictionary = gv.get_construction_cost(zone_type)
```

### 2.2 GameValuesRef

- **路径**：`scripts/core/game_values_ref.gd`
- **作用**：通过 `Engine.get_main_loop().root.get_node_or_null("GameValues")` 获取单例，避免直接引用 autoload 名称

### 2.3 引用 game_values 的脚本

| 脚本 | 用途 |
|------|------|
| `zone_type.gd` | 建设消耗、研究员数、每单位耗时 |
| `room_info.gd` | 清理花费、研究员、时间 |
| `game_main_built_room.gd` | 研究区/造物区产出、24h 消耗 |
| `construction_hover_panel.gd` | 建设悬停产出/消耗/住房显示 |
| `room_detail_panel.gd` | 房间详情面板产出/消耗显示 |

---

## 3. 修改数值后的同步

### 3.1 三种生效方式

| 方式 | 场景 | 说明 |
|------|------|------|
| **重启游戏** | 任意 | 启动时重新加载 JSON |
| **手动重载** | 开发/调试 | 调用 `GameValues.reload()` 立即生效 |
| **自动热重载** | 编辑器 F5 运行 | 每 2 秒检测文件变化，有变更则自动 `reload()` |

### 3.2 自动热重载

- **条件**：`OS.has_feature("editor_runtime")` 为 true（从编辑器 F5 运行）
- **间隔**：2 秒
- **机制**：比较 `game_values.json` 内容 hash，变化则重新解析并替换 `_data`
- **导出后**：不启用，因 `res://` 已打包进 PCK 无法修改

### 3.3 数值同步子代理

当用户表示「调整数值」「我调整了数值」等时，按 `.cursor/subagents/game-values-sync.md` 执行全量同步：

- 更新 `datas/game_values.json`、`datas/game_base.json`
- 同步 `docs/design/08-game-values.md` 及相关设计文档
- 确保脚本中的数值引用与 JSON 一致（脚本已全部改为引用，无需同步硬编码）

---

## 4. 数值键名对照

| 概念 | JSON 键 | 说明 |
|------|---------|------|
|  zone_type | 1, 2, 3, 4 | 1=研究区 2=造物区 3=事务所 4=生活区 |
| room_type | 0, 1, 2, 3, 5, 6 | 0=图书室 1=机房 2=教学室 3=资料库 5=实验室 6=推理室 |
| 因子 | cognition, computation, willpower, permission | 与 `00-project-keywords.md` 一致 |

---

## 5. 相关文档

- [08 - 游戏数值系统](08-game-values.md)（设计）
- [datas/README.md](../datas/README.md)（数据文件说明）
- [.cursor/subagents/game-values-sync.md](../../.cursor/subagents/game-values-sync.md)（数值同步工作流）

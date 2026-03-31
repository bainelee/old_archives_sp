# 02 - 游戏数值运行时系统

## 概述

本文档描述《旧日档案馆》中游戏数值的**运行时架构**：数据来源、加载方式、引用约定、热重载机制及同步工作流。设计层面的数值定义见 [01 - 游戏数值系统](01-game-values.md)。

---

## 1. 数据源与加载

### 1.1 权威数据源

| 文件 | 内容 | 加载器 |
|------|------|--------|
| `datas/game_values.json` | 基础经济与产出、改造 | GameValues (Autoload) |
| `datas/time_system.json` | 时间推进、日历、倍速 | GameValues -> GameTime |
| `datas/cleanup_system.json` | 清理需求 | GameValues |
| `datas/construction_system.json` | 建设需求、生产推进阈值 | GameValues |
| `datas/researcher_system.json` | 研究员认知/危机/住房、信息日结 `info_daily` | GameValues |
| `datas/erosion_system.json` | 侵蚀、治愈、死亡、灾厄 | GameValues |
| `datas/shelter_system.json` | 庇护等级、分配参数 | GameValues |
| `datas/game_base.json` | 新游戏开局资源默认值 | SaveManager |

`docs/design/0-values/01-game-values.md` 为设计文档，**不打包进游戏**。字段解释以 `datas/schemas/*.schema.json` 为准，完整索引见 `00-data-driven-index.md`。

### 1.2 GameValues Autoload

- **路径**：`scripts/core/game_values.gd`
- **时机**：`_ready()` 时加载 JSON，之后所有 `get_*` 从内存读取
- **接口**：提供 `get_researcher_cognition_per_hour()`、`get_construction_cost()`、`get_cleanup_for_units()`、`get_time_real_seconds_per_game_hour()` 等
- **Phase 2 契约说明**：`researcher_system.recruitment/housing_linkage`、`construction_system.zone_extensions` 已进入数据层；逻辑接入按系统迭代推进
- **Phase 2.5 访问层**：已提供只读 getter（如 `get_recruitment_config()`、`get_housing_linkage_config()`、`get_zone_extension_config()`），方便后续逻辑模块无缝接入
- **Phase 2.6 逻辑接入**：`construction_overlay.gd` 已根据 `zone_extensions.enabled` 过滤 5–8 区按钮；招募 UI 待实现后接入 `recruitment.enabled`

### 1.3 Autoload 依赖顺序

- **PersonnelErosionCore**、**GameTime** 在 `_ready()` 中从 GameValues 读取配置，故 GameValues 须已就绪。
- 当前 `project.godot` 顺序：LocaleManager → GameTime → ErosionCore → **GameValues** → PersonnelErosionCore → SaveManager。
- GameTime 早于 GameValues，依赖 `GameValues.ensure_loaded()` 触发首次加载；PersonnelErosionCore 晚于 GameValues，直接读取即可。
- 调整 autoload 顺序时，确保 **PersonnelErosionCore 在 GameValues 之后**。

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
| `room_detail_panel.gd` | 旧房间详情面板产出/消耗显示（若仍使用） |
| `room_detail_panel_figma.gd` | Figma 房间详情：四组消耗/产出、庇护数字与分配竖条（`get_shelter_energy_per_room_max` 等） |

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
- **机制**：比较各配置文件内容 hash，变化则调用 `reload()`，重新解析并替换内存数据
- **导出后**：不启用，因 `res://` 已打包进 PCK 无法修改

### 3.3 热重载后配置刷新（config_reloaded）

- **信号**：`GameValues.reload()` 成功后发出 `config_reloaded`
- **连接方**：PersonnelErosionCore、GameTime、construction_overlay 已连接该信号，热重载后自动刷新各自缓存的配置
- **按需读取**：zone_type、room_info、construction_hover_panel 等每次调用 getter 时从 GameValues 取数，热重载后下次调用即生效，无需特殊处理

### 3.4 运行时轻量校验（开发期）

- `GameValues` 在加载各 `datas/*.json` 后，会执行轻量结构校验（必填键与基础类型）。
- 校验只在 `editor_runtime` 下输出 `push_warning`，不会阻断游戏运行。
- warning 会标注类似 `time_system.calendar`、`game_values.creation_output.5` 的路径，便于快速定位配置问题。

### 3.5 数值同步子代理

当用户表示「调整数值」「我调整了数值」等时，按 `.cursor/subagents/game-values-sync.md` 执行全量同步：

- 更新 `datas/game_values.json`、`datas/game_base.json` 及拆分后的系统配置文件
- 同步 `docs/design/0-values/01-game-values.md` 及相关设计文档
- 确保脚本中的数值引用与 JSON 一致（避免新增硬编码）

---

## 4. 数值键名对照

| 概念 | JSON 键 | 说明 |
|------|---------|------|
|  zone_type | 1, 2, 3, 4 | 1=研究区 2=造物区 3=事务所 4=生活区 |
| room_type | 0, 1, 2, 3, 5, 6 | 0=图书室 1=机房 2=教学室 3=资料库 5=实验室 6=推理室 |
| 因子 | cognition, computation, willpower, permission | 与 `00-project-keywords.md` 一致 |

---

## 5. 相关文档

- [01 - 游戏数值系统](01-game-values.md)（设计）
- [datas/README.md](../../../datas/README.md)（数据文件说明）
- [.cursor/subagents/game-values-sync.md](../../../.cursor/subagents/game-values-sync.md)（数值同步工作流）

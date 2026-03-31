# 00 - 数据驱动配置索引

## 目标

本索引是 `datas/*.json` 与运行时代码的对照入口。  
字段解释以 `datas/schemas/*.schema.json` 为唯一来源（`description`）。

---

## 1) 配置文件总览

| 配置文件 | 作用域 | 主要读取入口 |
|------|------|------|
| `datas/game_values.json` | 基础经济与产出（因子上限、研究区/造物区产出、改造成本） | `scripts/core/game_values.gd` |
| `datas/game_base.json` | 新游戏开局资源、开局时间、序章房间 | `scripts/core/save_manager.gd` |
| `datas/time_system.json` | 时间推进、日历、倍速参数 | `scripts/core/game_values.gd` -> `scripts/core/game_time.gd` |
| `datas/cleanup_system.json` | 清理成本/耗时/研究员占用（按单位区间） | `scripts/core/game_values.gd` -> `scripts/editor/room_info.gd` |
| `datas/construction_system.json` | 建设成本/耗时（按 zone_type）+ 生产推进运行时阈值 | `scripts/core/game_values.gd` -> `scripts/core/zone_type.gd` / `scripts/game/game_main_built_room.gd` |
| `datas/researcher_system.json` | 研究员认知消耗、认知危机、住房参数、**信息日结**（`info_daily`） | `scripts/core/game_values.gd` -> `scripts/core/personnel_erosion_core.gd` / `scripts/game/game_main_shelter.gd` |
| `datas/erosion_system.json` | 侵蚀概率、治愈、死亡曲线、灾厄参数 | `scripts/core/game_values.gd` -> `scripts/core/personnel_erosion_core.gd` |
| `datas/shelter_system.json` | 庇护等级、能量上限、每级能量配置、不参与房型 | `scripts/core/game_values.gd` -> `scripts/game/game_main_shelter.gd` |
| `datas/room_size_config.json` | 房间尺寸类型（size_3d）→ volum、单位映射 | `scripts/core/game_values.gd` -> `scripts/editor/room_info.gd` |
| `datas/room_info.json` | 3D 房间清单、文案、资源与布局 | `scripts/game/room_info_loader.gd` |
| `datas/room_info_legacy.json` | 2D 编辑器模板房间数据 | `scripts/editor/map_editor_map_io.gd` / 工具脚本 |

---

## 2) Schema 对照

| Schema 文件 | 对应配置 | 说明 |
|------|------|------|
| `datas/schemas/game_values.schema.json` | `datas/game_values.json` | 基础经济与产出 |
| `datas/schemas/game_base.schema.json` | `datas/game_base.json` | 开局基础配置 |
| `datas/schemas/time_system.schema.json` | `datas/time_system.json` | 时间/日历/倍速 |
| `datas/schemas/cleanup_system.schema.json` | `datas/cleanup_system.json` | 清理参数 |
| `datas/schemas/construction_system.schema.json` | `datas/construction_system.json` | 建设与生产推进参数 |
| `datas/schemas/researcher_system.schema.json` | `datas/researcher_system.json` | 研究员基础参数 |
| `datas/schemas/erosion_system.schema.json` | `datas/erosion_system.json` | 侵蚀参数 |
| `datas/schemas/shelter_system.schema.json` | `datas/shelter_system.json` | 庇护参数 |
| `datas/schemas/room_size_config.schema.json` | `datas/room_size_config.json` | 房间尺寸→单位 |
| `datas/schemas/room_info.schema.json` | `datas/room_info.json` | 3D 房间数据 |
| `datas/schemas/room_info_legacy.schema.json` | `datas/room_info_legacy.json` | 2D 旧版模板数据 |

---

## 3) 迁移边界（Phase 1）

- 已迁移为独立配置：`time`、`cleanup`、`construction`、`researcher cognition`、`erosion`、`shelter`。
- `game_values.json` 保留“基础经济与产出”数据，避免一次性重构全部读写路径。
- `scripts/core/game_values.gd` 继续作为统一读取入口，对旧调用保持兼容 fallback。

---

## 4) Phase 2 契约（已定义，逐步接入）

- `datas/researcher_system.json`
  - 已新增 `housing_linkage`：无住房侵蚀倍率、无住房治愈跳过策略
  - 已新增 `recruitment`：招募开关、基础批次、进度与住房惩罚参数
- `datas/construction_system.json`
  - 已新增 `zone_extensions`：`5/6/7/8`（医疗/娱乐/宗教/奇观）预留建设与运行契约
- 当前状态：上述字段用于“数据契约固定”，逻辑代码可按模块迭代接入

---

## 4.1) Phase 2.6 最小逻辑接入（已完成）

- **`scripts/ui/construction_overlay.gd`**：建设区域按钮根据 `zone_extensions.enabled` 过滤。
  - 区域 1–4（研究/造物/事务所/生活）固定显示；
  - 区域 5–8（医疗/娱乐/宗教/奇观）仅在 `construction_system.json` 中对应 `enabled: true` 时显示。
- **招募**：`recruitment.enabled` 的 UI 过滤待招募入口实现后接入。
- **`scripts/core/personnel_erosion_core.gd`**：`housing_linkage` 已接入。
  - `no_housing_erosion_probability_multiplier`：无住房研究员的侵蚀概率倍率；
  - `no_housing_skip_cure_for_eroded`：无住房被侵蚀者是否跳过治愈判定。

---

## 5) 相关文档

- [04 - 实现审计与问题预测](04-implementation-audit.md)：已实现内容盘点、潜在问题与解决方案。

---

## 6) 变更规范

- 新增可调参数时：必须同步更新对应 `schema` 的 `description/default/range`。
- 若字段语义变化：对应配置文件 `version` 递增，并在设计文档记录迁移说明。
- 若调整数值：同时检查 `docs/design/2-gameplay/` 与 UI 文案是否需要同步。

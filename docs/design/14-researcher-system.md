# 14 - 研究员系统

## 概述

本文档将**研究员**作为独立系统进行策划与实现整理，汇总当前设定、已实现功能及待办事项。术语中英对照见 [00-project-keywords](../settings/00-project-keywords.md)。

相关文档分散于 [08 - 游戏数值系统](08-game-values.md)、[09 - 研究员侵蚀机制](09-researcher-erosion.md)、[10 - 房间清理系统](10-room-cleanup-system.md)、[11 - 区域建设功能](11-zone-construction.md)、[名词解释](../../名词解释.md) 等，本文档作为研究员系统的统一入口。

---

## 1. 设定汇总

### 1.1 基础定义

| 项目 | 说明 |
|------|------|
| 研究员 | 基础人员资源，参与生产、清理、建设 |
| 数据键 | `personnel.researcher`（总数）、`personnel.eroded`（被侵蚀数） |
| 初始数量 | 10 人（`datas/game_base.json` 的 `initial_resources.personnel.researcher`） |

### 1.2 消耗

| 类型 | 数值 | 来源 |
|------|------|------|
| 认知因子 | 每人每小时 1 认知，每人每天 24 认知 | [08-game-values §1](08-game-values.md#1-研究员认知消耗)、[09 §5](09-researcher-erosion.md#5-认知消耗与认知危机) |
| 认知不足 | 获得「认知危机」标记（上限 3），达上限则认知失能，每天 +10 灾厄值 | [09 §5.3](09-researcher-erosion.md#53-认知危机) |

### 1.3 产出

| 类型 | 数值 | 时机 |
|------|------|------|
| 信息因子 | 每人 1 信息 | 每天结束时 |

科研、房间类型等加成见后续设计。

### 1.4 住房

| 项目 | 说明 |
|------|------|
| 住房需求 | 1 名研究员需 1 住房 |
| 住房来源 | 宿舍建设**生活区**后提供住房，每个宿舍生活区提供 **4 住房** |
| **无住房惩罚** | 无住房的研究员：侵蚀判定概率 +10% |
| **无住房 + 被侵蚀** | 无住房的研究员若被侵蚀，**无法**通过在宿舍休息治愈，只能等待死亡或通过其他方式（待定） |

待实现：住房数量计算、无住房人数统计、侵蚀/治愈逻辑对接。

### 1.5 招募（设定存在，**未实现**）

| 项目 | 说明 |
|------|------|
| 机制 | 根据招募效率持续增加招募进度，100% 时招募新一批研究员 |
| 初始招募数量 | 20 人 |
| 数量减少条件 | 存在无住房研究员时降低 |
| 数量提升 | 部分科研可提高招募数量 |

### 1.6 侵蚀与治愈（设定完整，**已实现**）

详见 [09 - 研究员侵蚀机制](09-researcher-erosion.md)，摘要：

| 阶段 | 说明 |
|------|------|
| 侵蚀风险 | 每日在薄弱/暴露/绝境庇护下判定，命中获得侵蚀风险标记 |
| 侵蚀触发 | 每 7 天结算，标记超过 5 个则被侵蚀 |
| 被侵蚀状态 | 不工作，返回生活区宿舍，每小时 +1 灾厄值 |
| 死亡 | 被侵蚀时间过长，概率曲线约第 16 周 50%、第 20 周 100% |
| 治愈 | 宿舍庇护妥善/完美时，每 3 天判定（妥善 30%、完美 80%），治愈后 1 周免疫侵蚀；**无住房**的研究员**无法**被治愈 |

### 1.7 劳动力（预留，**暂未使用**）

当前版本仅使用研究员数量，劳动力由研究员按比例转化，为预留设计。劳动力分为空闲、临时占用、长期占用。

---

## 2. 研究员占用分类（已实现）

| 分类 | 说明 | 占用方式 | 数据来源 |
|------|------|----------|----------|
| 被侵蚀 | 不参与劳动 | 永久（直至治愈/死亡） | PersonnelErosionCore |
| 清理中 | 正在清理房间 | 临时占用，清理结束返还 | GameMainCleanupHelper |
| 建设中 | 正在建设区域 | 长期占用，建设完成后转为房间工作 | GameMainConstructionHelper |
| 房间工作 | 研究区/造物区/事务所已建设房间内 | 长期占用 | GameMainBuiltRoomHelper |
| 空闲 | 总数 − 以上四项 | 可被分配 | 计算得出 |

**空闲公式**：`空闲 = 总数 − 被侵蚀 − 清理中 − 建设中 − 房间工作`

---

## 3. 数值配置

### 3.1 数据源

| 文件 | 内容 |
|------|------|
| `datas/game_values.json` | `researcher_cognition`（每人每小时消耗）、`cleanup`（清理占用）、`construction`（建设占用）、`housing`（住房） |
| `datas/game_base.json` | `initial_resources.personnel.researcher`、`eroded` |
| `scripts/core/game_values.gd` | `get_researcher_cognition_per_hour()`、`get_cleanup_configs()`、`get_construction_researcher_count()` |

### 3.2 清理占用

| 房间单位 | 研究员占用 | 信息消耗 | 时长（小时） |
|----------|------------|----------|--------------|
| 3～5 | 2 | 20 | 3 |
| 6～7 | 3 | 40 | 5 |

### 3.3 建设占用

| 区域类型 | 研究员占用 | 占用方式 |
|----------|------------|----------|
| 研究区 | 2 | 建设时占用，建设完成后继续留在房间工作 |
| 造物区 | 2 | 同上 |
| 事务所 | 2 | 同上 |
| 生活区 | 1 | 同上 |

### 3.4 研究员产出与住房惩罚

| 项目 | 数值 | 说明 |
|------|------|------|
| 信息产出 | 每人每天 1 信息 | 每天结束时结算 |
| 宿舍生活区住房 | 每宿舍 4 住房 | 生活区建设于宿舍后提供 |
| 无住房侵蚀惩罚 | +10% | 在基础侵蚀概率上叠加 |
| 无住房不可治愈 | 是 | 被侵蚀且无住房的研究员跳过治愈判定 |

---

## 4. 已实现功能

### 4.1 PersonnelErosionCore（Autoload）

| 项目 | 说明 |
|------|------|
| 文件 | `scripts/core/personnel_erosion_core.gd` |
| 职责 | 侵蚀风险、被侵蚀状态、死亡、治愈、灾厄值、认知消耗 |
| 接口 | `initialize_from_personnel()`、`load_from_save_dict()`、`get_personnel()`、`to_save_dict()`、`register_cognition_provider()` |
| 信号 | `personnel_updated`、`calamity_updated` |
| 研究员个体 | 每人有 `id`、`erosion_risk`、`is_eroded`、`eroded_days`、`prev_room_id`、`immunity_days`、`cognition_crisis` |

### 4.2 数据流

| 环节 | 说明 |
|------|------|
| 新游戏 | `GameMainSaveHelper.apply_resources()` 用 `initial_resources.personnel` 调用 `PersonnelErosionCore.initialize_from_personnel()` |
| 读档 | `PersonnelErosionCore.load_from_save_dict()` 恢复研究员个体数据 |
| 认知消耗 | `PersonnelErosionCore` 通过 `register_cognition_provider` 从 UIMain 读取/扣除认知 |
| 人员同步 | `personnel_updated` → `game_main._on_personnel_updated()` → UIMain `set_resources()` |

### 4.3 UI

| 组件 | 说明 |
|------|------|
| TopBar 人员区 | 显示「空闲/总数」（如 8/10） |
| ResearcherHoverPanel | 悬停时显示：总数、被侵蚀、清理中、建设中、房间工作、空闲 |
| 清理/建设悬停 | 显示「研究员占用 X 人（可用 Y）」 |

### 4.4 占用同步

| 系统 | 方法 | 说明 |
|------|------|------|
| 清理 | `_sync_cleanup_researchers_to_ui()` | 每帧设置 `UIMain.researchers_in_cleanup` |
| 建设 | `_sync_construction_researchers_to_ui()` | 每帧设置 `UIMain.researchers_in_construction` |
| 房间工作 | `_sync_researchers_working_in_rooms_to_ui()` | 遍历已建设房间累加 |

### 4.5 存档

| 字段 | 说明 |
|------|------|
| `resources.personnel` | `researcher`、`labor`、`eroded`、`investigator` |
| `personnel_erosion` | `researchers`（个体数据）、`calamity`、`next_id`、`investigator` |

---

## 5. 待实现 / 待完善

### 5.1 住房约束

- [ ] 住房数量计算（根据生活区宿舍统计，每宿舍生活区 4 住房）
- [ ] 研究员个体住房状态：有住房 / 无住房
- [ ] 无住房研究员侵蚀判定 +10% 概率
- [ ] 无住房被侵蚀研究员不可治愈（治愈判定时跳过）
- [ ] 招募数量受住房影响的逻辑

### 5.2 招募系统

- [ ] 招募进度与招募效率
- [ ] 招募周期与批次数量
- [ ] 科研对招募效率/数量的加成

### 5.3 研究员个体与房间分配

- [ ] 研究员与工作房间的绑定（`prev_room_id` 已存，治愈返回逻辑待与房间系统对接）
- [ ] 宿舍庇护等级按房间计算（当前 PersonnelErosionCore 使用全局 `ErosionCore.current_erosion`）
- [ ] 侵蚀判定按研究员所在房间庇护等级

### 5.4 劳动力系统（可选）

- [ ] 研究员 → 劳动力的转化比例
- [ ] 劳动力不足 / 严重不足对房间产出的影响

### 5.5 信息产出

- [ ] 每人每天结束时 +1 信息（基础公式已定）
- [ ] 与科研、房间类型的联动（加成待设计）

---

## 6. 核心文件索引

| 类型 | 文件 |
|------|------|
| 侵蚀核心 | `scripts/core/personnel_erosion_core.gd` |
| 数值 | `scripts/core/game_values.gd`、`datas/game_values.json` |
| 游戏主逻辑 | `scripts/game/game_main.gd`、`game_main_cleanup.gd`、`game_main_construction.gd`、`game_main_built_room.gd`、`game_main_save.gd` |
| UI | `scripts/ui/ui_main.gd`、`scripts/ui/researcher_hover_panel.gd` |
| 房间 | `scripts/editor/room_info.gd`（`get_cleanup_researcher_count()`、`get_construction_researcher_count()`） |
| 区域类型 | `scripts/core/zone_type.gd` |

---

## 7. 相关文档

- [08 - 游戏数值系统](08-game-values.md)（认知消耗、清理、建设、住房）
- [09 - 研究员侵蚀机制](09-researcher-erosion.md)
- [10 - 房间清理系统](10-room-cleanup-system.md)
- [11 - 区域建设功能](11-zone-construction.md)
- [12 - 已建设房间系统](12-built-room-system.md)
- [名词解释：研究员](../../名词解释.md#研究员)

# 08 - 研究员系统

## 概述

本文档将**研究员**作为独立系统进行策划与实现整理，汇总当前设定、已实现功能及待办事项。术语中英对照见 [00-project-keywords](../../settings/00-project-keywords.md)。

相关文档分散于 [01 - 游戏数值系统](../0-values/01-game-values.md)、[07 - 研究员侵蚀机制](07-researcher-erosion.md)、[04 - 房间清理系统](04-room-cleanup-system.md)、[05 - 区域建设功能](05-zone-construction.md)、[名词解释](../../名词解释.md) 等，本文档作为研究员系统的统一入口。

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
| 认知因子 | 每人每小时 1 认知，每人每天 24 认知 | [01-game-values §1](../0-values/01-game-values.md#1-研究员认知消耗)、[07 §5](07-researcher-erosion.md#5-认知消耗与认知危机) |
| 认知不足 | 获得「认知危机」标记（上限 3），达上限则认知失能，每天 +10 灾厄值 | [07 §5.3](07-researcher-erosion.md#53-认知危机) |

### 1.3 产出（信息 · 货币）

信息指 TopBar **货币** `currency.info`（非四条因子）。**研究员日结信息**在**每个游戏日结束时**按**个体**结算一次；**已被神秘侵蚀**的研究员**不参与**本产出（产出 **0**），与 [07](07-researcher-erosion.md)「被侵蚀者不工作」一致。

**口径区分**：
- **侵蚀/治愈口径**：沿用 [07 §1.1 庇护等级与工作/住房分配](07-researcher-erosion.md#11-庇护等级与工作住房分配) 的 `has_no_housing`（**有工作但无分配住房**）。
- **信息日结口径**：只要**未分配住房**即视为无住房扣减（**不区分是否有工作**）。

**单名研究员、未侵蚀**时的日结公式：

1. 基础：**+3** 信息。
2. 若处于 **无住房** 状态：**−1** 信息。
3. 若处于 **认知危机** 状态（见 [07 §5.3 认知危机](07-researcher-erosion.md#53-认知危机)，当日用于结算时 **认知危机标记数 ≥ 1**）：**−1** 信息。
4. 在 **未被侵蚀** 的前提下，当日实际获得 **`max(1, 基础 + 修正)`**，即**至少 +1 信息/游戏日**。

说明：若未来增加其他日结修正项，仍保留上述 **未侵蚀保底 1** 的规则（除非文档另有修订）。

科研、房间类型等对信息产出的**加成**见后续设计（在基础日结之上叠加）。

### 1.4 住房

| 项目 | 说明 |
|------|------|
| 住房需求 | 1 名研究员需 1 住房 |
| 住房来源 | 宿舍建设**生活区**后提供住房，每个宿舍生活区提供 **4 住房** |
| **无住房惩罚** | 有工作但无住房的研究员：侵蚀判定概率 **×2** |
| **无住房 + 被侵蚀** | 无住房的研究员若被侵蚀，**无法**治愈，治愈判定时跳过 |

住房分配：按研究员 id 或优先级将住房槽位分配给研究员，超出总住房数的研究员为无住房。

### 1.5 招募（设定存在，**未实现**）

| 项目 | 说明 |
|------|------|
| 机制 | 根据招募效率持续增加招募进度，100% 时招募新一批研究员 |
| 初始招募数量 | 20 人 |
| 数量减少条件 | 存在无住房研究员时降低 |
| 数量提升 | 部分科研可提高招募数量 |

### 1.6 侵蚀与治愈（设定完整，**已实现**）

详见 [07 - 研究员侵蚀机制](07-researcher-erosion.md)，摘要：

| 阶段 | 说明 |
|------|------|
| 侵蚀风险 | 每日在薄弱/暴露/绝境庇护下判定，命中获得侵蚀风险标记 |
| 侵蚀触发 | 每 7 天结算，标记超过 5 个则被侵蚀 |
| 被侵蚀状态 | 不工作，返回生活区宿舍，每小时 +1 灾厄值 |
| 死亡 | 被侵蚀时间过长，概率曲线约第 16 周 50%、第 20 周 100% |
| 治愈 | 宿舍庇护妥善/完美时，每 3 天判定（妥善 30%、完美 80%），治愈后 1 周免疫侵蚀；**无住房**的研究员跳过治愈判定 |

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

### 3.4 研究员信息日结与住房惩罚

| 项目 | 数值 | 说明 |
|------|------|------|
| 信息日结基础 | 每名**未侵蚀**研究员 **+3/游戏日** | 游戏日结束时按个体结算 |
| 无住房修正 | **−1** | 状态定义见 **无住房**（[07 §1.1](07-researcher-erosion.md#11-庇护等级与工作住房分配)） |
| 认知危机修正 | **−1** | 认知危机标记 ≥ 1 时（[07 §5.3](07-researcher-erosion.md#53-认知危机)） |
| 未侵蚀保底 | 实际入账 **`max(1, 3 + 修正)`** | 被侵蚀者不参与日结，产出 **0** |
| 宿舍生活区住房 | 每宿舍 4 住房 | 生活区建设于宿舍后提供 |
| 无住房侵蚀惩罚 | ×2 | 有工作但无住房时，侵蚀判定概率加倍（与信息修正独立） |
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

### 4.6 研究员 3D 可视化（已实现）

| 项目 | 说明 |
|------|------|
| 场景 | `scenes/actors/researcher_3d.tscn` |
| 脚本 | `scripts/actors/researcher_3d.gd` |
| 模型 | `assets/meshes/characters/test_archives_chara.glb`（纸片风格，无骨骼无动画） |
| 生成 | 游戏加载时 `game_main._setup_researchers()` 在档案馆核心 room_00 生成 `personnel.researcher` 数量的 3D 实例 |

**行为**：
- 地面约束：`position.y` 固定为 floor_y（0.5），仅在地面 XZ 平面移动
- 周期性移动：每 3～8 秒随机选目标，速度上限 2 m/s，Tween 插值移动
- 防重叠：选目标时距离 ≥ 0.6m；移动中若正在靠近他人则中止本次移动
- 纸片朝向：仅朝左或朝右（`rotation.y` 为 0 或 PI），斜向移动时不偏转
- 行走摇摆：移动时 Z 轴正弦摇摆模拟步伐，幅度 1°～3° 随机，频率 1～2.5 Hz

**与 PersonnelErosionCore 的关系**：每个 3D 实例通过 `researcher_id` 与 PersonnelErosionCore 的研究员一一对应；由 ResearcherLifecycle 按游戏时间驱动阶段并调用 `apply_phase` / `teleport_to_room_id`。

### 4.7 研究员生活周期（已实现）

| 项目 | 说明 |
|------|------|
| 脚本 | `scripts/game/researcher_lifecycle.gd`（ResearcherLifecycle 节点，挂于 GameMain 下） |
| 驱动 | 订阅 GameTime.time_updated，按当前小时与 work_room_id / housing_room_id 计算阶段 |
| 时段 | 工作 8–16、游荡 16–20、回居住区 20–22、睡眠 22–6、前往工作间 6–8；无工作/无住房时仅游荡或原地睡眠 |
| 优先级 | 清理/建设中的研究员优先阶段 CLEANUP/CONSTRUCTION 并传送到目标房间；分配工作即传送 |
| 可游荡房间 | room_00（核心）+ 已解锁且已清理的房间 |

### 4.8 研究员头顶 Emoji（已实现）

| 项目 | 说明 |
|------|------|
| 资源 | `assets/icons/emoji/icon_emoji_*.png`（idle, walking, happy, good, clean, build, work, confuse, talk, erosion, erosion_danger, no_house, heal） |
| 节点 | researcher_3d.tscn 下 EmojiAnchor + EmojiHead（Sprite3D），头顶 +1.5，scale 0.4，Billboard |
| 脚本 | `scripts/actors/researcher_emoji.gd`：0.15s 出现（Y 拉伸）/ 消失（缩小）；按状态选图 |
| 状态 | 持续 walking；2s 真实时间 clean/build/work；0.8s idle/happy/good；4s 周期随机（含 no_house/eroded/heal 等） |
| 驱动 | ResearcherLifecycle 在 apply_phase 后调用 Researcher3D.set_emoji_state(flags) |

### 4.9 研究员列表与详情 UI（已实现）

| 项目 | 说明 |
|------|------|
| 入口 | TopBar 下方右侧「研究员」按钮，点击展开/关闭面板 |
| 列表 | 按 id 升序，每行 id + 名称（暂为「研究员 N」）；点击行 → 摄像机聚焦该研究员 + 切到详情 Tab |
| 详情 | 展示 id、名称、当前状态、工作区、居住区、被侵蚀概率、回复概率、每小时消耗认知、信息产出；返回按钮回列表 |
| 镜头 | GameMainCameraHelper.focus_camera_on_researcher(game_main, researcher_id)；GameMain.get_researcher_detail(researcher_id) 供详情绑定 |
| 场景/脚本 | `scenes/ui/researcher_list_panel.tscn`、`scripts/ui/researcher_list_panel.gd` |

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

- [ ] `work_room_id`、`housing_room_id`：工作与住房房间绑定
- [ ] 庇护等级按工作/住房取用（见 07 §1.1）
- [ ] 宿舍庇护等级按房间计算（核心分配庇护能量至房间）

### 5.4 劳动力系统（可选）

- [ ] 研究员 → 劳动力的转化比例
- [ ] 劳动力不足 / 严重不足对房间产出的影响

### 5.5 信息产出（日结）与信息详情 UI

**数值与时机（相对 §1.3 / §3.4）**

- [x] 游戏日边界触发日结：对每名 **`is_eroded == false`** 的研究员按配置计算后累加并写入 `currency.info`；被侵蚀者跳过（`PersonnelErosionCore._run_daily_logic` 开头 + `GameMain._register_info_grant_provider`）。
- [x] 配置项位于 `datas/researcher_system.json` 的 `info_daily`（`per_researcher_base`、`penalty_no_housing`、`penalty_cognition_crisis`、`minimum_if_not_eroded`），由 `GameValues` 读取；索引见 [00-data-driven-index](../0-values/00-data-driven-index.md)。
- [ ] 与科研、房间类型的联动加成（在日结基础之上叠加，待设计）。

**信息详情 UI · 细则条目（必做，已实现汇总 + 推理室满负荷理论行）**

研究员日结产出的信息须在 **TopBar → 信息 → 信息详情面板** 中展示，版式遵循预设计文档（与实现 `scripts/ui/information_details_panel.gd`、`scenes/ui/information_details_panel.tscn` 一致）：

- 面板结构：**信息产出**（章节标题 + **总产出/游戏日** 同行）→ **细则条目**（灰色背景行：`产出来源` + `数量`）→ … → **信息储量**。版式与条目层级见 [ui-detail-panel-design.md § 信息相关详细信息](../../predesign/ui-detail-panel-design.md)（文内「信息相关详细信息」小节）。
- **DataProvider**（`DataProviders.get_information_breakdown()` 的 `output` 数组）须包含研究员相关条目，例如：
  - **汇总行（已实现 · 方案 A）**：`source` 为翻译键 `INFO_BREAKDOWN_RESEARCHER_DAILY`，`amount` 为 **`get_researcher_daily_info_theoretical_total()`**（按**当前**研究员状态计算的「下一游戏日」理论总和）；与**上一日实际入账**可能因跨日瞬间状态变化略有差异。
  - **可选扩展**：在汇总之下再按研究员 `id` 各增一行细则（`研究员 #3` + `+2` 等），便于玩家理解无住房/认知危机扣减；若性能或版面受限，可仅保留汇总行，扣减原因在研究员详情中解释。
- 推理室造物区、探索奖励等其他信息来源继续作为 **信息产出** 下的独立细则条目，与研究员条目并列，共同计入章节标题旁的总产出数值。

---

## 6. 核心文件索引

| 类型 | 文件 |
|------|------|
| 侵蚀核心 | `scripts/core/personnel_erosion_core.gd` |
| 3D 可视化 | `scripts/actors/researcher_3d.gd`、`scenes/actors/researcher_3d.tscn`、`scripts/actors/researcher_emoji.gd` |
| 生活周期 | `scripts/game/researcher_lifecycle.gd` |
| 数值 | `scripts/core/game_values.gd`、`datas/game_values.json`、`datas/researcher_system.json`（含 `info_daily`） |
| 信息详情数据 | `scripts/core/data_providers.gd`（`get_information_breakdown`） |
| 游戏主逻辑 | `scripts/game/game_main.gd`、`game_main_cleanup.gd`、`game_main_construction.gd`、`game_main_built_room.gd`、`game_main_save.gd`、`game_main_camera.gd` |
| UI | `scripts/ui/ui_main.gd`、`scripts/ui/researcher_hover_panel.gd`、`scripts/ui/researcher_list_panel.gd` |
| 房间 | `scripts/editor/room_info.gd`（`get_cleanup_researcher_count()`、`get_construction_researcher_count()`） |
| 区域类型 | `scripts/core/zone_type.gd` |
| 庇护/空闲 id | `scripts/game/game_main_shelter.gd`（`get_free_researcher_ids()`、`enrich_researcher_with_rooms()`） |

---

## 7. 相关文档

- [01 - 游戏数值系统](../0-values/01-game-values.md)（认知消耗、清理、建设、住房）
- [07 - 研究员侵蚀机制](07-researcher-erosion.md)（**无住房**、认知危机、被侵蚀行为）
- [04 - 房间清理系统](04-room-cleanup-system.md)
- [05 - 区域建设功能](05-zone-construction.md)
- [06 - 已建设房间系统](06-built-room-system.md)
- [名词解释：研究员](../../名词解释.md#研究员)
- [详细信息界面详解（预设计）](../../predesign/ui-detail-panel-design.md)（「信息相关详细信息」：产出章节 + 灰色背景细则行）
- [因子详情面板总结](../../predesign/ui-detail-panel-summary.md)（信息详情面板路径与 Figma 70:1154）

# 05 - 房间详细信息界面（Figma 同步）开发状态

## 概述

本文档用于明确 `room_detail_panel_figma` 的当前实现范围，并区分「已开发」与「未开发/占位」内容。  
对应 Figma 节点：`139:747`（fileKey `ndfJ5hiWy9b4iq5JNuZwSJ`）。

---

## 1. 相关文件

| 类型 | 路径 | 说明 |
|------|------|------|
| 主场景 | `scenes/ui/room_detail_panel_figma.tscn` | 房间详情面板（560x840） |
| 主脚本 | `scripts/ui/room_detail_panel_figma.gd` | show/hide、动态刷新、四组数据注入 |
| 信息条目组件 | `scenes/ui/components/room_details_info_entry.tscn` | `group_single_info_entry` 复用组件 |
| 信息条目脚本 | `scripts/ui/components/room_details_info_entry.gd` | icon/name/value 渲染 |
| 信息组组件 | `scenes/ui/components/room_details_info_group.tscn` | 四个 info group 共用组件 |
| 信息组脚本 | `scripts/ui/components/room_details_info_group.gd` | 标题+4条条目渲染、按变化刷新 |
| 底部按钮组件 | `scenes/ui/components/room_details_action_button.tscn` | 拆除/关停统一按钮组件 |
| 底部按钮脚本 | `scripts/ui/components/room_details_action_button.gd` | nor/press 状态与 icon/文案配置 |
| 资源映射文档 | `docs/design/100-figma_process/03-room-detail-panel-figma-assets.md` | Figma node 与本地资源映射 |

---

## 2. 功能状态总览

### 2.1 已开发

| 模块 | 状态 | 说明 |
|------|------|------|
| 面板挂载与入口 | 已开发 | `game_main.gd` 优先调用 `RoomDetailPanelFigma`，保留旧 `RoomDetailPanel` 回退 |
| 面板定位 | 已开发 | 固定在右上区域：距右 40px、距上 148px |
| 顶部栏基础结构 | 已开发 | icon/frame、标题、类型、关闭按钮已接入 |
| 顶部栏文案排版逻辑 | 已开发 | 类型文案位于名称右侧，按文本宽度动态排版并做右侧边界限制 |
| 图片区/描述区 | 已开发 | 图片框与描述框已接入；描述区为滚动容器（超长可滚动） |
| 四个信息组复用化 | 已开发 | `fixed/reserve/dynamic/output` 四组共用同一 `room_details_info_group` 组件 |
| 信息条目复用化 | 已开发 | 条目统一使用 `room_details_info_entry`（icon/name/value） |
| 底部按钮复用化 | 已开发 | 拆除/关停使用同一 `room_details_action_button` 组件，仅配置图标与文案差异 |
| 按钮 nor/press 状态映射 | 已开发 | 将同名前缀的 nor/press 作为同一按钮不同状态资源 |
| 技能按钮布局规则 | 已开发（视觉层） | 支持最多 4 个，从最右向左排列；当前默认展示 2 个占位 |
| 改造槽位显示规则 | 已开发（基础） | 支持最多 3 个，当前默认 1 个显示，其余隐藏 |
| 文本颜色规则 | 已开发 | title/desc/info group 为黑字，最顶部 bar 为白字 |
| 动态刷新防抖 | 已开发 | 使用 hash 对比，仅在数据变化时刷新，避免每帧重建 |
| 本地化键补齐 | 已开发 | 新增 `LABEL_DYNAMIC_CONSUMPTION` |

### 2.2 已接入（本轮）

| 模块 | 状态 | 说明 |
|------|------|------|
| 拆除按钮业务逻辑 | 已开发 | 点击调用 `GameMain.request_demolish_room()`，清除 `zone_type` 并返还研究员 |
| 关停按钮业务逻辑 | 已开发 | 点击调用 `GameMain.toggle_room_forced_shutdown()`，文案在"关停/恢复"之间切换 |
| 技能按钮业务逻辑 | 已开发 | 按房间状态动态生成技能列表（聚焦、关停切换），绑定点击行为与 disabled/tooltip |
| 改造槽位真实数据源 | 已开发 | 读取 `room.remodel_slot_count`（正式模型字段，1~3） |
| 左侧庇护展示（数字 + 竖条） | 已开发 | 见本文 [§7](#7-庇护展示区左侧竖条与数字)；数字与竖条数据源不同，均接运行时庇护系统 |
| info group 图标动态映射 | 已开发 | 资源类型→icon 映射（认知/计算/意志/权限/信息），建设消耗 key→icon 映射 |
| 固有消耗组完整定义 | 已开发 | 包含：人员占用数量、建设消耗（信息/权限等）、造物区每小时意志消耗 |

### 2.3 未开发/占位

| 模块 | 状态 | 说明 |
|------|------|------|
| 顶部栏超长文案策略精修 | 部分未开发 | 已做右侧限制与裁切，未做完整多语言排版规范（如最小间距/截断符统一） |

---

## 3. 设计约束（执行中）

1. 四个信息组必须同构，禁止四套独立场景结构复制。  
2. `group_single_info_entry` 必须使用单独组件维护。  
3. 同名按钮的 `nor/press` 视为同一按钮状态，不得拆成两个业务按钮。  
4. 描述区文本必须可滚动，不允许撑开外框。  
5. 编辑器可见逻辑不得写在 `_ready()`（遵守预制作 UI 规范）。

---

## 4. 已知限制与风险

- 新旧面板并存阶段，若后续脚本改动只改旧面板，可能出现显示不一致。  
- 顶部栏中英文混排长度差异大，仍需在真实长文本下做视觉回归检查。  
- 当前部分功能为视觉占位，文档与代码必须同步维护，防止误判为已接业务。

---

## 5. 固有消耗组（fixed overhead）定义

**固有消耗**显示当前房间因建设区域而产生的**不随时间/状态波动的固定开销**。

### 5.1 条目构成

| 条目 | 来源 | 何时显示 | 示例 |
|------|------|----------|------|
| **人员占用** | `room.get_construction_researcher_count(zone_type)` | `zone_type != 0` | 2 名研究员 |
| **固有意志消耗** | 常量（`24/天`） | `zone_type != 0` | 意志 -24/天 |

> 说明 1：**建设消耗**（信息/权限等）不属于固有消耗，不在 fixed 组显示。  
> 说明 2：所有已建设区域都带有固有意志消耗 `24/天`，并在运行时优先于其它消耗结算。  
> 说明 3：**造物区每小时意志消耗**归类为「动态消耗」，显示在 `dynamic overhead` 组。  
> 说明 4：人员口径为“区域长期占用人力”。实现上建设完成后先释放建设占用人力，再以同数量重新占用到区域工作。

### 5.2 未建设时

若 `zone_type == 0`（未建设），固有消耗组仅显示一条占位「（未建设）」。

### 5.3 图标规则

| 条目类型 | 图标 |
|----------|------|
| 人员占用 | `icon_researcher.png` |
| 信息 | `icon_infomation.png` |
| 权限 | `icon_permission.png` |
| 认知 | `icon_cognition.png` |
| 计算 | `icon_computing_power_white.png` |
| 意志 | `icon_willpower.png` |
| 其他 | `icon_questions.png`（兜底） |

---

## 6. 后续建议（按优先级）

1. 补一组 UI 回归用例（中文/英文长文案、超长房间名、0/1/3 改造槽）。
2. 顶栏多语言排版精修（最小间距、截断符统一）。
3. 新旧面板并存策略收口。

---

## 7. 庇护展示区（左侧竖条与数字）

与 TopBar 因子详情里的「庇护能量出力/缺口」三段条**不是同一套 UI**。本节仅描述房间详情面板左侧「庇护」标签旁的**数值标签**与**竖向进度条**。

### 7.1 语义区分（设计约定）

| 控件 | 含义 | 说明 |
|------|------|------|
| **上方数字**（`text_shelter_value`） | **当前房间庇护数值**（庇护等级） | 与 [`01-game-values` §2.5](../0-values/01-game-values.md#25-房间庇护等级公式) 一致：`ErosionCore.current_erosion + 本房分配庇护能量`；可为负（薄弱/暴露/绝境等档位），**不做 0～5 截断显示**。 |
| **竖条填充**（`room_shelter_progress_inside`） | **本房获得的庇护能量（分配量）** | 与数字自洽：`clamp(房间庇护等级 - 全局有效侵蚀, 0, energy_per_room_max)`；**节点挂在 `room_shelter_progress_back` 下**，用相对槽底的 **本地 `position`/`size`** 更新，避免 `PanelRoot`（`layout_mode=3`）对顶层子控件排序覆盖条高度。 |

### 7.2 实现与数据流

- **脚本**：`scripts/ui/room_detail_panel_figma.gd` → `_update_shelter_visual()`。
- **API**：
  - 数字：`GameMainShelterHelper.get_room_shelter_level(game_main, room_id)`。
  - 全局基线（与数字同源）：`get_shelter_baseline_erosion()`（即 `ErosionCore.current_erosion`）。
  - 竖条比例：由 `等级 - 基线` 反推分配量，与 tick 写入的 `_room_shelter_energy` 在一致状态下相同；避免仅读字典时与布局刷新不同步导致条、数不一致。
- **刷新**：打开面板时更新；因 `show_room` 常在 `_input` 中早于 `GameMain._process` 的 `process_shelter_tick`，首帧 `_room_shelter_energy` 可能仍空，故在 `visible = true` 后 **`call_deferred("_update_shelter_visual")`**，在本帧 `_process`（含 tick）之后再画一次条/数。面板可见期间若动态 hash 变化，仍会 `_refresh_dynamic_data()` 并 `_update_shelter_visual()`。

### 7.3 handle 手动操控规则（已接入）

- **交互方式**：玩家可在房间详情中拖动左侧 `room_shelter_handle`（或其背景槽）调整该房手动目标值。
- **提交时机**：拖动中仅预览；**松手提交**到运行时分配器。
- **数值粒度**：整数步长 `1`，范围 `0..energy_per_room_max`。
- **总量限制**：采用**严格总量限制**。拖动上限由当前总可分配量减去其它手动锁定值决定，handle 到上限后硬停止。
- **冲突处理**：若手动锁定总和超过本 tick 可分配总量，按比例缩放并向下取整，余量丢弃。
- **房间失效**：房间不再需要庇护（拆除/未建设/不在需求列表）时，自动清除该房手动目标值。
- **上限变更**：`energy_per_room_max` 变化时，清空全部手动目标值。

### 7.4 存档

- 手动目标值写入 `erosion.manual_room_shelter_targets`（`room_id -> int`）。
- 读档后恢复该字典并参与后续 `process_shelter_tick` 分配。

### 7.5 与数值文档的关系

庇护能量产出、分配规则、每房上限见 [`docs/design/0-values/01-game-values.md` §2](../0-values/01-game-values.md#2-档案馆核心庇护能量与计算因子消耗)。

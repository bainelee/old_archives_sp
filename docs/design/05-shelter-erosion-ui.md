# 05 - 庇护/侵蚀 UI

## 概述

本文档记录《旧日档案馆》项目中**庇护与侵蚀 UI** 的设计与实现，包括可复用的 ShelterErosionPanel、ErosionCycleBar 以及 ErosionCore 数据源。

---

## 1. 组件概览

| 组件 | 路径 | 职责 |
|------|------|------|
| **ErosionCore** | `scripts/core/erosion_core.gd` | 侵蚀数据源（Autoload），提供当前等级与未来 3 个月预测 |
| **ShelterErosionPanel** | `scenes/ui/shelter_erosion_panel.tscn` | 可复用面板：左侧当前侵蚀，右侧周期长条 |
| **ErosionCycleBar** | `scripts/ui/erosion_cycle_bar.gd` | 长条形侵蚀变化周期标识，不同颜色图元随时间向左滚动 |

---

## 2. 侵蚀等级与变化类型

### 侵蚀等级（名词解释）

| 等级 | 数值 | 说明 |
|------|------|------|
| 隐性 | +1 | 几乎不存在侵蚀 |
| 轻度 | 0 | 轻微的侵蚀 |
| 显性 | -2 | 明显的侵蚀 |
| 涌动阴霾 | -4 | 剧烈的侵蚀 |
| 莱卡昂的暗影 | -8 | 无休止的侵蚀风暴 |

### 图元颜色与侵蚀数值对应

| 侵蚀数值 | 颜色 | 等级 |
|----------|------|------|
| +1 | 白色 | 隐性侵蚀 |
| 0 | 翠绿 | 轻度侵蚀 |
| -2 | 橙黄 | 显性侵蚀 |
| -4 | 赤红 | 涌动阴霾 |
| -8 | 深紫 | 莱卡昂的暗影 |

---

## 3. 周期长条行为

- **时间跨度**：未来 3 个月（90 天 = 2160 游戏小时）
- **侵蚀序列**：基于绝对游戏时间生成，每级侵蚀持续 2 周，随机选取五种等级之一
- **连续滚动**：时间流逝时视图左移，序列不重置（`_forecast_start_hours` 递进）
- **悬停提示**：鼠标悬停周期条时，显示「距离现在Xd 等级名 数值」
- **分段数**：90 段，每段约 1 天
- **滚动**：随时间流逝，图元向左移动；每滚动一个分段，刷新预测数据
- **时间比例**：与 GameTime 一致（3 秒 = 1 游戏小时）

---

## 4. 主 UI 集成

**路径**：`scenes/ui/ui_main.tscn`

ShelterErosionPanel 置于 TopBar 右侧，在人员信息之后，布局为：

- … | 人员 | VSep3 | **ShelterErosionPanel**

---

## 5. 关键文件

| 文件 | 职责 |
|------|------|
| `scripts/core/erosion_core.gd` | ErosionCore Autoload，侵蚀常量、预测接口 |
| `scripts/ui/shelter_erosion_panel.gd` | 面板逻辑，同步 ErosionCore 与 UI |
| `scripts/ui/erosion_cycle_bar.gd` | 周期长条绘制与滚动 |
| `scenes/ui/shelter_erosion_panel.tscn` | 面板场景 |
| `project.godot` | ErosionCore Autoload 配置 |

---

## 6. 侵蚀来源悬停提示

鼠标悬停于左侧侵蚀标识时，在其下方展开侵蚀数据来源说明，例如：

- 当前：0 轻度侵蚀
- -2 来自显性侵蚀
- +2 来自文明的庇佑

数据来自 `ErosionCore.raw_mystery_erosion`（神秘侵蚀）与 `ErosionCore.shelter_bonus`（文明的庇佑），当前值 = 两者之和。

---

## 7. 扩展说明

- **数据源**：当前使用 ErosionCore 的程序化模拟；后续可接入庇护/核心消耗等真实逻辑。
- **预测算法**：`get_forecast_at_hours` 可替换为与游戏机制绑定的计算。
- **图元样式**：当前为纯色矩形，可替换为纹理或更复杂的绘制。

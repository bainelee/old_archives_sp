# 06 - 主 UI 设计概览与规范

## 概述

本文档汇总《旧日档案馆》游戏主界面的设计、功能规则与实现规范，供开发与 AI 辅助时参考。

---

## 1. 整体布局

### 1.1 主 UI 结构

- **入口场景**：`scenes/ui/ui_main.tscn`，挂载于 CanvasLayer（layer=10）
- **根节点**：TopBar（PanelContainer），全屏宽度，高度 48px
- **布局**：横向 HBox，顺序：**左侧资源** | Spacer | **TimePanel** | Spacer | **右侧信息** | **ShelterErosionPanel**

### 1.2 TopBar 分区

| 区域 | 内容 | 说明 |
|------|------|------|
| 左侧 | 因子 + 货币 | 认知/计算/意志/权限；信息/真相 |
| 中间 | TimePanel | 时间控制与显示，通过 Spacer 居中 |
| 右侧 | 人员 + ShelterErosionPanel | 研究员（劳动力暂未使用）、调查员；庇护与侵蚀面板 |

### 1.3 视觉规范

- **TopBar 背景**：`StyleBoxFlat`，`bg_color = Color(0.12, 0.12, 0.18, 0.92)`，下角圆角 4px
- **边距**：Content 左右 16px，上下 6px
- **分区间距**：HBox separation 32px；各子区域内部 12px；因子/货币/人员内部项 4px
- **分隔符**：VSeparator，`custom_minimum_size = Vector2(2, 0)`
- **标签颜色**：名称 `Color(0.7, 0.75, 0.85)`；数值 `Color(0.95, 0.9, 0.7)`，字体 14

---

## 2. 可复用组件

### 2.1 TimePanel

| 项目 | 说明 |
|------|------|
| 场景 | `scenes/ui/time_panel.tscn` |
| 脚本 | `scripts/ui/time_panel.gd`、`scripts/ui/time_indicator.gd` |
| 布局顺序 | 播放/暂停 → 1x → 2x → 6x → 96x → 时间文本 |
| 数据源 | GameTime Autoload |
| 倍速 | 1x / 2x / 6x / 96x |
| 时间格式 | `xx时 第XX天 第XX周`（format_time_short） |
| 时间比例 | 3 秒现实 = 1 游戏小时 |

**TimeIndicator**：时间流动时旋转的箭头图元，半径 `min(size)*0.32`，`pivot_offset=size/2` 绕中心旋转。

**播放/暂停**：流逝时显示 ▶，暂停时显示 ⏸；悬停时显示「将要切换到的」图标。

### 2.2 ShelterErosionPanel

| 项目 | 说明 |
|------|------|
| 场景 | `scenes/ui/shelter_erosion_panel.tscn` |
| 脚本 | `scripts/ui/shelter_erosion_panel.gd` |
| 布局 | 左侧当前侵蚀等级；右侧 ErosionCycleBar |
| 数据源 | ErosionCore Autoload |
| 最小宽度 | 280px |

**悬停提示**：
- 左侧侵蚀标识：显示侵蚀来源（神秘侵蚀 + 文明的庇佑）
- 右侧周期条：显示「距离现在Xd 等级名 数值」

**弹出层**：需 reparent 到 CanvasLayer 顶层（z_index=100），避免被 TopBar 裁剪；隐藏延迟 0.15 秒。

### 2.3 ErosionCycleBar

| 项目 | 说明 |
|------|------|
| 脚本 | `scripts/ui/erosion_cycle_bar.gd` |
| 时间跨度 | 90 天（2160 游戏小时） |
| 分段数 | 90 段，每段≈1 天 |
| 行为 | 随时间流逝图元向左滚动；每滚动一个分段刷新预测 |
| 颜色 | +1 白、0 翠绿、-2 橙黄、-4 赤红、-8 深紫 |

---

## 3. 数据与 API

### 3.1 UIMain 数据属性

通过属性或 `set_resources()` 注入：

- **因子**：cognition_amount, computation_amount, will_amount, permission_amount（对应 factors.cognition/computation/willpower/permission）
- **货币**：info_amount, truth_amount
- **人员**：researcher_count（显示为 未侵蚀/总数，如 8/10）、eroded_count（供 PersonnelErosionCore）、investigator_count

### 3.2 Autoload 依赖

| Autoload | 职责 |
|----------|------|
| GameTime | 时间流逝、倍速、format_time |
| ErosionCore | 侵蚀等级、预测、来源说明 |

---

## 4. 规范与约定

### 4.1 新增 TopBar 组件的规范

- 使用 HBoxContainer 或等价横向布局
- 与相邻区域用 VSeparator 分隔
- 使用统一的标签颜色（Name/Value）
- 可复用面板保持最小尺寸以适配 TopBar 高度

### 4.2 悬停弹出层规范

- 弹出层移出父容器后需 reparent 到 CanvasLayer 顶层
- 使用短延迟（约 0.15s）隐藏，避免闪烁
- 位置限制在视口内：`clampi(x, 4, vp_size.x - ps.x - 4)`

### 4.3 颜色规范（侵蚀）

| 侵蚀值 | 颜色常量 | 用途 |
|--------|----------|------|
| +1 | COLOR_LATENT 白 | 隐性侵蚀 |
| 0 | COLOR_MILD 翠绿 | 轻度侵蚀 |
| -2 | COLOR_VISIBLE 橙黄 | 显性侵蚀 |
| -4 | COLOR_SURGE 赤红 | 涌动阴霾 |
| -8 | COLOR_LYCAON 深紫 | 莱卡昂的暗影 |

---

## 5. 关键文件索引

| 文件 | 职责 |
|------|------|
| `scenes/ui/ui_main.tscn` | 主 UI 场景 |
| `scripts/ui/ui_main.gd` | TopBar 数据绑定 |
| `scenes/ui/time_panel.tscn` | 时间面板 |
| `scripts/ui/time_panel.gd` | 时间控制逻辑 |
| `scripts/ui/time_indicator.gd` | 时间流逝图元 |
| `scenes/ui/shelter_erosion_panel.tscn` | 庇护/侵蚀面板 |
| `scripts/ui/shelter_erosion_panel.gd` | 侵蚀显示与弹出 |
| `scripts/ui/erosion_cycle_bar.gd` | 侵蚀周期长条 |
| `scripts/core/game_time.gd` | 时间系统 |
| `scripts/core/erosion_core.gd` | 侵蚀数据源 |

---

## 相关文档

- [04 - 时间流逝系统](04-time-system.md)
- [05 - 庇护/侵蚀 UI](05-shelter-erosion-ui.md)
- [名词解释](../名词解释.md)

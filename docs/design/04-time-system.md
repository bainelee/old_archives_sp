# 04 - 时间流逝系统

## 概述

本文档记录《旧日档案馆》项目中**时间流逝系统**的设计与实现，包括 GameTime 单例、TimePanel UI 及其与主界面的集成。

---

## 1. 时间比例与单位

| 配置项 | 值 |
|--------|-----|
| 现实时间 : 游戏时间 | 3 秒 : 1 小时 |
| 游戏内小时/天 | 24 |
| 游戏内天/周 | 7 |
| 游戏内天/月 | 30 |
| 游戏内月/年 | 12 |

---

## 2. GameTime Autoload

**路径**：`scripts/core/game_time.gd`

### 常量

- `REAL_SECONDS_PER_GAME_HOUR := 3.0` — 现实 3 秒 = 1 游戏小时
- `SPEED_1X / SPEED_2X / SPEED_6X` — 倍速常量

### 主要属性

- `is_flowing: bool` — 时间是否正在流逝
- `speed_multiplier: float` — 当前倍速 (1.0 / 2.0 / 6.0)

### 信号

- `flowing_changed(is_flowing)` — 播放/暂停状态变化
- `speed_changed(speed)` — 倍速变化
- `time_updated()` — 每帧时间推进时触发（用于 UI 刷新）

### 主要 API

| 方法 | 说明 |
|------|------|
| `toggle_flow()` | 切换播放/暂停 |
| `set_speed_1x() / set_speed_2x() / set_speed_6x()` | 设置倍速 |
| `format_time()` | 完整格式，如 "14时 第5天 第2周" |
| `format_time_short()` | 与 `format_time` 相同 |
| `get_hour() / get_day() / get_week() / get_month() / get_year()` | 获取各时间单位 |
| `get_total_hours()` | 获取总小时数 |
| `reset_time()` | 重置为 0（调试用） |

---

## 3. TimePanel 可复用 UI

**场景**：`scenes/ui/time_panel.tscn`  
**脚本**：`scripts/ui/time_panel.gd`、`scripts/ui/time_indicator.gd`

### 组件

| 组件 | 说明 |
|------|------|
| **TimeIndicator** | 循环旋转图元，时间流动时旋转；半径 `min(size) * 0.32`，`pivot_offset` 在 `NOTIFICATION_RESIZED` 中设为 `size/2` 以绕中心旋转 |
| **PlayPauseButton** | 时间流逝时默认显示 ▶，暂停时显示 ⏸；悬浮时显示将切换到的图标 |
| **Speed1xButton** | 普通按钮，点击恢复基础速度，取消 2x/6x 选中 |
| **Speed2xButton** | 切换按钮，2 倍速 |
| **Speed6xButton** | 切换按钮，6 倍速 |
| **TimeLabel** | 显示 `format_time()` 格式 |

### 布局顺序

播放/暂停 → 1x → 2x → 6x → 时间文本

---

## 4. 主 UI 集成

**路径**：`scenes/ui/ui_main.tscn`

TimePanel 置于 TopBar 中间，通过 `SpacerLeft`、`SpacerRight`（`size_flags_horizontal = 3`）实现居中，布局为：

- 左侧：因子、货币
- 中间：TimePanel
- 右侧：人员

---

## 5. 关键文件

| 文件 | 职责 |
|------|------|
| `scripts/core/game_time.gd` | GameTime Autoload |
| `scripts/ui/time_panel.gd` | TimePanel 逻辑 |
| `scripts/ui/time_indicator.gd` | 旋转指示器绘制 |
| `scenes/ui/time_panel.tscn` | TimePanel 场景 |
| `scenes/ui/ui_main.tscn` | 主 UI（含 TimePanel） |
| `project.godot` | GameTime Autoload 配置 |

---

## 6. 迭代记录（会话摘要）

1. 初始实现：6 秒 = 1 小时，2x/3x 倍速
2. 时间比例改为 3 秒 = 1 小时
3. 旋转图元半径缩小至 0.32，设置 `pivot_offset` 避免越界
4. 播放/暂停按钮显示逻辑：流逝时默认 ▶，暂停时默认 ⏸；悬浮显示将切换到的图标
5. 时间显示格式：`xx时 第XX天 第XX周`
6. 第二个快进按钮由 3x 改为 6x
7. 新增 1x 按钮用于恢复基础速度

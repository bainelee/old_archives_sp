# 04 - 住房详情面板设计规范

## 概述

住房详情面板（HousingDetailsPanel）是点击 TopBar 住房图标时弹出的信息面板，展示档案馆当前住房供需状况的详细 breakdown。

---

## 1. 整体结构

```
┌─────────────────────────────┐
│  ▲                          │  ← UpPointer (20px 高)
│ ┌───────────────────────────┐│
│ │ 🏠 住房              ││  ← DetailsTitle (40px 高，蓝色背景)
│ └───────────────────────────┘│
│                              │
│      (8px 间距)              │  ← ContentMargin.margin_top = 8
│                              │
│ ┌───────────────────────────┐│
│ │ 住房信息总览               ││  ← 标题
│ │ ━━━━━━━━━━━━━━━━━━━━━━━━ ││  ← 进度条 (HousingOverviewBar)
│ │                           ││
│ │ 可分配住房          0     ││  ← AvailableRow
│ │ ──────────────────────── ││  ← SplitLine1
│ │ 住房缺口            4     ││  ← DeficitRow (缺口>0时显示，数值红色)
│ │                           ││
│ │ 住房产出           32     ││  ← OutputTitle
│ │   居住区           30     ││  ← OutputEntries Entry1 (灰色背景)
│ │   造物区            2     ││  ← OutputEntries Entry2 (灰色背景)
│ │                           ││
│ │ ──────────────────────── ││  ← SplitLine2
│ │ 住房总数           32     ││  ← TotalRow
│ └───────────────────────────┘│
└─────────────────────────────┘
```

---

## 2. 布局规范

### 2.1 节点层级

```
HousingDetailsPanel (PanelContainer, 320px 宽)
└── DetailsVboxContainer (VBoxContainer)
    ├── HeaderVbox (VBoxContainer)
    │   ├── UpPointer (Control, 20px 高)
    │   └── DetailsTitle (PanelContainer, 40px 高)
    │       └── TitleLayout (HBoxContainer)
    │           ├── IconHolder (32x32)
    │           ├── TextTitleName (Label)
    │           └── SpacerTitle
    └── ContentMargin (MarginContainer)
        ├── margin_left = 20
        ├── margin_top = 8      ← 关键：标题与内容的间距
        └── margin_right = 20
        └── ContentVbox (VBoxContainer, separation=4)
            ├── DetailStorageInfo (VBoxContainer, separation=8)
            │   ├── TextStorageTitle (Label)
            │   └── ProgressBarWrapper (Control)
            │       └── HousingOverviewBar
            ├── AvailableRow (HBoxContainer)
            ├── SplitLine1 (VBoxContainer, 2px 高)
            ├── DeficitRow (HBoxContainer)      ← 缺口>0时显示
            ├── OutputWrap (MarginContainer, margin_top=4)
            │   └── Output (VBoxContainer)
            │       ├── OutputTitle (HBoxContainer)
            │       └── OutputEntries (VBoxContainer)
            │           ├── Entry1 (PanelContainer, 灰色背景)
            │           └── Entry2 (PanelContainer, 灰色背景)
            ├── SplitLine2 (VBoxContainer, 2px 高)
            └── TotalRow (HBoxContainer)
```

### 2.2 间距规则

| 位置 | 数值 | 说明 |
|------|------|------|
| 标题栏 → 内容区 | 8px | ContentMargin.margin_top（详情面板通用规范） |
| 内容区内条目 | 4px | ContentVbox.separation |
| 产出区顶部 | 4px | OutputWrap.margin_top |
| 产出细则条目 | 0px | OutputEntries.separation |
| 进度条标题到条 | 4px | DetailStorageInfo.separation（详情面板通用规范） |

---

## 3. 内容条目顺序

内容区条目从上到下依次为：

1. **住房信息总览** - 标题 + 进度条
2. **可分配住房** - 当前可分配给新研究员的住房数量
3. **分隔线1** - 双线分隔（深灰 + 浅灰）
4. **住房缺口** - 需求超过供给的数量（仅在缺口>0时显示）
5. **住房产出** - 总产出数值 + 各区域细则
6. **分隔线2** - 双线分隔
7. **住房总数** - 当前可提供的住房总量

---

## 4. 视觉规范

### 4.1 颜色

| 元素 | 颜色值 | 用途 |
|------|--------|------|
| 标题栏背景 | `Color(0.09, 0.145, 0.498, 1)` | 蓝色 |
| 正常文本 | `Color(0.063, 0.063, 0.063)` | 深色 |
| 缺口数值 | `Color(0.9, 0.3, 0.3)` | 红色 |
| 产出细则背景 | `Color(0.165, 0.165, 0.165, 0.18)` | 半透明灰 |
| 分隔线深 | `Color(0.447, 0.447, 0.447)` | 深灰 |
| 分隔线浅 | `Color(0.792, 0.792, 0.792)` | 浅灰 |

### 4.2 字体大小

| 元素 | 字号 |
|------|------|
| 面板标题 | 20px |
| "住房信息总览" | 14px |
| 行标签（可分配住房等） | 16px |
| 章节标题（住房缺口、住房产出等） | 20px |
| 产出细则 | 14px |

---

## 5. 数据与显示规则

### 5.1 数据来源

通过 `data_provider.get_housing_breakdown()` 获取：

```gdscript
{
    "demand": int,        # 住房需求（研究员人数）
    "supplied": int,      # 已提供住房
    "deficit": int,       # 住房缺口（需求-供给）
    "output_details": [   # 产出细则
        {"source": "居住区", "amount": 30},
        {"source": "造物区", "amount": 2}
    ]
}
```

### 5.2 计算逻辑

- **可分配住房** = max(0, 供给 - 需求) 当供给>需求时，否则为0
- **住房缺口** = max(0, 需求 - 供给)
- **住房总数** = 供给

### 5.3 显示规则

| 条目 | 显示条件 |
|------|----------|
| 住房缺口行 | 仅当 deficit > 0 时显示 |
| 住房产出区 | 仅当 output_details 非空时显示 |
| 产出细则条目 | 按数据动态显示，多余预设条目隐藏 |

---

## 6. 设计决策说明

### 6.1 为什么移除底部警告行？

**旧设计**：在面板最底部动态添加带icon的警告行（"⚠ 住房缺口: X"）。

**问题**：
- 冗余信息：上方已有"住房缺口"条目显示相同信息
- 视觉混乱：icon警告与设计稿不符
- 动态添加导致布局不稳定

**新设计**：住房缺口信息仅在"住房缺口"条目中显示，以红色数值标识。无额外警告行。

### 6.2 为什么设置 8px 标题间距？

**旧设计**：内容区紧贴标题栏，视觉上过于拥挤。

**新设计**：通过 ContentMargin.margin_top = 8 确保呼吸空间，与同类面板（如因子详情面板）保持一致。

---

## 7. 关键文件索引

| 文件 | 职责 |
|------|------|
| `scenes/ui/housing_details_panel.tscn` | 面板场景布局 |
| `scripts/ui/housing_details_panel.gd` | 面板逻辑与数据绑定 |
| `scenes/ui/detail_housing_overview_bar.tscn` | 住房总览进度条 |
| `scripts/core/data_providers.gd` | 住房数据源 |

---

## 相关文档

- [02 - 主 UI 设计概览与规范](02-ui-main-overview.md) - 详见 4.4 详情面板通用布局规范
- [03 - TopBar UI 元素](03-topbar-ui-elements.md)
- [06 - 已建设房间系统](../../2-gameplay/06-built-room-system.md) - 生活区住房产出

# Godot 4.x UI 自适应布局问题 - 调试与修复指南

## 问题描述

研究员详情面板 (`ResearcherDetailsPanel`) 出现布局问题：
- 左侧标签（如"闲置研究员"）和右侧数值（如"10"）之间**没有正确间隔**
- 所有元素挤在一起，无法正确左右对齐

## 根本原因分析

### 1. 容器层级 size_flags 设置不完整

Godot 4.x 的 Container 布局系统要求**每一级父容器**都正确设置 `size_flags_horizontal`，否则子元素无法正确扩展：

```
PanelContainer (根节点)
  └─ DetailsVboxContainer [size_flags_horizontal = 0] ❌ 未扩展
       └─ ContentMargin [size_flags_horizontal = 0] ❌ 未扩展
            └─ ContentVbox [size_flags_horizontal = 0] ❌ 未扩展
                 └─ IdleRow [size_flags_horizontal = 1] ✅ 扩展但父容器太窄
                      └─ Label | Spacer | Value
```

**问题**：父容器没有扩展，导致子元素即使设置了 `EXPAND_FILL` 也没有空间可填充。

### 2. MarginContainer 内的子节点尺寸问题

`ContentVbox` 作为 `MarginContainer` 的子节点，默认行为是**收缩到内容尺寸**，而不是填满可用空间。

### 3. 各行的 size_flags 设置不一致

各 HBoxContainer 行（IdleRow, ErodedRow 等）的 size_flags 可能不一致，导致布局计算混乱。

## 解决方案

### 场景文件修复

修改 `scenes/ui/researcher_details_panel.tscn`：

```
[node name="DetailsVboxContainer" type="VBoxContainer" parent="."]
layout_mode = 2
size_flags_horizontal = 3  # EXPAND_FILL ✅

[node name="ContentMargin" type="MarginContainer" parent="DetailsVboxContainer"]
layout_mode = 2
size_flags_horizontal = 3  # EXPAND_FILL ✅

[node name="ContentVbox" type="VBoxContainer" parent="DetailsVboxContainer/ContentMargin"]
layout_mode = 2
size_flags_horizontal = 3  # EXPAND_FILL ✅

[node name="IdleRow" type="HBoxContainer" parent="DetailsVboxContainer/ContentMargin/ContentVbox"]
layout_mode = 2
size_flags_horizontal = 3  # EXPAND_FILL ✅
```

### 代码运行时修复

在 `researcher_details_panel.gd` 的 `show_panel()` 中：

```gdscript
func show_panel(data: Dictionary) -> void:
    # ... 更新数据 ...
    
    # 必须先调用基类设置 visible = true
    super.show_panel(data)
    
    # 面板可见后才能正确修复布局
    _fix_predefined_rows_layout()

func _fix_predefined_rows_layout() -> void:
    # 强制 ContentVbox 填满可用空间
    content.custom_minimum_size.x = 276  # 316 - 40边距
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    
    # 强制各行填满 ContentVbox
    for row in rows:
        row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.custom_minimum_size.x = 276
        
        # 正确设置子元素
        label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN  # 左对齐
        spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # 占满中间
        value.size_flags_horizontal = Control.SIZE_SHRINK_END    # 右对齐
```

### 基类初始化修复

在 `detail_panel_base.gd` 的 `_enter_tree()` 中：

```gdscript
func _enter_tree() -> void:
    _cache_nodes()
    
    # 确保内容容器在水平方向上填满面板
    if _details_vbox:
        _details_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    if _content_margin:
        _content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    if _content_vbox:
        _content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
```

## 布局策略最佳实践

### 左右对齐布局（Label - Spacer - Value）

```
HBoxContainer (行容器)
  ├─ Label: SIZE_SHRINK_BEGIN + HORIZONTAL_ALIGNMENT_LEFT
  ├─ Spacer: SIZE_EXPAND_FILL (占据所有剩余空间)
  └─ Value: SIZE_SHRINK_END + HORIZONTAL_ALIGNMENT_RIGHT
```

### 层级 size_flags 检查清单

当遇到布局扩展问题时，按层级检查：

| 层级 | 节点类型 | 推荐 size_flags_horizontal |
|------|---------|---------------------------|
| 1 | 根容器 (PanelContainer) | 无需设置（由内容决定） |
| 2 | 主内容容器 (VBoxContainer) | SIZE_EXPAND_FILL (3) |
| 3 | 边距容器 (MarginContainer) | SIZE_EXPAND_FILL (3) |
| 4 | 内容区域 (VBoxContainer) | SIZE_EXPAND_FILL (3) |
| 5 | 行容器 (HBoxContainer) | SIZE_EXPAND_FILL (3) |
| 6 | 行内元素 | 根据需求设置 |

### 关键调试指标

出现布局问题时检查：

1. **父容器宽度**：是否达到预期值（如 316px）
2. **当前容器宽度**：是否填满父容器（如 276px = 316 - 40边距）
3. **行宽度**：是否填满内容区域
4. **Spacer 宽度**：是否占据剩余空间（应 > 100px）

## 常见错误

### 错误 1：只在行级别设置 size_flags

❌ 只设置 HBoxContainer 的 size_flags，不设置父容器
✅ 从根容器到行容器，每一级都要设置

### 错误 2：在面板不可见时修复布局

❌ 在 `visible = false` 时调用布局修复
✅ 先设置 `visible = true`，等待一帧后再修复

### 错误 3：使用 SIZE_FILL 代替 SIZE_EXPAND_FILL

❌ `size_flags_horizontal = SIZE_FILL` (值为 1)
✅ `size_flags_horizontal = SIZE_EXPAND_FILL` (值为 3)

## Godot 4.x size_flags 枚举参考

```gdscript
SIZE_FILL = 1              # 填充但不扩展
SIZE_EXPAND = 2          # 仅扩展
SIZE_EXPAND_FILL = 3     # 扩展并填充 ✅ 最常用
SIZE_SHRINK_BEGIN = 0    # 收缩到开头
SIZE_SHRINK_CENTER = 4   # 收缩到中心
SIZE_SHRINK_END = 8      # 收缩到末尾 ✅ 用于右对齐
```

## 修复验证步骤

1. 在编辑器中打开场景，检查所有容器的 `size_flags_horizontal`
2. 运行游戏，悬停触发面板显示
3. 检查布局是否正确：
   - 左侧标签靠左
   - 中间有间隔
   - 右侧数值靠右
4. 检查容器尺寸（使用调试输出或 Remote 场景树）

## 相关文件

- `scenes/ui/researcher_details_panel.tscn`
- `scripts/ui/researcher_details_panel.gd`
- `scripts/ui/detail_panel_base.gd`

## 参考规则

- `.cursor/rules/ui-no-ready.mdc` - 编辑器可见逻辑规范
- `.cursor/rules/ui-editor-live.mdc` - 编辑器实时预览规范

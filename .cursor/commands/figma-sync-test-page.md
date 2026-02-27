# Figma 同步 test_figma_page

## 概述

从 Figma 读取**原始设计数据**（Layout、Fills、Corner Radius、Layer Properties 等），直接写入 `scenes/ui/test_figma_page.tscn`，使引擎编辑器中即可看到与 Figma 一致的 UI。

## 禁止

- 使用截图或图像描述作为设计依据
- 将设计数据存入 JSON 并在游戏运行时加载
- 猜测或估算数值

## 步骤

1. **要求用户** 在 Figma 中选中要同步的 Frame（含 Title、Btn1/2/3 的父节点）

2. **可选 MCP**：优先使用 **Framelink MCP for Figma**（`get_figma_data`）— 返回结构化 layout 数据更稳定。配置见 `docs/design/09-framelink-mcp-setup.md`。若用 Figma Desktop MCP 且报 “Path for asset writes”，见 `docs/design/figma_process/02-figma-mcp-write-to-disk-config.md`。

3. **调用 Figma MCP** 获取原始数据：
   - `get_metadata`：获取节点结构、layout（left, top, width, height）
   - `get_design_context`：获取 fills、cornerRadius、typography 等完整设计数据

4. **解析 MCP 返回**（get_metadata 返回 XML 含 position/size，get_design_context 返回 code 与 fills/cornerRadius 等）提取：
   - 画布尺寸（1920×1080 或 Frame 的 absoluteBoundingBox）
   - 各控件：`left`, `top`, `width`, `height`（来自 layout / absoluteBoundingBox）
   - 背景色：fills[0].color（0–1 转为 Godot Color）
   - 按钮：fills、cornerRadius（直角=0）、fontSize、fontColor
   - 标题：fills（文字色）、fontSize、text
   - 图片：fills.type=IMAGE → 调用 Images API 导出 PNG，按命名分类：`icon*`→`assets/icons/`、`button_back`→`assets/ui/`、其余→`assets/misc/`

5. **直接编辑** `scenes/ui/test_figma_page.tscn`：
   - 坐标换算：Figma layout left/top/width/height → Godot offset：
     - **position = (left, top)**（控件轴心为左上角时，transform position 即 left, top）
     - offset_left = left，offset_top = top
     - offset_right = left + width，offset_bottom = top + height
   - `DesignCanvas`：custom_minimum_size = 画布尺寸
   - `Background` ColorRect：color
   - `Title` Label、`Btn1/2/3`：按上述公式设置 offset

6. **颜色转换**：Figma 0–1 → Godot Color(r, g, b, a)

## 相关文件

- `scenes/ui/test_figma_page.tscn`：唯一数据源，编辑器中直接可见
- `scripts/ui/test_figma_page.gd`：仅负责缩放与 show/hide
- `docs/design/figma_process/01-test-figma-page-sync.md`：同步说明

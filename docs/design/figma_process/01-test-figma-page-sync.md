# Test Figma Page 同步规范

> **完整流程**：Figma 读取→下载→导入的全局规则见 `.cursor/rules/figma-import.mdc`。本文档针对 test_figma_page 做细化说明。

## 原则

1. **数据源**：Figma 的 Layout、Fills、Corner Radius、Layer Properties 等原始数据
2. **目标**：`scenes/ui/test_figma_page.tscn`，引擎编辑器中直接可见
3. **禁止**：截图作为参考、JSON 运行时加载、猜测数值

## 同步流程

1. 在 Figma 中选中包含 Title 与三个 Button 的 Frame
2. 对 Agent 说：「同步 test_figma_page」或「从 Figma 更新 test_figma_page」
3. Agent 调用 `plugin-figma-figma-desktop` 的 `get_metadata` 与 `get_design_context`
4. Agent 解析返回的 layout、fills、cornerRadius 等，**直接编辑 .tscn**

## 需提取的 Figma 数据

| Figma 属性 | 目标（.tscn） | 说明 |
|------------|---------------|------|
| layout left | offset_left = left | position.x |
| layout top | offset_top = top | position.y（控件轴心为左上角时） |
| layout width | offset_right = left + width | size.x |
| layout height | offset_bottom = top + height | size.y |
| fills[0].color (0–1) | Color(r,g,b,a) | 背景、按钮 fill、文字色 |
| cornerRadius | StyleBoxFlat corner_radius_* = 0（直角）或对应 px | 直角矩形为 0 |
| fontSize | theme_override_font_sizes/font_size | |
| characters / text | text | |
| fills[0].type=IMAGE, imageRef | 调用 Images API 导出 PNG，按命名分类存放 | 见下方分类规则 |

### 图片导出与分类规则

1. 从 nodes 文档中识别 `type":"IMAGE"` 的 fills，记下 node id、name 与 imageRef
2. 调用 `GET /v1/images/:fileKey?ids=:nodeIds&format=png&scale=1` 获取下载 URL
3. **按 Figma 元素命名分类存放**：
   - `icon*`（如 icon_news、icon_firesalt）→ `assets/icons/`
   - `button_back` → `assets/ui/`
   - 其余未分类 → `assets/misc/`（新建目录）
4. 在 .tscn 中引用对应路径，TextureButton/TextureRect 使用 `ignore_texture_size` 或 `expand_mode=1` 以按布局尺寸显示

## 相关文件

- `.cursor/commands/figma-sync-test-page.md`：同步命令
- `scenes/ui/test_figma_page.tscn`：场景文件
- `scripts/ui/test_figma_page.gd`：仅缩放与显示逻辑

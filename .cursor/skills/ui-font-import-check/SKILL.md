---
name: ui-font-import-check
description: Enforces UI font binding after UI/Figma import in this project. Use when importing or creating UI scenes, syncing Figma UI, or adjusting UI visual consistency; verify all text controls use the project font via theme or explicit font resource.
---

# UI Font Import Check

## 目标

确保所有新导入或改动的 UI 场景使用项目指定字体，避免回退到 Godot 默认字体。

## 项目字体基准

- 详情面板统一主题：`assets/ui/detail_panel_theme.tres`
- 该主题默认字体：`assets/fonts/Sarasa-Mono-SC-Nerd.ttf`

## 动态字体导入（MSDF，必须）

- 项目内 **TTF/OTF/WOFF** 等动态字体（`font_data_dynamic`）须在对应 `*.import` 中启用 **`multichannel_signed_distance_field=true`**（Godot Import 面板「Multichannel Signed Distance Field」）。
- 新增字体文件后：在编辑器中选中该字体 → Import 勾选 MSDF → 保存；或直接在 `.import` 的 `[params]` 写入上述键为 `true`（可保留默认 `msdf_pixel_range=8`、`msdf_size=48`，有粗描边时按 [官方文档](https://docs.godotengine.org/en/stable/classes/class_resourceimporterdynamicfont.html) 提高 `msdf_pixel_range`）。
- **像素风字体**若观感异常再单独关闭 MSDF；默认与本项目现有 Sarasa 系列保持一致为 **开启**。

## 触发时机

当出现以下任一情况时必须执行本技能检查：

- 新增或修改 `scenes/ui/**/*.tscn`
- Figma 同步或 UI 导入
- 新增 UI 组件（`scenes/ui/components/**/*.tscn`）
- 用户反馈“字体不对”“字形变了”“中英文字体不一致”

## 执行流程

1. 扫描字体来源
   - 检查场景是否设置 `theme = ...`
   - 检查是否存在 `theme_override_fonts/font = ...`
   - 检查脚本是否有运行时强制字体覆盖（如 `add_theme_font_override`）

2. 按优先级修正
   - 优先方案：场景挂项目主题（如 `detail_panel_theme.tres`）
   - 次优方案：仅对个别控件设置 `theme_override_fonts/font`
   - 禁止方案：在脚本中运行时强制覆盖字体（除非用户明确要求）

3. 复核范围
   - 主场景
   - 该场景实例化的子组件场景
   - 同一 UI 功能链路内的关联面板

4. 输出结论
   - 列出“已正确绑定字体”的场景
   - 列出“缺失字体绑定”的场景
   - 列出本次已修改文件与策略（主题绑定/控件覆盖）

## 快速检查命令（建议）

- 搜索场景字体设置：`theme =`、`theme_override_fonts/font`
- 搜索脚本强制覆盖：`add_theme_font_override`、`set_theme`

## 约束

- 不随意改全局字体配置。
- 不用脚本在 `_ready()` 强制改字体。
- 若用户指定“只改目标 UI”，则仅改目标链路，不扩散到全项目。

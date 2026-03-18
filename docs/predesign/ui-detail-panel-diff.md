# 认知因子详情面板 — 当前 UI 与文档 / Figma 差异对照

> 最后更新：详情面板进度条改为专用 DetailStorageProgressBar（Figma storage_progress_bar_back 90:52），总高 20、内高 16；topbar 仍用 ResourceProgressBar（MARGIN=1 已还原）。

## Figma 来源

| 项 | 值 |
|----|-----|
| 设计链接 | https://www.figma.com/design/ndfJ5hiWy9b4iq5JNuZwSJ/old_archives_main_ui?node-id=67-622 |
| fileKey | `ndfJ5hiWy9b4iq5JNuZwSJ` |
| nodeId（API） | `67:622` |

用 API 对照时：`GET https://api.figma.com/v1/files/ndfJ5hiWy9b4iq5JNuZwSJ/nodes?ids=67%3A622&depth=4`

## 一、资产与视觉

| 项目 | 文档/Figma 规范 | 当前实现 | 差异 |
|------|-----------------|----------|------|
| details_background | 与 basebutton 相同 ninepath，2px 边距；Figma 使用专用切图（node 74:9） | `details_background.png` | 已从 Figma API 重新下载并覆盖，StyleBoxTexture 2px 边距 |
| up_pointer | 顶部指示图，在 details_vbox_container 顶端 | up_pointer_cognition.png | 已使用 Figma 切图 |
| down_pointer | 属于另一未同步界面，此面板不含 | — | 已移除 |
| detials_title_back | 316×40 背景图，左右拉伸 | StyleBoxFlat 纯色 #17257f | 文档为背景图，Figma 也有 detials_title_back 节点 |
| icon_detials_title | 32×32，距左上 4px；icon 需白色（HSV 调整） | icon_cognition 原色 | 文档要求白色 icon，当前未做 HSV 处理 |
| split_line | 2px 高；Figma 双层 (#727272 + #cacaca) | VBox + LineDark + LineLight 双层 | 已实现双层 #727272 + #cacaca |
| storage_progress_bar | Figma 67:453，back 图 90:52，总高 20、内高 16、2px 边距 | DetailStorageProgressBar 专用组件，back 从 Figma 下载，填充 #fd9729 | 与 topbar 用 ResourceProgressBar 分离，详情面板独立进度条 |
| warning_icon | 警告图标图 | warning_sign.png | 已使用切图 |
| 字体 | Figma: Sarasa_Nerd:Regular | Sarasa-Mono-SC-Nerd.ttf | 已导入并应用于 factor_details_panel |

---

## 二、布局与间距

| 项目 | 文档/Figma 规范 | 当前实现 | 差异 |
|------|-----------------|----------|------|
| 内容区边距 | 文档：左右 20px（相对 316）；Figma：left 20px | ContentMargin 20px 左右 | 已对齐 |
| split_line 与上一条目 | 文档：4px | ContentVbox separation=4 | 已对齐 |
| 固有消耗组距上 | 8px | 8px | 一致 |
| 条目行高 | 固有/档案馆/产出条目 24px，消耗影响 16px | 24/16 | 一致 |
| text_title_name 距 icon | 8px | HBox separation 8 | 一致 |
| text_title_state 距右 | 8px | StyleBoxFlat_title content_margin_right=8 | 已对齐 |
| storage_progress_bar 距 text_storage_title | 8px | DetailStorageInfo separation 8 | 一致 |
| storage_warning 距 progress_bar | 8px | separation 8 | 一致 |

---

## 三、结构与逻辑

| 项目 | 文档/Figma 规范 | 当前实现 | 差异 |
|------|-----------------|----------|------|
| storage_progress_bar 中央文案 | "当前因子储存量/因子服务器上限" 如 50,000 / 55,000 | ProgressBarLabel 覆于 DetailStorageProgressBar 上，运行期脚本同步 | 已实现 |
| storage_warning 中文 | 正常：设计文档「预计{x}天到达储存上限」；Figma 示例「将在 32天 后到达上限。」 | "将在 32天 后到达上限。" | 示例文案已与 Figma 一致；与设计文档为同义表述，运行时可按设计文档做动态替换 |
| total_expected_burn 中文 | "预期总消耗：" | "预期总消耗：" | 已对齐 Figma |
| 消耗影响条目 | 文档：条目归属类型，如 "增加原因：决议-「深度研究」" | "增加原因：决议-「深度研究」" | 一致 |
| resource_storage_row | 文档未单独列出 | 实现 "资源储备 -160/天" | Figma 有，逻辑合理 |

储存警告「正常」状态：场景示例文案已与 Figma 统一为「将在 32天 后到达上限。」；设计文档中的「预计{x}天到达储存上限」为同义表述，运行时可按设计文档做动态替换。

---

## 四、场景节点路径（已修复）

已将所有 `ContentVbox` 子节点及其子树的 `parent` 路径修正为包含 `ContentMargin/ContentVbox`。

---

## 五、未实现 / 待补充

1. ~~**down_pointer**~~：此面板不含，属另一界面
2. ~~**进度条中央文案**~~：已添加 ProgressBarLabel
3. **字体**：Sarasa_Nerd:Regular（若项目有引入）
4. **Figma 资产导入**：details_background、storage_progress_bar_back、up_pointer、warning 等已同步；split_line 为程序绘制双层线
5. **icon 白色处理**：当前用 modulate 提亮，完美白色需专用 asset
6. ~~**split_line 双层**~~：已实现双层

---

## 六、已对齐项

- 宽度 320px 固定
- 结构：details_title、detail_storage_info、total_expected_burn、fixed_overhead、archives_overhead、output、resource_shortage、resource_storage_row、bottom_placeholder
- 认知因子特例：档案馆消耗标题行 +「所有研究员」+ 消耗影响条目
- 条目格式：归属类型-名称 + 数值/天
- 分割线 2px
- 行高 24px / 16px

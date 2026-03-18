# 因子详情面板 — 可复用部分、设计规范与同步问题总结

## 一、此 UI 可复用的部分

### 1. 场景与组件

| 复用项 | 路径 | 说明 |
|--------|------|------|
| **详情面板主场景** | `scenes/ui/factor_details_panel.tscn` | 认知因子；宽度 320、结构完整（HeaderVbox + ContentMargin + 各区块），可复制后改文案与数据类型作为其他「详情类」面板 |
| **意志因子详情面板** | `scenes/ui/factor_details_panel_willpower.tscn` | 与认知因子结构一致、解耦独立场景；复用同一套资产与 DetailStorageProgressBar；Figma 67:629 |
| **权限因子详情面板** | `scenes/ui/factor_details_panel_permission.tscn` | 无资源消耗 list（即时瞬时消耗）；仅储存 + 产出 + 资源富余；Figma 67:630 |
| **计算因子详情面板** | `scenes/ui/factor_details_panel_computation.tscn` | 消耗组为「核心消耗」、仅 title 层无子条目；Figma 67:751 |
| **庇护能量详情面板** | `scenes/ui/factor_details_panel_shelter.tscn` | 无状态文、标题 SHELTER POWER；储存为「庇护能量出力上限」、已分配/固有分配/建设分配/产出/区域庇护状态；Figma 67:855 |
| **研究员详情面板** | `scenes/ui/researcher_details_panel.tscn` | 无状态文、标题 RESEARCHER；储存为「研究员总览」、三段进度条（闲置/在职/被侵蚀）；闲置/被侵蚀/在职+区域细则/研究员总数；Figma 70:964 |
| **住房详情面板** | `scenes/ui/housing_details_panel.tscn` | 无状态文、标题 HOUSING；储存为「住房信息总览」、住房总览条（需求/已提供，橙/灰/红）；可分配/住房缺口/住房产出+细则/住房总数；Figma 76:65 |
| **信息详情面板** | `scenes/ui/information_details_panel.tscn` | 无储存条、标题 INFORMATION；信息产出+细则、额外影响+细则、信息储量；Figma 70:1154 |
| **调查员详情面板** | `scenes/ui/investigator_details_panel.tscn` | 无储存条、标题 INVESTIGATOR；可分配/已分配+探索节点细则、已招募+事务所·事件细则；Figma 72:1259 |
| **真相详情面板** | `scenes/ui/truth_details_panel.tscn` | 无储存条、标题 TRUTH；已获得真相+细则（名称）、已解读真相+细则（名称）；Figma 72:1337 |
| **详情面板脚本** | 各 factor_details_panel_*.gd、researcher_details_panel.gd、housing/information/investigator/truth_details_panel.gd | @tool、@export 布局、运行期隐藏；各 show_for_*(data) |
| **详情用进度条** | `scenes/ui/detail_storage_progress_bar.tscn` | 因子/庇护等储存条；总高 20、内高 16、2px 边距 |
| **研究员总览条** | `scenes/ui/detail_researcher_overview_bar.tscn` | 三段（橙/灰/红）闲置/在职/被侵蚀，中央 8/32/4；仅研究员详情用 |
| **住房总览条** | `scenes/ui/detail_housing_overview_bar.tscn` | 三段（橙/灰/红）可分配/已提供/缺口，中央 需求/已提供（如 36/32）；仅住房详情用 |
| **主题** | `assets/ui/detail_panel_theme.tres` | 默认字体 Sarasa；凡用此主题的面板可统一字体 |

### 2. 资产

| 资产 | 路径 | 复用场景 |
|------|------|----------|
| details_background | `assets/ui/factor_details/details_background.png` | 所有「详情类」面板背景（StyleBoxTexture 2px 边距） |
| up_pointer / down_pointer | `assets/ui/factor_details/up_pointer_cognition.png` 等 | 详情面板顶端/底端指示 |
| warning_sign | `assets/ui/factor_details/warning_sign.png` | 储存警告、消耗影响等警告条 |
| storage_progress_bar_back | `assets/ui/factor_details/storage_progress_bar_back.png` | 仅详情内的储存进度条背景 |
| icon_frame_blue_32x32 | `assets/ui/resource_block/icon_frame_blue_32x32.png` | 标题栏 icon 底框 |

### 3. 结构模式

- **标题栏**：PanelContainer（StyleBoxFlat 或图）+ HBoxContainer（32×32 icon 区 + 8px 间距 + 标题名 + Spacer + 状态文右对齐），可复用于灾厄/因子/庇护/研究员等详情标题。
- **区块模式**：MarginContainer(margin_top=4) + VBoxContainer + 标题行(HBox) + 条目列表(VBox，每行 PanelContainer + StyleBoxFlat_row)，可复用于固有消耗、档案馆消耗、产出等。
- **分割线**：VBoxContainer(高 2) + 两条 ColorRect(高 1)，颜色 #727272 / #cacaca，可抽成场景或常量复用。
- **进度条 + 中央文案**：父 Control 固定高 + 进度条实例铺满 + Label 锚点居中覆在进度条上；运行期用脚本根据 current_value/max_value 同步 Label 文案。

---

## 二、此 UI 的设计规范

### 2.1 尺寸与边距

| 项 | 规范值 |
|----|--------|
| 面板总宽 | 320px 固定 |
| 内容区（details_vbox 逻辑宽） | 316px（相对面板左右各 2px） |
| 内容区左右边距 | 20px（ContentMargin），内容宽 276px |
| 标题栏 | 316×40；icon 32×32，距左上 4px；标题与 icon 间距 8px；状态文距右 8px |
| up_pointer | 316×20，与标题栏之间 0 间距（HeaderVbox separation=0） |
| 储存进度条 | 总高 20px，内高 16px，左右上下的「边框」各 2px |
| 分割线 | 高 2px；与上一条目 4px（由 VBox separation 或 margin_top 实现） |
| 区块间 | 主区块距上 8px（FixedOverheadWrap 等 margin_top=4 + separation=4） |
| 条目行高 | 普通条目 24px，消耗影响类 16px |

### 2.2 视觉

| 项 | 规范 |
|----|------|
| 背景 | NinePatch/StyleBoxTexture，四边 2px 边距 |
| 标题栏背景 | #17257f 或 316×40 背景图 |
| 条目行背景 | 半透明灰 rgba(42,42,42,0.18)；高亮行 0.26 |
| 分割线 | 上 #727272，下 #cacaca |
| 进度条填充 | 橙色 #fd9729（详情用）；topbar 用 ResourceProgressBar 自管颜色 |
| 字体 | Sarasa Mono SC Nerd；标题 20px，正文 14/16，小字 12px |

### 2.3 预制作 UI 与编辑器

- **不在 _ready 里写编辑器可见逻辑**：字体、边距、间距、主题等用 `_enter_tree()` 或 `@export` setter；`_ready()` 仅做运行期初始化（如 visible=false）。见 `.cursor/rules/ui-no-ready.mdc`、`ui-editor-live.mdc`。
- **可调项暴露为 @export**：如 content_margin_horizontal、separation、storage_progress_wrapper_path，便于在 Inspector 中改而不改代码。
- **不锁死节点路径**：进度条容器用 NodePath 配置，方便重命名或移动节点后只改 Inspector。

---

## 三、本次同步过程中遇到的问题与解决方案

### 3.1 逻辑写在编辑器不刷新的函数中

- **现象**：多次同步后，字体、边距、进度条文案等被写在 `_ready()` 中，在编辑器中改 Inspector 或场景时界面不更新。
- **原因**：Godot 在编辑场景时不会调用 `_ready()`，只有 setter、`_enter_tree()` 或 `@tool` 下的 `_process()` 会在编辑时再次执行。
- **解决**：
  - 所有「编辑器可见」的更新改为 `_enter_tree()`、`@export` setter 或 `_process(Engine.is_editor_hint())`。
  - 在 `.cursor/rules/figma-import.mdc` 中强制引用 ui-no-ready / ui-editor-live，Figma 同步时必须遵守。
  - 脚本顶注注明禁止在 _ready 中写编辑器可见逻辑。

### 3.2 进度条在详情面板中纵向拉伸 / 尺寸不对

- **现象**：进度条在单独场景中正常，放入详情后面板里被拉得很高。
- **原因**：详情与 topbar 共用同一套 `ResourceProgressBar`，但详情要求总高 20、内高 16（2px 边距），topbar 为另一尺寸；且 wrapper 未限制最大高度，实例在 VBox 中被拉高。
- **解决**：
  - **拆组件**：新增仅用于详情面板的 `DetailStorageProgressBar`（back 图 + 2px 边距 + 16px 内高 + 色块填充），topbar 继续用 `ResourceProgressBar`（MARGIN=1 已还原）。
  - 从 Figma 同步 **storage_progress_bar_back**（node 90:52），用作详情进度条背景。
  - ProgressBarWrapper 设置 `custom_maximum_size = (0, 20)`；详情进度条实例不再写死 280，由 wrapper 的 size_flags 填满内容区宽度。

### 3.3 档案馆 / 产出等条目左边距异常大

- **现象**：固有消耗条目与标题左对齐，但档案馆消耗、产出等子项左边距明显更大，与 Figma 不一致。
- **原因**：部分条目使用了 `StyleBoxFlat_row_indent`（content_margin_left=27），与「固有消耗」用的 `StyleBoxFlat_row`（7px）不统一。
- **解决**：将档案馆消耗、产出、资源储备等条目的 panel 样式统一改为 **StyleBoxFlat_row**（7px），与固有消耗一致；删除未再使用的 row_indent / row_highlight 的 sub_resource。

### 3.4 UpPointer 与 DetailsTitle 之间有多余间距

- **现象**：Figma 中 up_pointer 与 details_title 顶边相接无隙，Godot 中两者之间有缝。
- **原因**：DetailsVboxContainer 的 `separation = 4` 作用于所有子节点，包括 UpPointer 与 DetailsTitle。
- **解决**：新增 **HeaderVbox**（VBoxContainer，separation=0），将 UpPointer 和 DetailsTitle 放入 HeaderVbox 作为 DetailsVboxContainer 的第一个子节点，使两者间距为 0；其余区块仍受 DetailsVboxContainer separation=4 控制。

### 3.5 details_background 与设计不一致

- **现象**：背景图与 Figma 或设计不符。
- **解决**：用 Figma Images API（node 74:9）重新下载并覆盖 `details_background.png`，保持 StyleBoxTexture 2px 边距；在 diff 文档中记录来源 nodeId。

### 3.6 文案与示例数据不一致

- **现象**：储存警告文案与 Figma 不同（如「预计 32 天到达储存上限」vs「将在 32天 后到达上限。」）；固有消耗标题 200/天 与子项之和 300 矛盾。
- **解决**：场景内示例文案改为与 Figma 一致（「将在 32天 后到达上限。」）；固有消耗标题改为 300/天，与子项 240+60 一致；在 diff 文档中说明与设计文档为同义表述、运行期可按设计做动态替换。

### 3.7 代码锁定编辑器中可调的位置与数据

- **现象**：希望边距、进度条节点、Label 文案等可在编辑器中自由调节，但被脚本覆盖。
- **解决**：字体不再在脚本中强制覆盖，交由主题与场景；进度条中央文案仅在运行期同步，编辑器中不覆盖 ProgressBarLabel；进度条容器路径改为 @export NodePath，便于在 Inspector 中重指。

### 3.8 Figma 同步时规则未生效

- **现象**：执行 Figma→Godot 同步的 agent 未遵守预制作 UI 规范，反复把逻辑写进 _ready。
- **解决**：在 figma-import.mdc 中显式加入「预制作 UI 脚本规范」与「Figma 同步预制作 UI 自检清单」，并扩大 glob 覆盖 factor_details_panel / detail_panel，确保编辑该面板时加载规则。

---

## 四、参考文档与资源

- 设计详解：[ui-detail-panel-design.md](ui-detail-panel-design.md)
- 与 Figma/文档差异：[ui-detail-panel-diff.md](ui-detail-panel-diff.md)
- Figma 来源：认知 67:622、意志 67:629、权限 67:630、计算 67:751、庇护 67:855、研究员 70:964、住房 76:65、信息 70:1154、调查员 72:1259、真相 72:1337（fileKey `ndfJ5hiWy9b4iq5JNuZwSJ`）；details_background 74:9，storage_progress_bar_back 90:52
- 规则：`.cursor/rules/ui-no-ready.mdc`、`ui-editor-live.mdc`、`figma-import.mdc`

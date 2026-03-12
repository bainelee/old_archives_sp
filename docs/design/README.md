# 设计文档

本目录用于记录《旧日档案馆》的游戏系统与功能设计讨论。

## 文档索引

### 根目录

| 文档 | 说明 |
|------|------|
| [00 - 项目概览与新系统准备](00-project-overview.md) | 项目定位、结构、已实现功能、数据流、新系统开发建议 |

### 按模块分类

| 模块 | 文档 | 说明 |
|------|------|------|
| **0-values/** | [01 - 游戏数值系统](0-values/01-game-values.md) | 研究员认知消耗、核心庇护/范围、房间清理、建设区域、生活区住房、研究区/造物区产出、空房间改造 |
| | [02 - 游戏数值运行时系统](0-values/02-game-values-runtime.md) | 数值数据源、加载与引用、热重载、同步工作流 |
| **1-editor/** | [01 - 地图编辑器](1-editor/01-map-editor.md) | 网格系统、底板编辑、房间划分 |
| | [02 - 房间信息与 room_info.json 同步](1-editor/02-room-info-and-json-sync.md) | RoomInfo 结构、JSON 格式、同步逻辑 |
| | [03 - 3D 场景编辑器](1-editor/03-3d-scene-editor.md) | 3D 格子、元件盒 actor_box、3d_actor 模板 |
| | [04 - 预设 3D 房间框架](1-editor/04-preset-room-frame.md) | preset_room_frame、房间参考网格、外轮廓、外墙、道具 |
| | [05 - RoomItems 网格对齐](1-editor/05-room-items-grid-snap.md) | 编辑器插件：RoomItems 子节点移动时对齐 RoomReferenceGrid 网格 |
| **2-gameplay/** | [01 - 游戏主场景](2-gameplay/01-game-main.md) | 主运行入口、slot_0 展示、编辑器隔离 |
| | [02 - 时间流逝系统](2-gameplay/02-time-system.md) | GameTime Autoload、TimePanel UI、时间比例与倍速 |
| | [03 - 存档系统](2-gameplay/03-save-system.md) | 存档架构、数据模型、保存/加载流程、与地图槽位关系 |
| | [04 - 房间清理系统](2-gameplay/04-room-cleanup-system.md) | 选择未清理房间、确认清理、多房间并行、进度与遮罩、研究员占用 |
| | [05 - 区域建设功能](2-gameplay/05-zone-construction.md) | 研究区/造物区/生活区/事务所建设流程、数据模型、UI 边界、资源授予约束 |
| | [06 - 已建设房间系统](2-gameplay/06-built-room-system.md) | 已建设房间持续运作、研究区/造物区产出、存量耗尽、住房 |
| | [07 - 研究员侵蚀机制](2-gameplay/07-researcher-erosion.md) | 侵蚀风险、被侵蚀状态、灾厄值、死亡、治愈 |
| | [08 - 研究员系统](2-gameplay/08-researcher-system.md) | 研究员设定汇总、占用分类、已实现功能、待办事项 |
| | [09 - Debug 因子/庇护/UI 技术问题总结](2-gameplay/09-debug-factor-shelter-ui-lessons.md) | 因子细则显示异常、庇护消耗、Node.get 解析问题等 debug 经验 |
| **3-ui/** | [01 - 庇护/侵蚀 UI](3-ui/01-shelter-erosion-ui.md) | ShelterErosionPanel、ErosionCycleBar、侵蚀等级与周期 |
| | [02 - 主 UI 设计概览](3-ui/02-ui-main-overview.md) | TopBar 布局、TimePanel、数据 API |
| | [03 - TopBar UI 元素说明](3-ui/03-topbar-ui-elements.md) | 顶栏各项显示信息及游戏内作用 |
| **99-tools/** | [01 - Framelink MCP 配置](99-tools/01-framelink-mcp-setup.md) | Figma Personal Access Token、Framelink MCP 配置 |
| **100-figma_process/** | [README](100-figma_process/README.md) | Figma 设计与同步规则、MCP 配置（独立编号 01、02…） |
| **locale/** | [01 - 本地化](locale/01-localization.md) | 中英双语、CSV 翻译表、tr()、语言切换（开始界面互斥按钮） |

## 文档编号约定

- **根目录**：仅保留 `00-project-overview.md` 作为入口
- **子目录**：各模块使用自身编号体系（01、02、03…），确保**同一子目录内编号唯一**
- **2-gameplay/**：涵盖游戏主场景、时间、存档、清理、建设、已建设房间、研究员等全部 gameplay 相关设计

---

## 研究员文档速查

| 文档 | 说明 |
|------|------|
| [08 - 研究员系统](2-gameplay/08-researcher-system.md) | **统一入口**：设定汇总、占用分类、3D 可视化、待办 |
| [07 - 研究员侵蚀机制](2-gameplay/07-researcher-erosion.md) | 侵蚀风险、被侵蚀、死亡、治愈、灾厄值、认知危机 |
| [01 - 游戏数值](0-values/01-game-values.md) | 研究员认知消耗、清理/建设占用、住房 |
| [04 - 房间清理](2-gameplay/04-room-cleanup-system.md) | 清理时研究员占用 |
| [05 - 区域建设](2-gameplay/05-zone-construction.md) | 建设时研究员占用 |
| [06 - 已建设房间](2-gameplay/06-built-room-system.md) | 房间工作占用、住房 |
| [名词解释：研究员](../名词解释.md#研究员) | 术语定义 |

---

## 开发变更（近期）

**2025-03 研究员生活周期与 UI**

- 研究员 3D 与 researcher_id 绑定；清理/建设 progress 记录 researcher_ids；空闲 id 列表由 GameMainShelterHelper.get_free_researcher_ids 提供
- ResearcherLifecycle 按游戏时间驱动阶段（工作 8–16、游荡 16–20、回居住区 20–22、睡眠 22–6、前往工作 6–8）；teleport_to_room_id / apply_phase；可游荡房间 = 核心 + 已清理
- 研究员列表与详情 UI：TopBar 下入口按钮、id+名称列表、详情 Tab（状态/工作区/居住区/侵蚀与回复概率等）、摄像机聚焦研究员
- 头顶 Emoji：EmojiAnchor + EmojiHead（Sprite3D），0.15s 进出场动画，按状态与 0.8s/2s/4s 规则显示图标
- 详见 08-researcher-system §4.6–4.9

**2025-02-25 房间清理与研究员 UI**

- 清理悬停面板：消耗显示「信息 X (拥有 Y)」；新增研究员占用「X 人（可用 Y）」
- 清理完成：房间 `resources` 授予玩家，`_sync_resources_to_topbar()` 刷新显示
- 研究员 TopBar：左侧仅显示**空闲**数（总数 − 被侵蚀 − 清理中 − 建设中 − 房间工作）
- 研究员悬停：悬停「研究员：空闲/总数」→ 左侧面板显示总数、被侵蚀、清理中、建设中、房间工作、空闲
- 输入排除：CheatShelterPanel 加入 `_is_click_over_ui_buttons` 与 `_is_click_over_cleanup_allowed_ui`，修复 debug 庇护等级按钮点击无效

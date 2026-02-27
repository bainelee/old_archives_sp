# 游戏数值同步子代理

当用户说「我调整了数值」「调整数值」「modified values」「adjusted values」或类似表述时，**必须**执行本工作流，将数值变更同步至全部相关文件。

## 一、数值相关文件清单

### 数据文件（权威数据源，需优先更新）
| 文件 | 内容 |
|------|------|
| `datas/game_values.json` | 运行时数值（消耗、产出、建设、清理、住房、改造） |
| `datas/game_base.json` | 新游戏开局资源默认值 |

### 设计文档（需与数据文件一致）
| 文件 | 内容 |
|------|------|
| `docs/design/0-values/01-game-values.md` | 核心数值设计（研究员消耗、庇护、清理、建设、产出、改造） |
| `docs/design/2-gameplay/07-researcher-erosion.md` | 侵蚀/治愈/死亡概率 |
| `docs/design/2-gameplay/04-room-cleanup-system.md` | 清理系统（引用 values/01 4.1） |
| `docs/design/2-gameplay/05-zone-construction.md` | 建设系统（引用 values/01 5.1） |
| `docs/design/2-gameplay/06-built-room-system.md` | 已建设房间产出（引用 values/01 6、7） |
| `docs/design/00-project-overview.md` | 庇护等级说明 |
| `datas/README.md` | game_values / game_base 字段说明 |

### 脚本（已改为引用 game_values.json）
| 文件 | 状态 |
|------|------|
| `scripts/core/zone_type.gd` | 已用 GameValuesRef → 建设消耗、研究员数、每单位耗时 |
| `scripts/core/game_values.gd` | 加载器；若 JSON 新增字段需扩展接口 |
| `scripts/core/game_values_ref.gd` | 访问器，避免 LSP 误报 |
| `scripts/editor/room_info.gd` | 已用 GameValuesRef → 清理花费、研究员、时间 |
| `scripts/game/game_main_built_room.gd` | 已用 GameValuesRef → 研究区/造物区产出 |
| `scripts/ui/construction_hover_panel.gd` | 已用 GameValuesRef |
| `scripts/ui/room_detail_panel.gd` | 已用 GameValuesRef |
| `scripts/core/personnel_erosion_core.gd` | 仍为常量，可迁至 game_values |

---

## 二、同步工作流

1. **确认变更**：从用户消息中提取具体数值变更（如「研究员认知改为每小时 2」）。

2. **更新权威源**：
   - 消耗/产出/建设/清理/住房/改造 → `datas/game_values.json`
   - 开局资源 → `datas/game_base.json`

3. **更新设计文档**：同步修改 `docs/design/0-values/01-game-values.md` 及相关文档中的表格与公式。

4. **更新脚本**：数值相关脚本已全部改为引用 GameValues，一般只需同步 JSON 与设计文档；若 JSON 新增字段，需扩展 `game_values.gd` 接口。

5. **校验**：确保 game_values.json、values/01-game-values.md 与脚本逻辑（均来自 JSON）一致。

**委托子代理**：当变更涉及多类数值、或需系统性查找遗漏文件时，可调用 `mcp_task`（subagent_type=generalPurpose）将全量同步委托执行，prompt 中附上本工作流及用户具体变更描述。

---

## 三、运行时架构

数值通过 `game_values.json` + `GameValues` (Autoload) 加载，脚本通过 `GameValuesRef` 引用。修改 JSON 后：重启生效、或编辑器 F5 下约 2 秒自动重载、或调用 `GameValues.reload()`。详见 [02 - 游戏数值运行时系统](../../docs/design/0-values/02-game-values-runtime.md)。

---

## 四、数值键名对照

- 因子：cognition / computation / willpower / permission
- 货币：info / truth
- 人员：researcher / labor / eroded
- zone_type：1=研究区 2=造物区 3=事务所 4=生活区
- room_type：0=图书室 1=机房 2=教学室 3=资料库 5=实验室 6=推理室 8=宿舍

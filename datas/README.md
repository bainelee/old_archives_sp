# datas 数据文件夹

本文件夹存放数据类文件（如 JSON），**未被 Godot 导入**（见项目根目录 `.gdignore`）。位于 `res://datas/` 的文件会随项目打包进游戏，可供运行时加载。

## game_values.json

游戏数值数据，供 `GameValues`（Autoload）运行时加载。设计来源为 `docs/design/0-values/01-game-values.md`；该设计文档不打包进游戏，故游戏逻辑应读取本 JSON 作为唯一数据源。

- `researcher_cognition`：研究员认知消耗（每小时每人）
- `shelter`：档案馆核心庇护等级、范围档位、消耗倍率
- `cleanup`：房间清理需求（按房间单位，支持 `units_min`/`units_max`）
- `construction`：建设区域需求（按 zone_type）
- `housing`：住房相关（宿舍单位、住房数量）
- `research_output`：研究区产出（按 room_type）
- `creation_output`：造物区产出（按 room_type）
- `remodel`：空房间改造消耗

数据键名与 `docs/settings/00-project-keywords.md` 一致。`_fields_comment` 等以 `_` 开头的键仅作说明，加载时跳过。

### 修改后生效

- **重启游戏**：始终生效
- **编辑器 F5 运行**：保存后约 2 秒内自动检测并重载
- **手动**：调用 `GameValues.reload()` 可立即生效

详见 [02 - 游戏数值运行时系统](../docs/design/0-values/02-game-values-runtime.md)。

## game_base.json

游戏基础数据，存放固定数值（如新游戏开局时的资源与人员）。供 SaveManager、GameMain 等读取，作为新游戏默认值或存档缺省补齐。数据键名与 [docs/settings/00-project-keywords.md](../docs/settings/00-project-keywords.md) 一致。

- `initial_resources.factors`：四种因子（cognition 认知, computation 计算, willpower 意志, permission 权限）
- `initial_resources.currency`：货币（info 信息, truth 真相）
- `initial_resources.personnel`：人员（researcher 研究员, labor 劳动力（暂未使用）, eroded 被侵蚀, investigator 调查员）
- `initial_time.total_game_hours`：开局游戏内小时数（通常为 0）

`_fields_comment` 为字段中英对照，加载时需跳过（以 `_` 开头的键仅作说明用）。所有数值为整数。

## room_info.json

房间信息表，从地图槽位 1（基础档案馆分布）导出，UTF-8 编码。每个房间具有唯一编号 `id`（如 ROOM_001）。

```json
{
  "source": "数据来源说明",
  "rooms": [
    {
      "id": "ROOM_001",
      "room_name": "房间名称",
      "size": "5×3",
      "room_type": "房间类型",
      "room_type_id": 3,
      "clean_status": 0,
      "base_image_path": "res://assets/...",
      "resources": [{"resource_type": 4, "resource_amount": 5000}],
      "pre_clean_text": "默认清理前文本",
      "desc": "房间背景描述"
    }
  ]
}
```

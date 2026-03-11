# datas 数据文件夹

本文件夹存放数据类文件（如 JSON），**未被 Godot 导入**（见项目根目录 `.gdignore`）。位于 `res://datas/` 的文件会随项目打包进游戏，可供运行时加载。

## game_values.json

游戏数值数据，供 `GameValues`（Autoload）运行时加载。设计来源为 `docs/design/0-values/01-game-values.md`；该设计文档不打包进游戏，故游戏逻辑应读取本 JSON 作为唯一数据源。

- `factor_caps`：四种因子储藏上限（cognition/computation/willpower/permission），达上限后不再获得
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

- `initial_resources.factors`：四种因子（cognition 认知, computation 计算, willpower 意志, permission 权限）；计算因子 60,000，认知 6,000，意志/权限 4,000
- `initial_resources.currency`：货币（info 信息, truth 真相）
- `initial_resources.personnel`：人员（researcher 研究员, labor 劳动力（暂未使用）, eroded 被侵蚀, investigator 调查员）
- `initial_time.total_game_hours`：开局游戏内小时数（通常为 0）

`_fields_comment` 为字段中英对照，加载时需跳过（以 `_` 开头的键仅作说明用）。所有数值为整数。

## room_info.json（新版本，v2）

3D 档案馆房间信息表，UTF-8 编码。每个房间具有唯一 `id`。设计参考 `docs/design/4-archives_rooms/01-archive_rooms_info.md`。

```json
{
  "source": "新版本档案馆房间 (3D)",
  "version": 2,
  "rooms": [
    {
      "id": "room_00",
      "clean_status": 0,
      "room_name": "档案馆核心",
      "3d_size": "base|long|tall|small|small_tall",
      "room_type": "核心",
      "items_in_room": [{"item_id": "xxx", "item_position": [x, y, z]}],
      "room_resources": [{"type": 2, "amount": 0}],
      "pre_clean_text": "默认清理前描述",
      "desc": ["描述行1", "描述行2"]
    }
  ]
}
```

- **clean_status**：0=未清理，1=已清理
- **3d_size**：房间体积标识，见 `docs/design/4-archives_rooms/02-room-dimensions-and-specs.md`
- **room_type**：房间类型，见 `docs/design/4-archives_rooms/03-room-types.md`
- **items_in_room**：房间内道具，`item_position` 为格子坐标 [x, y, z]
- **room_resources**：`type` 对应 RoomInfo.ResourceType 枚举，`amount` 为数量

## room_info_legacy.json（旧版，2D 地图编辑器用）

2D 地图编辑器模板库，从地图槽位导出。编辑器保存/导入模板、本地化同步脚本均引用此文件。每个房间 `id` 为 ROOM_XXX 格式。

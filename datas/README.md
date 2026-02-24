# datas 数据文件夹

本文件夹存放数据类文件（如 JSON），**未被 Godot 导入**（见项目根目录 `.gdignore`）。

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

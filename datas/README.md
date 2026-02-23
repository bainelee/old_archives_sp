# datas 数据文件夹

本文件夹存放数据类文件（如 JSON），**未被 Godot 导入**（见项目根目录 `.gdignore`）。

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

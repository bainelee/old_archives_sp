class_name UIUtils
extends RefCounted
## UI 相关通用工具
## 安全类型转换、消耗格式化等

static func _tr(key: String) -> String:
	return TranslationServer.translate(key)

## 安全转换因子/资源值为 int：防止 "60000/60000" 等字符串被误解析
## 注意：UI 中的 "库存 X / Y" 格式，斜杠为显示用字符，不是除法运算
static func safe_int(v: Variant, default_val: int = 0) -> int:
	if v is int:
		return int(v)
	if v is float:
		return int(v)
	if v is String:
		var s: String = (v as String).strip_edges()
		if "/" in s:
			var parts: PackedStringArray = s.split("/", true, 1)
			s = parts[0].strip_edges() if parts.size() > 0 else ""
		return int(s) if s.is_valid_int() else default_val
	return default_val


const _COST_KEY_TR: Dictionary = {
	"cognition": "RESOURCE_COGNITION",
	"computation": "RESOURCE_COMPUTATION",
	"willpower": "RESOURCE_WILL",
	"permission": "RESOURCE_PERMISSION",
	"info": "RESOURCE_INFO",
	"truth": "RESOURCE_TRUTH",
}

## 显示消耗并附带玩家拥有量，如「信息 20 (拥有 500)」
static func format_cost_with_have(cost: Dictionary, player_resources: Dictionary) -> String:
	if cost.is_empty():
		return _tr("COST_NONE")
	var parts: PackedStringArray = []
	for key in cost:
		var amt: int = int(cost.get(key, 0))
		if amt > 0:
			var have: int = int(player_resources.get(key, 0))
			var name_str: String = _tr(_COST_KEY_TR.get(key, key))
			parts.append(_tr("COST_WITH_HAVE") % [name_str, amt, have])
	return ", ".join(parts) if parts.size() > 0 else _tr("COST_NONE")

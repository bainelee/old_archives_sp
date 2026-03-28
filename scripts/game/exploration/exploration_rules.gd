class_name ExplorationRules
extends RefCounted

## 探索静态规则与配置查询。

const _Codec := preload("res://scripts/game/exploration/exploration_state_codec.gd")


static func get_initial_unlock_region_ids(config: Dictionary) -> Array[String]:
	var raw: Variant = config.get("initial_unlock_region_ids", [])
	return _Codec.normalize_string_id_array(raw)


static func get_hub_region_id(config: Dictionary) -> String:
	return str(config.get("hub_region_id", "old_archives"))


static func get_default_debug_investigator_count(config: Dictionary) -> int:
	return int(config.get("default_initial_investigator_count_debug", 5))


static func catalog_has_region_id(config: Dictionary, region_id: String) -> bool:
	var catalog: Variant = config.get("regions_placeholder", [])
	if not (catalog is Array):
		return false
	for entry in catalog as Array:
		if entry is Dictionary and str((entry as Dictionary).get("id", "")) == region_id:
			return true
	return false


static func get_neighbor_region_ids(config: Dictionary, region_id: String) -> Array[String]:
	var out: Array[String] = []
	var edges: Variant = config.get("region_edges", [])
	if not (edges is Array):
		return out
	for item in edges as Array:
		if not (item is Array):
			continue
		var pair: Array = item as Array
		if pair.size() < 2:
			continue
		var a: String = str(pair[0])
		var b: String = str(pair[1])
		if a == region_id and not out.has(b):
			out.append(b)
		elif b == region_id and not out.has(a):
			out.append(a)
	return out


static func get_region_explore_game_hours(config: Dictionary, region_id: String) -> float:
	var catalog: Variant = config.get("regions_placeholder", [])
	if catalog is Array:
		for entry in catalog as Array:
			if entry is Dictionary:
				var d: Dictionary = entry as Dictionary
				if str(d.get("id", "")) == region_id:
					if d.has("explore_game_hours"):
						return float(d.get("explore_game_hours", 0.0))
	return float(config.get("default_explore_game_hours", 24.0))

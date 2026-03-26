class_name ExplorationRules
extends RefCounted

## 探索静态规则与配置查询（P1）。邻接与结算逻辑后续扩展。

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

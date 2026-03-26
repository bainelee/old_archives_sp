class_name ExplorationService
extends RefCounted

## 探索运行时服务骨架（P1）。
## ---------------------------------------------------------------------------
## 呈现层决策：探索地图 UI 应由 **overlay / 独立 Canvas 层** 承载（与主基地画布解耦）。
## 本阶段不创建场景、不接线；打开探索地图时由流程挂接本服务并读取状态即可。
## ---------------------------------------------------------------------------
## 时间与离线：P1 **不做** 离线时长补算；`tick` 仅为占位，供后续与 GameTime 对齐。
## ---------------------------------------------------------------------------

const CONFIG_PATH := "res://datas/exploration_config.json"

const _Codec := preload("res://scripts/game/exploration/exploration_state_codec.gd")
const _Rules := preload("res://scripts/game/exploration/exploration_rules.gd")
const _TickScript := preload("res://scripts/game/exploration/exploration_tick.gd")

var _config: Dictionary = {}
var _state: Dictionary = {}


func _init() -> void:
	reload_static_config()


func reload_static_config() -> void:
	_config = _load_config_file()


func init_default_state() -> void:
	_state = _Codec.create_default_runtime_state()


func ensure_first_open_initialized() -> void:
	if _state.is_empty():
		init_default_state()
	if bool(_state.get(_Codec.KEY_FIRST_OPEN_DONE, false)):
		return
	var hub: String = _Rules.get_hub_region_id(_config)
	var initial_ids: Array[String] = _Rules.get_initial_unlock_region_ids(_config)
	var dbg_count: int = _Rules.get_default_debug_investigator_count(_config)
	var unlocked: Array = _state.get(_Codec.KEY_UNLOCKED_REGION_IDS, []).duplicate()
	var explored: Array = _state.get(_Codec.KEY_EXPLORED_REGION_IDS, []).duplicate()
	if not (unlocked is Array):
		unlocked = []
	if not (explored is Array):
		explored = []
	if not explored.has(hub):
		explored.append(hub)
	if not unlocked.has(hub):
		unlocked.append(hub)
	for rid in initial_ids:
		if not unlocked.has(rid):
			unlocked.append(rid)
	_state[_Codec.KEY_FIRST_OPEN_DONE] = true
	_state[_Codec.KEY_UNLOCKED_REGION_IDS] = unlocked
	_state[_Codec.KEY_EXPLORED_REGION_IDS] = explored
	_state[_Codec.KEY_DEBUG_INVESTIGATOR_POOL] = dbg_count


func ensure_starter_neighbors_on_first_map_open() -> bool:
	var was_done: bool = bool(_state.get(_Codec.KEY_FIRST_OPEN_DONE, false))
	ensure_first_open_initialized()
	var now_done: bool = bool(_state.get(_Codec.KEY_FIRST_OPEN_DONE, false))
	return (not was_done) and now_done


func export_save_snapshot() -> Dictionary:
	return _Codec.encode_for_save(_state)


func to_save_dict() -> Dictionary:
	return export_save_snapshot()


func restore_from_save(blob: Variant) -> void:
	_state = _Codec.decode_to_runtime(blob)


func load_from_save_dict(data: Variant) -> void:
	restore_from_save(data)


func get_runtime_state_readonly() -> Dictionary:
	return _state.duplicate(true)


func get_config_readonly() -> Dictionary:
	return _config.duplicate(true)


func tick(delta_game_hours: float) -> void:
	_TickScript.tick(self, delta_game_hours)


static func _load_config_file() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_error("ExplorationService: missing config " + CONFIG_PATH)
		return {}
	var f: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not f:
		push_error("ExplorationService: cannot read " + CONFIG_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}

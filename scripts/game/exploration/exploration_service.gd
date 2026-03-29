class_name ExplorationService
extends RefCounted

## 探索运行时服务骨架（P1）。
## ---------------------------------------------------------------------------
## 呈现层决策：探索地图 UI 应由 **overlay / 独立 Canvas 层** 承载（与主基地画布解耦）。
## 本阶段不创建场景、不接线；打开探索地图时由流程挂接本服务并读取状态即可。
## ---------------------------------------------------------------------------
## 时间与离线：**不做** 离线现实时间补算；`tick` 接收 `GameMain` 汇总的 `game_hours_delta` 推进探索中计时；完成后解锁邻接（见 exploration_tick）。
## ---------------------------------------------------------------------------

const CONFIG_PATH := "res://datas/exploration_config.json"
const INVESTIGATIONS_PATH := "res://datas/exploration_investigations.json"

const _Codec := preload("res://scripts/game/exploration/exploration_state_codec.gd")
const _Rules := preload("res://scripts/game/exploration/exploration_rules.gd")
const _TickScript := preload("res://scripts/game/exploration/exploration_tick.gd")

var _config: Dictionary = {}
var _investigations_blob: Dictionary = {}
## site_id -> { "region_id": String, "site": Dictionary }
var _site_index: Dictionary = {}
var _state: Dictionary = {}


func _init() -> void:
	reload_static_config()


func reload_static_config() -> void:
	_config = _load_config_file()
	_investigations_blob = _load_investigations_file()
	_rebuild_site_index()


func init_default_state() -> void:
	_state = _Codec.create_default_runtime_state()


func ensure_first_open_initialized() -> void:
	if _state.is_empty():
		init_default_state()
	if not _state.has(_Codec.KEY_EXPLORING_BY_REGION):
		_state[_Codec.KEY_EXPLORING_BY_REGION] = {}
	if not _state.has(_Codec.KEY_COMPLETED_INVESTIGATION_SITE_IDS):
		_state[_Codec.KEY_COMPLETED_INVESTIGATION_SITE_IDS] = []
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


func get_investigations_readonly() -> Dictionary:
	return _investigations_blob.duplicate(true)


func get_investigation_sites_for_region(region_id: String) -> Array:
	var rid: String = region_id.strip_edges()
	var raw: Variant = _investigations_blob.get("sites_by_region", {})
	if not (raw is Dictionary):
		return []
	var arr: Variant = (raw as Dictionary).get(rid, [])
	if not (arr is Array):
		return []
	var out: Array = []
	for item in arr as Array:
		if item is Dictionary:
			out.append((item as Dictionary).duplicate(true))
	return out


func get_site_definition(site_id: String) -> Dictionary:
	var sid: String = site_id.strip_edges()
	var entry: Variant = _site_index.get(sid, null)
	if entry is Dictionary:
		var site: Variant = (entry as Dictionary).get("site", {})
		if site is Dictionary:
			return (site as Dictionary).duplicate(true)
	return {}


func get_site_region_id(site_id: String) -> String:
	var sid: String = site_id.strip_edges()
	var entry: Variant = _site_index.get(sid, null)
	if entry is Dictionary:
		return str((entry as Dictionary).get("region_id", ""))
	return ""


func is_investigation_site_completed(site_id: String) -> bool:
	var sid: String = site_id.strip_edges()
	var raw: Variant = _state.get(_Codec.KEY_COMPLETED_INVESTIGATION_SITE_IDS, [])
	if not (raw is Array):
		return false
	return (raw as Array).has(sid)


func mark_investigation_site_completed(site_id: String) -> void:
	var sid: String = site_id.strip_edges()
	if sid.is_empty():
		return
	var raw: Variant = _state.get(_Codec.KEY_COMPLETED_INVESTIGATION_SITE_IDS, [])
	var arr: Array = raw.duplicate() if raw is Array else []
	if arr.has(sid):
		return
	arr.append(sid)
	_state[_Codec.KEY_COMPLETED_INVESTIGATION_SITE_IDS] = arr


## 校验地区已探索、调查点未完成、选项存在；返回 cost/reward 供 GameMain 扣发。
func validate_investigation_option(site_id: String, option_id: String) -> Dictionary:
	var sid: String = site_id.strip_edges()
	var oid: String = option_id.strip_edges()
	if sid.is_empty() or oid.is_empty():
		return {"ok": false, "reason": "empty_id"}
	var site: Dictionary = get_site_definition(sid)
	if site.is_empty():
		return {"ok": false, "reason": "unknown_site"}
	var rid: String = get_site_region_id(sid)
	if rid.is_empty():
		return {"ok": false, "reason": "unknown_site_region"}
	var explored: Variant = _state.get(_Codec.KEY_EXPLORED_REGION_IDS, [])
	if not (explored is Array) or not (explored as Array).has(rid):
		return {"ok": false, "reason": "region_not_explored"}
	if is_investigation_site_completed(sid):
		return {"ok": false, "reason": "site_already_completed"}
	var opts: Variant = site.get("options", [])
	if not (opts is Array):
		return {"ok": false, "reason": "no_options"}
	for item in opts as Array:
		if not (item is Dictionary):
			continue
		var o: Dictionary = item as Dictionary
		if str(o.get("id", "")) != oid:
			continue
		var cost: Dictionary = {}
		var cr: Variant = o.get("cost", {})
		if cr is Dictionary:
			cost = (cr as Dictionary).duplicate(true)
		var reward: Dictionary = {}
		var rr: Variant = o.get("reward", {})
		if rr is Dictionary:
			reward = (rr as Dictionary).duplicate(true)
		return {"ok": true, "reason": "", "cost": cost, "reward": reward}
	return {"ok": false, "reason": "unknown_option"}


func _rebuild_site_index() -> void:
	_site_index.clear()
	var raw: Variant = _investigations_blob.get("sites_by_region", {})
	if not (raw is Dictionary):
		return
	for region_key in (raw as Dictionary).keys():
		var rid: String = str(region_key)
		var arr: Variant = (raw as Dictionary)[region_key]
		if not (arr is Array):
			continue
		for item in arr as Array:
			if not (item is Dictionary):
				continue
			var site: Dictionary = item as Dictionary
			var sid: String = str(site.get("id", ""))
			if sid.is_empty():
				continue
			_site_index[sid] = {"region_id": rid, "site": site.duplicate(true)}


func tick(delta_game_hours: float) -> void:
	_TickScript.apply_tick(_state, _config, delta_game_hours)


## 发起地区探索：占用调查员、写入计时；完成后由 tick 迁移并解锁邻接。
func explore_region(region_id: String) -> Dictionary:
	ensure_first_open_initialized()
	var rid: String = region_id.strip_edges()
	if rid.is_empty():
		return {"ok": false, "reason": "empty_region_id", "hours_total": 0.0}
	if not _Rules.catalog_has_region_id(_config, rid):
		return {"ok": false, "reason": "unknown_region", "hours_total": 0.0}
	var explored: Variant = _state.get(_Codec.KEY_EXPLORED_REGION_IDS, [])
	if explored is Array and (explored as Array).has(rid):
		return {"ok": false, "reason": "already_explored", "hours_total": 0.0}
	var unlocked: Variant = _state.get(_Codec.KEY_UNLOCKED_REGION_IDS, [])
	if not (unlocked is Array) or not (unlocked as Array).has(rid):
		return {"ok": false, "reason": "not_unlocked", "hours_total": 0.0}
	var exploring: Variant = _state.get(_Codec.KEY_EXPLORING_BY_REGION, {})
	if exploring is Dictionary and (exploring as Dictionary).has(rid):
		return {"ok": false, "reason": "already_exploring", "hours_total": 0.0}
	var need_inv: int = int(_config.get("explore_investigators_per_region", 1))
	var pool: int = int(_state.get(_Codec.KEY_DEBUG_INVESTIGATOR_POOL, 0))
	if pool < need_inv:
		return {"ok": false, "reason": "no_investigators", "hours_total": 0.0}
	var hours: float = _Rules.get_region_explore_game_hours(_config, rid)
	if hours <= 0.0:
		hours = float(_config.get("default_explore_game_hours", 24.0))
	var ex: Dictionary = {}
	if exploring is Dictionary:
		ex = (exploring as Dictionary).duplicate(true)
	ex[rid] = {"hours_remaining": hours, "investigators_reserved": need_inv}
	_state[_Codec.KEY_EXPLORING_BY_REGION] = ex
	_state[_Codec.KEY_DEBUG_INVESTIGATOR_POOL] = pool - need_inv
	return {"ok": true, "reason": "", "hours_total": hours}


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


static func _load_investigations_file() -> Dictionary:
	if not FileAccess.file_exists(INVESTIGATIONS_PATH):
		push_warning("ExplorationService: missing investigations " + INVESTIGATIONS_PATH)
		return {}
	var f2: FileAccess = FileAccess.open(INVESTIGATIONS_PATH, FileAccess.READ)
	if not f2:
		push_error("ExplorationService: cannot read " + INVESTIGATIONS_PATH)
		return {}
	var parsed2: Variant = JSON.parse_string(f2.get_as_text())
	f2.close()
	return parsed2 if parsed2 is Dictionary else {}

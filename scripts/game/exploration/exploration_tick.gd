class_name ExplorationTick
extends RefCounted

## 游戏内时间推进（游戏小时）。不做离线现实时间补算。

const _Codec := preload("res://scripts/game/exploration/exploration_state_codec.gd")
const _Rules := preload("res://scripts/game/exploration/exploration_rules.gd")


static func apply_tick(state: Dictionary, config: Dictionary, delta_game_hours: float) -> void:
	if delta_game_hours <= 0.0:
		return
	var exploring: Variant = state.get(_Codec.KEY_EXPLORING_BY_REGION, {})
	if not (exploring is Dictionary):
		return
	var ex: Dictionary = exploring as Dictionary
	if ex.is_empty():
		return
	var to_complete: Array[String] = []
	for rid in ex.keys():
		var entry: Variant = ex[rid]
		if not (entry is Dictionary):
			continue
		var e: Dictionary = (entry as Dictionary).duplicate(true)
		var left: float = float(e.get("hours_remaining", 0.0))
		left -= delta_game_hours
		e["hours_remaining"] = left
		ex[rid] = e
		if left <= 0.001:
			to_complete.append(str(rid))
	for region_id in to_complete:
		_complete_region_exploration(state, config, region_id)


static func _complete_region_exploration(state: Dictionary, config: Dictionary, region_id: String) -> void:
	var exploring: Variant = state.get(_Codec.KEY_EXPLORING_BY_REGION, {})
	if not (exploring is Dictionary):
		return
	var ex: Dictionary = exploring as Dictionary
	if not ex.has(region_id):
		return
	var entry: Variant = ex[region_id]
	ex.erase(region_id)
	var inv_back: int = 0
	if entry is Dictionary:
		inv_back = int((entry as Dictionary).get("investigators_reserved", 0))
	var pool: int = int(state.get(_Codec.KEY_DEBUG_INVESTIGATOR_POOL, 0))
	state[_Codec.KEY_DEBUG_INVESTIGATOR_POOL] = pool + inv_back
	var explored: Array = state.get(_Codec.KEY_EXPLORED_REGION_IDS, []).duplicate()
	if not (explored is Array):
		explored = []
	if not explored.has(region_id):
		explored.append(region_id)
	state[_Codec.KEY_EXPLORED_REGION_IDS] = explored
	var unlocked: Array = state.get(_Codec.KEY_UNLOCKED_REGION_IDS, []).duplicate()
	if not (unlocked is Array):
		unlocked = []
	var neigh: Array[String] = _Rules.get_neighbor_region_ids(config, region_id)
	for nid in neigh:
		if not unlocked.has(nid):
			unlocked.append(nid)
	state[_Codec.KEY_UNLOCKED_REGION_IDS] = unlocked

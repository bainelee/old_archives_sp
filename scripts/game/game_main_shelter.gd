class_name GameMainShelterHelper
extends RefCounted

## 档案馆核心庇护能量分配
## 核心消耗计算因子产出庇护能量，按需分配至需要庇护的房间
## 详见 docs/design/0-values/01-game-values.md §2

const ZoneTypeScript = preload("res://scripts/core/zone_type.gd")
const _GameValuesRef = preload("res://scripts/core/game_values_ref.gd")
## 每小时 tick 后的庇护能量分配结果 { room_id: energy }
var _room_shelter_energy: Dictionary = {}
## 本小时实际消耗的计算因子
var _last_cf_consumed: int = 0
## 玩家手动设置的房间庇护目标值（room_id -> target_energy）
var _manual_room_shelter_target: Dictionary = {}
## 记录最近一次每房上限；变化时按规则清空全部手动目标
var _last_energy_per_room_max: int = -1


## 执行庇护 tick，计算分配并扣除计算因子
## shelter_level: 核心能耗等级 1～5
static func process_shelter_tick(game_main: Node2D, game_hours_delta: float, shelter_level: int) -> void:
	var helper: GameMainShelterHelper = _get_or_create_helper(game_main)
	helper._tick(game_main, game_hours_delta, shelter_level)


## 获取房间庇护等级（全局有效侵蚀 + 分配的庇护能量）
## 全局基线与 TopBar 一致：ErosionCore.current_erosion（raw_mystery_erosion + shelter_bonus）
static func get_room_shelter_level(game_main: Node2D, room_id: String) -> int:
	var helper: GameMainShelterHelper = game_main.get("_shelter_helper")
	if not helper:
		return _get_global_erosion_for_shelter()
	var energy: int = int(helper._room_shelter_energy.get(room_id, 0))
	return _get_global_erosion_for_shelter() + energy


## 本房当前由核心分配的庇护能量（上一小时 tick 结果；与 get_room_shelter_level 中的加项一致）
static func get_room_allocated_shelter_energy(game_main: Node2D, room_id: String) -> int:
	var helper: Variant = game_main.get("_shelter_helper")
	if not helper or not (helper is GameMainShelterHelper):
		return 0
	return int((helper as GameMainShelterHelper)._room_shelter_energy.get(room_id, 0))


## 设置房间手动庇护目标值（严格总量限制）
## 返回 {applied, clamped, max_assignable, reason}
static func set_room_manual_shelter_target(game_main: Node2D, room_id: String, target: int) -> Dictionary:
	var result: Dictionary = {
		"applied": 0,
		"clamped": false,
		"max_assignable": 0,
		"reason": "ok",
	}
	if room_id.is_empty():
		result["reason"] = "invalid_room_id"
		return result
	var helper: GameMainShelterHelper = _get_or_create_helper(game_main)
	var ctx: Dictionary = helper._build_manual_context(game_main)
	if not bool(ctx.get("valid", false)):
		result["reason"] = "invalid_context"
		return result
	var need_ids: Dictionary = ctx.get("need_room_ids", {})
	if not need_ids.has(room_id):
		helper._manual_room_shelter_target.erase(room_id)
		result["reason"] = "room_not_need_shelter"
		return result
	var per_room_max: int = int(ctx.get("per_room_max", 0))
	var safe_target: int = clampi(target, 0, per_room_max)
	var max_assignable: int = helper._compute_manual_max_assignable(room_id, ctx)
	var applied: int = mini(safe_target, max_assignable)
	helper._manual_room_shelter_target[room_id] = applied
	result["applied"] = applied
	result["max_assignable"] = max_assignable
	result["clamped"] = applied != target
	if applied < target:
		result["reason"] = "clamped_by_total_cap"
	return result


## 查询当前房间在严格总量限制下可手动设置的最大值
static func get_room_manual_shelter_max_assignable(game_main: Node2D, room_id: String) -> int:
	if room_id.is_empty():
		return 0
	var helper: GameMainShelterHelper = _get_or_create_helper(game_main)
	var ctx: Dictionary = helper._build_manual_context(game_main)
	if not bool(ctx.get("valid", false)):
		return 0
	var need_ids: Dictionary = ctx.get("need_room_ids", {})
	if not need_ids.has(room_id):
		return 0
	return helper._compute_manual_max_assignable(room_id, ctx)


static func get_room_manual_shelter_target(game_main: Node2D, room_id: String) -> int:
	var helper: Variant = game_main.get("_shelter_helper")
	if not helper or not (helper is GameMainShelterHelper):
		return 0
	return int((helper as GameMainShelterHelper)._manual_room_shelter_target.get(room_id, 0))


static func clear_room_manual_shelter_target(game_main: Node2D, room_id: String) -> void:
	if room_id.is_empty():
		return
	var helper: Variant = game_main.get("_shelter_helper")
	if helper and helper is GameMainShelterHelper:
		(helper as GameMainShelterHelper)._manual_room_shelter_target.erase(room_id)


static func get_manual_room_shelter_targets_for_save(game_main: Node2D) -> Dictionary:
	var helper: Variant = game_main.get("_shelter_helper")
	if not helper or not (helper is GameMainShelterHelper):
		return {}
	return ((helper as GameMainShelterHelper)._manual_room_shelter_target).duplicate(true)


static func load_manual_room_shelter_targets(game_main: Node2D, data: Dictionary) -> void:
	var helper: GameMainShelterHelper = _get_or_create_helper(game_main)
	helper._manual_room_shelter_target.clear()
	for k in data.keys():
		var room_id: String = str(k)
		if room_id.is_empty():
			continue
		helper._manual_room_shelter_target[room_id] = maxi(0, int(data.get(k, 0)))


## 根据研究员工作/住房返回有效庇护等级（用于侵蚀判定）
## researcher: { work_room_id, housing_room_id, is_eroded }
static func get_shelter_level_for_researcher(game_main: Node2D, researcher: Dictionary) -> int:
	var work_rid: String = str(researcher.get("work_room_id", ""))
	var housing_rid: String = str(researcher.get("housing_room_id", ""))
	var is_eroded: bool = bool(researcher.get("is_eroded", false))

	if work_rid.is_empty() and housing_rid.is_empty():
		return _get_global_erosion_for_shelter()
	if work_rid.is_empty():
		return get_room_shelter_level(game_main, housing_rid)
	if is_eroded:
		return get_room_shelter_level(game_main, housing_rid) if not housing_rid.is_empty() else _get_global_erosion_for_shelter()
	return get_room_shelter_level(game_main, work_rid)


## 研究员是否有工作但无住房
static func has_no_housing(researcher: Dictionary) -> bool:
	var work_rid: String = str(researcher.get("work_room_id", ""))
	var housing_rid: String = str(researcher.get("housing_room_id", ""))
	return not work_rid.is_empty() and housing_rid.is_empty()


## 返回当前「空闲」研究员 id 列表（未侵蚀，且未被清理/建设/已建设房间占用），按 id 升序，与 enrich 槽位顺序一致
static func get_free_researcher_ids(game_main: Node2D) -> Array:
	var ids: Array = []
	if not PersonnelErosionCore:
		return ids
	var researchers: Array = PersonnelErosionCore.get_researchers()
	if researchers.is_empty():
		return ids
	var work_slots_count: int = _count_work_slots(game_main)
	for r in researchers:
		if r.get("is_eroded", false):
			continue
		var rid: int = int(r.get("id", 0))
		if rid >= work_slots_count:
			ids.append(rid)
	ids.sort()
	return ids


static func _count_work_slots(game_main: Node2D) -> int:
	var rooms: Array = game_main.get_game_rooms()
	var cleanup_rooms: Dictionary = game_main.get("_cleanup_rooms_in_progress")
	var construction_rooms: Dictionary = game_main.get("_construction_rooms_in_progress")
	var n: int = 0
	for room_idx in cleanup_rooms:
		if room_idx >= 0 and room_idx < rooms.size():
			n += rooms[room_idx].get_cleanup_researcher_count()
	for room_idx in construction_rooms:
		var data: Dictionary = construction_rooms[room_idx]
		var zt: int = int(data.get("zone_type", 0))
		if room_idx >= 0 and room_idx < rooms.size():
			n += rooms[room_idx].get_construction_researcher_count(zt)
	for room in rooms:
		var rm: ArchivesRoomInfo = room as ArchivesRoomInfo
		if rm.zone_type == 0 or rm.zone_type == ZoneTypeScript.Type.LIVING:
			continue
		if (rm.id if rm.id else rm.json_room_id).is_empty():
			continue
		n += rm.get_construction_researcher_count(rm.zone_type)
	return n


## 根据游戏状态为研究员填充 work_room_id、housing_room_id（动态推算，按 researcher id 顺序分配）
## 返回带 work_room_id、housing_room_id 的研究员副本
static func enrich_researcher_with_rooms(game_main: Node2D, researcher: Dictionary) -> Dictionary:
	var r: Dictionary = researcher.duplicate()
	var researcher_id: int = int(r.get("id", 0))

	var work_slots: Array[String] = []
	var rooms: Array = game_main.get_game_rooms()
	var cleanup_rooms: Dictionary = game_main.get("_cleanup_rooms_in_progress")
	var construction_rooms: Dictionary = game_main.get("_construction_rooms_in_progress")

	for room_idx in cleanup_rooms:
		if room_idx >= 0 and room_idx < rooms.size():
			for _j in rooms[room_idx].get_cleanup_researcher_count():
				work_slots.append("")
	for room_idx in construction_rooms:
		var data: Dictionary = construction_rooms[room_idx]
		var zt: int = int(data.get("zone_type", 0))
		if room_idx >= 0 and room_idx < rooms.size():
			for _j in rooms[room_idx].get_construction_researcher_count(zt):
				work_slots.append("")

	for room in rooms:
		var rm: ArchivesRoomInfo = room as ArchivesRoomInfo
		if rm.zone_type == 0 or rm.zone_type == ZoneTypeScript.Type.LIVING:
			continue
		var rid_str: String = rm.id if rm.id else rm.json_room_id
		if rid_str.is_empty():
			continue
		for _j in rm.get_construction_researcher_count(rm.zone_type):
			work_slots.append(rid_str)

	var housing_slots: Array[String] = []
	var gv: Node = _GameValuesRef.get_singleton()
	for room in rooms:
		var rm: ArchivesRoomInfo = room as ArchivesRoomInfo
		if rm.zone_type != ZoneTypeScript.Type.LIVING:
			continue
		var rid_str: String = rm.id if rm.id else rm.json_room_id
		if rid_str.is_empty():
			continue
		var room_units: int = rm.get_room_units()
		var housing_count: int = gv.get_housing_for_room_units(room_units) if gv else (room_units * 2)
		for _j in housing_count:
			housing_slots.append(rid_str)

	r["work_room_id"] = work_slots[researcher_id] if researcher_id < work_slots.size() else ""
	r["housing_room_id"] = housing_slots[researcher_id] if researcher_id < housing_slots.size() else ""
	return r


const MAX_HOURS_PER_FRAME := 24  ## 单帧最多处理小时数，避免 delta 尖峰导致计算因子瞬间耗尽

func _tick(game_main: Node2D, game_hours_delta: float, shelter_level: int) -> void:
	var rooms: Array = game_main.get_game_rooms()
	if rooms.is_empty():
		return
	var ui: Node = game_main.get_node_or_null("InteractiveUiRoot/UIMain")
	if not ui:
		return
	var gv: Node = _GameValuesRef.get_singleton()
	if not gv:
		return

	var no_shelter_types: Array = gv.get_shelter_room_types_no_shelter()
	var need_shelter: Array[Dictionary] = _collect_need_shelter(rooms, ui, game_main, no_shelter_types)
	## 无需庇护房间时，不累积、不处理，累计器清零
	if need_shelter.is_empty():
		game_main.set("_shelter_accumulator", 0.0)
		_clear_shelter_allocation_and_topbar(game_main)
		return

	var cf_cap: Dictionary = gv.get_shelter_cf_and_cap_for_level(shelter_level)
	var energy_cap: int = cf_cap.get("energy_cap", 30)
	if cf_cap.has("cf_per_day"):
		var cf_per_day: int = int(cf_cap.get("cf_per_day", 0))
		if cf_per_day > 0:
			energy_cap = mini(energy_cap, int(cf_per_day / 24.0))  # 日上限转每小时上限（72 -> 3）
	var energy_per_room_max: int = gv.get_shelter_energy_per_room_max() if gv.has_method("get_shelter_energy_per_room_max") else 5
	if _last_energy_per_room_max >= 0 and _last_energy_per_room_max != energy_per_room_max:
		## 规则：每房上限变化时，清空全部手动目标，避免旧配置越界污染
		_manual_room_shelter_target.clear()
	_last_energy_per_room_max = energy_per_room_max
	var global_erosion: int = _get_global_erosion_for_shelter()
	var target_per_room: int = mini(maxi(0, 2 - global_erosion), energy_per_room_max)
	_prune_manual_targets(need_shelter)

	var v_acc: Variant = game_main.get("_shelter_accumulator")
	var accumulator: float = float(v_acc) if v_acc != null else 0.0
	accumulator += game_hours_delta
	var hours_to_process: int = mini(int(accumulator), MAX_HOURS_PER_FRAME)
	game_main.set("_shelter_accumulator", accumulator - float(hours_to_process))

	if hours_to_process <= 0:
		var demand_preview: int = _compute_total_demand(need_shelter, target_per_room, energy_per_room_max)
		_sync_topbar_shelter_totals(game_main, demand_preview)
		return

	for _h in hours_to_process:
		_compute_and_apply(game_main, ui, rooms, energy_cap, target_per_room, energy_per_room_max, no_shelter_types)


func _collect_need_shelter(rooms: Array, ui: Node, game_main: Node2D, no_shelter_types: Array) -> Array[Dictionary]:
	var need_shelter: Array[Dictionary] = []
	for room in rooms:
		if not (room is ArchivesRoomInfo):
			continue
		var r: ArchivesRoomInfo = room as ArchivesRoomInfo
		var rid: String = r.id if r.id else r.json_room_id
		if rid.is_empty():
			continue
		if r.room_type in no_shelter_types:
			continue
		if r.zone_type == 0:
			continue
		if not _room_in_use(r, ui, game_main):
			continue
		need_shelter.append({"room": r, "rid": rid})
	return need_shelter


func _clear_shelter_allocation_and_topbar(game_main: Node2D) -> void:
	_room_shelter_energy.clear()
	_manual_room_shelter_target.clear()
	_last_cf_consumed = 0
	game_main.set("_shelter_energy", 0)
	game_main.set("_shelter_demand", 0)
	if DataProviders:
		DataProviders.on_shelter_topbar_sync(game_main)


func _sync_topbar_shelter_totals(game_main: Node2D, demand: int) -> void:
	var allocated_sum: int = 0
	for v in _room_shelter_energy.values():
		allocated_sum += int(v)
	game_main.set("_shelter_energy", allocated_sum)
	game_main.set("_shelter_demand", demand)
	if DataProviders:
		DataProviders.on_shelter_topbar_sync(game_main)


func _compute_and_apply(game_main: Node2D, ui: Node, rooms: Array, energy_cap: int, target_per_room: int, energy_per_room_max: int, no_shelter_types: Array) -> void:
	var need_shelter: Array[Dictionary] = _collect_need_shelter(rooms, ui, game_main, no_shelter_types)
	_prune_manual_targets(need_shelter)
	if need_shelter.is_empty():
		_clear_shelter_allocation_and_topbar(game_main)
		return

	var demand: int = _compute_total_demand(need_shelter, target_per_room, energy_per_room_max)
	var cf_needed: int = mini(demand, energy_cap)
	var player_cf: int = ui.get_computation() if ui.has_method("get_computation") else floori(ui.get("computation_amount") or 0)
	var cf_to_deduct: int = mini(cf_needed, player_cf)
	var actual_output: int = cf_to_deduct

	var cf_after: int = maxi(0, player_cf - cf_to_deduct)
	ui.set("computation_amount", cf_after)
	game_main.call("_sync_resources_to_topbar")

	## 分配能量（不足时按优先级）
	_room_shelter_energy.clear()
	var manual_effective: Dictionary = _build_effective_manual_targets(need_shelter, actual_output, energy_per_room_max)
	var to_allocate: int = actual_output
	_sort_rooms_by_priority(need_shelter)
	for entry in need_shelter:
		var rid: String = str(entry.get("rid", ""))
		if rid.is_empty() or not manual_effective.has(rid):
			continue
		var give_manual: int = maxi(0, int(manual_effective.get(rid, 0)))
		if give_manual <= 0:
			continue
		_room_shelter_energy[rid] = give_manual
		to_allocate -= give_manual
	for entry in need_shelter:
		if to_allocate <= 0:
			break
		var rid: String = str(entry.get("rid", ""))
		if manual_effective.has(rid):
			continue
		var give: int = mini(target_per_room, to_allocate)
		if give <= 0:
			continue
		_room_shelter_energy[rid] = give
		to_allocate -= give

	_last_cf_consumed = cf_to_deduct
	_sync_topbar_shelter_totals(game_main, demand)


static func _room_in_use(room: ArchivesRoomInfo, ui: Node, _game_main: Node2D) -> bool:
	if room.zone_type == ZoneTypeScript.Type.RESEARCH:
		return _research_has_reserve(room)
	if room.zone_type == ZoneTypeScript.Type.CREATION:
		return not GameMainBuiltRoomHelper.is_creation_zone_paused(room, ui)
	if room.zone_type == ZoneTypeScript.Type.LIVING or room.zone_type == ZoneTypeScript.Type.OFFICE:
		return true
	return false


static func _research_has_reserve(room: ArchivesRoomInfo) -> bool:
	var gv: Node = _GameValuesRef.get_singleton()
	if not gv:
		return false
	var rt: String = gv.get_research_output_resource(room.room_type)
	var res_type: int = ResourceLedger.resource_key_string_to_type(rt)
	if res_type == ArchivesRoomInfo.ResourceType.NONE:
		return false
	for r in room.resources:
		if r is Dictionary and int(r.get("resource_type", -1)) == res_type:
			return int(r.get("resource_amount", 0)) > 0
	return false


static func _sort_rooms_by_priority(entries: Array[Dictionary]) -> void:
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var za: int = int((a.room as ArchivesRoomInfo).zone_type)
		var zb: int = int((b.room as ArchivesRoomInfo).zone_type)
		var pa: int = _zone_priority(za)
		var pb: int = _zone_priority(zb)
		if pa != pb:
			return pa < pb
		var ra: String = a.rid
		var rb: String = b.rid
		return ra < rb
	)


static func _zone_priority(zone_type: int) -> int:
	match zone_type:
		ZoneTypeScript.Type.LIVING: return 0
		ZoneTypeScript.Type.RESEARCH: return 1
		ZoneTypeScript.Type.CREATION: return 2
		ZoneTypeScript.Type.OFFICE: return 3
		_: return 99


## 与 TopBar / 侵蚀 UI 一致的全局侵蚀基线（含 shelter_bonus「文明的庇佑」）
static func _get_global_erosion_for_shelter() -> int:
	if not ErosionCore:
		return 0
	return int(ErosionCore.current_erosion)


## 供 UI 使用：与 `get_room_shelter_level` 中「未加本房分配」项相同（`current_erosion`）
static func get_shelter_baseline_erosion() -> int:
	return _get_global_erosion_for_shelter()


static func _get_or_create_helper(game_main: Node2D) -> GameMainShelterHelper:
	var helper: Variant = game_main.get("_shelter_helper")
	if helper and helper is GameMainShelterHelper:
		return helper as GameMainShelterHelper
	var created: GameMainShelterHelper = GameMainShelterHelper.new()
	game_main.set("_shelter_helper", created)
	return created


func _build_manual_context(game_main: Node2D) -> Dictionary:
	var rooms: Array = game_main.get_game_rooms()
	var ui: Node = game_main.get_node_or_null("InteractiveUiRoot/UIMain")
	var gv: Node = _GameValuesRef.get_singleton()
	if rooms.is_empty() or ui == null or gv == null:
		return {"valid": false}
	var no_shelter_types: Array = gv.get_shelter_room_types_no_shelter()
	var need_shelter: Array[Dictionary] = _collect_need_shelter(rooms, ui, game_main, no_shelter_types)
	_prune_manual_targets(need_shelter)
	var need_ids: Dictionary = {}
	for e in need_shelter:
		var rid: String = str(e.get("rid", ""))
		if not rid.is_empty():
			need_ids[rid] = true
	var cf_cap: Dictionary = gv.get_shelter_cf_and_cap_for_level(int(game_main.get("_shelter_level")))
	var energy_cap: int = int(cf_cap.get("energy_cap", 30))
	if cf_cap.has("cf_per_day"):
		var cf_per_day: int = int(cf_cap.get("cf_per_day", 0))
		if cf_per_day > 0:
			energy_cap = mini(energy_cap, int(cf_per_day / 24.0))
	var player_cf: int = ui.get_computation() if ui.has_method("get_computation") else floori(ui.get("computation_amount") or 0)
	var energy_per_room_max: int = gv.get_shelter_energy_per_room_max() if gv.has_method("get_shelter_energy_per_room_max") else 5
	return {
		"valid": true,
		"need_room_ids": need_ids,
		"per_room_max": maxi(0, energy_per_room_max),
		"total_available": maxi(0, mini(energy_cap, player_cf)),
	}


func _compute_manual_max_assignable(room_id: String, ctx: Dictionary) -> int:
	var per_room_max: int = int(ctx.get("per_room_max", 0))
	var total_available: int = int(ctx.get("total_available", 0))
	var need_ids: Dictionary = ctx.get("need_room_ids", {})
	var other_manual_sum: int = 0
	for k in _manual_room_shelter_target.keys():
		var rid: String = str(k)
		if rid == room_id:
			continue
		if not need_ids.has(rid):
			continue
		other_manual_sum += clampi(int(_manual_room_shelter_target.get(rid, 0)), 0, per_room_max)
	return clampi(total_available - other_manual_sum, 0, per_room_max)


func _prune_manual_targets(need_shelter: Array[Dictionary]) -> void:
	var need_ids: Dictionary = {}
	for entry in need_shelter:
		var rid: String = str(entry.get("rid", ""))
		if not rid.is_empty():
			need_ids[rid] = true
	var keys: Array = _manual_room_shelter_target.keys()
	for k in keys:
		var rid: String = str(k)
		if not need_ids.has(rid):
			_manual_room_shelter_target.erase(rid)


func _compute_total_demand(need_shelter: Array[Dictionary], target_per_room: int, per_room_max: int) -> int:
	var demand: int = 0
	for entry in need_shelter:
		var rid: String = str(entry.get("rid", ""))
		if _manual_room_shelter_target.has(rid):
			demand += clampi(int(_manual_room_shelter_target.get(rid, 0)), 0, per_room_max)
		else:
			demand += clampi(target_per_room, 0, per_room_max)
	return demand


func _build_effective_manual_targets(need_shelter: Array[Dictionary], total_available: int, per_room_max: int) -> Dictionary:
	var requested: Dictionary = {}
	var request_sum: int = 0
	for entry in need_shelter:
		var rid: String = str(entry.get("rid", ""))
		if rid.is_empty() or not _manual_room_shelter_target.has(rid):
			continue
		var t: int = clampi(int(_manual_room_shelter_target.get(rid, 0)), 0, per_room_max)
		requested[rid] = t
		request_sum += t
	if request_sum <= total_available:
		return requested
	if request_sum <= 0 or total_available <= 0:
		var all_zero: Dictionary = {}
		for rid in requested.keys():
			all_zero[rid] = 0
		return all_zero
	var scale: float = float(total_available) / float(request_sum)
	var scaled: Dictionary = {}
	for rid in requested.keys():
		var scaled_val: int = int(floor(float(int(requested.get(rid, 0))) * scale))
		scaled[rid] = maxi(0, scaled_val)
	return scaled


## 获取庇护消耗细则，用于 TopBar 因子悬停面板
## 返回 [{zone_name, room_name, per_day}]；按需显示各需要庇护的房间及实际分配消耗
## 优先使用上次 tick 的实际分配（_room_shelter_energy），否则按相同逻辑模拟
static func get_shelter_consumption_breakdown(game_main: Node2D, shelter_level: int) -> Array:
	var rooms: Array = game_main.get_game_rooms()
	var ui: Node = game_main.get_node_or_null("InteractiveUiRoot/UIMain")
	var gv: Node = _GameValuesRef.get_singleton()
	if not gv or not ui:
		return []

	## 若上次 tick 已有实际分配结果，直接使用（确保细则与真实消耗一致）
	var helper: Variant = game_main.get("_shelter_helper")
	if helper is GameMainShelterHelper:
		var h: GameMainShelterHelper = helper as GameMainShelterHelper
		if not h._room_shelter_energy.is_empty():
			var from_helper: Array = []
			var rid_to_room: Dictionary = {}
			for room in rooms:
				if not (room is ArchivesRoomInfo):
					continue
				var r: ArchivesRoomInfo = room as ArchivesRoomInfo
				var rid: String = r.id if r.id else r.json_room_id
				if rid.is_empty():
					continue
				rid_to_room[rid] = r
			for rid in h._room_shelter_energy:
				var energy: int = int(h._room_shelter_energy.get(rid, 0))
				if energy <= 0:
					continue
				var r: Variant = rid_to_room.get(rid)
				if not (r is ArchivesRoomInfo):
					continue
				var room: ArchivesRoomInfo = r as ArchivesRoomInfo
				from_helper.append({
					"zone_name": ZoneTypeScript.get_zone_name(room.zone_type),
					"room_name": room.get_display_name(),
					"per_day": energy * 24
				})
			if not from_helper.is_empty():
				return from_helper

	## 否则按与 _compute_and_apply 相同逻辑模拟
	var cf_cap: Dictionary = gv.get_shelter_cf_and_cap_for_level(shelter_level)
	var energy_cap: int = cf_cap.get("energy_cap", 30)
	if cf_cap.has("cf_per_day"):
		var cf_per_day: int = int(cf_cap.get("cf_per_day", 0))
		if cf_per_day > 0:
			energy_cap = mini(energy_cap, int(cf_per_day / 24.0))  # 日上限转每小时上限（72 -> 3）
	var energy_per_room_max: int = gv.get_shelter_energy_per_room_max() if gv.has_method("get_shelter_energy_per_room_max") else 5
	var no_shelter_types: Array = gv.get_shelter_room_types_no_shelter()
	var global_erosion: int = _get_global_erosion_for_shelter()
	var target_per_room: int = mini(maxi(0, 2 - global_erosion), energy_per_room_max)

	var need_shelter: Array[Dictionary] = []
	for room in rooms:
		if not (room is ArchivesRoomInfo):
			continue
		var r: ArchivesRoomInfo = room as ArchivesRoomInfo
		var rid: String = r.id if r.id else r.json_room_id
		if rid.is_empty():
			continue
		if r.room_type in no_shelter_types:
			continue
		if r.zone_type == 0:
			continue
		if not _room_in_use(r, ui, game_main):
			continue
		need_shelter.append({"room": r, "rid": rid})

	if need_shelter.is_empty():
		return []

	var demand: int = need_shelter.size() * target_per_room
	var actual_per_hour: int = mini(demand, energy_cap)
	var player_cf: int = ui.get_computation() if ui.has_method("get_computation") else floori(ui.get("computation_amount") or 0)
	actual_per_hour = mini(actual_per_hour, player_cf)
	if actual_per_hour <= 0:
		return []

	_sort_rooms_by_priority(need_shelter)
	var to_allocate: int = actual_per_hour
	var result: Array = []
	for entry in need_shelter:
		if to_allocate <= 0:
			break
		var give: int = mini(target_per_room, to_allocate)
		to_allocate -= give
		var r: ArchivesRoomInfo = entry.room as ArchivesRoomInfo
		result.append({
			"zone_name": ZoneTypeScript.get_zone_name(r.zone_type),
			"room_name": r.get_display_name(),
			"per_day": give * 24
		})
	return result

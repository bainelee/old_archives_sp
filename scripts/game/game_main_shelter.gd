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


## 执行庇护 tick，计算分配并扣除计算因子
## shelter_level: 核心能耗等级 1～5
static func process_shelter_tick(game_main: Node2D, game_hours_delta: float, shelter_level: int) -> void:
	var helper: GameMainShelterHelper = game_main.get("_shelter_helper")
	if not helper:
		helper = GameMainShelterHelper.new()
		game_main.set("_shelter_helper", helper)
	helper._tick(game_main, game_hours_delta, shelter_level)


## 获取房间庇护等级（raw_erosion + 分配的庇护能量）
static func get_room_shelter_level(game_main: Node2D, room_id: String) -> int:
	var helper: GameMainShelterHelper = game_main.get("_shelter_helper")
	if not helper:
		return _get_raw_erosion()
	var energy: int = int(helper._room_shelter_energy.get(room_id, 0))
	return _get_raw_erosion() + energy


## 根据研究员工作/住房返回有效庇护等级（用于侵蚀判定）
## researcher: { work_room_id, housing_room_id, is_eroded }
static func get_shelter_level_for_researcher(game_main: Node2D, researcher: Dictionary) -> int:
	var work_rid: String = str(researcher.get("work_room_id", ""))
	var housing_rid: String = str(researcher.get("housing_room_id", ""))
	var is_eroded: bool = bool(researcher.get("is_eroded", false))

	if work_rid.is_empty() and housing_rid.is_empty():
		return _get_raw_erosion()
	if work_rid.is_empty():
		return get_room_shelter_level(game_main, housing_rid)
	if is_eroded:
		return get_room_shelter_level(game_main, housing_rid) if not housing_rid.is_empty() else _get_raw_erosion()
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
	var rooms: Array = game_main.get("_rooms")
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
	var rooms: Array = game_main.get("_rooms")
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
	var rooms: Array = game_main.get("_rooms")
	if rooms.is_empty():
		return
	var ui: Node = game_main.get_node_or_null("UIMain")
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
		_last_cf_consumed = 0
		return

	var cf_cap: Dictionary = gv.get_shelter_cf_and_cap_for_level(shelter_level)
	var energy_cap: int = cf_cap.get("energy_cap", 30)
	if cf_cap.has("cf_per_day"):
		var cf_per_day: int = int(cf_cap.get("cf_per_day", 0))
		if cf_per_day > 0:
			energy_cap = mini(energy_cap, int(cf_per_day / 24.0))  # 日上限转每小时上限（72 -> 3）
	var energy_per_room_max: int = gv.get_shelter_energy_per_room_max() if gv.has_method("get_shelter_energy_per_room_max") else 5
	var raw_erosion: int = _get_raw_erosion()
	var target_per_room: int = mini(maxi(0, 2 - raw_erosion), energy_per_room_max)

	var v_acc: Variant = game_main.get("_shelter_accumulator")
	var accumulator: float = float(v_acc) if v_acc != null else 0.0
	accumulator += game_hours_delta
	var hours_to_process: int = mini(int(accumulator), MAX_HOURS_PER_FRAME)
	game_main.set("_shelter_accumulator", accumulator - float(hours_to_process))

	if hours_to_process <= 0:
		return

	for _h in hours_to_process:
		_compute_and_apply(game_main, ui, rooms, energy_cap, target_per_room, no_shelter_types)


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


func _compute_and_apply(game_main: Node2D, ui: Node, rooms: Array, energy_cap: int, target_per_room: int, no_shelter_types: Array) -> void:
	var need_shelter: Array[Dictionary] = _collect_need_shelter(rooms, ui, game_main, no_shelter_types)
	if need_shelter.is_empty():
		_last_cf_consumed = 0
		return

	var demand: int = need_shelter.size() * target_per_room
	var cf_needed: int = mini(demand, energy_cap)
	var player_cf: int = ui.get_computation() if ui.has_method("get_computation") else floori(ui.get("computation_amount") or 0)
	var cf_to_deduct: int = mini(cf_needed, player_cf)
	var actual_output: int = cf_to_deduct

	var cf_after: int = maxi(0, player_cf - cf_to_deduct)
	ui.set("computation_amount", cf_after)
	game_main.call("_sync_resources_to_topbar")

	## 分配能量（不足时按优先级）
	_room_shelter_energy.clear()
	var to_allocate: int = actual_output
	_sort_rooms_by_priority(need_shelter)
	for entry in need_shelter:
		if to_allocate <= 0:
			break
		var give: int = mini(target_per_room, to_allocate)
		_room_shelter_energy[entry.rid] = give
		to_allocate -= give

	_last_cf_consumed = cf_to_deduct


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
	var res_type: int = ArchivesRoomInfo.ResourceType.NONE
	match rt:
		"cognition": res_type = ArchivesRoomInfo.ResourceType.COGNITION
		"computation": res_type = ArchivesRoomInfo.ResourceType.COMPUTATION
		"willpower": res_type = ArchivesRoomInfo.ResourceType.WILL
		"permission": res_type = ArchivesRoomInfo.ResourceType.PERMISSION
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


static func _get_raw_erosion() -> int:
	if not ErosionCore:
		return 0
	return int(ErosionCore.raw_mystery_erosion)


## 获取庇护消耗细则，用于 TopBar 因子悬停面板
## 返回 [{zone_name, room_name, per_day}]；按需显示各需要庇护的房间及实际分配消耗
## 优先使用上次 tick 的实际分配（_room_shelter_energy），否则按相同逻辑模拟
static func get_shelter_consumption_breakdown(game_main: Node2D, shelter_level: int) -> Array:
	var rooms: Array = game_main.get("_rooms")
	var ui: Node = game_main.get_node_or_null("UIMain")
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
	var raw_erosion: int = _get_raw_erosion()
	var target_per_room: int = mini(maxi(0, 2 - raw_erosion), energy_per_room_max)

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

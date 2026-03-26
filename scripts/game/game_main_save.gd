class_name GameMainSaveHelper
extends RefCounted

## 游戏主场景存档收集与加载应用
## 纯 I/O 逻辑，与 UI 解耦

const _GameValuesRef = preload("res://scripts/core/game_values_ref.gd")

const SAVE_KEY_TILES := "tiles"
const SAVE_KEY_ROOMS := "rooms"
const SAVE_KEY_FORCED_SHUTDOWN_ROOMS := "forced_shutdown_room_ids"
const KEY_MAP := "map"
const KEY_TIME := "time"
const KEY_RESOURCES := "resources"
const KEY_VERSION := "version"
const KEY_MAP_NAME := "map_name"
const KEY_SAVED_AT_GAME_HOUR := "saved_at_game_hour"
const KEY_EROSION := "erosion"
const KEY_PERSONNEL_EROSION := "personnel_erosion"


static func _get_shelter_level_from_game_main(game_main: Node2D) -> int:
	var v: Variant = game_main.get("_shelter_level")
	return int(v) if v != null else 1


static func _collect_erosion_for_save(game_main: Node2D) -> Dictionary:
	var erosion: Dictionary = {"shelter_level": _get_shelter_level_from_game_main(game_main)}
	if ErosionCore and ErosionCore.has_method("get_forecast_handles_for_save"):
		erosion["forecast_handles"] = ErosionCore.get_forecast_handles_for_save()
	erosion["manual_room_shelter_targets"] = GameMainShelterHelper.get_manual_room_shelter_targets_for_save(game_main)
	return erosion


static func collect_game_state(game_main: Node2D) -> Dictionary:
	## 收集当前游戏状态（供暂停菜单保存调用）
	var grid_width: int = game_main.get("GRID_WIDTH")
	var grid_height: int = game_main.get("GRID_HEIGHT")
	var cell_size: int = game_main.get("CELL_SIZE")
	var rooms: Array = game_main.get("_rooms")
	var construction_rooms: Dictionary = game_main.get("_construction_rooms_in_progress")
	var cleanup_rooms: Dictionary = game_main.get("_cleanup_rooms_in_progress")

	var map_name: String = "存档"
	## 不再保存 tiles（2D 网格），archives 模式仅使用 rooms
	var tiles_data: Array = []
	var rooms_data: Array = []
	for i in rooms.size():
		var room: ArchivesRoomInfo = rooms[i]
		var rd: Dictionary = room.to_dict()
		if construction_rooms.has(i):
			var data: Dictionary = construction_rooms[i]
			rd["zone_building_elapsed"] = data.get("elapsed", 0.0)
			rd["zone_building_total"] = data.get("total", 1.0)
			rd["zone_building_zone_type"] = data.get("zone_type", 0)
			var ids: Array = data.get("researcher_ids", [])
			if not ids.is_empty():
				rd["zone_building_researcher_ids"] = ids
		if cleanup_rooms.has(i):
			var data: Dictionary = cleanup_rooms[i]
			rd["cleanup_elapsed"] = data.get("elapsed", 0.0)
			rd["cleanup_total"] = data.get("total", 1.0)
			var ids: Array = data.get("researcher_ids", [])
			if not ids.is_empty():
				rd["cleanup_researcher_ids"] = ids
		rooms_data.append(rd)
	var next_room_id: int = 1
	for room in rooms:
		var rid: String = room.json_room_id if room.json_room_id else room.id
		if rid.begins_with("ROOM_"):
			var num: int = int(rid.substr(5))
			next_room_id = max(next_room_id, num + 1)
	var map_data: Dictionary = {
		"grid_width": grid_width,
		"grid_height": grid_height,
		"cell_size": cell_size,
		"tiles": tiles_data,
		"rooms": rooms_data,
		"next_room_id": next_room_id,
		"map_name": map_name,
	}
	var forced_shutdown: Dictionary = game_main.get("_forced_shutdown_room_ids")
	if forced_shutdown is Dictionary and not forced_shutdown.is_empty():
		var room_ids: Array = []
		for room_id in forced_shutdown.keys():
			if bool(forced_shutdown.get(room_id, false)):
				room_ids.append(str(room_id))
		if not room_ids.is_empty():
			map_data[SAVE_KEY_FORCED_SHUTDOWN_ROOMS] = room_ids
	var total_hours: int = int(GameTime.get_total_hours()) if GameTime else 0
	var resources: Dictionary = {"factors": {}, "currency": {}, "personnel": {}}
	var ui: Node = game_main.get_node_or_null("UIMain")
	if ui and ui.has_method("get_resources"):
		resources = ui.get_resources()
	if PersonnelErosionCore:
		resources["personnel"] = PersonnelErosionCore.get_personnel()
	var state: Dictionary = {
		KEY_VERSION: 1,
		KEY_MAP_NAME: map_name,
		KEY_SAVED_AT_GAME_HOUR: total_hours,
		KEY_MAP: map_data,
		KEY_TIME: {
			"total_game_hours": total_hours,
			"is_flowing": GameTime.is_flowing if GameTime else true,
			"speed_multiplier": GameTime.speed_multiplier if GameTime else 1.0,
		},
		KEY_RESOURCES: resources,
		KEY_EROSION: _collect_erosion_for_save(game_main),
	}
	if PersonnelErosionCore:
		state[KEY_PERSONNEL_EROSION] = PersonnelErosionCore.to_save_dict()
	## 研究员 3D 位置：id, room_id, position
	var researchers_3d: Array = []
	var researcher_count: int = int(resources.get("personnel", {}).get("researcher", 0))
	for i in researcher_count:
		var r3d: Node3D = game_main.get_researcher_3d_by_id(i) if game_main.has_method("get_researcher_3d_by_id") else null
		if r3d and r3d.has_method("get_current_room_id"):
			var rid: String = r3d.get_current_room_id()
			var pos: Vector3 = r3d.position
			researchers_3d.append({"id": i, "room_id": rid, "pos": [pos.x, pos.y, pos.z]})
	state["researchers_3d"] = researchers_3d
	return state


## 新游戏时调用：若房间有 grid 且无 adjacent_ids（未从存档恢复），则计算邻接并应用开篇
## 读档时跳过，避免覆盖已恢复的 unlocked
static func ensure_layout_and_prologue(game_main: Node2D) -> void:
	var rooms: Array = game_main.get("_rooms")
	if rooms.is_empty():
		return
	var has_any_adjacent: bool = false
	var has_any_grid: bool = false
	for room in rooms:
		if room.adjacent_ids.size() > 0:
			has_any_adjacent = true
		if room.grid_x != 0 or room.grid_y != 0 or room.size_3d != "":
			has_any_grid = true
	if has_any_adjacent:
		return
	if not has_any_grid:
		return
	RoomLayoutHelper.compute_adjacency(rooms, {})
	var id_to_index: Dictionary = RoomLayoutHelper.build_id_to_index(rooms)
	var base: Dictionary = _load_game_base()
	var prologue: Array = base.get("prologue_room_ids", []) as Array
	RoomLayoutHelper.apply_prologue(rooms, prologue, id_to_index)


static func _load_game_base() -> Dictionary:
	var path: String = "res://datas/game_base.json"
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


static func apply_map(game_main: Node2D, d: Dictionary) -> void:
	var grid_width: int = game_main.get("GRID_WIDTH")
	var grid_height: int = game_main.get("GRID_HEIGHT")
	var map_data: Variant = d.get(KEY_MAP, null)
	if map_data == null:
		return
	if not (map_data is Dictionary):
		return
	var m: Dictionary = map_data as Dictionary
	## 不再加载 tiles（2D 网格已废弃），保持 _tiles 为 EMPTY
	var tiles_data: Array = m.get(SAVE_KEY_TILES, []) as Array
	var tiles: Array = game_main.get("_tiles")
	for x in grid_width:
		for y in grid_height:
			tiles[x][y] = FloorTileType.Type.EMPTY
	if not tiles_data.is_empty():
		for x in min(tiles_data.size(), grid_width):
			var col: Variant = tiles_data[x]
			if col is Array:
				for y in min(col.size(), grid_height):
					tiles[x][y] = int(col[y])

	var rooms: Array = game_main.get("_rooms")
	var construction_rooms: Dictionary = game_main.get("_construction_rooms_in_progress")
	var cleanup_rooms: Dictionary = game_main.get("_cleanup_rooms_in_progress")
	var forced_shutdown: Dictionary = game_main.get("_forced_shutdown_room_ids")
	rooms.clear()
	construction_rooms.clear()
	cleanup_rooms.clear()
	forced_shutdown.clear()
	var rooms_data: Array = m.get(SAVE_KEY_ROOMS, []) as Array
	for i in rooms_data.size():
		var room_dict: Variant = rooms_data[i]
		if room_dict is Dictionary:
			var rd: Dictionary = room_dict as Dictionary
			rooms.append(ArchivesRoomInfo.from_dict(rd))
			var elapsed: Variant = rd.get("zone_building_elapsed", null)
			var total_val: Variant = rd.get("zone_building_total", null)
			if elapsed != null and total_val != null:
				var el: float = float(elapsed)
				var tot: float = float(total_val)
				if el < tot and tot > 0:
					var cdata: Dictionary = {
						"elapsed": el,
						"total": tot,
						"zone_type": int(rd.get("zone_building_zone_type", 0))
					}
					var cids: Variant = rd.get("zone_building_researcher_ids", null)
					if cids is Array and not (cids as Array).is_empty():
						cdata["researcher_ids"] = (cids as Array).duplicate()
					construction_rooms[i] = cdata
			var celapsed: Variant = rd.get("cleanup_elapsed", null)
			var ctotal: Variant = rd.get("cleanup_total", null)
			if celapsed != null and ctotal != null:
				var cel: float = float(celapsed)
				var ctot: float = float(ctotal)
				if cel < ctot and ctot > 0:
					var cpdata: Dictionary = {"elapsed": cel, "total": ctot}
					var cpids: Variant = rd.get("cleanup_researcher_ids", null)
					if cpids is Array and not (cpids as Array).is_empty():
						cpdata["researcher_ids"] = (cpids as Array).duplicate()
					cleanup_rooms[i] = cpdata
	var shutdown_ids: Variant = m.get(SAVE_KEY_FORCED_SHUTDOWN_ROOMS, null)
	if shutdown_ids is Array:
		for rid in shutdown_ids:
			forced_shutdown[str(rid)] = true
	ensure_layout_and_prologue(game_main)
	game_main.call("_sync_researchers_working_in_rooms_to_ui")


static func apply_time(d: Dictionary) -> void:
	var time_data: Variant = d.get(KEY_TIME, null)
	if time_data == null or not (time_data is Dictionary):
		return
	var t: Dictionary = time_data as Dictionary
	if GameTime:
		GameTime.set_total_hours(float(t.get("total_game_hours", 0)))
		GameTime.is_flowing = bool(t.get("is_flowing", true))
		GameTime.speed_multiplier = float(t.get("speed_multiplier", 1.0))
		## 读档恢复暂停状态时同步 tree.paused
		if not GameTime.is_flowing and GameTime.is_inside_tree():
			GameTime.get_tree().paused = true


static func apply_resources(game_main: Node2D, d: Dictionary) -> void:
	var res_data: Variant = d.get(KEY_RESOURCES, null)
	if res_data == null or not (res_data is Dictionary):
		return
	var r: Dictionary = res_data as Dictionary
	var factors: Dictionary = r.get("factors", {}) as Dictionary
	var currency: Dictionary = r.get("currency", {}) as Dictionary
	var personnel: Dictionary = r.get("personnel", {}) as Dictionary
	var total_hours: float = 0.0
	var time_data: Variant = d.get(KEY_TIME, null)
	if time_data is Dictionary:
		total_hours = float((time_data as Dictionary).get("total_game_hours", 0))
	if PersonnelErosionCore:
		var per_data: Variant = d.get(KEY_PERSONNEL_EROSION, null)
		if per_data is Dictionary and (per_data as Dictionary).has("researchers"):
			PersonnelErosionCore.load_from_save_dict(per_data as Dictionary, personnel)
		else:
			PersonnelErosionCore.initialize_from_personnel(personnel, total_hours)
		PersonnelErosionCore.sync_last_tick()
		personnel = PersonnelErosionCore.get_personnel()
	var ui: Node = game_main.get_node_or_null("UIMain")
	if ui and ui.has_method("set_resources"):
		ui.set_resources(factors, currency, personnel)
	if PersonnelErosionCore and ui:
		game_main.call("_register_cognition_provider", ui)
		if not PersonnelErosionCore.personnel_updated.is_connected(Callable(game_main, "_on_personnel_updated")):
			PersonnelErosionCore.personnel_updated.connect(Callable(game_main, "_on_personnel_updated"))

	## 庇护核心等级 + ForecastWarning handle 池
	var erosion_data: Variant = d.get(KEY_EROSION, null)
	var shelter_level: int = 1
	if erosion_data is Dictionary:
		var ed: Dictionary = erosion_data as Dictionary
		shelter_level = int(ed.get("shelter_level", 1))
		## 恢复 ForecastWarning handle 池到 ErosionCore
		if ErosionCore and ErosionCore.has_method("load_forecast_handles"):
			var handles: Variant = ed.get("forecast_handles", null)
			if handles is Array:
				ErosionCore.load_forecast_handles(handles as Array, total_hours)
			else:
				ErosionCore.load_forecast_handles([], total_hours)
		var manual_targets: Variant = ed.get("manual_room_shelter_targets", null)
		if manual_targets is Dictionary:
			GameMainShelterHelper.load_manual_room_shelter_targets(game_main, manual_targets as Dictionary)
		else:
			GameMainShelterHelper.load_manual_room_shelter_targets(game_main, {})
	else:
		GameMainShelterHelper.load_manual_room_shelter_targets(game_main, {})
	var gv: Node = _GameValuesRef.get_singleton()
	if gv and gv.has_method("get_shelter_level_min"):
		shelter_level = clampi(shelter_level, gv.get_shelter_level_min(), gv.get_shelter_level_max())
	game_main.set("_shelter_level", shelter_level)

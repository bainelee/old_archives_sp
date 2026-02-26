class_name GameMainSaveHelper
extends RefCounted

## 游戏主场景存档收集与加载应用
## 纯 I/O 逻辑，与 UI 解耦

const SAVE_KEY_TILES := "tiles"
const SAVE_KEY_ROOMS := "rooms"
const KEY_MAP := "map"
const KEY_TIME := "time"
const KEY_RESOURCES := "resources"
const KEY_VERSION := "version"
const KEY_MAP_NAME := "map_name"
const KEY_SAVED_AT_GAME_HOUR := "saved_at_game_hour"
const KEY_EROSION := "erosion"
const KEY_PERSONNEL_EROSION := "personnel_erosion"


static func collect_game_state(game_main: Node2D) -> Dictionary:
	## 收集当前游戏状态（供暂停菜单保存调用）
	var grid_width: int = game_main.get("GRID_WIDTH")
	var grid_height: int = game_main.get("GRID_HEIGHT")
	var cell_size: int = game_main.get("CELL_SIZE")
	var tiles: Array = game_main.get("_tiles")
	var rooms: Array = game_main.get("_rooms")
	var construction_rooms: Dictionary = game_main.get("_construction_rooms_in_progress")

	var map_name: String = "存档"
	var tiles_data: Array = []
	for x in grid_width:
		var col: Array = []
		for y in grid_height:
			col.append(tiles[x][y])
		tiles_data.append(col)
	var rooms_data: Array = []
	for i in rooms.size():
		var room: RoomInfo = rooms[i]
		var rd: Dictionary = room.to_dict()
		if construction_rooms.has(i):
			var data: Dictionary = construction_rooms[i]
			rd["zone_building_elapsed"] = data.get("elapsed", 0.0)
			rd["zone_building_total"] = data.get("total", 1.0)
			rd["zone_building_zone_type"] = data.get("zone_type", 0)
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
		KEY_EROSION: {},
	}
	if PersonnelErosionCore:
		state[KEY_PERSONNEL_EROSION] = PersonnelErosionCore.to_save_dict()
	return state


static func apply_map(game_main: Node2D, d: Dictionary) -> void:
	var grid_width: int = game_main.get("GRID_WIDTH")
	var grid_height: int = game_main.get("GRID_HEIGHT")
	var map_data: Variant = d.get(KEY_MAP, null)
	if map_data == null:
		return
	if not (map_data is Dictionary):
		return
	var m: Dictionary = map_data as Dictionary
	var tiles_data: Array = m.get(SAVE_KEY_TILES, []) as Array
	var tiles: Array = game_main.get("_tiles")
	for x in grid_width:
		for y in grid_height:
			tiles[x][y] = FloorTileType.Type.EMPTY
	for x in min(tiles_data.size(), grid_width):
		var col: Variant = tiles_data[x]
		if col is Array:
			for y in min(col.size(), grid_height):
				tiles[x][y] = int(col[y])

	var rooms: Array = game_main.get("_rooms")
	var construction_rooms: Dictionary = game_main.get("_construction_rooms_in_progress")
	rooms.clear()
	construction_rooms.clear()
	var rooms_data: Array = m.get(SAVE_KEY_ROOMS, []) as Array
	for i in rooms_data.size():
		var room_dict: Variant = rooms_data[i]
		if room_dict is Dictionary:
			var rd: Dictionary = room_dict as Dictionary
			rooms.append(RoomInfo.from_dict(rd))
			var elapsed: Variant = rd.get("zone_building_elapsed", null)
			var total_val: Variant = rd.get("zone_building_total", null)
			if elapsed != null and total_val != null:
				var el: float = float(elapsed)
				var tot: float = float(total_val)
				if el < tot and tot > 0:
					construction_rooms[i] = {
						"elapsed": el,
						"total": tot,
						"zone_type": int(rd.get("zone_building_zone_type", 0))
					}
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

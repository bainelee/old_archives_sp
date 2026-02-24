class_name SceneEditorMapIO
extends RefCounted

## 场景编辑器地图保存/加载与 room_info.json 同步
## 纯 I/O 逻辑，与 UI 解耦

const SAVE_KEY_GRID := "grid_width"
const SAVE_KEY_GRID_H := "grid_height"
const SAVE_KEY_CELL := "cell_size"
const SAVE_KEY_TILES := "tiles"
const SAVE_KEY_ROOMS := "rooms"
const SAVE_KEY_MAP_NAME := "map_name"
const MAP_SLOTS := 5
const MAPS_DIR := "user://maps/"
const ROOM_INFO_JSON_PATH := "datas/room_info.json"


static func get_slot_path(slot: int) -> String:
	return MAPS_DIR + "slot_%d.json" % slot


## 一次性迁移：若存在旧的 scene_archive.json 且槽位 0 为空，则迁移到 slot_0.json
static func migrate_old_map_to_slot0() -> void:
	var old_path: String = "user://scene_archive.json"
	var slot0_path: String = get_slot_path(0)
	if not FileAccess.file_exists(old_path):
		return
	if FileAccess.file_exists(slot0_path):
		return
	var file: FileAccess = FileAccess.open(old_path, FileAccess.READ)
	if not file:
		return
	var json_str: String = file.get_as_text()
	file.close()
	var data: Variant = JSON.parse_string(json_str)
	if not (data is Dictionary):
		return
	(data as Dictionary)[SAVE_KEY_MAP_NAME] = "原场景"
	ensure_maps_dir()
	var out: FileAccess = FileAccess.open(slot0_path, FileAccess.WRITE)
	if out:
		out.store_string(JSON.stringify(data))
		out.close()
		print("已从 scene_archive.json 迁移到槽位 1")


static func ensure_maps_dir() -> void:
	if not DirAccess.dir_exists_absolute(MAPS_DIR):
		DirAccess.make_dir_recursive_absolute(MAPS_DIR)


static func get_slot_map_name(slot: int) -> String:
	var path: String = get_slot_path(slot)
	if not FileAccess.file_exists(path):
		return ""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return ""
	var json: String = file.get_as_text()
	file.close()
	var result: Variant = JSON.parse_string(json)
	if result is Dictionary:
		return str((result as Dictionary).get(SAVE_KEY_MAP_NAME, ""))
	return ""


static func save_to_slot(slot: int, grid_width: int, grid_height: int, cell_size: int, tiles: Array, rooms: Array, map_name: String, next_room_id: int) -> bool:
	ensure_maps_dir()
	var data: Dictionary = {
		SAVE_KEY_GRID: grid_width,
		SAVE_KEY_GRID_H: grid_height,
		SAVE_KEY_CELL: cell_size,
		SAVE_KEY_TILES: [],
		SAVE_KEY_ROOMS: [],
		SAVE_KEY_MAP_NAME: map_name,
		"next_room_id": next_room_id
	}
	for x in grid_width:
		var col: Array = []
		for y in grid_height:
			col.append(tiles[x][y])
		data[SAVE_KEY_TILES].append(col)
	for room in rooms:
		data[SAVE_KEY_ROOMS].append(room.to_dict())
	var path: String = get_slot_path(slot)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("保存失败: ", path)
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	print("地图已保存: ", path, " (", map_name, ")")
	return true


static func load_from_slot(slot: int) -> Variant:
	var path: String = get_slot_path(slot)
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("无法打开: ", path)
		return null
	var json: String = file.get_as_text()
	file.close()
	return JSON.parse_string(json)


## 同步房间到 room_info.json；会修改 rooms 中元素的 json_room_id
static func sync_rooms_to_json(rooms: Array) -> bool:
	var project_path: String = ProjectSettings.globalize_path("res://")
	var json_path: String = project_path.path_join(ROOM_INFO_JSON_PATH)
	var json_data: Dictionary
	var json_rooms: Array
	if FileAccess.file_exists(json_path):
		var f: FileAccess = FileAccess.open(json_path, FileAccess.READ)
		if not f:
			push_error("无法读取 room_info.json")
			return false
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if parsed is Dictionary:
			json_data = parsed as Dictionary
			json_rooms = (json_data.get("rooms", []) as Array).duplicate()
		else:
			json_data = {"source": "场景编辑器同步", "rooms": []}
			json_rooms = []
	else:
		json_data = {"source": "场景编辑器同步", "rooms": []}
		json_rooms = []
	var max_num: int = 0
	for r in json_rooms:
		if r is Dictionary:
			var rid: String = str(r.get("id", ""))
			if rid.begins_with("ROOM_"):
				var num: int = int(rid.substr(5))
				if num > max_num:
					max_num = num
	var next_num: int = max_num + 1
	for room in rooms:
		if room.json_room_id.is_empty():
			room.json_room_id = "ROOM_%03d" % next_num
			next_num += 1
			json_rooms.append(room.to_json_room_dict(room.json_room_id))
		else:
			var found: int = -1
			for i in json_rooms.size():
				if json_rooms[i] is Dictionary and str((json_rooms[i] as Dictionary).get("id", "")) == room.json_room_id:
					found = i
					break
			var entry: Dictionary = room.to_json_room_dict(room.json_room_id)
			if found >= 0:
				json_rooms[found] = entry
			else:
				json_rooms.append(entry)
	json_data["rooms"] = json_rooms
	var out: FileAccess = FileAccess.open(json_path, FileAccess.WRITE)
	if not out:
		push_error("无法写入 room_info.json: ", json_path)
		return false
	out.store_string(JSON.stringify(json_data, "  ", false))
	out.close()
	print("房间信息已同步至 room_info.json")
	return true

extends Node
## 存档管理器（Autoload: SaveManager）
## 负责游戏存档槽位的保存、加载、元数据获取
## 注意：游戏存档（user://saves/）与地图编辑器（user://maps/）完全分离。
## 新游戏从 room_info.json 加载房间，不再使用地图编辑器 maps/slot_0。

const SAVES_DIR := "user://saves/"
const MAPS_DIR := "user://maps/"
const SLOT_COUNT := 5
## 存档格式主版本；与旧版不兼容时递增，旧档读取即删槽，不做迁移
const SAVE_VERSION_CURRENT := 2

const KEY_VERSION := "version"
const KEY_MAP_NAME := "map_name"
const KEY_SAVED_AT_GAME_HOUR := "saved_at_game_hour"
const KEY_MAP := "map"
const KEY_TIME := "time"
const KEY_RESOURCES := "resources"
const KEY_EROSION := "erosion"
const KEY_EXPLORATION := "exploration"
const GAME_BASE_PATH := "res://datas/game_base.json"
const GRID_WIDTH := 80
const GRID_HEIGHT := 60
const CELL_SIZE := 20

## 主菜单选择新游戏槽位后设置，GameMain 加载时读取并清零
var pending_load_slot: int = -1


func ensure_saves_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		DirAccess.make_dir_recursive_absolute(SAVES_DIR)


func get_slot_path(slot: int) -> String:
	return SAVES_DIR + "slot_%d.json" % slot


func delete_slot(slot: int) -> bool:
	## 删除指定槽位的游戏存档（仅 user://saves/）
	var path: String = get_slot_path(slot)
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(path) == OK


func clear_all_game_saves() -> void:
	## 清空所有游戏存档（仅 user://saves/，绝不动 user://maps/）
	ensure_saves_dir()
	for i in SLOT_COUNT:
		var path: String = get_slot_path(i)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var autosave_path: String = SAVES_DIR + "autosave.json"
	if FileAccess.file_exists(autosave_path):
		DirAccess.remove_absolute(autosave_path)


func get_slot_metadata(slot: int) -> Variant:
	## 返回 { map_name, saved_at_game_hour, version, has_save }，空槽位返回 null
	## 仅读取游戏存档（user://saves/），与地图编辑器无关
	var data: Variant = _read_save_json(slot)
	if data == null:
		return null
	if not (data is Dictionary):
		return null
	var d: Dictionary = data as Dictionary
	if not _is_supported_save_version(d):
		push_warning("SaveManager: 槽位 %d 存档版本过旧或无效，已清理。" % slot)
		delete_slot(slot)
		return null
	var map_name: String = _get_map_name_from_data(d)
	if map_name.is_empty() and not d.has(KEY_MAP):
		return null
	return {
		"map_name": map_name,
		"saved_at_game_hour": d.get(KEY_SAVED_AT_GAME_HOUR, 0),
		"version": d.get(KEY_VERSION, SAVE_VERSION_CURRENT),
		"has_save": true,
	}


func default_exploration_dict() -> Dictionary:
	## 与 ExplorationService.to_save_dict / ExplorationStateCodec 同形
	return {
		"save_version": 2,
		"first_open_done": false,
		"unlocked_region_ids": [],
		"explored_region_ids": [],
		"debug_investigator_pool": 5,
		"exploring_by_region": {},
	}


func exploration_from_state(game_state: Dictionary) -> Dictionary:
	var raw: Variant = game_state.get(KEY_EXPLORATION, null)
	if raw is Dictionary:
		return (raw as Dictionary).duplicate(true)
	return default_exploration_dict().duplicate(true)


func validate_save(data: Dictionary) -> bool:
	var ver: int = int(data.get(KEY_VERSION, 0))
	if ver != SAVE_VERSION_CURRENT:
		return false
	var map_raw: Variant = data.get(KEY_MAP, null)
	if not (map_raw is Dictionary):
		return false
	return true


func create_new_game_state(map_name: String = "") -> Dictionary:
	if map_name.is_empty():
		map_name = tr("DEFAULT_NEW_GAME")
	## 创建新游戏状态：从 room_info.json 加载带 grid 的房间 + game_base 默认值
	## 不再使用地图编辑器 maps/slot_0
	var map_data: Dictionary = _load_map_from_room_info()
	var base: Dictionary = _load_game_base()
	var resources: Dictionary
	if base.is_empty():
		resources = {
			"factors": {"cognition": 6000, "computation": 60000, "willpower": 4000, "permission": 4000},
			"currency": {"info": 500, "truth": 0},
			"personnel": {"researcher": 10, "labor": 0, "eroded": 0, "investigator": 0},
		}
	else:
		resources = base.get("initial_resources", {}).duplicate(true)
	var total_hours: int = int(base.get("initial_time", {}).get("total_game_hours", 0))
	var display_name: String = map_data.get("map_name", map_name) as String
	if display_name.is_empty():
		display_name = map_name
	return {
		KEY_VERSION: SAVE_VERSION_CURRENT,
		KEY_MAP_NAME: display_name,
		KEY_SAVED_AT_GAME_HOUR: total_hours,
		KEY_MAP: map_data,
		KEY_TIME: {
			"total_game_hours": total_hours,
			"is_flowing": true,
			"speed_multiplier": 1.0,
		},
		KEY_RESOURCES: resources,
		KEY_EROSION: {},
		KEY_EXPLORATION: default_exploration_dict().duplicate(true),
	}


func _load_map_from_room_info() -> Dictionary:
	## 从 room_info.json 加载带 grid 的房间，计算邻接并应用开篇
	var rooms: Array = RoomInfoLoader.load_rooms_from_room_info(true)
	if rooms.is_empty():
		return _make_blank_map()
	RoomLayoutHelper.compute_adjacency(rooms, {})
	var id_to_index: Dictionary = RoomLayoutHelper.build_id_to_index(rooms)
	var base: Dictionary = _load_game_base()
	var prologue: Array = base.get("prologue_room_ids", []) as Array
	RoomLayoutHelper.apply_prologue(rooms, prologue, id_to_index)
	var rooms_data: Array = []
	for room in rooms:
		rooms_data.append(room.to_dict())
	return {
		"grid_width": GRID_WIDTH,
		"grid_height": GRID_HEIGHT,
		"cell_size": CELL_SIZE,
		"tiles": [],
		"rooms": rooms_data,
		"next_room_id": 1,
		"map_name": tr("DEFAULT_NEW_GAME"),
	}


func _make_blank_map() -> Dictionary:
	return {
		"grid_width": GRID_WIDTH,
		"grid_height": GRID_HEIGHT,
		"cell_size": CELL_SIZE,
		"tiles": [],
		"rooms": [],
		"next_room_id": 1,
		"map_name": tr("DEFAULT_NEW_GAME"),
	}


func get_first_occupied_slot() -> int:
	## 返回第一个有存档的槽位索引，若无则返回 -1
	for i in SLOT_COUNT:
		if get_slot_metadata(i) != null:
			return i
	return -1


func save_to_slot(slot: int, game_state: Dictionary) -> bool:
	## 保存到槽位；P0 占位实现，写出 JSON 框架
	ensure_saves_dir()
	var path: String = get_slot_path(slot)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error(tr("ERROR_SAVE_FAILED") + " " + path)
		return false
	file.store_string(JSON.stringify(game_state))
	file.close()
	return true


func load_from_slot(slot: int) -> Variant:
	## 加载槽位存档，返回完整 GameState Dictionary，失败或空槽位返回 null
	## 仅读取游戏存档（user://saves/）；版本不符则删槽并返回 null（不做旧结构迁移）
	var raw: Variant = _read_save_json(slot)
	if raw == null:
		return null
	if not (raw is Dictionary):
		return null
	var d: Dictionary = (raw as Dictionary).duplicate(true)
	if not validate_save(d):
		push_warning("SaveManager: 槽位 %d 存档无效或版本非 %d，已清理。" % [slot, SAVE_VERSION_CURRENT])
		delete_slot(slot)
		return null
	_ensure_current_format_branches(d)
	return d


func _is_supported_save_version(d: Dictionary) -> bool:
	return int(d.get(KEY_VERSION, 0)) == SAVE_VERSION_CURRENT


func _ensure_current_format_branches(d: Dictionary) -> void:
	## 当前版本内补全可选分支（非旧版迁移）；缺 exploration 时补默认子树
	if not d.has(KEY_MAP_NAME) and d.has(KEY_MAP):
		var m: Variant = d[KEY_MAP]
		if m is Dictionary:
			d[KEY_MAP_NAME] = (m as Dictionary).get(KEY_MAP_NAME, tr("DEFAULT_UNTITLED"))
	var ex: Variant = d.get(KEY_EXPLORATION, null)
	if not (ex is Dictionary):
		d[KEY_EXPLORATION] = default_exploration_dict().duplicate(true)


func _load_game_base() -> Dictionary:
	var file: FileAccess = FileAccess.open(GAME_BASE_PATH, FileAccess.READ)
	if not file:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func _read_save_json(slot: int) -> Variant:
	## 仅读取游戏存档 user://saves/slot_N.json
	var path: String = get_slot_path(slot)
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var json_str: String = file.get_as_text()
	file.close()
	return JSON.parse_string(json_str)


func _get_map_name_from_data(d: Dictionary) -> String:
	# 新格式：根级或 map 下
	if d.has(KEY_MAP_NAME):
		return str(d.get(KEY_MAP_NAME, ""))
	var map_data: Variant = d.get(KEY_MAP, null)
	if map_data is Dictionary:
		return str((map_data as Dictionary).get(KEY_MAP_NAME, ""))
	return ""

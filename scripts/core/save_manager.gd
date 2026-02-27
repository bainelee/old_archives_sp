extends Node
## 存档管理器（Autoload: SaveManager）
## 负责游戏存档槽位的保存、加载、元数据获取
## 注意：游戏存档（user://saves/）与地图编辑器（user://maps/）完全分离。
## 地图编辑器保存的是项目级地图资源；新游戏以 maps/slot_0 为起始场景。

const SAVES_DIR := "user://saves/"
const MAPS_DIR := "user://maps/"
const START_MAP_SLOT := 0  ## 新游戏使用的起始地图槽位（地图编辑器编号第一张）
const SLOT_COUNT := 5
const SAVE_VERSION_CURRENT := 1

const KEY_VERSION := "version"
const KEY_MAP_NAME := "map_name"
const KEY_SAVED_AT_GAME_HOUR := "saved_at_game_hour"
const KEY_MAP := "map"
const KEY_TIME := "time"
const KEY_RESOURCES := "resources"
const KEY_EROSION := "erosion"
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
	var map_name: String = _get_map_name_from_data(d)
	if map_name.is_empty() and not d.has(KEY_MAP) and not d.has("tiles"):
		return null
	return {
		"map_name": map_name,
		"saved_at_game_hour": d.get(KEY_SAVED_AT_GAME_HOUR, 0),
		"version": d.get(KEY_VERSION, 0),
		"has_save": true,
	}


func validate_save(data: Dictionary) -> bool:
	var ver: int = int(data.get(KEY_VERSION, 0))
	if ver > SAVE_VERSION_CURRENT:
		return false
	var has_map := data.has(KEY_MAP)
	var has_legacy_map := data.has("tiles") or data.has("rooms")
	return has_map or has_legacy_map


func create_new_game_state(map_name: String = "") -> Dictionary:
	if map_name.is_empty():
		map_name = tr("DEFAULT_NEW_GAME")
	## 创建新游戏状态：从地图编辑器 slot_0 读取起始地图 + game_base 默认值
	## 地图编辑器保存的是项目级资源，新游戏以编号第一张地图为起始场景
	var map_data: Dictionary = _load_start_map()
	var base: Dictionary = _load_game_base()
	var resources: Dictionary
	if base.is_empty():
		resources = {
			"factors": {"cognition": 500, "computation": 0, "willpower": 400, "permission": 400},
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
	}


func _load_start_map() -> Dictionary:
	## 从地图编辑器 slot_0 读取起始地图；不存在则返回空白网格
	var path: String = MAPS_DIR + "slot_%d.json" % START_MAP_SLOT
	if not FileAccess.file_exists(path):
		return _make_blank_map()
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return _make_blank_map()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return _make_blank_map()
	var d: Dictionary = (parsed as Dictionary).duplicate(true)
	# 地图格式：根级 grid_width, grid_height, cell_size, tiles, rooms, map_name, next_room_id
	# 封装为 map 结构以符合 GameState
	if not d.has(KEY_MAP):
		var map_obj: Dictionary = {}
		for key in ["grid_width", "grid_height", "cell_size", "tiles", "rooms", "next_room_id", "map_name"]:
			if d.has(key):
				map_obj[key] = d[key]
		if not map_obj.has("next_room_id"):
			map_obj["next_room_id"] = 1
		return map_obj
	return d.get(KEY_MAP, {}) as Dictionary


func _make_blank_map() -> Dictionary:
	var tiles: Array = []
	for x in GRID_WIDTH:
		var col: Array = []
		for y in GRID_HEIGHT:
			col.append(FloorTileType.Type.EMPTY)
		tiles.append(col)
	return {
		"grid_width": GRID_WIDTH,
		"grid_height": GRID_HEIGHT,
		"cell_size": CELL_SIZE,
		"tiles": tiles,
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
	## 仅读取游戏存档（user://saves/）
	var raw: Variant = _read_save_json(slot)
	if raw == null:
		return null
	if not (raw is Dictionary):
		return null
	var d: Dictionary = (raw as Dictionary).duplicate(true)
	if not validate_save(d):
		return null
	_migrate_to_game_state(d)
	return d


func _migrate_to_game_state(d: Dictionary) -> void:
	## 将原始数据迁移为完整 GameState 格式
	# 1. 旧版纯地图：根级 tiles/rooms 放入 map
	if d.has("tiles") or d.has("rooms"):
		if not d.has(KEY_MAP):
			var map_obj: Dictionary = {}
			for key in ["grid_width", "grid_height", "cell_size", "tiles", "rooms", "next_room_id", "map_name"]:
				if d.has(key):
					map_obj[key] = d[key]
			if d.has(KEY_MAP_NAME):
				map_obj[KEY_MAP_NAME] = d[KEY_MAP_NAME]
			d[KEY_MAP] = map_obj
	# 2. 确保 version
	if not d.has(KEY_VERSION):
		d[KEY_VERSION] = 0
	var ver: int = int(d.get(KEY_VERSION, 0))
	if ver < 1:
		_fill_defaults(d)
		d[KEY_VERSION] = SAVE_VERSION_CURRENT
	# 3. 确保 map_name 在根级（便于元数据）
	if not d.has(KEY_MAP_NAME) and d.has(KEY_MAP):
		var m: Variant = d[KEY_MAP]
		if m is Dictionary:
			d[KEY_MAP_NAME] = (m as Dictionary).get(KEY_MAP_NAME, tr("DEFAULT_UNTITLED"))


func _fill_defaults(d: Dictionary) -> void:
	## 补全 time、resources、erosion 默认值
	if not d.has(KEY_TIME):
		d[KEY_TIME] = {
			"total_game_hours": 0,
			"is_flowing": true,
			"speed_multiplier": 1.0,
		}
	var base: Dictionary = _load_game_base()
	if base.is_empty():
		if not d.has(KEY_RESOURCES):
			d[KEY_RESOURCES] = {
				"factors": {"cognition": 500, "computation": 0, "willpower": 400, "permission": 400},
				"currency": {"info": 500, "truth": 0},
				"personnel": {"researcher": 10, "labor": 0, "eroded": 0, "investigator": 0},
			}
	else:
		if not d.has(KEY_RESOURCES):
			d[KEY_RESOURCES] = base.get("initial_resources", {}).duplicate(true)
	if not d.has(KEY_EROSION):
		d[KEY_EROSION] = {}


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

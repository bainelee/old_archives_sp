extends Node
## 游戏数值加载器（Autoload: GameValues）
## 运行时从 res://datas/game_values.json 加载数值，供消耗、产出、建设等逻辑调用。
## 数据来源与设计文档对应：docs/design/0-values/01-game-values.md（该文档不打包进游戏）。
## 修改 JSON 后：重启游戏会生效；或调用 reload() 手动重载；开发时每 2 秒自动检测文件变化并重载。

const GAME_VALUES_PATH := "res://datas/game_values.json"
const AUTO_RELOAD_INTERVAL := 2.0  ## 开发时自动检测间隔（秒）

var _data: Dictionary = {}
var _loaded_file_hash: int = 0


func _ready() -> void:
	_load()
	_start_auto_reload_timer()


func _load(force: bool = false) -> bool:
	if not force and not _data.is_empty():
		return true
	var file := FileAccess.open(GAME_VALUES_PATH, FileAccess.READ)
	if file == null:
		push_error(tr("ERROR_GAME_VALUES_OPEN") % GAME_VALUES_PATH)
		return false
	var content: String = file.get_as_text()
	file.close()
	_loaded_file_hash = content.hash()
	var json := JSON.new()
	var err := json.parse(content)
	if err != OK:
		push_error(tr("ERROR_GAME_VALUES_JSON") % json.get_error_message())
		return false
	var raw: Variant = json.get_data()
	if not (raw is Dictionary):
		push_error(tr("ERROR_GAME_VALUES_ROOT"))
		return false
	_data = _filter_comment_keys(raw as Dictionary)
	return true


## 过滤以 _ 开头的说明用键
func _filter_comment_keys(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d:
		if k is String and k.begins_with("_"):
			continue
		var v: Variant = d[k]
		if v is Dictionary:
			out[k] = _filter_comment_keys(v as Dictionary)
		else:
			out[k] = v
	return out


## 确保已加载（延迟加载场景时调用）
func ensure_loaded() -> bool:
	return _load()


## 强制重新加载 JSON，修改 game_values.json 后调用可立即生效
func reload() -> bool:
	_data = {}
	_loaded_file_hash = 0
	return _load()


func _start_auto_reload_timer() -> void:
	## 仅从编辑器运行（F5）时启用：res:// 指向项目目录可检测文件变化；导出后 res:// 为 PCK 不可修改
	if not OS.has_feature("editor_runtime"):
		return
	var timer := Timer.new()
	timer.wait_time = AUTO_RELOAD_INTERVAL
	timer.one_shot = false
	timer.timeout.connect(_check_for_reload)
	add_child(timer)
	timer.start()


func _check_for_reload() -> void:
	var file := FileAccess.open(GAME_VALUES_PATH, FileAccess.READ)
	if file == null:
		return
	var content: String = file.get_as_text()
	file.close()
	if content.hash() != _loaded_file_hash:
		reload()


## --- 研究员认知消耗 ---
func get_researcher_cognition_per_hour() -> int:
	return int(_data.get("researcher_cognition", {}).get("consumption_per_researcher_per_hour", 1))


## --- 庇护等级 ---
func get_shelter_level_min() -> int:
	return int(_data.get("shelter", {}).get("level_min", 1))


func get_shelter_level_max() -> int:
	return int(_data.get("shelter", {}).get("level_max", 4))


func get_shelter_base_consumption_per_level_per_hour() -> int:
	return int(_data.get("shelter", {}).get("base_consumption_per_level_per_hour", 10))


func get_shelter_consumption_multiplier_per_tier() -> float:
	return float(_data.get("shelter", {}).get("consumption_multiplier_per_open_tier", 1.0))


func get_shelter_range_tiers() -> Array:
	return _data.get("shelter", {}).get("range_tiers", [])


## --- 房间清理 ---
## 返回 [{units或units_min/units_max, researchers, info, hours}, ...]
func get_cleanup_configs() -> Array:
	return _data.get("cleanup", [])


## 根据房间单位数返回匹配的清理配置，无匹配时用首/尾配置兜底（小房间用首项，大房间用尾项）
func get_cleanup_for_units(units: int) -> Variant:
	var configs: Array = get_cleanup_configs()
	for cfg in configs:
		if not cfg is Dictionary:
			continue
		var d: Dictionary = cfg as Dictionary
		if d.has("units"):
			if int(d.units) == units:
				return d
		elif d.has("units_min") and d.has("units_max"):
			var u_min: int = int(d.units_min)
			var u_max: int = int(d.units_max)
			if units >= u_min and units <= u_max:
				return d
	if configs.size() > 0:
		return configs[configs.size() - 1] if units >= 6 else configs[0]
	return null


## --- 建设区域 ---
## zone_type: ZoneType.Type 枚举值（1=研究区 2=造物区 3=事务所 4=生活区）
func get_construction_config(zone_type: int) -> Dictionary:
	var construction: Dictionary = _data.get("construction", {})
	return construction.get(str(zone_type), {})


func get_construction_cost(zone_type: int) -> Dictionary:
	var cfg: Dictionary = get_construction_config(zone_type)
	var cost: Dictionary = {}
	if cfg.has("info"):
		cost["info"] = int(cfg.info)
	if cfg.has("permission") and int(cfg.permission) > 0:
		cost["permission"] = int(cfg.permission)
	return cost


func get_construction_researcher_count(zone_type: int) -> int:
	var cfg: Dictionary = get_construction_config(zone_type)
	return int(cfg.get("researchers", 0))


func get_construction_hours_per_unit(zone_type: int) -> float:
	var cfg: Dictionary = get_construction_config(zone_type)
	return float(cfg.get("hours_per_unit", 2.0))


## --- 住房 ---
func get_housing_per_dormitory() -> int:
	return int(_data.get("housing", {}).get("housing_per_dormitory", 4))


func get_dormitory_units() -> int:
	return int(_data.get("housing", {}).get("dormitory_units", 3))


## --- 研究区产出 ---
## room_type: RoomInfo.RoomType（0=图书室 1=机房 2=教学室 3=资料库）
func get_research_output(room_type: int) -> Dictionary:
	var research: Dictionary = _data.get("research_output", {})
	return research.get(str(room_type), {})


func get_research_output_resource(room_type: int) -> String:
	return str(get_research_output(room_type).get("resource", ""))


func get_research_output_per_unit_per_hour(room_type: int) -> int:
	return int(get_research_output(room_type).get("per_unit_per_hour", 0))


## --- 造物区产出 ---
## room_type: RoomInfo.RoomType（5=实验室 6=推理室）
func get_creation_output(room_type: int) -> Dictionary:
	var creation: Dictionary = _data.get("creation_output", {})
	return creation.get(str(room_type), {})


func get_creation_consume_resource(room_type: int) -> String:
	return str(get_creation_output(room_type).get("consume", ""))


func get_creation_consume_per_unit_per_hour(room_type: int) -> int:
	return int(get_creation_output(room_type).get("consume_per_unit_per_hour", 0))


func get_creation_produce_resource(room_type: int) -> String:
	return str(get_creation_output(room_type).get("produce", ""))


func get_creation_produce_per_unit_per_hour(room_type: int) -> int:
	return int(get_creation_output(room_type).get("produce_per_unit_per_hour", 0))


## --- 改造消耗 ---
func get_remodel_cost() -> Dictionary:
	return (_data.get("remodel", {})).duplicate()


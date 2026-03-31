extends Node
## 游戏数值加载器（Autoload: GameValues）
## 运行时从 res://datas/*.json 加载数值，供消耗、产出、建设等逻辑调用。
## 数据来源与设计文档对应：docs/design/0-values/01-game-values.md（该文档不打包进游戏）。
## 修改 JSON 后：重启游戏会生效；或调用 reload() 手动重载；开发时每 2 秒自动检测文件变化并重载。
## 热重载后发出 config_reloaded 信号，缓存型模块可连接以刷新配置。

signal config_reloaded()

const GAME_VALUES_PATH := "res://datas/game_values.json"
const TIME_SYSTEM_PATH := "res://datas/time_system.json"
const CLEANUP_SYSTEM_PATH := "res://datas/cleanup_system.json"
const CONSTRUCTION_SYSTEM_PATH := "res://datas/construction_system.json"
const RESEARCHER_SYSTEM_PATH := "res://datas/researcher_system.json"
const EROSION_SYSTEM_PATH := "res://datas/erosion_system.json"
const SHELTER_SYSTEM_PATH := "res://datas/shelter_system.json"
const ROOM_SIZE_CONFIG_PATH := "res://datas/room_size_config.json"
const AUTO_RELOAD_INTERVAL := 2.0  ## 开发时自动检测间隔（秒）

var _data: Dictionary = {}  ## base: game_values.json
var _time_data: Dictionary = {}
var _cleanup_data: Dictionary = {}
var _construction_data: Dictionary = {}
var _researcher_data: Dictionary = {}
var _erosion_data: Dictionary = {}
var _shelter_data: Dictionary = {}
var _room_size_data: Dictionary = {}

var _loaded_file_hashes: Dictionary = {}


func _ready() -> void:
	_load()
	_start_auto_reload_timer()


func _load(force: bool = false) -> bool:
	if not force and not _data.is_empty():
		return true
	_data = _load_json_dict(GAME_VALUES_PATH, true)
	if _data.is_empty():
		return false
	_time_data = _load_json_dict(TIME_SYSTEM_PATH)
	_cleanup_data = _load_json_dict(CLEANUP_SYSTEM_PATH)
	_construction_data = _load_json_dict(CONSTRUCTION_SYSTEM_PATH)
	_researcher_data = _load_json_dict(RESEARCHER_SYSTEM_PATH)
	_erosion_data = _load_json_dict(EROSION_SYSTEM_PATH)
	_shelter_data = _load_json_dict(SHELTER_SYSTEM_PATH)
	_room_size_data = _load_json_dict(ROOM_SIZE_CONFIG_PATH)
	_validate_loaded_configs()
	return true


func _load_json_dict(path: String, required: bool = false) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		if required:
			push_error(tr("ERROR_GAME_VALUES_OPEN") % path)
		return {}
	var content: String = file.get_as_text()
	file.close()
	_loaded_file_hashes[path] = content.hash()
	var json := JSON.new()
	var err := json.parse(content)
	if err != OK:
		if required:
			push_error(tr("ERROR_GAME_VALUES_JSON") % json.get_error_message())
		return {}
	var raw: Variant = json.get_data()
	if not (raw is Dictionary):
		if required:
			push_error(tr("ERROR_GAME_VALUES_ROOT"))
		return {}
	return _filter_comment_keys(raw as Dictionary)


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
	_time_data = {}
	_cleanup_data = {}
	_construction_data = {}
	_researcher_data = {}
	_erosion_data = {}
	_shelter_data = {}
	_room_size_data = {}
	_loaded_file_hashes.clear()
	var ok: bool = _load()
	if ok:
		config_reloaded.emit()
	return ok


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
	for path in _all_config_paths():
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var content: String = file.get_as_text()
		file.close()
		if int(_loaded_file_hashes.get(path, -1)) != content.hash():
			reload()
			return


func _all_config_paths() -> Array:
	return [
		GAME_VALUES_PATH,
		TIME_SYSTEM_PATH,
		CLEANUP_SYSTEM_PATH,
		CONSTRUCTION_SYSTEM_PATH,
		RESEARCHER_SYSTEM_PATH,
		EROSION_SYSTEM_PATH,
		SHELTER_SYSTEM_PATH,
		ROOM_SIZE_CONFIG_PATH,
	]


func _validate_loaded_configs() -> void:
	# 运行时只做轻量结构校验：开发环境给出 warning，发布环境不影响性能。
	if not OS.has_feature("editor_runtime"):
		return
	_validate_required_keys(_data, "game_values", ["factor_caps", "research_output", "creation_output", "remodel"])
	_validate_required_keys(_time_data, "time_system", ["version", "time", "calendar", "speed_presets", "speed_range"])
	_validate_required_keys(_cleanup_data, "cleanup_system", ["version", "cleanup"])
	_validate_required_keys(_construction_data, "construction_system", ["version", "construction", "production", "zone_extensions"])
	_validate_required_keys(_researcher_data, "researcher_system", ["version", "cognition", "housing", "housing_linkage", "info_daily", "recruitment"])
	_validate_required_keys(_erosion_data, "erosion_system", ["version", "erosion_probability", "risk", "cure", "death_curve", "calamity"])
	_validate_required_keys(_shelter_data, "shelter_system", ["version", "shelter"])

	_validate_type(_time_data.get("time", null), "Dictionary", "time_system.time")
	_validate_type(_time_data.get("calendar", null), "Dictionary", "time_system.calendar")
	_validate_type(_time_data.get("speed_presets", null), "Dictionary", "time_system.speed_presets")
	_validate_type(_time_data.get("speed_range", null), "Dictionary", "time_system.speed_range")

	_validate_type(_cleanup_data.get("cleanup", null), "Array", "cleanup_system.cleanup")
	_validate_type(_construction_data.get("construction", null), "Dictionary", "construction_system.construction")
	_validate_type(_construction_data.get("production", null), "Dictionary", "construction_system.production")
	_validate_type(_construction_data.get("zone_extensions", null), "Dictionary", "construction_system.zone_extensions")
	_validate_type(_researcher_data.get("cognition", null), "Dictionary", "researcher_system.cognition")
	_validate_type(_researcher_data.get("housing", null), "Dictionary", "researcher_system.housing")
	_validate_type(_researcher_data.get("housing_linkage", null), "Dictionary", "researcher_system.housing_linkage")
	_validate_type(_researcher_data.get("info_daily", null), "Dictionary", "researcher_system.info_daily")
	_validate_type(_researcher_data.get("recruitment", null), "Dictionary", "researcher_system.recruitment")
	_validate_type(_erosion_data.get("erosion_probability", null), "Dictionary", "erosion_system.erosion_probability")
	_validate_type(_shelter_data.get("shelter", null), "Dictionary", "shelter_system.shelter")

	_validate_factor_caps()
	_validate_outputs()


func _validate_required_keys(data: Dictionary, root_name: String, keys: Array) -> void:
	for key in keys:
		if not data.has(key):
			_warn_config("%s.%s 缺失（将使用运行时 fallback）" % [root_name, str(key)])


func _validate_type(value: Variant, expected_type: String, path: String) -> void:
	match expected_type:
		"Dictionary":
			if not (value is Dictionary):
				_warn_config("%s 类型应为 Dictionary" % path)
		"Array":
			if not (value is Array):
				_warn_config("%s 类型应为 Array" % path)
		"String":
			if not (value is String):
				_warn_config("%s 类型应为 String" % path)
		"Number":
			if not (value is int or value is float):
				_warn_config("%s 类型应为 Number" % path)
		_:
			pass


func _validate_factor_caps() -> void:
	var caps: Variant = _data.get("factor_caps", {})
	if not (caps is Dictionary):
		_warn_config("game_values.factor_caps 类型应为 Dictionary")
		return
	var d: Dictionary = caps
	for factor_key in ["cognition", "computation", "willpower", "permission"]:
		if not d.has(factor_key):
			_warn_config("game_values.factor_caps.%s 缺失" % factor_key)
		elif not _is_int_or_whole_float(d[factor_key]):
			_warn_config("game_values.factor_caps.%s 应为整数" % factor_key)


func _validate_outputs() -> void:
	var research: Variant = _data.get("research_output", {})
	if not (research is Dictionary):
		_warn_config("game_values.research_output 类型应为 Dictionary")
	else:
		for k in (research as Dictionary).keys():
			var cfg: Variant = (research as Dictionary).get(k, null)
			if not (cfg is Dictionary):
				_warn_config("game_values.research_output.%s 类型应为 Dictionary" % str(k))
				continue
			if not (cfg as Dictionary).has("resource") or not (cfg as Dictionary).has("per_unit_per_hour"):
				_warn_config("game_values.research_output.%s 缺少 resource/per_unit_per_hour" % str(k))
	var creation: Variant = _data.get("creation_output", {})
	if not (creation is Dictionary):
		_warn_config("game_values.creation_output 类型应为 Dictionary")
	else:
		for k in (creation as Dictionary).keys():
			var cfg: Variant = (creation as Dictionary).get(k, null)
			if not (cfg is Dictionary):
				_warn_config("game_values.creation_output.%s 类型应为 Dictionary" % str(k))
				continue
			var cd: Dictionary = cfg
			for req in ["consume", "consume_per_unit_per_hour", "produce", "produce_per_unit_per_hour"]:
				if not cd.has(req):
					_warn_config("game_values.creation_output.%s 缺少 %s" % [str(k), req])


## JSON 解析后数字可能为 float，此处接受 int 或整型 float
func _is_int_or_whole_float(v: Variant) -> bool:
	if v is int:
		return true
	if v is float:
		var f: float = v
		return is_equal_approx(floorf(f), f)
	return false


func _warn_config(message: String) -> void:
	push_warning("[GameValues Validation] %s" % message)


## --- 因子储藏上限 ---
## factor_key: cognition / computation / willpower / permission
func get_factor_cap(factor_key: String) -> int:
	var caps: Dictionary = _data.get("factor_caps", {})
	return int(caps.get(factor_key, 999999))


## --- 研究员认知消耗 ---
func get_researcher_cognition_per_hour() -> int:
	var from_new: int = int(_researcher_data.get("cognition", {}).get("consumption_per_researcher_per_hour", 0))
	if from_new > 0:
		return from_new
	return int(_data.get("researcher_cognition", {}).get("consumption_per_researcher_per_hour", 1))


func get_researcher_cognition_per_day() -> int:
	var from_new: int = int(_researcher_data.get("cognition", {}).get("consumption_per_researcher_per_day", 0))
	if from_new > 0:
		return from_new
	return 24


## --- 庇护能量 ---
## 核心能耗等级 1～5，1 CF/h = 1 庇护能量
func get_shelter_level_min() -> int:
	if not _shelter_data.is_empty():
		return int(_shelter_data.get("shelter", {}).get("level_min", 1))
	return int(_data.get("shelter", {}).get("level_min", 1))


func get_shelter_level_max() -> int:
	if not _shelter_data.is_empty():
		return int(_shelter_data.get("shelter", {}).get("level_max", 5))
	return int(_data.get("shelter", {}).get("level_max", 5))


## 返回 energy_levels 数组：{"level", "cf_per_hour", "energy_cap"}
func get_shelter_energy_levels() -> Array:
	if not _shelter_data.is_empty():
		return _shelter_data.get("shelter", {}).get("energy_levels", [])
	return _data.get("shelter", {}).get("energy_levels", [])


## 根据核心等级返回 {cf_per_hour, cf_per_day?, energy_cap}
## cf_per_day 若存在则限制每日 CF 消耗上限，有效 energy_cap = min(energy_cap, cf_per_day/24)
func get_shelter_cf_and_cap_for_level(level: int) -> Dictionary:
	var levels: Array = get_shelter_energy_levels()
	for cfg in levels:
		if cfg is Dictionary and int(cfg.get("level", 0)) == level:
			var cf_per_hour: int = int(cfg.get("cf_per_hour", 30))
			var energy_cap: int = int(cfg.get("energy_cap", 30))
			var result: Dictionary = {"cf_per_hour": cf_per_hour, "energy_cap": energy_cap}
			if cfg.has("cf_per_day"):
				result["cf_per_day"] = int(cfg.get("cf_per_day", 0))
			return result
	return {"cf_per_hour": 30, "energy_cap": 30}


## 每个房间由核心提供的庇护能量上限（与侵蚀无关）
func get_shelter_energy_per_room_max() -> int:
	if not _shelter_data.is_empty():
		return int(_shelter_data.get("shelter", {}).get("energy_per_room_max", 5))
	return int(_data.get("shelter", {}).get("energy_per_room_max", 5))


## 不参与庇护分配的房间类型（RoomInfo.RoomType 枚举值）
func get_shelter_room_types_no_shelter() -> Array:
	if not _shelter_data.is_empty():
		return _shelter_data.get("shelter", {}).get("room_types_no_shelter", [4, 9, 10])
	return _data.get("shelter", {}).get("room_types_no_shelter", [4, 9, 10])


## --- 房间清理 ---
## 返回 [{units或units_min/units_max, researchers, info, hours}, ...]
func get_cleanup_configs() -> Array:
	if not _cleanup_data.is_empty():
		return _cleanup_data.get("cleanup", [])
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
	var construction: Dictionary = _construction_data.get("construction", {})
	if construction.is_empty():
		construction = _data.get("construction", {})
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


## --- 房间尺寸 ---
## 根据 size_3d 查表返回房间单位数，未知尺寸返回 -1（调用方需 fallback）
func get_room_units_for_size(size_id: String) -> int:
	if size_id.is_empty():
		return -1
	var sizes: Dictionary = _room_size_data.get("sizes", {})
	var entry: Variant = sizes.get(size_id.to_lower(), sizes.get(size_id, null))
	if entry is Dictionary:
		return int((entry as Dictionary).get("units", -1))
	return -1


## --- 住房 ---
## 每 N 单位居住区提供 M 住房；公式 housing = (room_units / living_units_per_batch) * housing_per_batch
func get_living_units_per_batch() -> int:
	return int(_researcher_data.get("housing", {}).get("living_units_per_batch", 2))


func get_housing_per_batch() -> int:
	return int(_researcher_data.get("housing", {}).get("housing_per_batch", 4))


## 根据房间单位数返回住房槽数（兼容旧调用，现由 get_housing_for_room_units 替代）
func get_housing_per_dormitory() -> int:
	return get_housing_per_batch()


func get_housing_for_room_units(units: int) -> int:
	var batch: int = get_living_units_per_batch()
	var per_batch: int = get_housing_per_batch()
	if batch <= 0:
		return 0
	## 每 batch 单位提供 per_batch 住房，比例计算（1 单位 = 2 住房）
	return maxi(0, int((float(units) / float(batch)) * per_batch))


func get_dormitory_units() -> int:
	return get_living_units_per_batch()


## --- Phase 2.5 researcher contracts (read-only) ---
func get_recruitment_config() -> Dictionary:
	return (_researcher_data.get("recruitment", {}) as Dictionary).duplicate(true)


func is_recruitment_enabled() -> bool:
	return bool(_researcher_data.get("recruitment", {}).get("enabled", false))


func get_recruitment_base_batch_size() -> int:
	return int(_researcher_data.get("recruitment", {}).get("base_batch_size", 20))


func get_recruitment_base_progress_per_day() -> float:
	return float(_researcher_data.get("recruitment", {}).get("base_progress_per_day", 1.0))


func get_recruitment_housing_shortage_batch_penalty() -> int:
	return int(_researcher_data.get("recruitment", {}).get("housing_shortage_batch_penalty_per_person", 1))


func get_recruitment_min_batch_size() -> int:
	return int(_researcher_data.get("recruitment", {}).get("min_batch_size", 1))


func get_housing_linkage_config() -> Dictionary:
	return (_researcher_data.get("housing_linkage", {}) as Dictionary).duplicate(true)


func get_no_housing_erosion_probability_multiplier() -> float:
	return float(_researcher_data.get("housing_linkage", {}).get("no_housing_erosion_probability_multiplier", 2.0))


func should_no_housing_skip_cure_for_eroded() -> bool:
	return bool(_researcher_data.get("housing_linkage", {}).get("no_housing_skip_cure_for_eroded", true))


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


## --- Time system ---
func get_time_real_seconds_per_game_hour() -> float:
	return float(_time_data.get("time", {}).get("real_seconds_per_game_hour", 1.0))


func get_time_hours_per_day() -> int:
	return int(_time_data.get("calendar", {}).get("hours_per_day", 24))


func get_time_days_per_week() -> int:
	return int(_time_data.get("calendar", {}).get("days_per_week", 7))


func get_time_days_per_month() -> int:
	return int(_time_data.get("calendar", {}).get("days_per_month", 28))


func get_time_months_per_year() -> int:
	return int(_time_data.get("calendar", {}).get("months_per_year", 12))


func get_time_speed_preset(preset_name: String) -> float:
	return float(_time_data.get("speed_presets", {}).get(preset_name, 1.0))


func get_time_speed_min() -> float:
	return float(_time_data.get("speed_range", {}).get("min", 1.0))


func get_time_speed_max() -> float:
	return float(_time_data.get("speed_range", {}).get("max", 96.0))


## --- Construction production runtime ---
func get_creation_pause_check_hours() -> int:
	return int(_construction_data.get("production", {}).get("creation_pause_check_hours", 24))


func get_production_max_hours_per_frame() -> int:
	return int(_construction_data.get("production", {}).get("max_hours_per_frame", 24))


## --- Phase 2.5 zone extension contracts (read-only) ---
func get_zone_extension_configs() -> Dictionary:
	return (_construction_data.get("zone_extensions", {}) as Dictionary).duplicate(true)


func get_zone_extension_config(zone_type: int) -> Dictionary:
	return (_construction_data.get("zone_extensions", {}).get(str(zone_type), {}) as Dictionary).duplicate(true)


func is_zone_extension_enabled(zone_type: int) -> bool:
	return bool(_construction_data.get("zone_extensions", {}).get(str(zone_type), {}).get("enabled", false))


## --- Erosion runtime ---
func get_erosion_prob_extreme() -> int:
	return int(_erosion_data.get("erosion_probability", {}).get("extreme", 80))


func get_erosion_prob_exposed() -> int:
	return int(_erosion_data.get("erosion_probability", {}).get("exposed", 50))


func get_erosion_prob_weak() -> int:
	return int(_erosion_data.get("erosion_probability", {}).get("weak", 20))


func get_erosion_risk_threshold_per_7_days() -> int:
	return int(_erosion_data.get("risk", {}).get("threshold_per_7_days", 5))


func get_erosion_cure_interval_days() -> int:
	return int(_erosion_data.get("cure", {}).get("interval_days", 3))


func get_erosion_cure_prob_adequate() -> int:
	return int(_erosion_data.get("cure", {}).get("probability", {}).get("adequate", 30))


func get_erosion_cure_prob_perfect() -> int:
	return int(_erosion_data.get("cure", {}).get("probability", {}).get("perfect", 80))


func get_erosion_immunity_days() -> int:
	return int(_erosion_data.get("cure", {}).get("immunity_days", 7))


func get_erosion_death_days_half() -> int:
	return int(_erosion_data.get("death_curve", {}).get("half_days", 112))


func get_erosion_death_days_full() -> int:
	return int(_erosion_data.get("death_curve", {}).get("full_days", 140))


func get_erosion_death_curve_exponent() -> float:
	return float(_erosion_data.get("death_curve", {}).get("exponent", 3.1))


func get_calamity_per_eroded_per_hour() -> float:
	return float(_erosion_data.get("calamity", {}).get("per_eroded_per_hour", 1.0))


func get_calamity_max_value() -> int:
	return int(_erosion_data.get("calamity", {}).get("max_value", 30000))


func get_cognition_crisis_max_stacks() -> int:
	return int(_researcher_data.get("cognition", {}).get("crisis", {}).get("max_stacks", 3))


func get_calamity_per_impaired_per_day() -> int:
	return int(_researcher_data.get("cognition", {}).get("crisis", {}).get("calamity_per_impaired_per_day", 10))


## --- 研究员信息日结（货币 info，见 08-researcher-system §1.3）---
func get_researcher_info_daily_base() -> int:
	return int(_researcher_data.get("info_daily", {}).get("per_researcher_base", 3))


func get_researcher_info_daily_penalty_no_housing() -> int:
	return int(_researcher_data.get("info_daily", {}).get("penalty_no_housing", 1))


func get_researcher_info_daily_penalty_cognition_crisis() -> int:
	return int(_researcher_data.get("info_daily", {}).get("penalty_cognition_crisis", 1))


func get_researcher_info_daily_minimum_if_not_eroded() -> int:
	return int(_researcher_data.get("info_daily", {}).get("minimum_if_not_eroded", 1))

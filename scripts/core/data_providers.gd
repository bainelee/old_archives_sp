extends Node
## 数据提供者（Autoload: DataProviders）
## 为详情面板提供分解后的数据接口
## 将原始游戏数据转换为面板友好的结构化格式

signal factor_data_changed(factor_key: String)
signal shelter_data_changed
signal researcher_data_changed
signal housing_data_changed
signal information_data_changed
signal investigator_data_changed
signal truth_data_changed

const _GameValuesRef = preload("res://scripts/core/game_values_ref.gd")
const _DataProvidersFutureStubs = preload("res://scripts/core/data_providers_future_stubs.gd")
const _UIUtils = preload("res://scripts/core/ui_utils.gd")
const ZoneTypeScript = preload("res://scripts/core/zone_type.gd")
const RoomInfoScript = preload("res://scripts/core/room_info.gd")

## 缓存的上次数据（用于检测变化）
var _last_factor_data: Dictionary = {}
var _last_shelter_sync_energy: int = -999999
var _last_shelter_sync_demand: int = -999999
var _last_shelter_sync_level: int = -999999
var _last_researcher_data: Dictionary = {}


func _ready() -> void:
	## 连接 GameValues 重载信号
	if GameValues:
		GameValues.config_reloaded.connect(_on_config_reloaded)


func _on_config_reloaded() -> void:
	## 配置重载时发出所有数据变化信号
	_last_shelter_sync_energy = -999999
	_last_shelter_sync_demand = -999999
	_last_shelter_sync_level = -999999
	factor_data_changed.emit("all")
	shelter_data_changed.emit()
	researcher_data_changed.emit()
	housing_data_changed.emit()
	information_data_changed.emit()
	investigator_data_changed.emit()
	truth_data_changed.emit()


## ============================================================================
## 因子数据分解
## ============================================================================

## 获取因子分解数据
## factor_key: cognition / computation / willpower / permission
func get_factor_breakdown(factor_key: String) -> Dictionary:
	var result := {
		"current": 0,
		"cap": 0,
		"status": "",
		"status_code": "",  # dried_up / lacking / strained / normal / abundant
		"daily_net": 0,
		"days_remaining": 0,
		"fixed_consumption": [],  # [{name, amount, source_type}]
		"archives_consumption": [],  # [{name, amount, room_type}]
		"output": [],  # [{source, amount, source_type}]
		"warning_text": "",
		"total_consumption": 0,
		"total_output": 0,
	}

	## 获取当前储量和上限
	result.current = _get_factor_current(factor_key)
	result.cap = _get_factor_cap(factor_key)

	## 计算消耗和产出
	result.fixed_consumption = _get_fixed_consumption(factor_key)
	result.archives_consumption = _get_archives_consumption(factor_key)
	result.output = _get_factor_output(factor_key)

	## 计算总量
	var fixed_total := 0
	for entry in result.fixed_consumption:
		fixed_total += entry.get("amount", 0)
	var archives_total := 0
	for entry in result.archives_consumption:
		archives_total += entry.get("amount", 0)
	result.total_consumption = fixed_total + archives_total

	for entry in result.output:
		result.total_output += entry.get("amount", 0)

	## 计算每日净变化
	result.daily_net = result.total_output - result.total_consumption

	## 计算状态和剩余天数
	result.status_code = _calculate_factor_status(result.current, result.cap, result.daily_net)
	result.status = tr("FACTOR_STATUS_" + result.status_code.to_upper())
	result.days_remaining = _calculate_days_remaining(result.current, result.daily_net)
	result.warning_text = _get_factor_warning(result.status_code, result.days_remaining, result.current, result.daily_net)

	return result


## 获取因子当前储量（从游戏状态）
func _get_factor_current(factor_key: String) -> int:
	var ui_main := _get_ui_main()
	if not ui_main:
		return 0
	match factor_key:
		"cognition": return ui_main.get_cognition() if ui_main.has_method("get_cognition") else 0
		"computation": return ui_main.get_computation() if ui_main.has_method("get_computation") else 0
		"willpower": return ui_main.get_willpower() if ui_main.has_method("get_willpower") else 0
		"permission": return ui_main.get_permission() if ui_main.has_method("get_permission") else 0
	return 0


## 获取因子上限
func _get_factor_cap(factor_key: String) -> int:
	if GameValues:
		return GameValues.get_factor_cap(factor_key)
	return 999999


## 获取固有消耗条目
## 来自探索中的节点
func _get_fixed_consumption(_factor_key: String) -> Array:
	return _DataProvidersFutureStubs.exploration_fixed_consumption_entries()


## 获取档案馆消耗条目
## 来自已建设房间的消耗
func _get_archives_consumption(factor_key: String) -> Array:
	var result: Array = []
	var game_main := _get_game_main()
	if not game_main or not game_main.has_method("get_game_rooms") or game_main.get_game_rooms().is_empty():
		return result

	var rooms: Array = game_main.get_game_rooms()
	for room in rooms:
		if not room or not room.has_method("get_consumption"):
			continue
		var consumption: Dictionary = room.get_consumption()
		if consumption.has(factor_key) and consumption[factor_key] > 0:
			var room_name := ""
			if room.has_method("get_room_name"):
				room_name = room.get_room_name()
			elif room.has("room_name"):
				room_name = room.get("room_name")
			else:
				room_name = tr("ROOM_UNKNOWN")

			result.append({
				"name": room_name,
				"amount": consumption[factor_key],
				"room_type": room.get("room_type") if room.has("room_type") else -1,
			})

	return result


## 获取因子产出条目
## 来自房间产出和探索节点产出
func _get_factor_output(factor_key: String) -> Array:
	var result: Array = []
	var game_main := _get_game_main()
	if not game_main or not game_main.has_method("get_game_rooms") or game_main.get_game_rooms().is_empty():
		return result

	var rooms: Array = game_main.get_game_rooms()
	for room in rooms:
		if not room or not room.has_method("get_output"):
			continue
		var output: Dictionary = room.get_output()
		if output.has(factor_key) and output[factor_key] > 0:
			var room_name := ""
			if room.has_method("get_room_name"):
				room_name = room.get_room_name()
			elif room.has("room_name"):
				room_name = room.get("room_name")
			else:
				room_name = tr("ROOM_UNKNOWN")

			## 判断产出类型（研究区、造物区、探索等）
			var source_type := "archives"
			if room.has("zone_type"):
				var zt: int = room.get("zone_type")
				match zt:
					ZoneTypeScript.Type.RESEARCH: source_type = "research"
					ZoneTypeScript.Type.CREATION: source_type = "creation"
					ZoneTypeScript.Type.OFFICE: source_type = "office"
					ZoneTypeScript.Type.LIVING: source_type = "living"

			result.append({
				"source": room_name,
				"amount": output[factor_key],
				"source_type": source_type,
			})

	return result


## 计算因子状态
## 返回: dried_up / lacking / strained / normal / abundant
func _calculate_factor_status(current: int, cap: int, daily_net: int) -> String:
	## 业务语义：
	## stock_current 当前库存；net_per_week 每周净结余（每周总产出 - 每周总消耗）
	## 设计口径：库存见底时，净结余<0 为 lacking；净结余==0 为 dried_up
	var stock_current: int = current
	var net_per_week: int = daily_net * 7
	if stock_current <= 0 and net_per_week < 0:
		return "lacking"
	if stock_current <= 0 and net_per_week == 0:
		return "dried_up"
	if stock_current > 0 and daily_net < 0:
		return "strained"
	if stock_current >= cap and daily_net > 0:
		return "abundant"
	return "normal"


## 计算剩余天数
func _calculate_days_remaining(current: int, daily_net: int) -> int:
	if daily_net == 0:
		return 999999 if current > 0 else 0
	if daily_net > 0:
		## 增加中，返回到达上限的天数
		## 需要cap信息，这里简化处理
		return 999999
	## 消耗中
	return maxi(0, ceili(float(current) / abs(daily_net)))


## 获取因子警告文本
func _get_factor_warning(status_code: String, days: int, _current: int, daily_net: int) -> String:
	match status_code:
		"dried_up":
			return tr("FACTOR_WARNING_DRIED_UP")
		"lacking":
			return tr("FACTOR_WARNING_LACKING")
		"strained":
			return tr("FACTOR_WARNING_STRAINED") % days
		"normal":
			if daily_net > 0:
				return tr("FACTOR_WARNING_NORMAL_GROWING") % days
			return tr("FACTOR_WARNING_NORMAL")
		"abundant":
			return tr("FACTOR_WARNING_ABUNDANT")
	return ""


## ============================================================================
## 庇护能量数据分解
## ============================================================================

func get_shelter_breakdown() -> Dictionary:
	var result := {
		"capacity": 0.0,
		"assigned": 0.0,
		"deficit": 0.0,
		"innate": 0.0,
		"construction": 0.0,
		"output": 0.0,
		"region_status": {
			"perfect": 0,
			"adequate": 0,
			"weak": 0,
			"exposed": 0,
			"critical": 0,
			"shutdown": 0,
		},
		"innate_details": [],
		"output_details": [],
	}

	var game_main := _get_game_main()
	if not game_main:
		return result

	var shelter_level := 1
	if game_main.get("_shelter_level") != null:
		shelter_level = int(game_main.get("_shelter_level"))

	if GameValues:
		var cfg := GameValues.get_shelter_cf_and_cap_for_level(shelter_level)
		result.capacity = float(cfg.get("energy_cap", 30))

	var assigned_i: int = _UIUtils.safe_int(game_main.get("_shelter_energy"))
	var demand_i: int = _UIUtils.safe_int(game_main.get("_shelter_demand"))
	result.assigned = float(assigned_i)
	result.deficit = float(maxi(0, demand_i - assigned_i))

	var cf_hour: int = 0
	var shelter_h: Variant = game_main.get("_shelter_helper")
	if shelter_h is GameMainShelterHelper:
		cf_hour = (shelter_h as GameMainShelterHelper)._last_cf_consumed
	result.output = float(cf_hour * 24)
	var output_details: Array = []
	if result.output > 0.0:
		output_details.append({
			"source": tr("ARCHIVES_CORE"),
			"amount": result.output,
		})
	result.output_details = output_details

	var breakdown: Array = GameMainShelterHelper.get_shelter_consumption_breakdown(game_main, shelter_level)
	var innate_details: Array = []
	var per_day_sum: float = 0.0
	for row in breakdown:
		var zn: String = str(row.get("zone_name", ""))
		var rn: String = str(row.get("room_name", ""))
		var pd: float = float(row.get("per_day", 0))
		per_day_sum += pd
		var label: String = zn if rn.is_empty() else "%s - %s" % [zn, rn]
		innate_details.append({"name": label, "amount": pd})
	result.innate_details = innate_details
	result.innate = per_day_sum if per_day_sum > 0.0 else float(assigned_i * 24)
	result.construction = 0.0

	var rs: Dictionary = result["region_status"]
	var rooms: Variant = game_main.get_game_rooms() if game_main.has_method("get_game_rooms") else []
	if rooms is Array:
		for room in rooms as Array:
			if not (room is ArchivesRoomInfo):
				continue
			var rm: ArchivesRoomInfo = room as ArchivesRoomInfo
			if rm.zone_type == 0:
				continue
			var rid: String = rm.id if rm.id else rm.json_room_id
			if rid.is_empty():
				continue
			if game_main.has_method("is_room_forced_shutdown") and bool(game_main.call("is_room_forced_shutdown", rm)):
				rs["shutdown"] = int(rs.get("shutdown", 0)) + 1
				continue
			var sl: int = GameMainShelterHelper.get_room_shelter_level(game_main, rid)
			var bucket: String = _shelter_status_bucket(sl)
			rs[bucket] = int(rs.get(bucket, 0)) + 1

	return result


## 与 ErosionCore.get_shelter_status_name 阈值一致，用于房间综合庇护等级计数
func _shelter_status_bucket(level: int) -> String:
	if level <= -5:
		return "critical"
	if level >= -4 and level <= -2:
		return "exposed"
	if level >= -1 and level <= 1:
		return "weak"
	if level >= 2 and level <= 4:
		return "adequate"
	if level >= 5:
		return "perfect"
	return "weak"


## 庇护 tick 写入 TopBar 汇总后调用：数值变化时通知详情面板刷新
func on_shelter_topbar_sync(game_main: Node) -> void:
	if not game_main:
		return
	var e: int = _UIUtils.safe_int(game_main.get("_shelter_energy"))
	var d: int = _UIUtils.safe_int(game_main.get("_shelter_demand"))
	var l: int = _UIUtils.safe_int(game_main.get("_shelter_level"), 1)
	if e == _last_shelter_sync_energy and d == _last_shelter_sync_demand and l == _last_shelter_sync_level:
		return
	_last_shelter_sync_energy = e
	_last_shelter_sync_demand = d
	_last_shelter_sync_level = l
	shelter_data_changed.emit()


## ============================================================================
## 研究员数据分解
## ============================================================================

func get_researcher_breakdown() -> Dictionary:
	var result := {
		"idle": 0,
		"on_duty": 0,
		"eroded": 0,
		"total": 0,
		"region_breakdown": [],  # [{region_name, count}]
	}

	var ui_main := _get_ui_main()
	if not ui_main:
		return result

	result.total = ui_main.researcher_count if ui_main.get("researcher_count") != null else 0
	result.eroded = ui_main.eroded_count if ui_main.get("eroded_count") != null else 0

	## 计算在职和空闲
	var in_cleanup: int = ui_main.researchers_in_cleanup if ui_main.get("researchers_in_cleanup") != null else 0
	var in_construction: int = ui_main.researchers_in_construction if ui_main.get("researchers_in_construction") != null else 0
	var in_rooms: int = ui_main.researchers_working_in_rooms if ui_main.get("researchers_working_in_rooms") != null else 0

	result.on_duty = in_cleanup + in_construction + in_rooms
	result.idle = maxi(0, result.total - result.eroded - result.on_duty)

	## TODO: 区域分布需要研究员系统提供数据

	return result


## ============================================================================
## 住房数据分解
## ============================================================================

func get_housing_breakdown() -> Dictionary:
	var result := {
		"demand": 0,      # 需求
		"supplied": 0,    # 已提供
		"deficit": 0,     # 缺口
		"output_details": [],  # [{source, amount}]
	}

	var game_main := _get_game_main()
	if not game_main or not game_main.has_method("get_game_rooms") or game_main.get_game_rooms().is_empty():
		return result

	## 计算住房供应
	var rooms: Array = game_main.get_game_rooms()
	var gv = _GameValuesRef.get_singleton()

	for room in rooms:
		if not room:
			continue
		var zt: int = room.get("zone_type") if room.get("zone_type") != null else 0
		if zt != ZoneTypeScript.Type.LIVING:
			continue

		var units: int = 0
		if room.has_method("get_room_units"):
			units = room.get_room_units()

		var housing := 0
		if gv and gv.has_method("get_housing_for_room_units"):
			housing = gv.get_housing_for_room_units(units)
		else:
			housing = units * 2  ## 默认每单位2住房

		result.supplied += housing

		var room_name := ""
		if room.has_method("get_room_name"):
			room_name = room.get_room_name()
		elif room.has("room_name"):
			room_name = room.get("room_name")

		result.output_details.append({
			"source": room_name,
			"amount": housing,
		})

	## 计算住房需求（研究员总数）
	var ui_main := _get_ui_main()
	if ui_main:
		result.demand = ui_main.researcher_count if ui_main.get("researcher_count") != null else 0

	result.deficit = maxi(0, result.demand - result.supplied)

	return result


## ============================================================================
## 信息数据分解
## ============================================================================

func get_information_breakdown() -> Dictionary:
	var result := {
		"current": 0,
		"output": [],        # [{source, amount}]
		"extra_effects": [], # [{source, amount, description}]
	}

	var ui_main := _get_ui_main()
	if ui_main:
		result.current = ui_main.info_amount if ui_main.get("info_amount") != null else 0

	for x in _DataProvidersFutureStubs.information_exploration_output():
		result.output.append(x)
	for x in _DataProvidersFutureStubs.information_extra_effects():
		result.extra_effects.append(x)

	return result


## ============================================================================
## 调查员数据分解
## ============================================================================

func get_investigator_breakdown() -> Dictionary:
	var result := {
		"available": 0,       # 可分配
		"assigned": 0,        # 已分配
		"total": 0,         # 已招募总数
		"assigned_details": [],  # [{node_name, count}]
		"recruited_details": [], # [{source, count}]
	}

	var ui_main := _get_ui_main()
	if ui_main:
		result.total = ui_main.investigator_count if ui_main.get("investigator_count") != null else 0

	for x in _DataProvidersFutureStubs.investigator_exploration_assignments():
		result.assigned_details.append(x)

	return result


## ============================================================================
## 真相数据分解
## ============================================================================

func get_truth_breakdown() -> Dictionary:
	var result := {
		"acquired": _DataProvidersFutureStubs.truth_acquired_list(),
		"interpreted": _DataProvidersFutureStubs.truth_interpreted_list(),
	}

	return result


## ============================================================================
## 辅助方法
## ============================================================================

func _get_ui_main() -> Node:
	var game_main := _get_game_main()
	if not game_main:
		return null
	return game_main.get_node_or_null("InteractiveUiRoot/UIMain")


func _get_game_main() -> Node:
	## 尝试从场景树找到 GameMain
	var root := get_tree().root if get_tree() else null
	if not root:
		return null

	## 先检查当前场景的直接子节点
	var current_scene := get_tree().current_scene
	if current_scene and current_scene.name == "GameMain":
		return current_scene

	## 遍历寻找 GameMain
	for child in root.get_children():
		if child.name == "GameMain":
			return child
		for sub in child.get_children():
			if sub.name == "GameMain":
				return sub

	return null


## ============================================================================
## 数据变化检测与刷新
## ============================================================================

## 检查因子数据是否变化，变化时发出信号
func check_factor_data_changed(factor_key: String, new_data: Dictionary) -> bool:
	var key := "factor_" + factor_key
	var old_data: Dictionary = _last_factor_data.get(key, {})
	if old_data.hash() != new_data.hash():
		_last_factor_data[key] = new_data.duplicate(true)
		factor_data_changed.emit(factor_key)
		return true
	return false


## 手动触发数据刷新（供外部调用）
func refresh_all_data() -> void:
	_on_config_reloaded()

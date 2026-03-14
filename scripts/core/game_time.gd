extends Node
## 游戏时间流逝系统（Autoload: GameTime）
## 比例：现实 6 秒 = 游戏内 1 小时
## 时间单位：小时、天、周、月、年

## 现实 3 秒 = 1 游戏小时（默认值，可由数据驱动覆盖）
var REAL_SECONDS_PER_GAME_HOUR := 3.0

## 每小时的秒数（游戏内一天 = 24 小时）
var GAME_HOURS_PER_DAY := 24
var GAME_DAYS_PER_WEEK := 7
var GAME_DAYS_PER_MONTH := 30
var GAME_MONTHS_PER_YEAR := 12

## 速度倍率
var SPEED_1X := 1.0
var SPEED_2X := 2.0
var SPEED_6X := 6.0
var SPEED_96X := 96.0
var _speed_min := 1.0
var _speed_max := 96.0

## 当前游戏时间（总小时数，从 0 开始）
var _total_game_hours: float = 0.0

## 调试：暂停时研究员 emoji/移动 问题（需与 GameMainCleanupHelper.RESEARCHER_PAUSE_DEBUG 同步）
const RESEARCHER_PAUSE_DEBUG := false

## 是否正在流逝
var is_flowing: bool = true:
	set(v):
		is_flowing = v
		if RESEARCHER_PAUSE_DEBUG:
			print("[ResearcherPause] flowing_changed is_flowing=%s" % is_flowing)
			var conns: Array = flowing_changed.get_connections()
			print("[ResearcherPause] flowing_connections total=%d" % conns.size())
			for i in conns.size():
				var c: Dictionary = conns[i]
				var callable_obj: Callable = c.get("callable", Callable())
				var target: Object = callable_obj.get_object() if callable_obj.is_valid() else null
				var method_str: String = String(callable_obj.get_method()) if callable_obj.is_valid() else ""
				var path_str: String
				if target and target is Node:
					path_str = str(target.get_path())
				elif target:
					path_str = str(target)
				else:
					path_str = "null"
				var rid: int = -1
				var parent_rid: int = -1
				if target:
					if "researcher_id" in target:
						rid = int(target.get("researcher_id"))
					elif target is Node:
						var anchor: Node = target.get_parent()
						if anchor and anchor.get_parent() and "researcher_id" in anchor.get_parent():
							parent_rid = int(anchor.get_parent().get("researcher_id"))
				var rid_s: String = str(rid) if rid >= 0 else "n/a"
				var prid_s: String = str(parent_rid) if parent_rid >= 0 else "n/a"
				print("[ResearcherPause] conn[%d] path=%s method=%s r3d_id=%s emoji_parent_id=%s" % [
					i, path_str, method_str, rid_s, prid_s])
		flowing_changed.emit(is_flowing)
		if RESEARCHER_PAUSE_DEBUG:
			print("[ResearcherPause] emit_done")
		## tree.paused 仅在时间面板/读档/ESC 菜单处设置，不在此统一设置。
		## 清理/建设模式也会设 is_flowing=false 但需保持输入可用（房间选择、右键退出）。

## 当前倍速 (1.0 / 2.0 / 3.0)
var speed_multiplier: float = 1.0:
	set(v):
		speed_multiplier = clampf(v, _speed_min, _speed_max)
		speed_changed.emit(speed_multiplier)

## 信号：时间流逝状态变化
signal flowing_changed(is_flowing: bool)
## 信号：倍速变化
signal speed_changed(speed: float)
## 信号：时间更新（用于 UI 刷新）
signal time_updated()


func _ready() -> void:
	_apply_time_config()
	if GameValues and GameValues.has_signal("config_reloaded"):
		GameValues.config_reloaded.connect(_apply_time_config)


func _apply_time_config() -> void:
	if not GameValues:
		return
	if GameValues.has_method("ensure_loaded"):
		GameValues.ensure_loaded()
	REAL_SECONDS_PER_GAME_HOUR = float(GameValues.get_time_real_seconds_per_game_hour())
	GAME_HOURS_PER_DAY = int(GameValues.get_time_hours_per_day())
	GAME_DAYS_PER_WEEK = int(GameValues.get_time_days_per_week())
	GAME_DAYS_PER_MONTH = int(GameValues.get_time_days_per_month())
	GAME_MONTHS_PER_YEAR = int(GameValues.get_time_months_per_year())
	SPEED_1X = float(GameValues.get_time_speed_preset("x1"))
	SPEED_2X = float(GameValues.get_time_speed_preset("x2"))
	SPEED_6X = float(GameValues.get_time_speed_preset("x6"))
	SPEED_96X = float(GameValues.get_time_speed_preset("x96"))
	_speed_min = float(GameValues.get_time_speed_min())
	_speed_max = float(GameValues.get_time_speed_max())
	speed_multiplier = clampf(speed_multiplier, _speed_min, _speed_max)


func _process(delta: float) -> void:
	if not is_flowing:
		return
	# 每秒游戏内经过的小时数 = (1 / 6) * speed_multiplier
	# delta 为现实秒数
	var game_hours_delta: float = (delta / REAL_SECONDS_PER_GAME_HOUR) * speed_multiplier
	_total_game_hours += game_hours_delta
	time_updated.emit()


## 获取当前游戏时间（总小时数）
func get_total_hours() -> float:
	return _total_game_hours


## 设置游戏时间（供存档加载恢复）
func set_total_hours(hours: float) -> void:
	_total_game_hours = maxf(0.0, hours)
	time_updated.emit()


## 获取各时间单位
func get_hour() -> int:
	return int(floorf(_total_game_hours)) % GAME_HOURS_PER_DAY


func get_day() -> int:
	return int(floorf(_total_game_hours / GAME_HOURS_PER_DAY)) % GAME_DAYS_PER_MONTH


## 获取本周第几日（1～7），每周重置
func get_day_in_week() -> int:
	var total_days: int = int(floorf(_total_game_hours / GAME_HOURS_PER_DAY))
	return (total_days % GAME_DAYS_PER_WEEK) + 1


## 获取周数（累计总量，1 起始，为 UI 最高级单位；无月年后周数递增不重置）
func get_week() -> int:
	var total_days: float = _total_game_hours / float(GAME_HOURS_PER_DAY * GAME_DAYS_PER_WEEK)
	return int(floorf(total_days)) + 1  # 1 起始


func get_month() -> int:
	return int(floorf(_total_game_hours / (GAME_HOURS_PER_DAY * GAME_DAYS_PER_MONTH))) % GAME_MONTHS_PER_YEAR


func get_year() -> int:
	return int(floorf(_total_game_hours / (GAME_HOURS_PER_DAY * GAME_DAYS_PER_MONTH * GAME_MONTHS_PER_YEAR)))


## 格式化为可读字符串：12时，7日，35周（日为本周第几日 1～7 每周重置；周为累计）
func format_time() -> String:
	var h: int = get_hour()
	var d: int = get_day_in_week()  # 1～7，本周第几日
	var w: int = get_week()  # 累计周数，1 起始
	return tr("TIME_FORMAT") % [h, d, w]


## 简短格式，与 format_time 相同：xx时 第XX天 第XX周
func format_time_short() -> String:
	return format_time()


## 设置倍速
func set_speed_1x() -> void:
	speed_multiplier = SPEED_1X


func set_speed_2x() -> void:
	speed_multiplier = SPEED_2X


func set_speed_6x() -> void:
	speed_multiplier = SPEED_6X


func set_speed_96x() -> void:
	speed_multiplier = SPEED_96X


## 播放/暂停切换
func toggle_flow() -> void:
	is_flowing = not is_flowing


## 重置时间（调试用）
func reset_time() -> void:
	_total_game_hours = 0.0
	time_updated.emit()

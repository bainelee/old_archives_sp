extends Node
## 游戏时间流逝系统（Autoload: GameTime）
## 比例：现实 6 秒 = 游戏内 1 小时
## 时间单位：小时、天、周、月、年

## 现实 3 秒 = 1 游戏小时
const REAL_SECONDS_PER_GAME_HOUR := 3.0

## 每小时的秒数（游戏内一天 = 24 小时）
const GAME_HOURS_PER_DAY := 24
const GAME_DAYS_PER_WEEK := 7
const GAME_DAYS_PER_MONTH := 30
const GAME_MONTHS_PER_YEAR := 12

## 速度倍率
const SPEED_1X := 1.0
const SPEED_2X := 2.0
const SPEED_6X := 6.0
const SPEED_96X := 96.0

## 当前游戏时间（总小时数，从 0 开始）
var _total_game_hours: float = 0.0

## 是否正在流逝
var is_flowing: bool = true:
	set(v):
		is_flowing = v
		flowing_changed.emit(is_flowing)

## 当前倍速 (1.0 / 2.0 / 3.0)
var speed_multiplier: float = 1.0:
	set(v):
		speed_multiplier = clampf(v, 1.0, 96.0)
		speed_changed.emit(speed_multiplier)

## 信号：时间流逝状态变化
signal flowing_changed(is_flowing: bool)
## 信号：倍速变化
signal speed_changed(speed: float)
## 信号：时间更新（用于 UI 刷新）
signal time_updated()


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

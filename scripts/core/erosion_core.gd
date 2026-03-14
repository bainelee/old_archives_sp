extends Node
## 侵蚀数据源（Autoload: ErosionCore）
## 提供当前侵蚀等级与未来 3 个月的侵蚀预测
## 暂时使用程序化模拟数据，后续可接入真实游戏逻辑

## 侵蚀等级数值（名词解释）
## +1 隐性 | 0 轻度 | -2 显性 | -4 涌动阴霾 | -8 莱卡昂的暗影
const EROSION_LATENT := 1
const EROSION_MILD := 0
const EROSION_VISIBLE := -2
const EROSION_SURGE := -4
const EROSION_LYCAON := -8

## 所有侵蚀等级列表（用于随机选取）
const _EROSION_VALUES := [EROSION_LATENT, EROSION_MILD, EROSION_VISIBLE, EROSION_SURGE, EROSION_LYCAON]

## 侵蚀变化类型（用于 UI 着色，保留兼容）
enum ChangeType {
	DESCENT,      ## 下降：负值变小，侵蚀减轻
	RISE,         ## 上升：负值变大，侵蚀加重
	RISE_HEAVY,   ## 大幅度上升：负值变得很大
	LYCAON_HAZE   ## 莱卡昂的阴霾：负值极大
}

## 3 个月 = 84 天（4 周/月 × 3 月）= 2016 游戏小时
const FORECAST_DAYS := 84
const FORECAST_HOURS := 2016  ## 84 天 * 24 小时
## 侵蚀变化周期：14 天可变化一次（每级持续 2 周）
const HOURS_PER_LEVEL := 336  ## 14 天 * 24 小时

## 来自神秘侵蚀的数值（从程序化预测读取当前游戏时刻，随时间变化）
var raw_mystery_erosion: int = EROSION_MILD:
	set(v):
		raw_mystery_erosion = v
		_recompute_current()

## 来自文明的庇佑的数值（正值，如 +4；当前未开发，默认 0 不显示）
var shelter_bonus: int = 0:
	set(v):
		shelter_bonus = v
		_recompute_current()

## 当前侵蚀等级 = 神秘侵蚀 + 文明的庇佑
var current_erosion: int = EROSION_MILD

signal erosion_changed(new_value: int)


func _recompute_current() -> void:
	var new_val := raw_mystery_erosion + shelter_bonus
	## 仅限制下限为最差侵蚀；上限不限制，以支持庇护叠加至妥善/完美（2~4、≥5）
	new_val = maxi(new_val, EROSION_LYCAON)
	if current_erosion != new_val:
		current_erosion = new_val
		erosion_changed.emit(new_val)


func _ready() -> void:
	if GameTime:
		GameTime.time_updated.connect(_on_time_updated)
		_on_time_updated()  # 同步初始值
	else:
		_recompute_current()


func _on_time_updated() -> void:
	# 从程序化预测同步当前时刻的神秘侵蚀值
	if GameTime:
		var h := GameTime.get_total_hours()
		raw_mystery_erosion = get_erosion_at_game_hour(h)
		_process_forecast_handles(h)


## 获取庇护状态名称（名词解释：绝境/暴露/薄弱/妥善/完美）
func get_shelter_status_name(value: int) -> String:
	if value <= -5:
		return tr("SHELTER_EXTREME")
	elif value >= -4 and value <= -2:
		return tr("SHELTER_EXPOSED")
	elif value >= -1 and value <= 1:
		return tr("SHELTER_WEAK")
	elif value >= 2 and value <= 4:
		return tr("SHELTER_SAFE")
	elif value >= 5:
		return tr("SHELTER_PERFECT")
	else:
		return tr("UNKNOWN")


## 获取侵蚀数据来源的格式化文本（用于悬停提示）
## 显示：当前庇护状态；逐个显示影响侵蚀的数值来源（如有）
func get_erosion_source_text() -> String:
	var lines: PackedStringArray = []
	var status := get_shelter_status_name(current_erosion)
	lines.append(tr("SHELTER_STATUS_LINE") % status)
	if shelter_bonus != 0:
		lines.append(tr("SHELTER_BONUS_LINE") % shelter_bonus)
	if raw_mystery_erosion != 0:
		var name_str := _get_mystery_erosion_name(raw_mystery_erosion)
		lines.append(tr("EROSION_SOURCE_LINE") % [raw_mystery_erosion, name_str])
	return "\n".join(lines)


func _get_mystery_erosion_name(value: int) -> String:
	match value:
		EROSION_LATENT: return tr("EROSION_LATENT")
		EROSION_MILD: return tr("EROSION_MILD")
		EROSION_VISIBLE: return tr("EROSION_VISIBLE")
		EROSION_SURGE: return tr("EROSION_SURGE")
		EROSION_LYCAON: return tr("EROSION_LYCAON")
		_: return tr("EROSION_MYSTERY")


## 获取侵蚀等级完整名称（用于周期条悬停，如「显性侵蚀」）
func get_erosion_name_full(value: int) -> String:
	return _get_mystery_erosion_name(value)


## 获取侵蚀等级显示名称
func get_erosion_name(value: int) -> String:
	match value:
		EROSION_LATENT: return tr("EROSION_LATENT_SHORT")
		EROSION_MILD: return tr("EROSION_MILD_SHORT")
		EROSION_VISIBLE: return tr("EROSION_VISIBLE_SHORT")
		EROSION_SURGE: return tr("EROSION_SURGE")
		EROSION_LYCAON: return tr("EROSION_LYCAON")
		_: return tr("UNKNOWN")


## 根据绝对游戏小时获取侵蚀值
## 侵蚀按周期可变化（HOURS_PER_LEVEL），使用确定性的随机序列
func get_erosion_at_game_hour(game_hour: float) -> int:
	var phase := int(floor(game_hour / float(HOURS_PER_LEVEL)))
	var seed_val := phase * 127 + 31  # 确定性种子，相邻相位不同
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var idx := rng.randi_range(0, _EROSION_VALUES.size() - 1)
	return _EROSION_VALUES[idx]


## 获取未来 N 小时内某时刻的侵蚀值（兼容旧接口）
func get_forecast_at_hours(hours_from_now: float) -> Dictionary:
	var value := get_erosion_at_game_hour(hours_from_now)
	return {"value": value}


## 生成未来 84 天的侵蚀预测序列（基于绝对游戏时间起点）
## start_game_hour: 预测的起始游戏小时（用于保证时间流逝时序列连续不重置）
## 每个元素为 {"value": int}，侵蚀最快 7 天可变化
func get_forecast_segments(segment_count: int, start_game_hour: float = 0.0) -> Array:
	var result: Array = []
	var hours_per_segment := float(FORECAST_HOURS) / float(segment_count)
	for i in segment_count:
		var game_hour := start_game_hour + hours_per_segment * (float(i) + 0.5)
		var value := get_erosion_at_game_hour(game_hour)
		result.append({"value": value})
	return result


## 获取未来 84 天内的侵蚀值序列（按侵蚀变化周期；84天/7天=12 周期，含当前共 13 点）
## 返回 [v0, v1, ... v12]，对应天 0, 7, 14, ..., 84 的侵蚀值
func get_erosion_schedule_for_forecast(start_game_hour: float = 0.0) -> Array:
	var result: Array = []
	var days_per_cycle: float = float(HOURS_PER_LEVEL) / 24.0 if HOURS_PER_LEVEL > 0 else 14.0
	var cycle_count: int = mini(int(ceil(float(FORECAST_DAYS) / days_per_cycle)) + 1, 13)
	for c in cycle_count:
		var hour_at_cycle_start := start_game_hour + float(c) * float(HOURS_PER_LEVEL)
		var val: int = get_erosion_at_game_hour(hour_at_cycle_start)
		result.append(val)
	return result


## 侵蚀数值比较：a 比 b 更严重（更负）返回 true
static func is_worse_than(a: int, b: int) -> bool:
	return a < b


## ForecastWarning handle 池（最多 12 个）
## 每个元素: {days_from_now: int, level: int, sign_type: int, pixel_offset: float}
## sign_type: 0=无 1=红(恶化) 2=绿(好转)
var _forecast_handles: Array = []
var _last_processed_week: int = -1
var _last_processed_day: int = -1


func get_forecast_handles() -> Array:
	return _forecast_handles.duplicate()


func get_forecast_handles_for_save() -> Array:
	var out: Array = []
	for h in _forecast_handles:
		if h is Dictionary:
			out.append({
				"days_from_now": int(h.get("days_from_now", 0)),
				"level": int(h.get("level", 1)),
				"sign_type": int(h.get("sign_type", 0)),
				"pixel_offset": float(h.get("pixel_offset", 0.0)),
			})
	return out


func load_forecast_handles(handles_data: Array, total_game_hours: float = 0.0) -> void:
	_forecast_handles.clear()
	for h in handles_data:
		if h is Dictionary:
			_forecast_handles.append({
				"days_from_now": int(h.get("days_from_now", 0)),
				"level": int(h.get("level", 1)),
				"sign_type": int(h.get("sign_type", 0)),
				"pixel_offset": float(h.get("pixel_offset", 0.0)),
			})
	if GameTime and total_game_hours >= 0:
		var hours_per_day: float = float(GameTime.GAME_HOURS_PER_DAY) if GameTime.GAME_HOURS_PER_DAY > 0 else 24.0
		_last_processed_day = int(floor(total_game_hours / hours_per_day))
		## 有 handle 数据则从存档恢复；无则保持 -1 以便首次运行时标记当前周期
		if handles_data.is_empty():
			_last_processed_week = -1
		else:
			_last_processed_week = int(floor(total_game_hours / float(HOURS_PER_LEVEL)))


## 侵蚀数值 → level 0–4（绿/蓝/橙/紫/红）
const VALUE_TO_LEVEL := {1: 0, 0: 1, -2: 2, -4: 3, -8: 4}


func _process_forecast_handles(total_hours: float) -> void:
	if not GameTime:
		return
	var hours_per_day: float = float(GameTime.GAME_HOURS_PER_DAY) if GameTime.GAME_HOURS_PER_DAY > 0 else 24.0
	## 使用侵蚀变化周期（当前 7 天），不固定为日历周
	var hours_per_cycle: float = float(HOURS_PER_LEVEL)
	var days_per_cycle: int = int(hours_per_cycle / hours_per_day)
	if days_per_cycle <= 0:
		days_per_cycle = 14
	var current_day: int = int(floor(total_hours / hours_per_day))
	var current_cycle: int = int(floor(total_hours / hours_per_cycle))

	# 每日：所有 handle 右移 3px
	if _last_processed_day >= 0 and current_day > _last_processed_day:
		var i := _forecast_handles.size() - 1
		while i >= 0:
			var h: Dictionary = _forecast_handles[i]
			var doff: float = float(h.get("days_from_now", 0))
			var poff: float = float(h.get("pixel_offset", 0.0))
			poff += 3.0 * float(current_day - _last_processed_day)
			h["pixel_offset"] = poff
			var pixel_position: float = (84.0 - doff) * 3.0 + poff
			if pixel_position >= 252.0:
				_forecast_handles.remove_at(i)
			i -= 1
	_last_processed_day = current_day

	# 每周期：进入新周期时，检查 84 天窗口远端是否有侵蚀变化，如有则新增 handle
	if _last_processed_week >= 0 and current_cycle > _last_processed_week:
		var cycles_in_window: int = int(floor(float(FORECAST_DAYS) / float(days_per_cycle))) if days_per_cycle > 0 else 6
		var far_cycle: int = current_cycle + cycles_in_window  ## 第 84 天对应的周期
		var prev_at_far: int = get_erosion_at_game_hour(float(far_cycle - 1) * hours_per_cycle)
		var this_at_far: int = get_erosion_at_game_hour(float(far_cycle) * hours_per_cycle)
		if this_at_far != prev_at_far and _forecast_handles.size() < 12:
			var level: int = VALUE_TO_LEVEL.get(this_at_far, 1)
			var sign_type: int = 1 if is_worse_than(this_at_far, prev_at_far) else 2
			_forecast_handles.append({
				"days_from_now": 84,
				"level": level,
				"sign_type": sign_type,
				"pixel_offset": 0.0,
			})
		_last_processed_week = current_cycle
	elif _last_processed_week < 0:
		# 新游戏开始时：按侵蚀变化周期，填满未来 84 天内的侵蚀变化点
		var schedule: Array = get_erosion_schedule_for_forecast(total_hours)
		for i in range(1, schedule.size()):
			if schedule[i] != schedule[i - 1] and _forecast_handles.size() < 12:
				var days: int = i * days_per_cycle
				days = mini(days, 84)
				var v: int = schedule[i]
				var prev_val: int = schedule[i - 1]
				var level: int = VALUE_TO_LEVEL.get(v, 1)
				var sign_type: int = 1 if is_worse_than(v, prev_val) else 2
				_forecast_handles.append({
					"days_from_now": days,
					"level": level,
					"sign_type": sign_type,
					"pixel_offset": 0.0,
				})
		## 预填已覆盖未来 84 天；后续每经过一个侵蚀变化周期，由上方块检测并添加新 handle（如有变化）
		_last_processed_week = current_cycle

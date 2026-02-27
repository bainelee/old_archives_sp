extends Node
## 研究员侵蚀核心（Autoload: PersonnelErosionCore）
## 实现侵蚀风险、被侵蚀状态、死亡、治愈、灾厄值等逻辑
## 详见 docs/design/2-gameplay/07-researcher-erosion.md

## 庇护等级对应的每日侵蚀概率（%）
const EROSION_PROB_EXTREME := 80  ## 绝境 ≤-5
const EROSION_PROB_EXPOSED := 50  ## 暴露 -4~-2
const EROSION_PROB_WEAK := 20     ## 薄弱 -1~1

## 7 天内超过此侵蚀风险数则被侵蚀
const EROSION_RISK_THRESHOLD := 5

## 治愈周期（天）
const CURE_INTERVAL_DAYS := 3
## 治愈概率
const CURE_PROB_ADEQUATE := 30   ## 妥善 2~4
const CURE_PROB_PERFECT := 80    ## 完美 ≥5

## 治愈后免疫天数
const IMMUNITY_DAYS := 7

## 死亡概率曲线：第 16 周 50%，第 20 周 100%
## P(day) = min(1, (day/140)^3.1)，约满足 (112/140)^3.1≈0.5
const DEATH_DAYS_HALF := 112   ## 50% 死亡
const DEATH_DAYS_FULL := 140   ## 100% 死亡
const DEATH_CURVE_EXP := 3.1

## 每个被侵蚀研究员每小时增加的灾厄值
const CALAMITY_PER_ERODED_PER_HOUR := 1
## 灾厄值上限
const CALAMITY_MAX := 30000

## 每人每天消耗认知
const COGNITION_PER_RESEARCHER_PER_DAY := 24
## 认知危机标记上限
const COGNITION_CRISIS_MAX := 3
## 认知失能研究员每天增加的灾厄值
const CALAMITY_PER_IMPAIRED_PER_DAY := 10

signal personnel_updated()
signal calamity_updated(new_value: float)

## 研究员记录：{ id, erosion_risk, is_eroded, eroded_days, prev_room_id, immunity_days, cognition_crisis }
## 每个研究员为独立个体，拥有唯一 id；按 id 顺序依次消耗认知
var _cognition_getter: Callable = func() -> int: return 0
var _cognition_setter: Callable = func(_amt: int) -> void: pass

## 研究员记录
var _researchers: Array[Dictionary] = []
var _calamity_value: float = 0.0
var _investigator_count: int = 0
var _last_game_day: int = -1
var _last_game_hour_floor: int = -1
var _next_researcher_id: int = 0


func _ready() -> void:
	if GameTime:
		GameTime.time_updated.connect(_on_time_updated)


## 从 personnel 字典初始化（researcher 总数，eroded 数量）
## 加载存档时由 GameMain 调用
func initialize_from_personnel(personnel: Dictionary, _total_game_hours: float = 0.0) -> void:
	var total: int = int(personnel.get("researcher", 0))
	var eroded: int = int(personnel.get("eroded", 0))
	eroded = mini(eroded, total)
	var working: int = total - eroded
	_researchers.clear()
	_next_researcher_id = 0
	for i in working:
		_researchers.append(_make_working_researcher())
	for i in eroded:
		_researchers.append(_make_eroded_researcher(0))
	_last_game_day = -1
	_last_game_hour_floor = -1
	_calamity_value = 0.0
	_investigator_count = int(personnel.get("investigator", 0))
	personnel_updated.emit()
	calamity_updated.emit(_calamity_value)


func _make_working_researcher() -> Dictionary:
	var id_val: int = _next_researcher_id
	_next_researcher_id += 1
	return {
		"id": id_val,
		"erosion_risk": 0,
		"is_eroded": false,
		"eroded_days": 0,
		"prev_room_id": "",
		"immunity_days": 0,
		"cognition_crisis": 0,
	}


func _make_eroded_researcher(eroded_days: int) -> Dictionary:
	var r: Dictionary = _make_working_researcher()
	r["is_eroded"] = true
	r["eroded_days"] = eroded_days
	return r


func get_personnel() -> Dictionary:
	var total: int = _researchers.size()
	var eroded: int = 0
	for r in _researchers:
		if r.get("is_eroded", false):
			eroded += 1
	return {
		"researcher": total,
		"labor": 0,
		"eroded": eroded,
		"investigator": _investigator_count,
	}


func get_calamity_value() -> float:
	return _calamity_value


func get_calamity_max() -> int:
	return CALAMITY_MAX


## 获取当前庇护状态对应的侵蚀概率（0 表示无判定）
func _get_erosion_probability() -> int:
	if not ErosionCore:
		return 0
	var val: int = ErosionCore.current_erosion
	if val <= -5:
		return EROSION_PROB_EXTREME
	elif val >= -4 and val <= -2:
		return EROSION_PROB_EXPOSED
	elif val >= -1 and val <= 1:
		return EROSION_PROB_WEAK
	return 0


## 获取宿舍庇护等级（当前简化：使用全局 current_erosion）
## 妥善 2~4，完美 ≥5，否则不满足治愈条件
func _get_dorm_shelter_level() -> int:
	if not ErosionCore:
		return -10
	return ErosionCore.current_erosion


##  death probability at given eroded_days
func _death_probability(eroded_days: int) -> float:
	if eroded_days <= 0:
		return 0.0
	var ratio: float = float(eroded_days) / float(DEATH_DAYS_FULL)
	return clampf(pow(ratio, DEATH_CURVE_EXP), 0.0, 1.0)


func _on_time_updated() -> void:
	if not GameTime:
		return
	var hours: float = GameTime.get_total_hours()
	var day_floor: int = int(floor(hours / 24.0))
	var hour_floor: int = int(floor(hours))
	# 每小时：灾厄值
	if hour_floor > _last_game_hour_floor and _last_game_hour_floor >= 0:
		var hours_passed: int = hour_floor - _last_game_hour_floor
		var eroded_count: int = 0
		for r in _researchers:
			if r.get("is_eroded", false):
				eroded_count += 1
		_calamity_value = minf(_calamity_value + eroded_count * CALAMITY_PER_ERODED_PER_HOUR * hours_passed, float(CALAMITY_MAX))
		calamity_updated.emit(_calamity_value)
	_last_game_hour_floor = hour_floor
	# 每天结束：侵蚀判定、死亡、治愈、7 日结算
	if day_floor > _last_game_day and _last_game_day >= 0:
		var days_passed: int = day_floor - _last_game_day
		for d in days_passed:
			_run_daily_logic(_last_game_day + d + 1)
		personnel_updated.emit()
		calamity_updated.emit(_calamity_value)
	_last_game_day = day_floor


func _run_daily_logic(day: int) -> void:
	# 0. 认知消耗（按 id 顺序，每人 24 认知；不足则 +1 认知危机，成功则 -1 认知危机）
	var cognition_left: int = _cognition_getter.call() if _cognition_getter.is_valid() else 0
	var sorted_by_id: Array[Dictionary] = _researchers.duplicate()
	sorted_by_id.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.get("id", 0) < b.get("id", 0))
	for r in sorted_by_id:
		if cognition_left >= COGNITION_PER_RESEARCHER_PER_DAY:
			cognition_left -= COGNITION_PER_RESEARCHER_PER_DAY
			var crisis: int = int(r.get("cognition_crisis", 0))
			if crisis > 0:
				r["cognition_crisis"] = crisis - 1
		else:
			var crisis: int = int(r.get("cognition_crisis", 0))
			r["cognition_crisis"] = mini(crisis + 1, COGNITION_CRISIS_MAX)
	if _cognition_setter.is_valid():
		_cognition_setter.call(cognition_left)
	# 0b. 认知失能研究员每天 +10 灾厄
	var impaired_count: int = 0
	for r in _researchers:
		if int(r.get("cognition_crisis", 0)) >= COGNITION_CRISIS_MAX:
			impaired_count += 1
	_calamity_value = minf(_calamity_value + impaired_count * CALAMITY_PER_IMPAIRED_PER_DAY, float(CALAMITY_MAX))
	calamity_updated.emit(_calamity_value)
	# 1. 死亡判定（先于治愈，死者不再有机会治愈）
	var to_remove: Array[int] = []
	for i in _researchers.size():
		var r: Dictionary = _researchers[i]
		if not r.get("is_eroded", false):
			continue
		var eroded_days: int = int(r.get("eroded_days", 0))
		var prob: float = _death_probability(eroded_days)
		if prob > 0 and randf() < prob:
			to_remove.append(i)
	for i in to_remove.size() - 1:
		_remove_researcher(to_remove[to_remove.size() - 1 - i])
	if to_remove.size() > 0:
		_remove_researcher(to_remove[0])
	# 2. 治愈判定（每 3 天）
	var dorm_level: int = _get_dorm_shelter_level()
	if dorm_level >= 2:
		var cure_prob: int = CURE_PROB_ADEQUATE if dorm_level < 5 else CURE_PROB_PERFECT
		for r in _researchers:
			if not r.get("is_eroded", false):
				continue
			var eroded_days: int = int(r.get("eroded_days", 0))
			if eroded_days > 0 and eroded_days % CURE_INTERVAL_DAYS == 0:
				if randi_range(1, 100) <= cure_prob:
					r["is_eroded"] = false
					r["eroded_days"] = 0
					r["erosion_risk"] = 0
					r["immunity_days"] = IMMUNITY_DAYS
	# 3. 增加被侵蚀者的 eroded_days
	for r in _researchers:
		if r.get("is_eroded", false):
			r["eroded_days"] = int(r.get("eroded_days", 0)) + 1
		elif r.get("immunity_days", 0) > 0:
			r["immunity_days"] = int(r.get("immunity_days", 0)) - 1
	# 4. 侵蚀风险判定（对非侵蚀、非免疫的工作者）
	var erosion_prob: int = _get_erosion_probability()
	if erosion_prob > 0:
		for r in _researchers:
			if r.get("is_eroded", false):
				continue
			if r.get("immunity_days", 0) > 0:
				continue
			if randi_range(1, 100) <= erosion_prob:
				r["erosion_risk"] = int(r.get("erosion_risk", 0)) + 1
	# 5. 每 7 天结束时结算侵蚀风险（day 8/15/22... = 第 7/14/21 天刚结束）
	if day >= 8 and (day % 7) == 1:
		for r in _researchers:
			if r.get("is_eroded", false):
				continue
			if int(r.get("erosion_risk", 0)) > EROSION_RISK_THRESHOLD:
				r["is_eroded"] = true
				r["eroded_days"] = 0
				r["erosion_risk"] = 0


func _remove_researcher(idx: int) -> void:
	_researchers.remove_at(idx)


## 序列化供存档
func to_save_dict() -> Dictionary:
	var researchers_data: Array = []
	for r in _researchers:
		researchers_data.append({
			"id": r.get("id", 0),
			"erosion_risk": r.get("erosion_risk", 0),
			"is_eroded": r.get("is_eroded", false),
			"eroded_days": r.get("eroded_days", 0),
			"prev_room_id": r.get("prev_room_id", ""),
			"immunity_days": r.get("immunity_days", 0),
			"cognition_crisis": r.get("cognition_crisis", 0),
		})
	return {
		"researchers": researchers_data,
		"calamity": _calamity_value,
		"next_id": _next_researcher_id,
		"investigator": _investigator_count,
	}


## 设置调查员数量（人员变化时由外部调用，当前侵蚀系统仅管理研究员）
func set_investigator_count(count: int) -> void:
	_investigator_count = maxi(0, count)


## 注册认知因子来源（供每日消耗时读取与扣除）
## getter: () -> int，setter: (int) -> void
func register_cognition_provider(getter: Callable, setter: Callable) -> void:
	_cognition_getter = getter
	_cognition_setter = setter


## 从存档恢复
func load_from_save_dict(d: Dictionary, personnel: Dictionary = {}) -> void:
	_researchers.clear()
	var next_id: int = 0
	var arr: Array = d.get("researchers", []) as Array
	for item in arr:
		if item is Dictionary:
			var r: Dictionary = (item as Dictionary).duplicate(true)
			if not r.has("id"):
				r["id"] = next_id
				next_id += 1
			if not r.has("cognition_crisis"):
				r["cognition_crisis"] = 0
			_researchers.append(r)
	var max_id: int = 0
	for r in _researchers:
		max_id = maxi(max_id, int(r.get("id", 0)))
	_next_researcher_id = int(d.get("next_id", maxi(max_id + 1, next_id)))
	_calamity_value = clampf(float(d.get("calamity", 0)), 0.0, float(CALAMITY_MAX))
	_investigator_count = int(d.get("investigator", personnel.get("investigator", 0)))
	_last_game_day = -1
	_last_game_hour_floor = -1
	personnel_updated.emit()
	calamity_updated.emit(_calamity_value)


## 供新游戏使用：在 initialize 后同步 last 为当前，避免首帧触发
func sync_last_tick() -> void:
	if GameTime:
		var h: float = GameTime.get_total_hours()
		_last_game_day = int(floor(h / 24.0))
		_last_game_hour_floor = int(floor(h))

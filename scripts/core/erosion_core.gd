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

## 3 个月 = 90 天 = 2160 游戏小时
const FORECAST_HOURS := 2160
## 每种侵蚀等级持续 2 周
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


## 获取庇护状态名称（名词解释：绝境/暴露/薄弱/妥善/完美）
func get_shelter_status_name(value: int) -> String:
	if value <= -5:
		return "绝境"
	elif value >= -4 and value <= -2:
		return "暴露"
	elif value >= -1 and value <= 1:
		return "薄弱"
	elif value >= 2 and value <= 4:
		return "妥善"
	elif value >= 5:
		return "完美"
	else:
		return "未知"


## 获取侵蚀数据来源的格式化文本（用于悬停提示）
## 显示：当前庇护状态；逐个显示影响侵蚀的数值来源（如有）
func get_erosion_source_text() -> String:
	var lines: PackedStringArray = []
	# 1. 当前的庇护状态
	var status := get_shelter_status_name(current_erosion)
	lines.append("当前的庇护状态：%s" % status)
	# 2. 当前影响侵蚀的数值信息（逐个），正值来自文明的庇佑，负值来自神秘侵蚀
	if shelter_bonus != 0:
		lines.append("+%d 来自 文明的庇佑" % shelter_bonus)
	if raw_mystery_erosion != 0:
		var name_str := _get_mystery_erosion_name(raw_mystery_erosion)
		lines.append("%d 来自 %s" % [raw_mystery_erosion, name_str])
	return "\n".join(lines)


func _get_mystery_erosion_name(value: int) -> String:
	match value:
		EROSION_LATENT: return "隐性侵蚀"
		EROSION_MILD: return "轻度侵蚀"
		EROSION_VISIBLE: return "显性侵蚀"
		EROSION_SURGE: return "涌动阴霾"
		EROSION_LYCAON: return "莱卡昂的暗影"
		_: return "神秘侵蚀"


## 获取侵蚀等级完整名称（用于周期条悬停，如「显性侵蚀」）
func get_erosion_name_full(value: int) -> String:
	return _get_mystery_erosion_name(value)


## 获取侵蚀等级显示名称
func get_erosion_name(value: int) -> String:
	match value:
		EROSION_LATENT: return "隐性"
		EROSION_MILD: return "轻度"
		EROSION_VISIBLE: return "显性"
		EROSION_SURGE: return "涌动阴霾"
		EROSION_LYCAON: return "莱卡昂的暗影"
		_: return "未知"


## 根据绝对游戏小时获取侵蚀值
## 每种侵蚀等级持续 2 周（336 小时），使用确定性的随机序列
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


## 生成未来 3 个月的侵蚀预测序列（基于绝对游戏时间起点）
## start_game_hour: 预测的起始游戏小时（用于保证时间流逝时序列连续不重置）
## 每个元素为 {"value": int}，每种等级持续 2 周，随机选取不同等级
func get_forecast_segments(segment_count: int, start_game_hour: float = 0.0) -> Array:
	var result: Array = []
	var hours_per_segment := float(FORECAST_HOURS) / float(segment_count)
	for i in segment_count:
		var game_hour := start_game_hour + hours_per_segment * (float(i) + 0.5)
		var value := get_erosion_at_game_hour(game_hour)
		result.append({"value": value})
	return result

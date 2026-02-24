extends Control
## 侵蚀变化周期长条 - 显示未来 3 个月的侵蚀预测
## 图元颜色对应侵蚀数值（名词解释）：白色 +1 隐性、翠绿 0 轻度、橙黄 -2 显性、赤红 -4 涌动阴霾、深紫 -8 莱卡昂的暗影
## 随时间流逝，图元向左滚动
## 悬停显示：距离现在Xd 等级名 数值

const SEGMENT_COUNT := 90  ## 3 个月 ≈ 90 天，每格 1 天
const FORECAST_HOURS := 2160  ## 90 天 * 24 小时
const HOURS_PER_DAY := 24

## 侵蚀数值对应颜色（名词解释）
const COLOR_LATENT := Color(0.95, 0.95, 0.95, 0.95)      ## +1 隐性侵蚀：白色
const COLOR_MILD := Color(0.3, 0.75, 0.5, 0.95)         ## 0 轻度侵蚀：翠绿
const COLOR_VISIBLE := Color(0.95, 0.75, 0.3, 0.95)     ## -2 显性侵蚀：橙黄
const COLOR_SURGE := Color(0.9, 0.35, 0.2, 0.95)        ## -4 涌动阴霾：赤红
const COLOR_LYCAON := Color(0.35, 0.15, 0.45, 0.95)    ## -8 莱卡昂的暗影：深紫

signal segment_hovered(days_from_now: int, erosion_value: int)
signal segment_hover_ended

var _segments: Array = []
var _scroll_offset: float = 0.0  ## 像素偏移（正=向左滚动）
var _last_total_hours: float = -1.0
var _forecast_start_hours: float = 0.0  ## 当前视图所代表的起始游戏小时（保证滚动时序列连续）
var _segment_width: float = 4.0  ## 每个图元的视觉宽度
var _hover_active: bool = false
var _last_hover_days: int = -1
var _last_hover_value: int = 0


func _ready() -> void:
	if GameTime:
		_forecast_start_hours = GameTime.get_total_hours()
		GameTime.time_updated.connect(_on_time_updated)
	_refresh_segments()


func _on_time_updated() -> void:
	_update_scroll()
	queue_redraw()


func _process(_delta: float) -> void:
	_update_hover()


func _update_hover() -> void:
	if _segments.is_empty():
		if _hover_active:
			_hover_active = false
			segment_hover_ended.emit()
		return
	var mp := get_local_mouse_position()
	var bar_w := size.x
	var bar_h := size.y
	if bar_w <= 0 or bar_h <= 0 or mp.x < 0 or mp.x >= bar_w or mp.y < 0 or mp.y >= bar_h:
		if _hover_active:
			_hover_active = false
			_last_hover_days = -1
			segment_hover_ended.emit()
		return
	var seg_w := bar_w / float(SEGMENT_COUNT)
	var seg_idx := int((mp.x + _scroll_offset) / seg_w)
	if seg_idx < 0 or seg_idx >= _segments.size():
		if _hover_active:
			_hover_active = false
			_last_hover_days = -1
			segment_hover_ended.emit()
		return
	var seg := _segments[seg_idx] as Dictionary
	var value: int = seg.get("value", ErosionCore.EROSION_MILD)
	var hours_per_seg := float(FORECAST_HOURS) / float(SEGMENT_COUNT)
	var seg_game_hour := _forecast_start_hours + hours_per_seg * (float(seg_idx) + 0.5)
	var days := int(floor(maxf(0, seg_game_hour - GameTime.get_total_hours()) / float(HOURS_PER_DAY))) if GameTime else seg_idx
	_hover_active = true
	if days != _last_hover_days or value != _last_hover_value:
		_last_hover_days = days
		_last_hover_value = value
		segment_hovered.emit(days, value)


func _update_scroll() -> void:
	if not GameTime:
		return
	var total := GameTime.get_total_hours()
	if _last_total_hours < 0:
		_last_total_hours = total
		return
	var delta := total - _last_total_hours
	_last_total_hours = total
	var bar_w := size.x
	if bar_w <= 0:
		return
	var seg_w := bar_w / float(SEGMENT_COUNT)
	var pixels_per_hour := bar_w / float(FORECAST_HOURS)
	_scroll_offset += delta * pixels_per_hour
	# 每滚动一个分段宽度，将起始小时前移，刷新预测数据（序列连续不重置）
	var hours_per_seg := FORECAST_HOURS / float(SEGMENT_COUNT)
	while _scroll_offset >= seg_w:
		_scroll_offset -= seg_w
		_forecast_start_hours += hours_per_seg
		_refresh_segments()


func _refresh_segments() -> void:
	if not ErosionCore:
		return
	# 基于绝对游戏时间生成，start = 当前已滚动掉的起始小时
	_segments = ErosionCore.get_forecast_segments(SEGMENT_COUNT, _forecast_start_hours)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_segment_width = maxf(2.0, size.x / float(SEGMENT_COUNT))
		queue_redraw()


func _get_color_for_value(value: int) -> Color:
	match value:
		ErosionCore.EROSION_LATENT: return COLOR_LATENT
		ErosionCore.EROSION_MILD: return COLOR_MILD
		ErosionCore.EROSION_VISIBLE: return COLOR_VISIBLE
		ErosionCore.EROSION_SURGE: return COLOR_SURGE
		ErosionCore.EROSION_LYCAON: return COLOR_LYCAON
	return Color.GRAY


func _draw() -> void:
	if _segments.is_empty():
		_refresh_segments()
	var bar_h := size.y
	var bar_w := size.x
	if bar_w <= 0 or bar_h <= 0:
		return
	var seg_w := bar_w / float(SEGMENT_COUNT)
	var offset_x := -_scroll_offset
	for i in _segments.size():
		var seg := _segments[i] as Dictionary
		var value: int = seg.get("value", ErosionCore.EROSION_MILD)
		var col := _get_color_for_value(value)
		var x := offset_x + i * seg_w
		if x + seg_w < 0:
			continue
		if x > bar_w:
			break
		var rect := Rect2(x, 0, maxf(1.0, seg_w - 1), bar_h)
		draw_rect(rect, col)
		# 图元内加一点高光区分（仅在足够大时）
		if seg_w > 4:
			draw_rect(Rect2(x + 1, 1, seg_w - 3, bar_h - 2), col.lightened(0.15))

@tool
class_name DetailStorageProgressBar
extends Control

## 仅用于详细信息面板的储存进度条
## 与 topbar 用的 ResourceProgressBar 分离：总高 20px，边框 2px，内部填充高 16px
## 按 Figma storage_progress_bar (67:453) / storage_progress_bar_back (90:52) 同步

const MARGIN := 2.0  ## 上下左右各 2px，内部 16px 高

@export var current_value: float = 50000.0:
	set(v):
		current_value = maxf(0.0, v)
		_update_fill()

@export var max_value: float = 55000.0:
	set(v):
		max_value = maxf(0.001, v)
		_update_fill()

## 填充色，Figma #fd9729
@export var fill_color: Color = Color(0.992, 0.592, 0.161, 1.0):
	set(v):
		fill_color = v
		_update_fill()

var _back: TextureRect
var _fill_clip: Control
var _fill: ColorRect


func _enter_tree() -> void:
	_cache_nodes()
	_update_fill()


func _ready() -> void:
	if _fill_clip == null:
		_cache_nodes()
	_update_fill()
	if Engine.is_editor_hint():
		call_deferred("_update_fill")


func _cache_nodes() -> void:
	_back = get_node_or_null("Back") as TextureRect
	_fill_clip = get_node_or_null("FillClip") as Control
	_fill = get_node_or_null("FillClip/Fill") as ColorRect


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_fill()


func _update_fill() -> void:
	if not _fill_clip:
		_fill_clip = get_node_or_null("FillClip") as Control
	var w: float = maxf(0.0, size.x - MARGIN * 2)
	var h: float = maxf(0.0, size.y - MARGIN * 2)
	if _fill_clip:
		_fill_clip.offset_left = MARGIN
		_fill_clip.offset_top = MARGIN
		_fill_clip.offset_right = size.x - MARGIN
		_fill_clip.offset_bottom = size.y - MARGIN
	if not _fill:
		_fill = get_node_or_null("FillClip/Fill") as ColorRect
	if not _fill or w <= 0 or h <= 0:
		return
	var ratio: float = clampf(current_value / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0
	_fill.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_fill.offset_left = 0
	_fill.offset_top = 0
	_fill.offset_right = w * ratio
	_fill.offset_bottom = h
	_fill.color = fill_color

@tool
class_name ResourceProgressBar
extends Control

## 通用资源进度条组件
## 标准模式：进度 = 当前资源量 / 储存上限
## 研究员模式：双条，左侧橙色=空闲/总数，右侧红色=被侵蚀/总数，均通过 HSV 调节颜色

enum Mode { NORMAL, RESEARCHER }

## 填充条相对 back 的四边边距（左右上下各 1px）
const MARGIN := 1.0

## 研究员模式左侧条颜色（空闲，默认橙，Inspector 可调 HSV）
@export var color_idle: Color = Color.from_hsv(0.08, 0.85, 1.0)

## 研究员模式右侧条颜色（被侵蚀，默认红，Inspector 可调 HSV）
@export var color_eroded: Color = Color.from_hsv(0.0, 0.9, 1.0)

@export var mode: Mode = Mode.NORMAL:
	set(v):
		mode = v
		_update_mode_visibility()
		_update_progress()

@export var current_value: float = 80.0:
	set(v):
		current_value = maxf(0.0, v)
		_update_progress()

@export var max_value: float = 100.0:
	set(v):
		max_value = maxf(0.001, v)
		_update_progress()

## 研究员模式：空闲可用人数量
@export var idle_count: int = 6:
	set(v):
		idle_count = maxi(0, v)
		_update_progress()

## 研究员模式：被侵蚀数量
@export var eroded_count: int = 2:
	set(v):
		eroded_count = maxi(0, v)
		_update_progress()

## 研究员模式：研究员总数
@export var total_count: int = 10:
	set(v):
		total_count = maxi(1, v)
		_update_progress()

@export var use_long_back: bool = false:
	set(v):
		use_long_back = v
		_update_back_texture()

var _back: TextureRect
var _mask_normal: Control
var _mask_left: Control
var _mask_right: Control
var _inside: TextureRect
var _inside_left: TextureRect
var _inside_right: TextureRect


func _ready() -> void:
	_back = get_node_or_null("Back") as TextureRect
	_mask_normal = get_node_or_null("MaskNormal") as Control
	_mask_left = get_node_or_null("MaskLeft") as Control
	_mask_right = get_node_or_null("MaskRight") as Control
	_inside = get_node_or_null("MaskNormal/Inside") as TextureRect
	_inside_left = get_node_or_null("MaskLeft/InsideLeft") as TextureRect
	_inside_right = get_node_or_null("MaskRight/InsideRight") as TextureRect
	_update_back_texture()
	_update_mode_visibility()
	_update_progress()
	# 编辑器下 layout 可能尚未完成，延迟一帧再更新以获取正确 size
	if Engine.is_editor_hint():
		call_deferred("_update_progress")


func _update_back_texture() -> void:
	if not _back:
		return
	if use_long_back:
		_back.texture = load("res://assets/ui/resource_block/progress_back_long.png") as Texture2D
	else:
		_back.texture = load("res://assets/ui/resource_block/progress_back.png") as Texture2D


func _update_mode_visibility() -> void:
	if _mask_normal:
		_mask_normal.visible = mode == Mode.NORMAL
	if _mask_left:
		_mask_left.visible = mode == Mode.RESEARCHER
	if _mask_right:
		_mask_right.visible = mode == Mode.RESEARCHER


func _update_progress() -> void:
	if not _back:
		return
	var fill_width: float = maxf(0.0, size.x - MARGIN * 2)
	var fill_height: float = maxf(0.0, size.y - MARGIN * 2)
	if fill_width <= 0:
		return

	if mode == Mode.NORMAL:
		if _mask_normal and _inside:
			var ratio: float = clampf(current_value / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0
			_mask_normal.offset_left = MARGIN
			_mask_normal.offset_top = MARGIN
			_mask_normal.offset_right = MARGIN + fill_width * ratio
			_mask_normal.offset_bottom = MARGIN + fill_height
			_inside.offset_left = 0
			_inside.offset_top = 0
			_inside.offset_right = fill_width
			_inside.offset_bottom = fill_height
			_inside.modulate = Color.WHITE
	else:
		if _mask_left and _mask_right and _inside_left and _inside_right and total_count > 0:
			var idle_ratio: float = clampf(float(idle_count) / float(total_count), 0.0, 1.0)
			var eroded_ratio: float = clampf(float(eroded_count) / float(total_count), 0.0, 1.0)
			# 左侧条：从左边起 idle_ratio 宽度
			_mask_left.offset_left = MARGIN
			_mask_left.offset_top = MARGIN
			_mask_left.offset_right = MARGIN + fill_width * idle_ratio
			_mask_left.offset_bottom = MARGIN + fill_height
			_inside_left.offset_left = 0
			_inside_left.offset_top = 0
			_inside_left.offset_right = fill_width
			_inside_left.offset_bottom = fill_height
			_inside_left.modulate = color_idle
			# 右侧条：从右边起 eroded_ratio 宽度，InsideRight 偏移以显示纹理右半部分
			_mask_right.offset_left = size.x - MARGIN - fill_width * eroded_ratio
			_mask_right.offset_top = MARGIN
			_mask_right.offset_right = size.x - MARGIN
			_mask_right.offset_bottom = MARGIN + fill_height
			_inside_right.offset_left = fill_width * (eroded_ratio - 1.0)
			_inside_right.offset_top = 0
			_inside_right.offset_right = fill_width * eroded_ratio
			_inside_right.offset_bottom = fill_height
			_inside_right.modulate = color_eroded


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_progress()


func set_progress(current: float, maximum: float) -> void:
	current_value = current
	max_value = maximum


func set_researcher_progress(idle: int, eroded: int, total: int) -> void:
	idle_count = idle
	eroded_count = eroded
	total_count = total

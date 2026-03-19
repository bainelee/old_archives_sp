@tool
class_name ResourceProgressBar
extends Control

## 通用资源进度条组件
## 标准模式：进度 = 当前资源量 / 储存上限
## 研究员模式：双条，左侧橙色=空闲/总数，右侧红色=被侵蚀/总数
## 庇护模式：三色条，橙色=已分配，灰色=剩余上限，红色=缺口（从右到左）
## 住房模式：双色条，橙色=已提供，红色=缺口（从右到左）

enum Mode { NORMAL, RESEARCHER, SHELTER, HOUSING }

const MARGIN := 1.0

## 橙色 #fd9729 - 用于空闲/已分配/已提供（与详情面板一致）
@export var color_orange: Color = Color(0.992, 0.592, 0.161, 1.0)

## 红色 - 用于被侵蚀/缺口
@export var color_red: Color = Color(1.0, 0.2, 0.2, 1.0)

@export var mode: Mode = Mode.NORMAL:
	set(v):
		mode = v
		_update_mode_visibility()
		if not _batch_updating:
			_update_progress()

@export var current_value: float = 80.0:
	set(v):
		current_value = maxf(0.0, v)
		if not _batch_updating:
			_update_progress()

@export var max_value: float = 100.0:
	set(v):
		max_value = maxf(0.001, v)
		if not _batch_updating:
			_update_progress()

@export var idle_count: int = 6:
	set(v):
		idle_count = maxi(0, v)
		if not _batch_updating:
			_update_progress()

@export var eroded_count: int = 2:
	set(v):
		eroded_count = maxi(0, v)
		if not _batch_updating:
			_update_progress()

@export var total_count: int = 10:
	set(v):
		total_count = maxi(1, v)
		if not _batch_updating:
			_update_progress()

@export var shelter_allocated: int = 30:
	set(v):
		shelter_allocated = maxi(0, v)
		if not _batch_updating:
			_update_progress()

@export var shelter_cap: int = 60:
	set(v):
		shelter_cap = maxi(0, v)
		if not _batch_updating:
			_update_progress()

@export var shelter_shortage: int = 10:
	set(v):
		shelter_shortage = maxi(0, v)
		if not _batch_updating:
			_update_progress()

@export var housing_provided: int = 8:
	set(v):
		housing_provided = maxi(0, v)
		if not _batch_updating:
			_update_progress()

@export var housing_shortage: int = 2:
	set(v):
		housing_shortage = maxi(0, v)
		if not _batch_updating:
			_update_progress()

@export var use_long_back: bool = false:
	set(v):
		use_long_back = v
		_update_back_texture()

var _back: TextureRect
var _mask_normal: Control
var _mask_left: Control
var _mask_right: Control
var _inside: ColorRect
var _inside_left: ColorRect
var _inside_right: ColorRect
var _batch_updating := false


func _enter_tree() -> void:
	_cache_nodes()


func _ready() -> void:
	if not _back:
		_cache_nodes()
	_update_back_texture()
	_update_mode_visibility()
	_update_progress()
	if Engine.is_editor_hint():
		call_deferred("_update_progress")


func _cache_nodes() -> void:
	_back = get_node_or_null("Back") as TextureRect
	_mask_normal = get_node_or_null("MaskNormal") as Control
	_mask_left = get_node_or_null("MaskLeft") as Control
	_mask_right = get_node_or_null("MaskRight") as Control
	_inside = get_node_or_null("MaskNormal/Inside") as ColorRect
	_inside_left = get_node_or_null("MaskLeft/InsideLeft") as ColorRect
	_inside_right = get_node_or_null("MaskRight/InsideRight") as ColorRect
	if _inside:
		_inside.set_anchors_preset(Control.PRESET_TOP_LEFT)
	if _inside_left:
		_inside_left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	if _inside_right:
		_inside_right.set_anchors_preset(Control.PRESET_TOP_LEFT)


func _update_back_texture() -> void:
	if not _back:
		return
	if use_long_back:
		_back.texture = load("res://assets/ui/resource_block/progress_back_long.png") as Texture2D
	else:
		_back.texture = load("res://assets/ui/resource_block/progress_back.png") as Texture2D


func _update_mode_visibility() -> void:
	var is_dual := mode == Mode.RESEARCHER or mode == Mode.SHELTER or mode == Mode.HOUSING
	if _mask_normal:
		_mask_normal.visible = mode == Mode.NORMAL
	if _mask_left:
		_mask_left.visible = is_dual
	if _mask_right:
		_mask_right.visible = is_dual


func _update_progress() -> void:
	if not _back:
		return
	var fw: float = maxf(0.0, size.x - MARGIN * 2)
	var fh: float = maxf(0.0, size.y - MARGIN * 2)
	if fw <= 0:
		return

	match mode:
		Mode.NORMAL:
			var ratio: float = clampf(current_value / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0
			_apply_single_bar(ratio, fw, fh)
		Mode.RESEARCHER:
			if total_count > 0:
				_apply_dual_bar(
					clampf(float(idle_count) / float(total_count), 0.0, 1.0),
					clampf(float(eroded_count) / float(total_count), 0.0, 1.0),
					fw, fh)
		Mode.SHELTER:
			var total_len: float = float(shelter_cap + shelter_shortage)
			if total_len > 0:
				_apply_dual_bar(
					clampf(float(shelter_allocated) / total_len, 0.0, 1.0),
					clampf(float(shelter_shortage) / total_len, 0.0, 1.0),
					fw, fh)
		Mode.HOUSING:
			var total_h: float = float(housing_provided + housing_shortage)
			if total_h > 0:
				_apply_dual_bar(
					clampf(float(housing_provided) / total_h, 0.0, 1.0),
					clampf(float(housing_shortage) / total_h, 0.0, 1.0),
					fw, fh)


func _apply_single_bar(ratio: float, fw: float, fh: float) -> void:
	if _mask_normal and _inside:
		_mask_normal.visible = true
		_mask_normal.offset_left = MARGIN
		_mask_normal.offset_top = MARGIN
		_mask_normal.offset_right = size.x - MARGIN
		_mask_normal.offset_bottom = size.y - MARGIN
		_inside.visible = true
		_inside.offset_left = 0
		_inside.offset_top = 0
		_inside.offset_right = fw * ratio
		_inside.offset_bottom = fh
		_inside.color = color_orange
	if _mask_left:
		_mask_left.visible = false
	if _mask_right:
		_mask_right.visible = false


func _apply_dual_bar(left_ratio: float, right_ratio: float, fw: float, fh: float) -> void:
	if _mask_left and _inside_left:
		_mask_left.visible = true
		_mask_left.offset_left = MARGIN
		_mask_left.offset_top = MARGIN
		_mask_left.offset_right = MARGIN + fw * left_ratio
		_mask_left.offset_bottom = MARGIN + fh
		_inside_left.visible = true
		_inside_left.offset_left = 0
		_inside_left.offset_top = 0
		_inside_left.offset_right = fw * left_ratio
		_inside_left.offset_bottom = fh
		_inside_left.color = color_orange
	if _mask_right and _inside_right:
		_mask_right.visible = true
		_mask_right.offset_left = size.x - MARGIN - fw * right_ratio
		_mask_right.offset_top = MARGIN
		_mask_right.offset_right = size.x - MARGIN
		_mask_right.offset_bottom = MARGIN + fh
		_inside_right.visible = true
		_inside_right.offset_left = 0
		_inside_right.offset_top = 0
		_inside_right.offset_right = fw * right_ratio
		_inside_right.offset_bottom = fh
		_inside_right.color = color_red
	if _mask_normal:
		_mask_normal.visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_progress()


func set_progress(current: float, maximum: float) -> void:
	_batch_updating = true
	current_value = current
	max_value = maximum
	_batch_updating = false
	_update_progress()


func set_researcher_progress(idle: int, eroded: int, total: int) -> void:
	_batch_updating = true
	idle_count = idle
	eroded_count = eroded
	total_count = total
	_batch_updating = false
	_update_progress()


func set_shelter_progress(allocated: int, cap: int, shortage: int) -> void:
	_batch_updating = true
	shelter_allocated = allocated
	shelter_cap = cap
	shelter_shortage = shortage
	_batch_updating = false
	_update_progress()


func set_housing_progress(provided: int, shortage: int) -> void:
	_batch_updating = true
	housing_provided = provided
	housing_shortage = shortage
	_batch_updating = false
	_update_progress()

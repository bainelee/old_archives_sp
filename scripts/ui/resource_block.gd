@tool
class_name ResourceBlock
extends Control

## 可复用的资源块组件
## 结构：IconFrame + Icon + Value + 可选 ProgressBar
## 鼠标悬停时发出 signal，详细信息面板由外部连接

enum LayoutStyle {
	STANDARD,   ## 标准布局 128x56，8px padding
	BLUE,       ## 蓝框紧凑 112x44，无 padding
	COMPACT,    ## 紧凑无进度 80x56
	RESEARCHER, ## 研究员宽布局 220x56
}

signal hovered(block_id: String)
signal unhovered(block_id: String)

@export var block_id: String = ""
@export var initial_value: String = "+1920"

@export var layout_style: LayoutStyle = LayoutStyle.STANDARD:
	set(v):
		layout_style = v
		_apply_layout()
		_update_progress_visibility()

@export var frame_texture: Texture2D:
	set(v):
		frame_texture = v
		if _icon_frame:
			_icon_frame.texture = v

@export var icon_texture: Texture2D:
	set(v):
		icon_texture = v
		if _icon:
			_icon.texture = v

@export var show_progress: bool = true:
	set(v):
		show_progress = v
		_update_progress_visibility()

@export var use_long_back: bool = false
@export var use_researcher_mode: bool = false
@export var researcher_idle: int = 6
@export var researcher_eroded: int = 2
@export var researcher_total: int = 10

var _icon_frame: TextureRect
var _icon: TextureRect
var _value: Label
var _progress_bar: ResourceProgressBar


func _enter_tree() -> void:
	_cache_nodes()
	_apply_layout()
	_update_progress_visibility()
	_apply_textures()
	_apply_initial_progress()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _cache_nodes() -> void:
	_icon_frame = get_node_or_null("IconFrame") as TextureRect
	_icon = get_node_or_null("Icon") as TextureRect
	_value = get_node_or_null("Value") as Label
	_progress_bar = get_node_or_null("ProgressBar") as ResourceProgressBar


func _apply_textures() -> void:
	if _icon_frame and frame_texture:
		_icon_frame.texture = frame_texture
	if _icon and icon_texture:
		_icon.texture = icon_texture
	if _value and initial_value:
		_value.text = initial_value


func _apply_initial_progress() -> void:
	if not _progress_bar:
		return
	_progress_bar.use_long_back = use_long_back
	_progress_bar.mode = ResourceProgressBar.Mode.RESEARCHER if use_researcher_mode else ResourceProgressBar.Mode.NORMAL
	if use_researcher_mode:
		_progress_bar.set_researcher_progress(researcher_idle, researcher_eroded, researcher_total)


func _apply_layout() -> void:
	if not _icon_frame or not _icon or not _value:
		_cache_nodes()
	if not _icon_frame or not _icon or not _value:
		return
	var pb: ResourceProgressBar = _progress_bar
	match layout_style:
		LayoutStyle.STANDARD:
			custom_minimum_size = Vector2(128, 56)
			_set_rect(_icon_frame, 8, 8, 40, 40)
			_set_rect(_icon, 8, 8, 40, 40)
			_set_rect(_value, 45, 8, 125, 40)
			if pb:
				_set_rect(pb, 8, 44, 120, 52)
		LayoutStyle.BLUE:
			custom_minimum_size = Vector2(112, 44)
			_set_rect(_icon_frame, 0, 0, 32, 32)
			_set_rect(_icon, 0, 0, 32, 32)
			_set_rect(_value, 34, 0, 112, 32)
			_value.add_theme_color_override("font_color", Color.WHITE)
			if pb:
				_set_rect(pb, 0, 36, 112, 44)
		LayoutStyle.COMPACT:
			custom_minimum_size = Vector2(80, 56)
			_set_rect(_icon_frame, 8, 8, 40, 40)
			_set_rect(_icon, 8, 8, 40, 40)
			_set_rect(_value, 45, 8, 76, 40)
			if pb:
				pb.visible = false
		LayoutStyle.RESEARCHER:
			custom_minimum_size = Vector2(220, 56)
			_set_rect(_icon_frame, 8, 8, 40, 40)
			_set_rect(_icon, 8, 8, 40, 40)
			_set_rect(_value, 45, 8, 220, 40)
			if pb:
				_set_rect(pb, 8, 44, 212, 52)
				pb.visible = show_progress


static func _set_rect(ctrl: Control, left: float, top: float, right: float, bottom: float) -> void:
	ctrl.offset_left = left
	ctrl.offset_top = top
	ctrl.offset_right = right
	ctrl.offset_bottom = bottom


func _update_progress_visibility() -> void:
	if _progress_bar:
		_progress_bar.visible = show_progress and layout_style != LayoutStyle.COMPACT


func _on_mouse_entered() -> void:
	hovered.emit(block_id)


func _on_mouse_exited() -> void:
	unhovered.emit(block_id)


func set_value(text: String) -> void:
	if _value:
		_value.text = text


func set_progress(current: float, maximum: float) -> void:
	if _progress_bar:
		_progress_bar.set_progress(current, maximum)
		_progress_bar.mode = ResourceProgressBar.Mode.NORMAL


func set_researcher_progress(idle: int, eroded: int, total: int) -> void:
	if _progress_bar:
		_progress_bar.set_researcher_progress(idle, eroded, total)
		_progress_bar.mode = ResourceProgressBar.Mode.RESEARCHER


func set_shelter_progress(allocated: int, cap: int, shortage: int) -> void:
	if _progress_bar:
		_progress_bar.set_shelter_progress(allocated, cap, shortage)
		_progress_bar.mode = ResourceProgressBar.Mode.SHELTER


func set_housing_progress(provided: int, shortage: int) -> void:
	if _progress_bar:
		_progress_bar.set_housing_progress(provided, shortage)
		_progress_bar.mode = ResourceProgressBar.Mode.HOUSING

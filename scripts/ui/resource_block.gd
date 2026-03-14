@tool
class_name ResourceBlock
extends Control

## 可复用的资源块组件
## 结构：IconFrame + Icon + Value + 可选 ProgressBar
## 鼠标悬停时发出 signal，详细信息面板由外部连接（暂未实现新界面）

enum LayoutStyle {
	STANDARD,   ## 标准布局 128x56，8px padding
	BLUE,       ## 蓝框紧凑 112x44，无 padding
	COMPACT,    ## 紧凑无进度 80x56
	RESEARCHER, ## 研究员宽布局 220x56
}

signal hovered(block_id: String)
signal unhovered(block_id: String)

## 用于 hover 回调标识
@export var block_id: String = ""

## 初始显示数值（也可运行时通过 set_value 更新）
@export var initial_value: String = "+1920"

@export var layout_style: LayoutStyle = LayoutStyle.STANDARD:
	set(v):
		layout_style = v
		_apply_layout()
		_update_progress_visibility()

## 蓝框/灰框
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

## 是否显示进度条
@export var show_progress: bool = true:
	set(v):
		show_progress = v
		_update_progress_visibility()

## 进度条用长背景
@export var use_long_back: bool = false

## 研究员模式：进度条为双条
@export var use_researcher_mode: bool = false

## 研究员模式时的数值（空闲/总数/被侵蚀）
@export var researcher_idle: int = 6
@export var researcher_eroded: int = 2
@export var researcher_total: int = 10

var _icon_frame: TextureRect
var _icon: TextureRect
var _value: Label
var _progress_bar: ResourceProgressBar


func _ready() -> void:
	_icon_frame = get_node_or_null("IconFrame") as TextureRect
	_icon = get_node_or_null("Icon") as TextureRect
	_value = get_node_or_null("Value") as Label
	_progress_bar = get_node_or_null("ProgressBar") as ResourceProgressBar
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_apply_layout()
	_update_progress_visibility()
	if _icon_frame and frame_texture:
		_icon_frame.texture = frame_texture
	if _icon and icon_texture:
		_icon.texture = icon_texture
	if _value and initial_value:
		_value.text = initial_value
	if _progress_bar:
		_progress_bar.use_long_back = use_long_back
		_progress_bar.mode = ResourceProgressBar.Mode.RESEARCHER if use_researcher_mode else ResourceProgressBar.Mode.NORMAL
		if use_researcher_mode:
			_progress_bar.set_researcher_progress(researcher_idle, researcher_eroded, researcher_total)


func _apply_layout() -> void:
	if not is_node_ready():
		return
	var fw: TextureRect = _icon_frame
	var ic: TextureRect = _icon
	var vl: Label = _value
	var pb: ResourceProgressBar = _progress_bar
	if not fw or not ic or not vl:
		return
	match layout_style:
		LayoutStyle.STANDARD:
			custom_minimum_size = Vector2(128, 56)
			fw.set_anchors_preset(Control.PRESET_TOP_LEFT)
			fw.offset_left = 8
			fw.offset_top = 8
			fw.offset_right = 40
			fw.offset_bottom = 40
			ic.offset_left = 8
			ic.offset_top = 8
			ic.offset_right = 40
			ic.offset_bottom = 40
			vl.offset_left = 45
			vl.offset_top = 8
			vl.offset_right = 125
			vl.offset_bottom = 40
			if pb:
				pb.offset_left = 8
				pb.offset_top = 44
				pb.offset_right = 120
				pb.offset_bottom = 52
		LayoutStyle.BLUE:
			custom_minimum_size = Vector2(112, 44)
			fw.offset_left = 0
			fw.offset_top = 0
			fw.offset_right = 32
			fw.offset_bottom = 32
			ic.offset_left = 0
			ic.offset_top = 0
			ic.offset_right = 32
			ic.offset_bottom = 32
			vl.offset_left = 34
			vl.offset_top = 0
			vl.offset_right = 112
			vl.offset_bottom = 32
			vl.add_theme_color_override("font_color", Color.WHITE)
			if pb:
				pb.offset_left = 0
				pb.offset_top = 36
				pb.offset_right = 112
				pb.offset_bottom = 44
		LayoutStyle.COMPACT:
			custom_minimum_size = Vector2(80, 56)
			fw.offset_left = 8
			fw.offset_top = 8
			fw.offset_right = 40
			fw.offset_bottom = 40
			ic.offset_left = 8
			ic.offset_top = 8
			ic.offset_right = 40
			ic.offset_bottom = 40
			vl.offset_left = 45
			vl.offset_top = 8
			vl.offset_right = 76
			vl.offset_bottom = 40
			if pb:
				pb.visible = false
		LayoutStyle.RESEARCHER:
			custom_minimum_size = Vector2(220, 56)
			fw.offset_left = 8
			fw.offset_top = 8
			fw.offset_right = 40
			fw.offset_bottom = 40
			ic.offset_left = 8
			ic.offset_top = 8
			ic.offset_right = 40
			ic.offset_bottom = 40
			vl.offset_left = 45
			vl.offset_top = 8
			vl.offset_right = 220
			vl.offset_bottom = 40
			if pb:
				pb.offset_left = 8
				pb.offset_top = 44
				pb.offset_right = 212
				pb.offset_bottom = 52
				pb.visible = show_progress


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


func set_researcher_progress(idle: int, eroded: int, total: int) -> void:
	if _progress_bar:
		_progress_bar.set_researcher_progress(idle, eroded, total)

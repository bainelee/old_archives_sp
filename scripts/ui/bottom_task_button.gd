@tool
extends Button

## 底栏专用按钮：复用通用按钮底图，但采用固定内边距规则
## - icon 左内边距 4px
## - 文字右内边距 6px

var _btn_w: int = 216
var _btn_h: int = 108
var _icon_left_padding: int = 4
var _text_gap_from_icon: int = 6
var _button_bg_color: Color = Color8(168, 168, 168)
var _button_bg_hover_color: Color = Color8(230, 230, 230)
var _button_bg_pressed_color: Color = Color8(139, 139, 139)
var _icon_bg_color: Color = Color8(162, 162, 162)
var _icon_frame_texture: Texture2D
var _hover_overlay_texture: Texture2D
var _icon_size: int = 32
var _hover_overlay_inset: int = 2

var _bg_rect: ColorRect
var _icon_bg_rect: ColorRect
var _icon_frame_rect: TextureRect
var _hover_overlay: NinePatchRect

@export var button_width: int = 216:
	get: return _btn_w
	set(v):
		_btn_w = v
		_apply_layout()

@export var button_height: int = 108:
	get: return _btn_h
	set(v):
		_btn_h = v
		_apply_layout()

@export var icon_left_padding: int = 4:
	get: return _icon_left_padding
	set(v):
		_icon_left_padding = maxi(0, v)
		_apply_layout()

@export var text_gap_from_icon: int = 6:
	get: return _text_gap_from_icon
	set(v):
		_text_gap_from_icon = maxi(0, v)
		_apply_layout()

@export var button_bg_color: Color = Color8(168, 168, 168):
	get: return _button_bg_color
	set(v):
		_button_bg_color = v
		_apply_layout()

@export var button_bg_hover_color: Color = Color8(230, 230, 230):
	get: return _button_bg_hover_color
	set(v):
		_button_bg_hover_color = v
		_apply_layout()

@export var button_bg_pressed_color: Color = Color8(139, 139, 139):
	get: return _button_bg_pressed_color
	set(v):
		_button_bg_pressed_color = v
		_apply_layout()

@export var icon_bg_color: Color = Color8(162, 162, 162):
	get: return _icon_bg_color
	set(v):
		_icon_bg_color = v
		_apply_layout()

@export var icon_frame_texture: Texture2D:
	get: return _icon_frame_texture
	set(v):
		_icon_frame_texture = v
		_apply_layout()

@export var hover_overlay_texture: Texture2D:
	get: return _hover_overlay_texture
	set(v):
		_hover_overlay_texture = v
		_apply_layout()

@export var hover_overlay_inset: int = 2:
	get: return _hover_overlay_inset
	set(v):
		_hover_overlay_inset = maxi(0, v)
		_apply_layout()


func _enter_tree() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_layout()


func _process(_delta: float) -> void:
	_refresh_button_bg_color()


func _apply_layout() -> void:
	custom_minimum_size = Vector2(_btn_w, _btn_h)
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	icon = null
	icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_theme_constant_override("h_separation", 0)
	add_theme_color_override("font_color", Color(0, 0, 0, 1))
	add_theme_color_override("font_hover_color", Color(0, 0, 0, 1))
	add_theme_color_override("font_pressed_color", Color(0, 0, 0, 1))
	add_theme_color_override("font_focus_color", Color(0, 0, 0, 1))
	add_theme_color_override("font_disabled_color", Color(0, 0, 0, 1))
	_apply_stylebox_content_margins()
	_ensure_visual_nodes()
	_layout_visual_nodes()
	_refresh_button_bg_color()


func _apply_stylebox_content_margins() -> void:
	var style_names: Array[StringName] = [&"normal", &"hover", &"pressed", &"disabled"]
	for style_name in style_names:
		var sb: StyleBox = get_theme_stylebox(style_name)
		if sb == null:
			continue
		var sb_copy: StyleBox = sb.duplicate()
		if sb_copy is StyleBoxTexture:
			var tex_box: StyleBoxTexture = sb_copy as StyleBoxTexture
			tex_box.content_margin_left = _icon_left_padding + _icon_size + _text_gap_from_icon
			tex_box.content_margin_right = 0
			add_theme_stylebox_override(style_name, tex_box)


func _ensure_visual_nodes() -> void:
	if _bg_rect == null or not is_instance_valid(_bg_rect):
		_bg_rect = ColorRect.new()
		_bg_rect.name = "ButtonBg"
		_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bg_rect.show_behind_parent = true
		add_child(_bg_rect)
		move_child(_bg_rect, 0)

	if _icon_bg_rect == null or not is_instance_valid(_icon_bg_rect):
		_icon_bg_rect = ColorRect.new()
		_icon_bg_rect.name = "IconBg"
		_icon_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_icon_bg_rect)
		move_child(_icon_bg_rect, get_child_count() - 1)

	if _icon_frame_rect == null or not is_instance_valid(_icon_frame_rect):
		_icon_frame_rect = TextureRect.new()
		_icon_frame_rect.name = "IconFrame"
		_icon_frame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon_frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon_frame_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(_icon_frame_rect)
		move_child(_icon_frame_rect, get_child_count() - 1)

	if _hover_overlay == null or not is_instance_valid(_hover_overlay):
		_hover_overlay = NinePatchRect.new()
		_hover_overlay.name = "HoverOverlay"
		_hover_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hover_overlay.draw_center = false
		_hover_overlay.patch_margin_left = 2
		_hover_overlay.patch_margin_right = 2
		_hover_overlay.patch_margin_top = 2
		_hover_overlay.patch_margin_bottom = 2
		add_child(_hover_overlay)
		move_child(_hover_overlay, get_child_count() - 1)


func _layout_visual_nodes() -> void:
	if _bg_rect:
		_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_bg_rect.offset_left = 0.0
		_bg_rect.offset_top = 0.0
		_bg_rect.offset_right = 0.0
		_bg_rect.offset_bottom = 0.0
		_bg_rect.color = _button_bg_color

	var icon_left: float = float(_icon_left_padding)
	var icon_top: float = floor((size.y - float(_icon_size)) * 0.5)
	if icon_top < 0.0:
		icon_top = 0.0
	var icon_right: float = icon_left + float(_icon_size)
	var icon_bottom: float = icon_top + float(_icon_size)

	if _icon_bg_rect:
		_icon_bg_rect.offset_left = icon_left
		_icon_bg_rect.offset_top = icon_top
		_icon_bg_rect.offset_right = icon_right
		_icon_bg_rect.offset_bottom = icon_bottom
		_icon_bg_rect.color = _icon_bg_color

	if _icon_frame_rect:
		_icon_frame_rect.offset_left = icon_left
		_icon_frame_rect.offset_top = icon_top
		_icon_frame_rect.offset_right = icon_right
		_icon_frame_rect.offset_bottom = icon_bottom
		_icon_frame_rect.texture = _icon_frame_texture

	if _hover_overlay:
		_hover_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_hover_overlay.offset_left = float(_hover_overlay_inset)
		_hover_overlay.offset_top = float(_hover_overlay_inset)
		_hover_overlay.offset_right = -float(_hover_overlay_inset)
		_hover_overlay.offset_bottom = -float(_hover_overlay_inset)
		_hover_overlay.texture = _hover_overlay_texture


func _refresh_button_bg_color() -> void:
	if not _bg_rect:
		return
	if is_pressed():
		_bg_rect.color = _button_bg_pressed_color
	elif is_hovered():
		_bg_rect.color = _button_bg_hover_color
	else:
		_bg_rect.color = _button_bg_color
	if _hover_overlay:
		_hover_overlay.visible = (is_hovered() and not is_pressed() and not disabled and _hover_overlay_texture != null)

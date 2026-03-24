@tool
class_name RoomDetailsActionButton
extends TextureButton

@export var label_text: String = "":
	set(v):
		label_text = v
		_apply_visual()
@export var icon_texture: Texture2D:
	set(v):
		icon_texture = v
		_apply_visual()
@export var normal_texture: Texture2D:
	set(v):
		normal_texture = v
		_apply_visual()
@export var pressed_state_texture: Texture2D:
	set(v):
		pressed_state_texture = v
		_apply_visual()

@onready var _icon: TextureRect = $Icon
@onready var _label: Label = $Label


func _enter_tree() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_visual()


func _apply_visual() -> void:
	if not is_inside_tree():
		return
	texture_normal = normal_texture
	texture_pressed = pressed_state_texture if pressed_state_texture != null else normal_texture
	if _icon:
		_icon.texture = icon_texture
		_icon.visible = icon_texture != null
	if _label:
		_label.text = label_text

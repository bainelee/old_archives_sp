@tool
class_name RoomDetailsInfoEntry
extends Control

const ENTRY_ICON_SIZE: Vector2 = Vector2(12, 12)
const _ALPHA_THRESHOLD: float = 0.02
static var _icon_crop_cache: Dictionary = {}

@export var entry_icon: Texture2D:
	set(v):
		entry_icon = v
		_apply_visual()
@export var entry_name: String = "":
	set(v):
		entry_name = v
		_apply_visual()
@export var entry_value: String = "":
	set(v):
		entry_value = v
		_apply_visual()
@export var show_when_empty: bool = false:
	set(v):
		show_when_empty = v
		_apply_visual()

@onready var _icon: TextureRect = $Icon
@onready var _name_label: Label = $NameLabel
@onready var _value_label: Label = $ValueLabel
@onready var _back: ColorRect = $BackInfoEntry


func _enter_tree() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_visual()


func set_entry_raw(icon: Texture2D, name_text: String, value_text: String) -> void:
	entry_icon = icon
	entry_name = name_text
	entry_value = value_text
	_apply_visual()


func set_entry_data(data: Dictionary) -> void:
	var icon: Texture2D = data.get("icon", null) as Texture2D
	var name_text: String = str(data.get("name", ""))
	var value_text: String = str(data.get("value", ""))
	set_entry_raw(icon, name_text, value_text)


func clear_entry() -> void:
	set_entry_raw(null, "", "")


func _apply_visual() -> void:
	if not is_inside_tree():
		return
	if _icon == null or _name_label == null or _value_label == null:
		return
	_icon.custom_minimum_size = ENTRY_ICON_SIZE
	_icon.size = ENTRY_ICON_SIZE
	_icon.texture = _get_cropped_icon(entry_icon)
	_icon.visible = entry_icon != null
	_name_label.text = entry_name
	_value_label.text = entry_value
	visible = show_when_empty or not (entry_name.is_empty() and entry_value.is_empty())
	if _back:
		_back.visible = visible


func _get_cropped_icon(source_tex: Texture2D) -> Texture2D:
	if source_tex == null:
		return null
	var cache_key: String = source_tex.resource_path if not source_tex.resource_path.is_empty() else str(source_tex.get_rid().get_id())
	if _icon_crop_cache.has(cache_key):
		return _icon_crop_cache[cache_key] as Texture2D
	var img: Image = source_tex.get_image()
	if img == null or img.is_empty():
		_icon_crop_cache[cache_key] = source_tex
		return source_tex
	var w: int = img.get_width()
	var h: int = img.get_height()
	var min_x: int = w
	var min_y: int = h
	var max_x: int = -1
	var max_y: int = -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > _ALPHA_THRESHOLD:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		_icon_crop_cache[cache_key] = source_tex
		return source_tex
	if min_x == 0 and min_y == 0 and max_x == w - 1 and max_y == h - 1:
		_icon_crop_cache[cache_key] = source_tex
		return source_tex
	# 为避免紧裁剪导致不同图标视觉比例失真，将包围盒扩成正方形区域。
	var box_w: int = max_x - min_x + 1
	var box_h: int = max_y - min_y + 1
	var side: int = maxi(box_w, box_h)
	var cx: float = float(min_x + max_x) * 0.5
	var cy: float = float(min_y + max_y) * 0.5
	var square_min_x: int = maxi(0, int(floor(cx - float(side) * 0.5)))
	var square_min_y: int = maxi(0, int(floor(cy - float(side) * 0.5)))
	var square_max_x: int = mini(w - 1, square_min_x + side - 1)
	var square_max_y: int = mini(h - 1, square_min_y + side - 1)
	# 触边时回推，尽量保持方形边长。
	square_min_x = maxi(0, square_max_x - side + 1)
	square_min_y = maxi(0, square_max_y - side + 1)
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = source_tex
	atlas.filter_clip = true
	atlas.region = Rect2(
		square_min_x,
		square_min_y,
		square_max_x - square_min_x + 1,
		square_max_y - square_min_y + 1
	)
	_icon_crop_cache[cache_key] = atlas
	return atlas

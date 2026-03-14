@tool
class_name ForecastWarning
extends Control

## 侵蚀预警条控件：显示未来 84 天的侵蚀变化点
## 尺寸 252×20，3px=1 天；mask 最右侧=今天，最左侧=距今 84 天
## 仅侵蚀变化时生成 handle，恶化→红标、好转→绿标；handle 每天右移 3px，到达今日后消失

const PX_PER_DAY := 3
const BAR_OFFSET_LEFT := 7.0
## handle 与 warning_sign 贴图尺寸由 tex.get_size() 动态获取，避免拉伸
const SIGN_OFFSET_FROM_HANDLE := 3.0

## 侵蚀等级 0–4 → 贴图索引：0=绿 1=蓝 2=橙 3=紫 4=红
const LEVEL_TO_INDEX := [1, 0, 2, 3, 4]
const HANDLE_PATHS := [
	"res://assets/ui/forecast_warning/handle_blue.png",
	"res://assets/ui/forecast_warning/handle_green.png",
	"res://assets/ui/forecast_warning/handle_orange.png",
	"res://assets/ui/forecast_warning/handle_purple.png",
	"res://assets/ui/forecast_warning/handle_red.png",
]
const SIGN_RED_PATH := "res://assets/ui/forecast_warning/forecast_warning_sign_red.png"
const SIGN_GREEN_PATH := "res://assets/ui/forecast_warning/forecast_warning_sign_green.png"

## 编辑器中预置 handle（用于 @tool 预览），运行时由 ErosionCore 提供
@export var handles: Array[Vector3] = []:
	set(v):
		handles = v
		call_deferred("_rebuild_from_handles_array")

var _background: TextureRect
var _handle_container: Control
var _last_handles_hash := 0
var _last_bar_height: float = -1.0


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	if not is_instance_valid(GameTime):
		return
	if GameTime.is_connected("time_updated", _on_time_updated):
		GameTime.disconnect("time_updated", _on_time_updated)


func _ready() -> void:
	_background = get_node_or_null("Background") as TextureRect
	_handle_container = get_node_or_null("HandleContainer") as Control
	if not _handle_container:
		_handle_container = self
	_rebuild_from_source()
	if not Engine.is_editor_hint() and ErosionCore and GameTime:
		if not GameTime.is_connected("time_updated", _on_time_updated):
			GameTime.connect("time_updated", _on_time_updated)
		_on_time_updated()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		var h := handles.size()
		for v in handles:
			h = h * 31 + clampi(int(v.x), 0, 84)
			h = h * 31 + clampi(int(v.y), 0, 4)
			h = h * 31 + (1 if v.z != 0 else 0)
		if h != _last_handles_hash:
			_last_handles_hash = h
			_rebuild_from_handles_array()
		return
	_rebuild_from_source()


func _on_time_updated() -> void:
	_rebuild_from_source()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		var bar_center: float = _get_bar_height_center()
		if abs(bar_center - _last_bar_height) > 0.5:
			_last_handles_hash = -1
			_rebuild_from_source()


func _rebuild_from_source() -> void:
	if Engine.is_editor_hint():
		return
	if not ErosionCore or not _handle_container:
		return
	var pool: Array = ErosionCore.get_forecast_handles()
	var h := _hash_handles_pool(pool)
	if h == _last_handles_hash:
		return
	_last_handles_hash = h
	_draw_handles_from_pool(pool)


func _rebuild_from_handles_array() -> void:
	if not _handle_container:
		return
	## 编辑器模式：将 Vector3 handles 转为 pool 格式用于绘制
	var pool: Array = []
	for v in handles:
		var days: int = clampi(int(v.x), 0, 84)
		var level: int = clampi(int(v.y), 0, 4)
		var sign_type: int = 1 if v.z != 0 else 0
		pool.append({
			"days_from_now": days,
			"level": level,
			"sign_type": sign_type,
			"pixel_offset": 0.0,
		})
	_draw_handles_from_pool(pool)


func _hash_handles_pool(pool: Array) -> int:
	var h := pool.size()
	for p in pool:
		if p is Dictionary:
			var d: Dictionary = p as Dictionary
			h = h * 31 + int(d.get("days_from_now", 0))
			h = h * 31 + int(d.get("level", 1))
			h = h * 31 + int(d.get("sign_type", 0))
			h = h * 31 + int(float(d.get("pixel_offset", 0.0)) * 10.0)
	return h


func _get_bar_height_center() -> float:
	## 与 forecastwarning-background 垂直居中对齐
	var h: float = size.y
	if h <= 0 and _handle_container:
		h = _handle_container.size.y
	if h <= 0:
		h = custom_minimum_size.y if custom_minimum_size.y > 0 else 20.0
	return h / 2.0


func _draw_handles_from_pool(pool: Array) -> void:
	if not _handle_container:
		return
	var bar_center: float = _get_bar_height_center()
	_last_bar_height = bar_center
	for c in _handle_container.get_children().duplicate():
		if c.name.begins_with("Handle_") or c.name.begins_with("Sign_"):
			_handle_container.remove_child(c)
			c.queue_free()
	for i in pool.size():
		var h: Variant = pool[i]
		if not (h is Dictionary):
			continue
		var d: Dictionary = h as Dictionary
		var days_from_now: float = float(d.get("days_from_now", 0))
		var level: int = int(d.get("level", 1))
		var sign_type: int = int(d.get("sign_type", 0))
		var pixel_offset: float = float(d.get("pixel_offset", 0.0))
		var tex_idx: int = level if level < LEVEL_TO_INDEX.size() else 0
		tex_idx = LEVEL_TO_INDEX[tex_idx]
		var tex: Texture2D = load(HANDLE_PATHS[tex_idx]) as Texture2D
		if not tex:
			continue
		var tex_size: Vector2 = tex.get_size()
		var hw: float = tex_size.x
		var hh: float = tex_size.y
		## 84 天→最左，今天→最右；初始 x = (84-days)*3，叠加 pixel_offset
		var x: float = BAR_OFFSET_LEFT + (84.0 - days_from_now) * PX_PER_DAY + pixel_offset - hw / 2.0
		var pos_y: float = bar_center - hh / 2.0
		var rect := TextureRect.new()
		rect.name = "Handle_%d" % i
		rect.texture = tex
		rect.offset_left = x
		rect.offset_top = pos_y
		rect.offset_right = x + hw
		rect.offset_bottom = pos_y + hh
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_handle_container.add_child(rect)
		if sign_type != 0:
			var sign_path: String = SIGN_RED_PATH if sign_type == 1 else SIGN_GREEN_PATH
			var sign_tex: Texture2D = load(sign_path) as Texture2D
			if sign_tex:
				var sign_size: Vector2 = sign_tex.get_size()
				var sign_rect := TextureRect.new()
				sign_rect.name = "Sign_%d" % i
				sign_rect.texture = sign_tex
				## sign 置于 handle 左侧，与 handle 保持 SIGN_OFFSET_FROM_HANDLE 间距
				sign_rect.offset_left = x - SIGN_OFFSET_FROM_HANDLE - sign_size.x
				sign_rect.offset_top = bar_center - sign_size.y / 2.0
				sign_rect.offset_right = x - SIGN_OFFSET_FROM_HANDLE
				sign_rect.offset_bottom = bar_center + sign_size.y / 2.0
				sign_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				sign_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				_handle_container.add_child(sign_rect)

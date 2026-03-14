@tool
class_name ForecastWarning
extends Control

## 侵蚀预测条控件
## 显示未来 84 天的侵蚀预测（252×20，3px=1天）
## 在编辑器中通过 handles 设置，每个 Vector3：(x=距今天数, y=侵蚀等级, z=是否警示)
## 侵蚀等级：0=绿 1=蓝 2=橙 3=紫 4=红，例：(30,1,1)=距今30天、蓝色、显示警示

const PX_PER_DAY := 3
const BAR_OFFSET_LEFT := 7.0
const BAR_HEIGHT_CENTER := 16.0
## handle 贴图有三种尺寸：7×11（绿）、7×13（蓝/橙）、7×15（紫/红），按 tex.get_size() 实际显示
const SIGN_SIZE := 12.0
const SIGN_OFFSET_FROM_HANDLE := 3.0

## 侵蚀数值 → handle y 等级 0–4：+1→0, 0→1, -2→2, -4→3, -8→4
const VALUE_TO_LEVEL := {1: 0, 0: 1, -2: 2, -4: 3, -8: 4}
## 侵蚀等级 → 贴图索引：0=绿 1=蓝 2=橙 3=紫 4=红
const LEVEL_TO_INDEX := [1, 0, 2, 3, 4]
const HANDLE_PATHS := [
	"res://assets/ui/forecast_warning/handle_blue.png",
	"res://assets/ui/forecast_warning/handle_green.png",
	"res://assets/ui/forecast_warning/handle_orange.png",
	"res://assets/ui/forecast_warning/handle_purple.png",
	"res://assets/ui/forecast_warning/handle_red.png",
]
const SIGN_RED_PATH := "res://assets/ui/forecast_warning/forecast_warning_sign_red.png"

## 每个 handle：(x=距今天数 0-84, y=侵蚀等级 0-4, z=是否警示 1=是 0=否)
@export var handles: Array[Vector3] = []:
	set(v):
		handles = v
		call_deferred("_rebuild_handles")

var _background: TextureRect
var _handle_container: Control
var _last_data_hash := 0


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	if not is_instance_valid(GameTime):
		return
	# 使用字符串形式避免直接访问 signal 属性可能引发的错误
	if GameTime.is_connected("time_updated", _on_time_updated):
		GameTime.disconnect("time_updated", _on_time_updated)


func _ready() -> void:
	_background = get_node_or_null("Background") as TextureRect
	_handle_container = get_node_or_null("HandleContainer") as Control
	if not _handle_container:
		_handle_container = self
	_rebuild_handles()
	if not Engine.is_editor_hint() and ErosionCore and GameTime:
		if not GameTime.is_connected("time_updated", _on_time_updated):
			GameTime.connect("time_updated", _on_time_updated)
		_on_time_updated()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	var h := _compute_hash()
	if h != _last_data_hash:
		_last_data_hash = h
		_rebuild_handles()


func _compute_hash() -> int:
	var h := handles.size()
	for v in handles:
		h = h * 31 + clampi(int(v.x), 0, 84)
		h = h * 31 + clampi(int(v.y), 0, 4)
		h = h * 31 + (1 if v.z != 0 else 0)
	return h


func _rebuild_handles() -> void:
	if not _handle_container:
		return
	# 清除已存在的 handle 节点（先 remove_child 再 queue_free，避免旧节点残留绘制）
	for c in _handle_container.get_children().duplicate():
		if c.name.begins_with("Handle_") or c.name.begins_with("Sign_"):
			_handle_container.remove_child(c)
			c.queue_free()
	# 重建
	for i in handles.size():
		var v := handles[i]
		var days: int = clampi(int(v.x), 0, 84)
		var level: int = clampi(int(v.y), 0, 4)
		var sign_on: bool = v.z != 0
		var tex_idx: int = LEVEL_TO_INDEX[level] if level < LEVEL_TO_INDEX.size() else 0
		# 84天→最左，1天→最右
		var days_mapped: int = 84 - days
		# Handle：按贴图实际尺寸显示（7×11/7×13/7×15 三种），避免拉伸
		var tex: Texture2D = load(HANDLE_PATHS[tex_idx]) as Texture2D
		if tex:
			var tex_size: Vector2 = tex.get_size()
			var hw: float = tex_size.x
			var hh: float = tex_size.y
			var x: float = BAR_OFFSET_LEFT + days_mapped * PX_PER_DAY - hw / 2.0
			var pos_y: float = BAR_HEIGHT_CENTER - hh / 2.0
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
			# Warning sign（handle 左侧，距 handle 3px，与 handle 水平对齐）
			if sign_on:
				var sign_tex: Texture2D = load(SIGN_RED_PATH) as Texture2D
				if sign_tex:
					var sign_rect := TextureRect.new()
					sign_rect.name = "Sign_%d" % i
					sign_rect.texture = sign_tex
					sign_rect.offset_left = x - SIGN_OFFSET_FROM_HANDLE - SIGN_SIZE
					sign_rect.offset_top = BAR_HEIGHT_CENTER - SIGN_SIZE / 2.0
					sign_rect.offset_right = x - SIGN_OFFSET_FROM_HANDLE
					sign_rect.offset_bottom = BAR_HEIGHT_CENTER + SIGN_SIZE / 2.0
					sign_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					sign_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					_handle_container.add_child(sign_rect)


## 设置预测数据，将 ErosionCore.get_forecast_segments 返回格式转为 handles
## segments: [{"value": int}, ...]，每段对应一天的侵蚀值
## 索引 0 = 1 天后（最右），索引 n-1 = n 天后；84 段时索引 83 = 84 天后（最左）
func set_forecast_data(segments: Array) -> void:
	var new_handles: Array[Vector3] = []
	for i in segments.size():
		var seg: Variant = segments[i]
		if seg is Dictionary:
			var value: int = seg.get("value", 0)
			var level: int = VALUE_TO_LEVEL.get(value, 1)
			var days_from_now: int = i + 1
			new_handles.append(Vector3(days_from_now, level, 0))
	handles = new_handles


func _on_time_updated() -> void:
	if ErosionCore and GameTime:
		var segs := ErosionCore.get_forecast_segments(84, GameTime.get_total_hours())
		set_forecast_data(segs)

extends HBoxContainer
## 可复用的庇护、侵蚀 UI 面板
## 左侧显示当前侵蚀等级，右侧显示未来 3 个月侵蚀变化周期长条
## 长条上使用不同颜色图元表示：下降、上升、大幅度上升、莱卡昂的阴霾
## 随时间流逝，图元向左滚动
## 鼠标悬停左侧侵蚀标识时，在下方显示侵蚀数据来源

@onready var _left: PanelContainer = $Left
@onready var _label_shelter: Label = $Left/LeftVBox/ErosionLabel
@onready var _right: PanelContainer = $Right
@onready var _cycle_bar: Control = $Right/BarMargin/ErosionCycleBar
@onready var _popup: PanelContainer = $Left/LeftVBox/ErosionSourcePopup
@onready var _source_label: Label = $Left/LeftVBox/ErosionSourcePopup/Margin/SourceLabel
@onready var _cycle_popup: PanelContainer = $Right/BarMargin/CycleBarPopup
@onready var _cycle_popup_label: Label = $Right/BarMargin/CycleBarPopup/Margin/CycleBarLabel

var _hide_timer: Timer
var _cycle_hide_timer: Timer
var _was_over: bool = false

func _ready() -> void:
	_hide_timer = Timer.new()
	_hide_timer.one_shot = true
	_hide_timer.timeout.connect(_on_hide_timer_timeout)
	add_child(_hide_timer)
	_cycle_hide_timer = Timer.new()
	_cycle_hide_timer.one_shot = true
	_cycle_hide_timer.timeout.connect(_on_cycle_hide_timer_timeout)
	add_child(_cycle_hide_timer)
	# 将弹出层移至 CanvasLayer 顶层，避免被 TopBar 裁剪（延迟执行，避免 _ready 期间 add_child 失败）
	call_deferred("_reparent_popup_to_canvas_layer")
	_cycle_bar.segment_hovered.connect(_on_cycle_segment_hovered)
	_cycle_bar.segment_hover_ended.connect(_on_cycle_segment_hover_ended)
	_update_display()
	if ErosionCore:
		ErosionCore.erosion_changed.connect(_on_erosion_changed)
	if GameTime:
		GameTime.time_updated.connect(_on_time_updated)
	_left.mouse_entered.connect(_on_left_mouse_entered)
	_left.mouse_exited.connect(_on_left_mouse_exited)
	# 弹出层移出 Left 后需单独处理悬停
	_popup.mouse_entered.connect(_on_popup_mouse_entered)
	_popup.mouse_exited.connect(_on_popup_mouse_exited)


func _reparent_popup_to_canvas_layer() -> void:
	var canvas: CanvasLayer = null
	var node: Node = self
	while node:
		if node is CanvasLayer:
			canvas = node as CanvasLayer
			break
		node = node.get_parent()
	if not canvas:
		return
	_left.get_node("LeftVBox").remove_child(_popup)
	canvas.add_child(_popup)
	_popup.z_index = 100
	# 周期条悬停弹出层同样移至顶层
	_right.get_node("BarMargin").remove_child(_cycle_popup)
	canvas.add_child(_cycle_popup)
	_cycle_popup.z_index = 100
	_cycle_popup.mouse_entered.connect(_on_cycle_popup_mouse_entered)
	_cycle_popup.mouse_exited.connect(_on_cycle_popup_mouse_exited)


func _on_erosion_changed(_new_value: int) -> void:
	_update_display()


func _on_time_updated() -> void:
	_update_display()


func _process(_delta: float) -> void:
	# 轮询兜底：防止 mouse_entered 因层级或主题未触发；弹出层可见时随鼠标更新位置
	if not _left or not _popup:
		return
	var mp := get_viewport().get_mouse_position()
	var over_left := _left.get_global_rect().has_point(mp)
	var over_popup := _popup.visible and _popup.get_global_rect().has_point(mp)
	var over_cycle := _cycle_bar.get_global_rect().has_point(mp)
	var over_cycle_popup := _cycle_popup.visible and _cycle_popup.get_global_rect().has_point(mp)
	var over_any := over_left or over_popup
	if over_any:
		if not _popup.visible:
			_on_left_mouse_entered()
		else:
			_update_popup_position()  # 随鼠标移动更新位置
		_hide_timer.stop()
		_was_over = true
	elif _was_over and _popup.visible:
		_start_hide_timer()
		_was_over = false
	if _cycle_popup.visible and (over_cycle or over_cycle_popup):
		_update_cycle_popup_position()  # 周期条弹出层随鼠标移动


func _update_display() -> void:
	if _label_shelter and ErosionCore:
		_label_shelter.text = ErosionCore.get_shelter_status_name(ErosionCore.current_erosion)


func _on_left_mouse_entered() -> void:
	if not ErosionCore or not _popup or not _source_label:
		return
	_hide_timer.stop()
	_source_label.text = ErosionCore.get_erosion_source_text()
	_popup.visible = true
	_update_popup_position()


func _on_left_mouse_exited() -> void:
	_start_hide_timer()


func _on_popup_mouse_entered() -> void:
	_hide_timer.stop()


func _on_popup_mouse_exited() -> void:
	_start_hide_timer()


func _update_popup_position() -> void:
	call_deferred("_deferred_update_popup_position")


func _deferred_update_popup_position() -> void:
	if not _popup.visible:
		return
	var mp := get_viewport().get_mouse_position()
	var ps := _popup.size
	if ps.x <= 0 or ps.y <= 0:
		ps = _popup.get_combined_minimum_size()
	if ps.x <= 0:
		ps.x = 200
	if ps.y <= 0:
		ps.y = 80
	# 显示在鼠标指针左侧，垂直居中；限制在视口内
	var x := int(mp.x - ps.x - 12)
	var y := int(mp.y - ps.y / 2)
	var vp_size := get_viewport_rect().size
	_popup.position = Vector2i(clampi(x, 4, int(vp_size.x) - int(ps.x) - 4), clampi(y, 4, int(vp_size.y) - int(ps.y) - 4))


func _on_hide_timer_timeout() -> void:
	if _popup:
		_popup.visible = false


func _start_hide_timer() -> void:
	_hide_timer.stop()
	_hide_timer.start(0.15)


func _on_cycle_segment_hovered(days_from_now: int, erosion_value: int) -> void:
	if not ErosionCore or not _cycle_popup or not _cycle_popup_label:
		return
	_cycle_hide_timer.stop()
	var name_str := ErosionCore.get_erosion_name_full(erosion_value)
	_cycle_popup_label.text = tr("EROSION_CYCLE_POPUP") % [days_from_now, name_str, erosion_value]
	_cycle_popup.visible = true
	_update_cycle_popup_position()


func _on_cycle_segment_hover_ended() -> void:
	_cycle_hide_timer.stop()
	_cycle_hide_timer.start(0.15)


func _on_cycle_popup_mouse_entered() -> void:
	_cycle_hide_timer.stop()


func _on_cycle_popup_mouse_exited() -> void:
	_cycle_hide_timer.start(0.15)


func _on_cycle_hide_timer_timeout() -> void:
	if _cycle_popup:
		_cycle_popup.visible = false


func _update_cycle_popup_position() -> void:
	call_deferred("_deferred_update_cycle_popup_position")


func _deferred_update_cycle_popup_position() -> void:
	if not _cycle_popup.visible:
		return
	var mp := get_viewport().get_mouse_position()
	var ps := _cycle_popup.size
	if ps.x <= 0 or ps.y <= 0:
		ps = _cycle_popup.get_combined_minimum_size()
	if ps.x <= 0:
		ps.x = 220
	if ps.y <= 0:
		ps.y = 60
	# 显示在鼠标指针左侧，垂直居中；限制在视口内
	var x := int(mp.x - ps.x - 12)
	var y := int(mp.y - ps.y / 2)
	var vp_size := get_viewport_rect().size
	_cycle_popup.position = Vector2i(clampi(x, 4, int(vp_size.x) - int(ps.x) - 4), clampi(y, 4, int(vp_size.y) - int(ps.y) - 4))

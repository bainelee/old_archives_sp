extends CanvasLayer
## 清理模式 UI 覆盖层 - 悬停面板、确认按钮、多房间进度环
## 由 GameMain 驱动，根据清理状态显示/隐藏

@onready var _dim_overlay: Control = $DimOverlay
@onready var _blocked_ui_overlay: Control = $BlockedUIOverlay
@onready var _hint_panel: Control = $HintPanel
@onready var _hover_panel: PanelContainer = $CleanupHoverPanel
@onready var _confirm_container: Control = $ConfirmContainer
@onready var _confirm_button: Button = $ConfirmContainer/ConfirmButton
@onready var _progress_ring: Control = $ConfirmContainer/ProgressRing
var _progress_rings_container: Control

const PROGRESS_RING_SCRIPT := preload("res://scripts/ui/cleanup_progress_ring.gd")
var _progress_rings: Dictionary = {}  ## room_index -> Control

var _confirm_room_screen_pos: Vector2 = Vector2.ZERO
const CONFIRM_SIZE := 80
const PROGRESS_RING_SIZE := 80
const PROGRESS_RING_RADIUS := 40.0


func _ready() -> void:
	layer = 11
	_progress_rings_container = get_node_or_null("ProgressRingsContainer") as Control
	_confirm_container.visible = false
	_progress_ring.visible = false
	_confirm_button.visible = true
	_confirm_button.text = "✓"
	_confirm_button.pressed.connect(_on_confirm_pressed)


func _on_confirm_pressed() -> void:
	if has_signal("confirm_cleanup_pressed"):
		confirm_cleanup_pressed.emit()


signal confirm_cleanup_pressed


func get_hover_panel() -> PanelContainer:
	return _hover_panel


func show_hover_for_room(room: RoomInfo, player_resources: Dictionary, can_afford: bool, researchers_needed: int = 0, researchers_available: int = 0) -> void:
	if _hover_panel.has_method("show_for_room"):
		_hover_panel.show_for_room(room, player_resources, can_afford, researchers_needed, researchers_available)


func hide_hover() -> void:
	if _hover_panel.has_method("hide_panel"):
		_hover_panel.hide_panel()


func update_hover_position(mouse_pos: Vector2, viewport_size: Vector2) -> void:
	if _hover_panel.visible and _hover_panel.has_method("update_position"):
		_hover_panel.update_position(mouse_pos, viewport_size)


func show_confirm_at(screen_pos: Vector2) -> void:
	_confirm_room_screen_pos = screen_pos
	_confirm_container.position = screen_pos - Vector2(CONFIRM_SIZE / 2.0, CONFIRM_SIZE / 2.0)
	_confirm_container.visible = true
	_confirm_button.visible = true
	_progress_ring.visible = false


func hide_confirm() -> void:
	_confirm_container.visible = false


func show_cleanup_selecting_ui() -> void:
	## 显示 30% 黑遮罩、提示文案、禁用其余 UI 的覆盖层
	if _dim_overlay:
		_dim_overlay.visible = true
	if _blocked_ui_overlay:
		_blocked_ui_overlay.visible = true
	if _hint_panel:
		_hint_panel.visible = true


func hide_cleanup_selecting_ui() -> void:
	if _dim_overlay:
		_dim_overlay.visible = false
	if _blocked_ui_overlay:
		_blocked_ui_overlay.visible = false
	if _hint_panel:
		_hint_panel.visible = false


func show_progress_at(screen_pos: Vector2, ratio: float) -> void:
	_confirm_room_screen_pos = screen_pos
	_confirm_container.position = screen_pos - Vector2(PROGRESS_RING_RADIUS, PROGRESS_RING_RADIUS)
	_confirm_container.visible = true
	_confirm_button.visible = false
	_progress_ring.visible = true
	_progress_ring.set("progress_ratio", clampf(ratio, 0.0, 1.0))
	_progress_ring.queue_redraw()


func update_progress_rooms(rooms_data: Array) -> void:
	if not _progress_rings_container:
		return
	var active_ids: Dictionary = {}
	for item in rooms_data:
		if item is Dictionary:
			var rid: int = int(item.get("room_index", -1))
			var pos: Vector2 = item.get("position", Vector2.ZERO)
			var ratio: float = clampf(float(item.get("ratio", 0)), 0.0, 1.0)
			active_ids[rid] = true
			if not _progress_rings.has(rid):
				var new_ring: Control = Control.new()
				new_ring.set_script(PROGRESS_RING_SCRIPT)
				new_ring.custom_minimum_size = Vector2(PROGRESS_RING_SIZE, PROGRESS_RING_SIZE)
				new_ring.set_anchors_preset(Control.PRESET_TOP_LEFT)
				new_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不阻挡房间点击
				_progress_rings_container.add_child(new_ring)
				_progress_rings[rid] = new_ring
			var r: Control = _progress_rings[rid]
			r.position = pos - Vector2(PROGRESS_RING_RADIUS, PROGRESS_RING_RADIUS)
			r.size = Vector2(PROGRESS_RING_SIZE, PROGRESS_RING_SIZE)
			r.set("progress_ratio", ratio)
			r.visible = true
			r.queue_redraw()
	for rid in _progress_rings.duplicate().keys():
		if not active_ids.has(rid):
			_progress_rings[rid].queue_free()
			_progress_rings.erase(rid)
	_progress_ring.visible = false
	# 不触碰确认按钮：进度环与确认可同时存在（清理房间 A 时仍可对房间 B 显示 ✓）


func hide_progress() -> void:
	## 仅清除进度环，不触碰确认按钮（由 show_confirm_at/hide_confirm 管理）
	for rid in _progress_rings.duplicate().keys():
		_progress_rings[rid].queue_free()
	_progress_rings.clear()


func _process(_delta: float) -> void:
	for ring in _progress_rings.values():
		ring.queue_redraw()

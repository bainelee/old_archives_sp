extends CanvasLayer
## 清理模式 UI 覆盖层 - 悬停面板、确认按钮、多房间进度环
## 由 GameMain 驱动，根据清理状态显示/隐藏

@onready var _dim_overlay: Control = $DimOverlay
@onready var _blocked_ui_overlay: Control = $BlockedUIOverlay
@onready var _hint_panel: Control = $HintPanel
@onready var _hint_title: Label = $HintPanel/Title
@onready var _hint_sub: Label = $HintPanel/Sub
@onready var _hover_panel: PanelContainer = $CleanupHoverPanel
@onready var _confirm_container: Control = $ConfirmContainer
@onready var _confirm_button: Button = $ConfirmContainer/ConfirmButton
@onready var _progress_ring: Control = $ConfirmContainer/ProgressRing
var _progress_rings_container: Control

var _progress_rings: Dictionary = {}  ## room_index -> Control

var _confirm_room_screen_pos: Vector2 = Vector2.ZERO
const CONFIRM_SIZE := 80


func _ready() -> void:
	## 清理模式时 is_flowing=false 会触发 tree.paused，覆盖层需 ALWAYS 以便用户可操作
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 11
	_progress_rings_container = get_node_or_null("ProgressRingsContainer") as Control
	_confirm_container.visible = false
	_progress_ring.visible = false
	_confirm_button.visible = true
	_confirm_button.text = tr("BTN_CONFIRM")
	if _hint_title:
		_hint_title.text = tr("CLEANUP_SELECT")
	if _hint_sub:
		_hint_sub.text = tr("CLEANUP_RIGHT_CANCEL")
	_confirm_button.pressed.connect(_on_confirm_pressed)


func _on_confirm_pressed() -> void:
	if has_signal("confirm_cleanup_pressed"):
		confirm_cleanup_pressed.emit()


signal confirm_cleanup_pressed


func get_hover_panel() -> PanelContainer:
	return _hover_panel


func show_hover_for_room(room: ArchivesRoomInfo, player_resources: Dictionary, can_afford: bool, researchers_needed: int = 0, researchers_available: int = 0) -> void:
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


func update_confirm_position(screen_pos: Vector2) -> void:
	## 镜头缩放/平移时同步更新确认按钮位置，使其跟随房间
	if _confirm_container.visible:
		_confirm_room_screen_pos = screen_pos
		_confirm_container.position = screen_pos - Vector2(CONFIRM_SIZE / 2.0, CONFIRM_SIZE / 2.0)


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
	_confirm_container.position = screen_pos - Vector2(ProgressRingOverlayHelper.PROGRESS_RING_RADIUS, ProgressRingOverlayHelper.PROGRESS_RING_RADIUS)
	_confirm_container.visible = true
	_confirm_button.visible = false
	_progress_ring.visible = true
	_progress_ring.set("progress_ratio", clampf(ratio, 0.0, 1.0))
	_progress_ring.queue_redraw()


func update_progress_rooms(rooms_data: Array) -> void:
	ProgressRingOverlayHelper.update_progress_rooms(_progress_rings_container, _progress_rings, rooms_data)
	_progress_ring.visible = false
	# 不触碰确认按钮：进度环与确认可同时存在（清理房间 A 时仍可对房间 B 显示 ✓）


func hide_progress() -> void:
	## 仅清除进度环，不触碰确认按钮（由 show_confirm_at/hide_confirm 管理）
	ProgressRingOverlayHelper.hide_progress(_progress_rings)


func _process(_delta: float) -> void:
	## 每帧从 3D 场景重算房间在屏幕上的位置，使镜头平移/缩放时（含暂停时）进度条、确认按钮、悬停面板仍正确跟随
	var gm: Node2D = get_parent() as Node2D
	var vp: Viewport = get_viewport() if gm else null
	if _hover_panel.visible and vp:
		update_hover_position(vp.get_mouse_position(), vp.get_visible_rect().size)
	if gm and gm.has_method("_room_center_to_screen"):
		if _confirm_container.visible:
			var confirm_idx: int = int(gm.get("_cleanup_confirm_room_index"))
			if confirm_idx >= 0:
				var pos: Vector2 = gm.call("_room_center_to_screen", confirm_idx)
				_confirm_container.position = pos - Vector2(CONFIRM_SIZE / 2.0, CONFIRM_SIZE / 2.0)
		for rid in _progress_rings:
			var pos: Vector2 = gm.call("_room_center_to_screen", rid)
			var r: Control = _progress_rings[rid]
			r.position = pos - Vector2(ProgressRingOverlayHelper.PROGRESS_RING_RADIUS, ProgressRingOverlayHelper.PROGRESS_RING_RADIUS)
			r.queue_redraw()
	else:
		for ring in _progress_rings.values():
			ring.queue_redraw()

extends CanvasLayer
## 建设模式 UI 覆盖层 - 分类 tag、区域按钮、悬停面板、确认按钮、多房间进度环
## 由 GameMain 驱动，根据建设状态显示/隐藏

const ZoneTypeScript = preload("res://scripts/core/zone_type.gd")

signal confirm_construction_pressed
signal zone_selected(zone_type: int)

@onready var _dim_overlay: Control = $DimOverlay
@onready var _blocked_ui_overlay: Control = $BlockedUIOverlay
@onready var _category_tags: Control = $ConstructionCategoryTags
@onready var _zone_buttons: Control = $ConstructionZoneButtons
@onready var _hover_panel: PanelContainer = $ConstructionHoverPanel
@onready var _confirm_container: Control = $ConfirmContainer
@onready var _confirm_button: Button = $ConfirmContainer/ConfirmButton
var _progress_rings_container: Control

const PROGRESS_RING_SCRIPT := preload("res://scripts/ui/cleanup_progress_ring.gd")
var _progress_rings: Dictionary = {}  ## room_index -> Control

var _confirm_room_screen_pos: Vector2 = Vector2.ZERO
const CONFIRM_SIZE := 80
const PROGRESS_RING_SIZE := 80
const PROGRESS_RING_RADIUS := 40.0

## 分类 -> 区域列表（当前实现的区域）
var _category_zones: Dictionary = {
	ZoneTypeScript.CATEGORY_WORK: [1, 2, 3],  ## RESEARCH, CREATION, OFFICE
	ZoneTypeScript.CATEGORY_LOGISTICS: [4],   ## LIVING
	ZoneTypeScript.CATEGORY_MYSTERY: [],
}
var _current_category: String = ZoneTypeScript.CATEGORY_WORK


func _ready() -> void:
	layer = 11
	_progress_rings_container = get_node_or_null("ProgressRingsContainer") as Control
	_confirm_container.visible = false
	_confirm_button.visible = true
	_confirm_button.text = tr("BTN_CONFIRM")
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_setup_category_tags()
	_show_zone_buttons_for_category(_current_category)


func _setup_category_tags() -> void:
	if not _category_tags or not _category_tags is HBoxContainer:
		return
	for cat in [ZoneTypeScript.CATEGORY_WORK, ZoneTypeScript.CATEGORY_LOGISTICS, ZoneTypeScript.CATEGORY_MYSTERY]:
		var btn: Button = Button.new()
		btn.text = ZoneTypeScript.get_category_display_name(cat)
		btn.pressed.connect(_on_category_tag_pressed.bind(cat))
		_category_tags.add_child(btn)


func _on_category_tag_pressed(cat: String) -> void:
	_current_category = cat
	_show_zone_buttons_for_category(cat)
	zone_selected.emit(0)  ## 切换分类时清除选中的区域


func _show_zone_buttons_for_category(cat: String) -> void:
	if not _zone_buttons or not _zone_buttons is HBoxContainer:
		return
	for c in _zone_buttons.get_children():
		c.queue_free()
	var zones: Array = _category_zones.get(cat, [])
	for z in zones:
		var btn: Button = Button.new()
		btn.text = ZoneTypeScript.get_zone_name(z)
		btn.custom_minimum_size = Vector2(120, 48)
		btn.pressed.connect(_on_zone_button_pressed.bind(z))
		_zone_buttons.add_child(btn)


func _on_zone_button_pressed(zone_type: int) -> void:
	zone_selected.emit(zone_type)


func _on_confirm_pressed() -> void:
	confirm_construction_pressed.emit()


func show_construction_selecting_ui() -> void:
	if _dim_overlay:
		_dim_overlay.visible = true
	if _blocked_ui_overlay:
		_blocked_ui_overlay.visible = true
	if _category_tags:
		_category_tags.visible = true
	if _zone_buttons:
		_zone_buttons.visible = true


func hide_construction_selecting_ui() -> void:
	if _dim_overlay:
		_dim_overlay.visible = false
	if _blocked_ui_overlay:
		_blocked_ui_overlay.visible = false
	if _category_tags:
		_category_tags.visible = false
	if _zone_buttons:
		_zone_buttons.visible = false


func show_hover_for_room(room: RoomInfo, zone_type: int, player_resources: Dictionary, can_afford: bool, researchers_needed: int = 0, researchers_available: int = 0) -> void:
	if _hover_panel.has_method("show_for_room"):
		_hover_panel.show_for_room(room, zone_type, player_resources, can_afford, researchers_needed, researchers_available)


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


func update_confirm_position(screen_pos: Vector2) -> void:
	if _confirm_container.visible:
		_confirm_container.position = screen_pos - Vector2(CONFIRM_SIZE / 2.0, CONFIRM_SIZE / 2.0)


func hide_confirm() -> void:
	_confirm_container.visible = false


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
				new_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func hide_progress() -> void:
	for rid in _progress_rings.duplicate().keys():
		_progress_rings[rid].queue_free()
	_progress_rings.clear()

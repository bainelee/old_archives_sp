extends CanvasLayer
## 建设模式 UI 覆盖层 - 分类 tag、区域按钮、悬停面板、确认按钮、多房间进度环
## 由 GameMain 驱动，根据建设状态显示/隐藏

const ZoneTypeScript = preload("res://scripts/core/zone_type.gd")
const _GameValuesRef := preload("res://scripts/core/game_values_ref.gd")

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

var _progress_rings: Dictionary = {}  ## room_index -> Control

var _confirm_room_screen_pos: Vector2 = Vector2.ZERO
const CONFIRM_SIZE := 80

## 分类 -> 区域列表（从配置读取，zone_extensions.enabled 控制 5-8 是否显示）
var _category_zones: Dictionary = {}
var _current_category: String = ZoneTypeScript.CATEGORY_WORK


func _build_category_zones() -> void:
	_category_zones = {
		ZoneTypeScript.CATEGORY_WORK: [1, 2, 3],
		ZoneTypeScript.CATEGORY_LOGISTICS: [4],
		ZoneTypeScript.CATEGORY_MYSTERY: [],
	}
	var gv: Node = _GameValuesRef.get_singleton()
	if gv and gv.has_method("get_zone_extension_configs"):
		var exts: Dictionary = gv.get_zone_extension_configs()
		for zone_key in exts:
			var zt: int = int(zone_key)
			if zt < 5 or zt > 8:
				continue
			if not gv.is_zone_extension_enabled(zt):
				continue
			var cat: String = ZoneTypeScript.get_category_for_zone(zt)
			if not _category_zones.has(cat):
				_category_zones[cat] = []
			if zt not in _category_zones[cat]:
				_category_zones[cat].append(zt)


func _ready() -> void:
	## 建设模式时 is_flowing=false 会触发 tree.paused，覆盖层需 ALWAYS 以便用户可操作
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_category_zones()
	var gv: Node = _GameValuesRef.get_singleton()
	if gv and gv.has_signal("config_reloaded"):
		gv.config_reloaded.connect(_on_config_reloaded)
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


func _on_config_reloaded() -> void:
	_build_category_zones()
	_show_zone_buttons_for_category(_current_category)


func _on_category_tag_pressed(cat: String) -> void:
	_current_category = cat
	_show_zone_buttons_for_category(cat)
	zone_selected.emit(0)  ## 切换分类时清除选中的区域


func _show_zone_buttons_for_category(cat: String) -> void:
	if not _zone_buttons or not _zone_buttons is HBoxContainer:
		return
	for c in _zone_buttons.get_children():
		_zone_buttons.remove_child(c)
		c.free()
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
	_build_category_zones()
	_show_zone_buttons_for_category(_current_category)
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


func show_hover_for_room(room: ArchivesRoomInfo, zone_type: int, player_resources: Dictionary, can_afford: bool, researchers_needed: int = 0, researchers_available: int = 0) -> void:
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
	ProgressRingOverlayHelper.update_progress_rooms(_progress_rings_container, _progress_rings, rooms_data)


func hide_progress() -> void:
	ProgressRingOverlayHelper.hide_progress(_progress_rings)


func _process(_delta: float) -> void:
	## 每帧从 3D 场景重算房间在屏幕上的位置，使镜头平移/缩放时（含暂停时）进度条、确认按钮、悬停面板仍正确跟随
	var gm: Node2D = get_parent() as Node2D
	var vp: Viewport = get_viewport() if gm else null
	if _hover_panel.visible and vp:
		update_hover_position(vp.get_mouse_position(), vp.get_visible_rect().size)
	if gm and gm.has_method("_room_center_to_screen"):
		if _confirm_container.visible:
			var confirm_idx: int = int(gm.get("_construction_confirm_room_index"))
			if confirm_idx >= 0:
				var pos: Vector2 = gm.call("_room_center_to_screen", confirm_idx)
				_confirm_container.position = pos - Vector2(CONFIRM_SIZE / 2.0, CONFIRM_SIZE / 2.0)
		for rid in _progress_rings:
			var pos: Vector2 = gm.call("_room_center_to_screen", rid)
			var r: Control = _progress_rings[rid]
			r.position = pos - Vector2(ProgressRingOverlayHelper.PROGRESS_RING_RADIUS, ProgressRingOverlayHelper.PROGRESS_RING_RADIUS)
			r.queue_redraw()

extends Node2D

## 游戏主场景 - 展示存档槽位，通过 SaveManager 加载完整游戏状态
## 主场景入口：加载 slot_0（或后续由主菜单指定槽位）并渲染
## 模块拆分：绘制/存档/清理/建设/已建设产出/镜头/输入 见 game_main_*.gd

const GRID_WIDTH := 80
const GRID_HEIGHT := 60
const CELL_SIZE := 20
const DEFAULT_SLOT := 0

var _tiles: Array[Array] = []
var _current_slot: int = 0
var _rooms: Array = []
var _base_image_cache: Dictionary = {}
var _camera: Camera2D
var _is_panning := false
var _pan_start := Vector2.ZERO

## 房间选择系统
var _hovered_room_index := -1
var _selected_room_index := -1

## 镜头聚焦缓动
var _focus_room_index := -1
var _focus_tween: Tween = null

## 清理房间模式（支持多房间同时清理）
enum CleanupMode { NONE, SELECTING, CONFIRMING, CLEANING }
var _cleanup_mode: CleanupMode = CleanupMode.NONE
var _cleanup_confirm_room_index := -1
var _cleanup_rooms_in_progress: Dictionary = {}
var _time_was_flowing_before_cleanup := false

## 建设模式（11-zone-construction）
enum ConstructionMode { NONE, SELECTING_ZONE, SELECTING_TARGET, CONFIRMING }
var _construction_mode: ConstructionMode = ConstructionMode.NONE
var _construction_selected_zone: int = 0
var _construction_confirm_room_index := -1
var _construction_rooms_in_progress: Dictionary = {}
var _time_was_flowing_before_construction := false

## 已建设房间产出
var _built_room_production_accumulator: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_setup_grid()
	var slot: int = DEFAULT_SLOT
	if SaveManager.pending_load_slot >= 0:
		slot = SaveManager.pending_load_slot
		SaveManager.pending_load_slot = -1
	_load_from_slot(slot)
	GameMainCameraHelper.setup_camera(self)
	call_deferred("_ensure_cognition_provider_registered")
	call_deferred("_setup_cleanup_mode")
	call_deferred("_setup_construction_mode")
	queue_redraw()


func _setup_grid() -> void:
	_tiles.clear()
	for x in GRID_WIDTH:
		var col: Array[int] = []
		for y in GRID_HEIGHT:
			col.append(FloorTileType.Type.EMPTY)
		_tiles.append(col)


func _load_from_slot(slot: int) -> void:
	_current_slot = slot
	var game_state: Variant = SaveManager.load_from_slot(slot)
	if game_state == null:
		print("游戏主场景：槽位 %d 无存档，显示空白网格" % [slot + 1])
		return
	if not (game_state is Dictionary):
		return
	var d: Dictionary = game_state as Dictionary
	GameMainSaveHelper.apply_map(self, d)
	GameMainSaveHelper.apply_time(d)
	GameMainSaveHelper.apply_resources(self, d)
	print("游戏主场景：已加载槽位 %d" % [slot + 1])


func collect_game_state() -> Dictionary:
	return GameMainSaveHelper.collect_game_state(self)


func _process(delta: float) -> void:
	var overlay: Node = _get_cleanup_overlay()
	var construction_overlay: Node = _get_construction_overlay()
	GameMainCleanupHelper.process_overlay(self, overlay, delta)
	GameMainConstructionHelper.process_overlay(self, construction_overlay, delta)
	if GameTime and GameTime.is_flowing:
		var game_hours_delta: float = (delta / GameTime.REAL_SECONDS_PER_GAME_HOUR) * GameTime.speed_multiplier
		GameMainBuiltRoomHelper.process_production(self, game_hours_delta)
	_sync_cleanup_researchers_to_ui()
	_sync_construction_researchers_to_ui()
	queue_redraw()


func _draw() -> void:
	GameMainDrawHelper.draw_all(self, self)


func _input(event: InputEvent) -> void:
	GameMainInputHelper.process_input(self, event)


func _room_center_to_screen(room_index: int) -> Vector2:
	if room_index < 0 or room_index >= _rooms.size():
		return Vector2.ZERO
	var room: RoomInfo = _rooms[room_index]
	var world_center: Vector2 = Vector2(
		(room.rect.position.x + room.rect.size.x / 2.0) * CELL_SIZE,
		(room.rect.position.y + room.rect.size.y / 2.0) * CELL_SIZE
	)
	return get_viewport().get_canvas_transform() * world_center


func _get_mouse_grid() -> Vector2i:
	var viewport: Viewport = get_viewport()
	var mouse_pos: Vector2 = viewport.get_mouse_position()
	var world: Vector2 = viewport.get_canvas_transform().affine_inverse() * mouse_pos
	var gx: int = int(world.x / CELL_SIZE)
	var gy: int = int(world.y / CELL_SIZE)
	return Vector2i(clampi(gx, 0, GRID_WIDTH - 1), clampi(gy, 0, GRID_HEIGHT - 1))


func _get_room_at_grid(gx: int, gy: int) -> int:
	for i in _rooms.size():
		var room: RoomInfo = _rooms[i]
		if room.rect.has_point(Vector2i(gx, gy)):
			return i
	return -1


func _get_player_resources() -> Dictionary:
	var ui: Node = get_node_or_null("UIMain")
	if not ui or not ui.has_method("get_resources"):
		return {}
	var res: Dictionary = ui.get_resources()
	var out: Dictionary = {}
	out.merge(res.get("factors", {}))
	out.merge(res.get("currency", {}))
	var personnel: Dictionary = res.get("personnel", {})
	out["researcher"] = personnel.get("researcher", 0)
	out["eroded"] = personnel.get("eroded", 0)
	return out


func _get_cleanup_overlay() -> Node:
	return get_node_or_null("CleanupOverlay")


func _get_construction_overlay() -> Node:
	return get_node_or_null("ConstructionOverlay")


func _grant_room_resources_to_player(room: RoomInfo) -> void:
	var ui: Node = get_node_or_null("UIMain")
	if not ui:
		return
	for r in room.resources:
		if not (r is Dictionary):
			continue
		var rt: int = int(r.get("resource_type", RoomInfo.ResourceType.NONE))
		var amt: int = int(r.get("resource_amount", 0))
		if rt == RoomInfo.ResourceType.NONE or amt <= 0:
			continue
		match rt:
			RoomInfo.ResourceType.COGNITION:
				ui.cognition_amount = ui.cognition_amount + amt
			RoomInfo.ResourceType.COMPUTATION:
				ui.computation_amount = ui.computation_amount + amt
			RoomInfo.ResourceType.WILL:
				ui.will_amount = ui.will_amount + amt
			RoomInfo.ResourceType.PERMISSION:
				ui.permission_amount = ui.permission_amount + amt
			RoomInfo.ResourceType.INFO:
				ui.info_amount = ui.info_amount + amt
			RoomInfo.ResourceType.TRUTH:
				ui.truth_amount = ui.truth_amount + amt
	_sync_resources_to_topbar()


func _sync_resources_to_topbar() -> void:
	var ui: Node = get_node_or_null("UIMain")
	if not ui or not ui.has_method("refresh_display"):
		return
	ui.refresh_display()


func _sync_cleanup_researchers_to_ui() -> void:
	var ui: Node = get_node_or_null("UIMain")
	if not ui or ui.get("researchers_in_cleanup") == null:
		return
	ui.researchers_in_cleanup = GameMainCleanupHelper.get_cleanup_researchers_occupied(self)


func _sync_construction_researchers_to_ui() -> void:
	var ui: Node = get_node_or_null("UIMain")
	if not ui or ui.get("researchers_in_construction") == null:
		return
	ui.researchers_in_construction = GameMainConstructionHelper.get_construction_researchers_occupied(self)


func _sync_researchers_working_in_rooms_to_ui() -> void:
	var total: int = 0
	for room in _rooms:
		if room.zone_type != 0:
			total += room.get_construction_researcher_count(room.zone_type)
	var ui: Node = get_node_or_null("UIMain")
	if ui and ui.get("researchers_working_in_rooms") != null:
		ui.researchers_working_in_rooms = total


func _ensure_cognition_provider_registered() -> void:
	var ui: Node = get_node_or_null("UIMain")
	if ui and PersonnelErosionCore:
		_register_cognition_provider(ui)


func _register_cognition_provider(ui: Node) -> void:
	if not PersonnelErosionCore:
		return
	if ui.get("cognition_amount") != null:
		PersonnelErosionCore.register_cognition_provider(
			func() -> int: return int(ui.get("cognition_amount")),
			func(amt: int) -> void: ui.set("cognition_amount", maxi(0, amt))
		)


func _on_personnel_updated() -> void:
	var ui: Node = get_node_or_null("UIMain")
	if ui and ui.has_method("set_resources") and PersonnelErosionCore:
		var res: Dictionary = ui.get_resources() if ui.has_method("get_resources") else {}
		var factors: Dictionary = res.get("factors", {})
		var currency: Dictionary = res.get("currency", {})
		var personnel: Dictionary = PersonnelErosionCore.get_personnel()
		ui.set_resources(factors, currency, personnel)


func _focus_camera_on_room(room_index: int) -> void:
	GameMainCameraHelper.focus_camera_on_room(self, room_index)


func _on_focus_tween_finished() -> void:
	_focus_tween = null
	_focus_room_index = -1
	if _camera:
		_camera.position.x = roundf(_camera.position.x)
		_camera.position.y = roundf(_camera.position.y)


func _clear_room_selection() -> void:
	_selected_room_index = -1
	_hide_room_detail()
	queue_redraw()


func _show_room_detail(room: RoomInfo) -> void:
	var panel: Node = get_node_or_null("RoomDetailPanel")
	if panel and panel.has_method("show_room"):
		panel.show_room(room)


func _hide_room_detail() -> void:
	var panel: Node = get_node_or_null("RoomDetailPanel")
	if panel and panel.has_method("hide_panel"):
		panel.hide_panel()


func _setup_cleanup_mode() -> void:
	var overlay: Node = get_node_or_null("CleanupOverlay")
	if overlay and overlay.has_signal("confirm_cleanup_pressed"):
		overlay.confirm_cleanup_pressed.connect(_on_cleanup_confirm_pressed)
	var btn: Button = get_node_or_null("UIMain/BottomRightBar/BtnCleanup") as Button
	if btn:
		btn.pressed.connect(_on_cleanup_button_pressed)
	else:
		var ui: Node = get_node_or_null("UIMain")
		if ui and ui.has_signal("cleanup_button_pressed"):
			ui.cleanup_button_pressed.connect(_on_cleanup_button_pressed)


func _on_cleanup_button_pressed() -> void:
	GameMainCleanupHelper.on_button_pressed(self)


func _on_cleanup_confirm_pressed() -> void:
	GameMainCleanupHelper.on_confirm_pressed(self)


func _setup_construction_mode() -> void:
	var overlay: Node = get_node_or_null("ConstructionOverlay")
	if overlay and overlay.has_signal("confirm_construction_pressed"):
		overlay.confirm_construction_pressed.connect(_on_construction_confirm_pressed)
	if overlay and overlay.has_signal("zone_selected"):
		overlay.zone_selected.connect(_on_construction_zone_selected)
	var ui: Node = get_node_or_null("UIMain")
	if ui and ui.has_signal("build_button_pressed"):
		ui.build_button_pressed.connect(_on_build_button_pressed)


func _on_build_button_pressed() -> void:
	GameMainConstructionHelper.on_build_button_pressed(self)


func _on_construction_zone_selected(zone_type: int) -> void:
	GameMainConstructionHelper.on_zone_selected(self, zone_type)


func _on_construction_confirm_pressed() -> void:
	GameMainConstructionHelper.on_confirm_pressed(self)

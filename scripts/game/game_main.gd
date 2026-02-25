extends Node2D

## 游戏主场景 - 展示存档槽位，通过 SaveManager 加载完整游戏状态
## 主场景入口：加载 slot_0（或后续由主菜单指定槽位）并渲染

const GRID_WIDTH := 80
const GRID_HEIGHT := 60
const CELL_SIZE := 20

const TILE_COLORS := {
	FloorTileType.Type.EMPTY: Color(0.15, 0.15, 0.2),
	FloorTileType.Type.WALL: Color(0.4, 0.4, 0.45),
	FloorTileType.Type.ROOM_FLOOR: Color(0.55, 0.45, 0.35),
}

const SAVE_KEY_TILES := "tiles"
const SAVE_KEY_ROOMS := "rooms"
const KEY_MAP := "map"
const KEY_TIME := "time"
const KEY_RESOURCES := "resources"
const KEY_VERSION := "version"
const KEY_MAP_NAME := "map_name"
const KEY_SAVED_AT_GAME_HOUR := "saved_at_game_hour"
const KEY_EROSION := "erosion"
const KEY_PERSONNEL_EROSION := "personnel_erosion"
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

## 镜头聚焦缓动：目标房间索引，Tween 进行中时有效
var _focus_room_index := -1
var _focus_tween: Tween = null
const FOCUS_DURATION := 0.5
const FOCUS_CENTER_ZONE_SIZE := 150
const FOCUS_CELL_SCREEN_SIZE := 50.0  ## 聚焦时每格在屏幕上显示为 50px，zoom = FOCUS_CELL_SCREEN_SIZE / CELL_SIZE


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_setup_grid()
	var slot: int = DEFAULT_SLOT
	if SaveManager.pending_load_slot >= 0:
		slot = SaveManager.pending_load_slot
		SaveManager.pending_load_slot = -1
	_load_from_slot(slot)
	_setup_camera()
	call_deferred("_ensure_cognition_provider_registered")
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
	_apply_map(d)
	_apply_time(d)
	_apply_resources(d)
	print("游戏主场景：已加载槽位 %d" % [slot + 1])


func collect_game_state() -> Dictionary:
	## 收集当前游戏状态（供暂停菜单保存调用）
	var map_name: String = "存档"
	var tiles_data: Array = []
	for x in GRID_WIDTH:
		var col: Array = []
		for y in GRID_HEIGHT:
			col.append(_tiles[x][y])
		tiles_data.append(col)
	var rooms_data: Array = []
	for room in _rooms:
		rooms_data.append(room.to_dict())
	var next_room_id: int = 1
	for room in _rooms:
		var rid: String = room.json_room_id if room.json_room_id else room.id
		if rid.begins_with("ROOM_"):
			var num: int = int(rid.substr(5))
			next_room_id = max(next_room_id, num + 1)
	var map_data: Dictionary = {
		"grid_width": GRID_WIDTH,
		"grid_height": GRID_HEIGHT,
		"cell_size": CELL_SIZE,
		"tiles": tiles_data,
		"rooms": rooms_data,
		"next_room_id": next_room_id,
		"map_name": map_name,
	}
	var total_hours: int = int(GameTime.get_total_hours()) if GameTime else 0
	var resources: Dictionary = {"factors": {}, "currency": {}, "personnel": {}}
	var ui: Node = get_node_or_null("UIMain")
	if ui and ui.has_method("get_resources"):
		resources = ui.get_resources()
	# 人员数据以 PersonnelErosionCore 为准（侵蚀系统为权威来源）
	if PersonnelErosionCore:
		resources["personnel"] = PersonnelErosionCore.get_personnel()
	var state: Dictionary = {
		KEY_VERSION: 1,
		KEY_MAP_NAME: map_name,
		KEY_SAVED_AT_GAME_HOUR: total_hours,
		KEY_MAP: map_data,
		KEY_TIME: {
			"total_game_hours": total_hours,
			"is_flowing": GameTime.is_flowing if GameTime else true,
			"speed_multiplier": GameTime.speed_multiplier if GameTime else 1.0,
		},
		KEY_RESOURCES: resources,
		KEY_EROSION: {},
	}
	if PersonnelErosionCore:
		state[KEY_PERSONNEL_EROSION] = PersonnelErosionCore.to_save_dict()
	return state


func _apply_map(d: Dictionary) -> void:
	var map_data: Variant = d.get(KEY_MAP, null)
	if map_data == null:
		return
	if not (map_data is Dictionary):
		return
	var m: Dictionary = map_data as Dictionary
	var tiles_data: Array = m.get(SAVE_KEY_TILES, []) as Array
	for x in GRID_WIDTH:
		for y in GRID_HEIGHT:
			_tiles[x][y] = FloorTileType.Type.EMPTY
	for x in min(tiles_data.size(), GRID_WIDTH):
		var col: Variant = tiles_data[x]
		if col is Array:
			for y in min(col.size(), GRID_HEIGHT):
				_tiles[x][y] = int(col[y])
	_rooms.clear()
	var rooms_data: Array = m.get(SAVE_KEY_ROOMS, []) as Array
	for room_dict in rooms_data:
		if room_dict is Dictionary:
			_rooms.append(RoomInfo.from_dict(room_dict as Dictionary))


func _apply_time(d: Dictionary) -> void:
	var time_data: Variant = d.get(KEY_TIME, null)
	if time_data == null or not (time_data is Dictionary):
		return
	var t: Dictionary = time_data as Dictionary
	if GameTime:
		GameTime.set_total_hours(float(t.get("total_game_hours", 0)))
		GameTime.is_flowing = bool(t.get("is_flowing", true))
		GameTime.speed_multiplier = float(t.get("speed_multiplier", 1.0))


func _apply_resources(d: Dictionary) -> void:
	var res_data: Variant = d.get(KEY_RESOURCES, null)
	if res_data == null or not (res_data is Dictionary):
		return
	var r: Dictionary = res_data as Dictionary
	var factors: Dictionary = r.get("factors", {}) as Dictionary
	var currency: Dictionary = r.get("currency", {}) as Dictionary
	var personnel: Dictionary = r.get("personnel", {}) as Dictionary
	var total_hours: float = 0.0
	var time_data: Variant = d.get(KEY_TIME, null)
	if time_data is Dictionary:
		total_hours = float((time_data as Dictionary).get("total_game_hours", 0))
	if PersonnelErosionCore:
		var per_data: Variant = d.get(KEY_PERSONNEL_EROSION, null)
		if per_data is Dictionary and (per_data as Dictionary).has("researchers"):
			PersonnelErosionCore.load_from_save_dict(per_data as Dictionary, personnel)
		else:
			PersonnelErosionCore.initialize_from_personnel(personnel, total_hours)
		PersonnelErosionCore.sync_last_tick()
		personnel = PersonnelErosionCore.get_personnel()
	var ui: Node = get_node_or_null("UIMain")
	if ui and ui.has_method("set_resources"):
		ui.set_resources(factors, currency, personnel)
	if PersonnelErosionCore and ui:
		_register_cognition_provider(ui)
		if not PersonnelErosionCore.personnel_updated.is_connected(_on_personnel_updated):
			PersonnelErosionCore.personnel_updated.connect(_on_personnel_updated)


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


func _setup_camera() -> void:
	_camera = Camera2D.new()
	_camera.name = "Camera2D"
	add_child(_camera)
	_camera.make_current()
	_camera.position_smoothing_enabled = false
	_camera.position = Vector2(GRID_WIDTH * CELL_SIZE / 2.0, GRID_HEIGHT * CELL_SIZE / 2.0)


func _get_base_image_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _base_image_cache.has(path):
		return _base_image_cache[path] as Texture2D
	var tex: Texture2D = load(path) as Texture2D
	if tex:
		_base_image_cache[path] = tex
	return tex


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


func _focus_camera_on_room(room_index: int) -> void:
	if room_index < 0 or room_index >= _rooms.size() or not _camera:
		return
	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()
	var room: RoomInfo = _rooms[room_index]
	var target_pos: Vector2 = Vector2(
		(room.rect.position.x + room.rect.size.x / 2.0) * CELL_SIZE,
		(room.rect.position.y + room.rect.size.y / 2.0) * CELL_SIZE
	)
	var target_zoom: Vector2 = Vector2(FOCUS_CELL_SCREEN_SIZE / float(CELL_SIZE), FOCUS_CELL_SCREEN_SIZE / float(CELL_SIZE))
	_focus_room_index = room_index
	_focus_tween = create_tween()
	_focus_tween.set_ease(Tween.EASE_OUT)
	_focus_tween.set_trans(Tween.TRANS_QUAD)
	_focus_tween.set_parallel(true)
	_focus_tween.tween_property(_camera, "position", target_pos, FOCUS_DURATION)
	_focus_tween.tween_property(_camera, "zoom", target_zoom, FOCUS_DURATION)
	_focus_tween.tween_callback(_on_focus_tween_finished)


func _on_focus_tween_finished() -> void:
	_focus_tween = null
	_focus_room_index = -1
	if _camera:
		_camera.position.x = roundf(_camera.position.x)
		_camera.position.y = roundf(_camera.position.y)


func _is_room_in_center_zone(room_index: int) -> bool:
	if room_index < 0 or room_index >= _rooms.size() or not _camera:
		return false
	var room: RoomInfo = _rooms[room_index]
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var half_zone: int = FOCUS_CENTER_ZONE_SIZE / 2
	var center_zone: Rect2 = Rect2(
		vp_size / 2 - Vector2(half_zone, half_zone),
		Vector2(FOCUS_CENTER_ZONE_SIZE, FOCUS_CENTER_ZONE_SIZE)
	)
	var world_rect: Rect2 = Rect2(
		Vector2(room.rect.position) * float(CELL_SIZE),
		Vector2(room.rect.size) * float(CELL_SIZE)
	)
	var xform: Transform2D = get_viewport().get_canvas_transform()
	var p0: Vector2 = xform * world_rect.position
	var p1: Vector2 = xform * world_rect.end
	var screen_min := Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y))
	var screen_max := Vector2(maxf(p0.x, p1.x), maxf(p0.y, p1.y))
	var screen_rect := Rect2(screen_min, screen_max - screen_min)
	return screen_rect.intersects(center_zone)


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


func _draw_single_base_image(tex: Texture2D, room_rect: Rect2i) -> void:
	var tw: float = tex.get_width()
	var th: float = tex.get_height()
	if tw <= 0 or th <= 0:
		return
	var px: float = room_rect.position.x * CELL_SIZE
	var py: float = room_rect.position.y * CELL_SIZE
	var room_px: Rect2 = Rect2(px, py, room_rect.size.x * CELL_SIZE, room_rect.size.y * CELL_SIZE)
	var img_rect: Rect2 = Rect2(px, py, tw, th)
	var clip: Rect2 = room_px.intersection(img_rect)
	if not clip.has_area():
		return
	var src_rect: Rect2 = Rect2(
		clip.position.x - img_rect.position.x,
		clip.position.y - img_rect.position.y,
		clip.size.x, clip.size.y
	)
	draw_texture_rect_region(tex, clip, src_rect)


func _draw() -> void:
	# 底板（背景图由场景中的 Background Sprite2D 节点绘制，z_index=-100）
	for x in GRID_WIDTH:
		for y in GRID_HEIGHT:
			var tile_type: int = _tiles[x][y] as int
			if tile_type == FloorTileType.Type.EMPTY:
				continue
			var color: Color = TILE_COLORS.get(tile_type, TILE_COLORS[FloorTileType.Type.EMPTY]) as Color
			var rect: Rect2 = Rect2(x * CELL_SIZE, y * CELL_SIZE, CELL_SIZE, CELL_SIZE)
			draw_rect(rect, color)
	# 房间底图
	for room in _rooms:
		if room.base_image_path.is_empty():
			continue
		var tex: Texture2D = _get_base_image_texture(room.base_image_path)
		if tex == null:
			continue
		_draw_single_base_image(tex, room.rect)
	# 房间边框：悬停亮起、选中常亮
	for i in _rooms.size():
		var room: RoomInfo = _rooms[i]
		var r: Rect2i = room.rect
		var px: float = r.position.x * CELL_SIZE
		var py: float = r.position.y * CELL_SIZE
		var pw: float = r.size.x * CELL_SIZE
		var ph: float = r.size.y * CELL_SIZE
		var border_rect: Rect2 = Rect2(px - 2, py - 2, pw + 4, ph + 4)
		if i == _selected_room_index:
			draw_rect(border_rect, Color(1, 0.85, 0.3, 0.95), false)
		elif i == _hovered_room_index:
			draw_rect(border_rect, Color(0.4, 0.75, 1, 0.85), false)


func _input(event: InputEvent) -> void:
	# 中键平移（与场景编辑器相同：使用视口坐标，避免世界坐标反馈导致晃动；取整避免模糊）
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = mb.pressed
			if _is_panning:
				_pan_start = get_viewport().get_mouse_position()
				# 拖动镜头时清除房间选中
				_clear_room_selection()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT and not _is_panning:
			if mb.pressed:
				var grid: Vector2i = _get_mouse_grid()
				var rid: int = _get_room_at_grid(grid.x, grid.y)
				_selected_room_index = rid
				if rid >= 0:
					_focus_camera_on_room(rid)
					_show_room_detail(_rooms[rid])
				else:
					_hide_room_detail()
				queue_redraw()
				get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera.zoom *= 1.1
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.zoom /= 1.1
			get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion:
		if _is_panning and _camera:
			var delta: Vector2 = get_viewport().get_mouse_position() - _pan_start
			_pan_start = get_viewport().get_mouse_position()
			_camera.position -= delta / _camera.zoom
			# 取整摄像机位置，避免像素画因亚像素渲染产生模糊
			_camera.position.x = roundf(_camera.position.x)
			_camera.position.y = roundf(_camera.position.y)
			get_viewport().set_input_as_handled()
		else:
			var grid: Vector2i = _get_mouse_grid()
			var new_hover: int = _get_room_at_grid(grid.x, grid.y)
			if new_hover != _hovered_room_index:
				_hovered_room_index = new_hover
				queue_redraw()

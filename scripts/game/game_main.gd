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
const DEFAULT_SLOT := 0

var _tiles: Array[Array] = []
var _current_slot: int = 0
var _rooms: Array = []
var _base_image_cache: Dictionary = {}
var _camera: Camera2D
var _is_panning := false
var _pan_start := Vector2.ZERO


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_setup_grid()
	var slot: int = DEFAULT_SLOT
	if SaveManager.pending_load_slot >= 0:
		slot = SaveManager.pending_load_slot
		SaveManager.pending_load_slot = -1
	_load_from_slot(slot)
	_setup_camera()
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
	return {
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
	var ui: Node = get_node_or_null("UIMain")
	if ui and ui.has_method("set_resources"):
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


func _input(event: InputEvent) -> void:
	# 中键平移（与场景编辑器相同：使用视口坐标，避免世界坐标反馈导致晃动；取整避免模糊）
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = mb.pressed
			if _is_panning:
				_pan_start = get_viewport().get_mouse_position()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera.zoom *= 1.1
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.zoom /= 1.1
			get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and _is_panning and _camera:
		var delta: Vector2 = get_viewport().get_mouse_position() - _pan_start
		_pan_start = get_viewport().get_mouse_position()
		_camera.position -= delta / _camera.zoom
		# 取整摄像机位置，避免像素画因亚像素渲染产生模糊
		_camera.position.x = roundf(_camera.position.x)
		_camera.position.y = roundf(_camera.position.y)
		get_viewport().set_input_as_handled()

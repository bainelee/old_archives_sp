extends Node2D

## 游戏主场景 - 展示第一个地图槽位，运行时无法唤出场景编辑器
## 主场景入口：加载 user://maps/slot_0.json 并渲染

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
const MAP_SLOTS_DIR := "user://maps/"

var _tiles: Array[Array] = []
var _rooms: Array = []
var _base_image_cache: Dictionary = {}
var _camera: Camera2D
var _is_panning := false
var _pan_start := Vector2.ZERO


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_setup_grid()
	_load_map_from_slot(0)
	_setup_camera()
	queue_redraw()


func _setup_grid() -> void:
	_tiles.clear()
	for x in GRID_WIDTH:
		var col: Array[int] = []
		for y in GRID_HEIGHT:
			col.append(FloorTileType.Type.EMPTY)
		_tiles.append(col)


func _get_slot_path(slot: int) -> String:
	return MAP_SLOTS_DIR + "slot_%d.json" % slot


func _load_map_from_slot(slot: int) -> void:
	var path: String = _get_slot_path(slot)
	if not FileAccess.file_exists(path):
		print("游戏主场景：槽位 1 无地图，显示空白网格")
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("无法打开地图: ", path)
		return
	var json_str: String = file.get_as_text()
	file.close()
	var result: Variant = JSON.parse_string(json_str)
	if not (result is Dictionary):
		push_error("地图 JSON 解析失败: ", path)
		return
	var d: Dictionary = result as Dictionary
	# 加载底板
	for x in GRID_WIDTH:
		for y in GRID_HEIGHT:
			_tiles[x][y] = FloorTileType.Type.EMPTY
	var tiles_data: Array = d.get(SAVE_KEY_TILES, []) as Array
	for x in min(tiles_data.size(), GRID_WIDTH):
		var col: Variant = tiles_data[x]
		if col is Array:
			for y in min(col.size(), GRID_HEIGHT):
				_tiles[x][y] = int(col[y])
	# 加载房间
	_rooms.clear()
	var rooms_data: Array = d.get(SAVE_KEY_ROOMS, []) as Array
	for room_dict in rooms_data:
		if room_dict is Dictionary:
			_rooms.append(RoomInfo.from_dict(room_dict as Dictionary))
	print("游戏主场景：已加载地图 ", path)


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

class_name GameMainCameraHelper
extends RefCounted

## 镜头控制 - 初始化、聚焦房间、缓动
## 中键平移与滚轮缩放在 GameMainInputHelper 中处理

const FOCUS_DURATION := 0.5
const FOCUS_CENTER_ZONE_SIZE := 150
const FOCUS_CELL_SCREEN_SIZE := 50.0


static func setup_camera(game_main: Node2D) -> void:
	var grid_width: int = game_main.get("GRID_WIDTH")
	var grid_height: int = game_main.get("GRID_HEIGHT")
	var cell_size: int = game_main.get("CELL_SIZE")
	var camera: Camera2D = Camera2D.new()
	camera.name = "Camera2D"
	game_main.add_child(camera)
	camera.make_current()
	camera.position_smoothing_enabled = false
	camera.position = Vector2(grid_width * cell_size / 2.0, grid_height * cell_size / 2.0)
	game_main.set("_camera", camera)


static func focus_camera_on_room(game_main: Node2D, room_index: int) -> void:
	var rooms: Array = game_main.get("_rooms")
	var camera: Camera2D = game_main.get("_camera")
	var focus_tween: Tween = game_main.get("_focus_tween")
	var cell_size: int = game_main.get("CELL_SIZE")

	if room_index < 0 or room_index >= rooms.size() or not camera:
		return
	if focus_tween and focus_tween.is_valid():
		focus_tween.kill()
	var room: RoomInfo = rooms[room_index]
	var target_pos: Vector2 = Vector2(
		(room.rect.position.x + room.rect.size.x / 2.0) * cell_size,
		(room.rect.position.y + room.rect.size.y / 2.0) * cell_size
	)
	var target_zoom: Vector2 = Vector2(FOCUS_CELL_SCREEN_SIZE / float(cell_size), FOCUS_CELL_SCREEN_SIZE / float(cell_size))
	game_main.set("_focus_room_index", room_index)
	var tween: Tween = game_main.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_parallel(true)
	tween.tween_property(camera, "position", target_pos, FOCUS_DURATION)
	tween.tween_property(camera, "zoom", target_zoom, FOCUS_DURATION)
	tween.tween_callback(Callable(game_main, "_on_focus_tween_finished"))
	game_main.set("_focus_tween", tween)


static func apply_pan(game_main: Node2D, current_mouse_pos: Vector2) -> void:
	var camera: Camera2D = game_main.get("_camera")
	var pan_start: Vector2 = game_main.get("_pan_start")
	if not camera:
		return
	var delta: Vector2 = current_mouse_pos - pan_start
	game_main.set("_pan_start", current_mouse_pos)
	camera.position -= delta / camera.zoom
	camera.position.x = roundf(camera.position.x)
	camera.position.y = roundf(camera.position.y)


static func apply_zoom(game_main: Node2D, zoom_in: bool) -> void:
	var camera: Camera2D = game_main.get("_camera")
	if not camera:
		return
	if zoom_in:
		camera.zoom *= 1.1
	else:
		camera.zoom /= 1.1


static func is_room_in_center_zone(game_main: Node2D, room_index: int) -> bool:
	var rooms: Array = game_main.get("_rooms")
	var camera: Camera2D = game_main.get("_camera")
	var cell_size: int = game_main.get("CELL_SIZE")
	if room_index < 0 or room_index >= rooms.size() or not camera:
		return false
	var room: RoomInfo = rooms[room_index]
	var vp_size: Vector2 = game_main.get_viewport().get_visible_rect().size
	var half_zone: int = int(FOCUS_CENTER_ZONE_SIZE / 2.0)
	var center_zone: Rect2 = Rect2(
		vp_size / 2 - Vector2(half_zone, half_zone),
		Vector2(FOCUS_CENTER_ZONE_SIZE, FOCUS_CENTER_ZONE_SIZE)
	)
	var world_rect: Rect2 = Rect2(
		Vector2(room.rect.position) * float(cell_size),
		Vector2(room.rect.size) * float(cell_size)
	)
	var xform: Transform2D = game_main.get_viewport().get_canvas_transform()
	var p0: Vector2 = xform * world_rect.position
	var p1: Vector2 = xform * world_rect.end
	var screen_min := Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y))
	var screen_max := Vector2(maxf(p0.x, p1.x), maxf(p0.y, p1.y))
	var screen_rect := Rect2(screen_min, screen_max - screen_min)
	return screen_rect.intersects(center_zone)

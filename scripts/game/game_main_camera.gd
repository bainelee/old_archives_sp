class_name GameMainCameraHelper
extends RefCounted

## 镜头控制 - 初始化、聚焦房间、缓动
## 中键平移与滚轮缩放在 GameMainInputHelper 中处理
## 3D 模式：以场景中 game_main_camera 的 FOV 与位置为基准，滚轮改变镜头距离 (Z)

const FOCUS_DURATION := 0.5
const FOCUS_CENTER_ZONE_SIZE := 150
const FOCUS_CELL_SCREEN_SIZE := 50.0

## 3D 镜头距离：基准 30（与 game_main_camera 初始 z 一致），滚轮缩放时在此范围限制
const CAM3D_DISTANCE_MIN := 5.0
const CAM3D_DISTANCE_MAX := 75.0
const CAM3D_ZOOM_FACTOR := 1.1

## 3D 平移范围随镜头距离线性插值：dist=5 时 X±140/Y±40，dist=75 时 X±75/Y±10
static func _get_cam3d_pan_limits(dist: float) -> Vector2:
	var d: float = clampf(dist, CAM3D_DISTANCE_MIN, CAM3D_DISTANCE_MAX)
	var t: float = (d - CAM3D_DISTANCE_MIN) / (CAM3D_DISTANCE_MAX - CAM3D_DISTANCE_MIN)
	var x_limit: float = lerpf(140.0, 75.0, t)
	var y_limit: float = lerpf(40.0, 10.0, t)
	return Vector2(x_limit, y_limit)


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
	var pan_start: Vector2 = game_main.get("_pan_start")
	var delta: Vector2 = current_mouse_pos - pan_start
	game_main.set("_pan_start", current_mouse_pos)
	var camera3d: Camera3D = game_main.get("_camera3d")
	if camera3d:
		## 3D 平移：沿 XZ 平面移动镜头，速度由 _pan_speed 控制，范围随镜头距离换算
		var raw_ps: Variant = game_main.get("_pan_speed")
		var ps: float = maxf(0.01, float(raw_ps)) if raw_ps != null else 0.02
		var pos: Vector3 = camera3d.global_position
		pos += Vector3(-delta.x * ps, delta.y * ps, 0)
		var limits: Vector2 = _get_cam3d_pan_limits(pos.z)
		pos.x = clampf(pos.x, -limits.x, limits.x)
		pos.y = clampf(pos.y, -limits.y, limits.y)
		camera3d.global_position = pos
		return
	var camera: Camera2D = game_main.get("_camera")
	if not camera:
		return
	var raw_ps2: Variant = game_main.get("_pan_speed")
	var ps2: float = maxf(0.01, float(raw_ps2)) if raw_ps2 != null else 0.02
	camera.position -= (delta / camera.zoom) * ps2
	camera.position.x = roundf(camera.position.x)
	camera.position.y = roundf(camera.position.y)


static func apply_zoom(game_main: Node2D, zoom_in: bool) -> void:
	var camera3d: Camera3D = game_main.get("_camera3d")
	if camera3d:
		var dist: float = game_main.get("_camera_distance")
		if zoom_in:
			dist /= CAM3D_ZOOM_FACTOR
		else:
			dist *= CAM3D_ZOOM_FACTOR
		dist = clampf(dist, CAM3D_DISTANCE_MIN, CAM3D_DISTANCE_MAX)
		game_main.set("_camera_distance", dist)
		var pos: Vector3 = camera3d.global_position
		var limits: Vector2 = _get_cam3d_pan_limits(dist)
		pos.x = clampf(pos.x, -limits.x, limits.x)
		pos.y = clampf(pos.y, -limits.y, limits.y)
		camera3d.global_position = Vector3(pos.x, pos.y, dist)
		return
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

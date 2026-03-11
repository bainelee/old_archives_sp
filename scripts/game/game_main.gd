extends Node2D

## 游戏主场景 - 展示存档槽位，通过 SaveManager 加载完整游戏状态
## 主场景入口：加载 slot_0（或后续由主菜单指定槽位）并渲染
## 模块拆分：绘制/存档/清理/建设/已建设产出/镜头/输入 见 game_main_*.gd

const _GameValuesRef = preload("res://scripts/core/game_values_ref.gd")
const ZoneTypeScript = preload("res://scripts/core/zone_type.gd")
const GRID_WIDTH := 80
const GRID_HEIGHT := 60
const CELL_SIZE := 20
const DEFAULT_SLOT := 0

var _tiles: Array[Array] = []
var _current_slot: int = 0
var _rooms: Array = []

var _base_image_cache: Dictionary = {}
var _camera: Camera2D  ## 2D 备用，若存在 game_main_camera 则主要用 3D
var _camera3d: Camera3D  ## 场景中的 game_main_camera，用于 3D 主视图
var _camera_distance: float = 30.0  ## 3D 镜头与场景中心沿 -Z 的距离，基准与 game_main_camera 初始位置一致
var _pan_speed: float = 0.02  ## 中键拖动镜头时的速度系数，可由 Debug 面板滑块调整
var _is_panning := false
var _pan_start := Vector2.ZERO

## 房间选择系统
var _hovered_room_index := -1
var _selected_room_index := -1
var _room_highlights: Dictionary = {}  ## room_id -> RoomBlockHighlight，3D 悬停高亮
var _room_overlays: Dictionary = {}  ## room_id -> MeshInstance3D，单 cube 按状态切换材质（黑/灰/蓝）
var _room_overlay_mats: Dictionary = {}  ## 预加载的材质引用

## Debug：射线落点可视化（开关由 UI 控制，落点显示 2 秒）
var _debug_hover_locked_rooms := false  ## 开关开启时可悬停未解锁房间
var _debug_show_room_info := false  ## 开关开启时在房间上显示 3D 信息（类型、解锁、清理、资源）
var _room_info_labels: Dictionary = {}  ## room_id -> Label3D
var _debug_show_ray_hit := false
var _debug_ray_marker: MeshInstance3D = null
var _debug_ray_hit_timer: float = 0.0

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

## 庇护能量：核心等级 1～5，存档持久化
var _shelter_level: int = 1
var _shelter_accumulator: float = 0.0

const _CURSOR_IMAGE_PATH := "res://assets/icons/icon_game_cursor_0.png"

func _reset_cursor_to_standard() -> void:
	## 游戏中鼠标指针重置为标准大小（使用项目内箭头图片）
	var cursor_tex: Texture2D = load(_CURSOR_IMAGE_PATH) as Texture2D
	if cursor_tex:
		Input.set_custom_mouse_cursor(cursor_tex, Input.CURSOR_ARROW, Vector2(0, 0))
	else:
		Input.set_custom_mouse_cursor(null)
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)


func _ready() -> void:
	_reset_cursor_to_standard()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_setup_grid()
	var slot: int = DEFAULT_SLOT
	if SaveManager.pending_load_slot >= 0:
		slot = SaveManager.pending_load_slot
		SaveManager.pending_load_slot = -1
	_load_from_slot(slot)
	GameMainCameraHelper.setup_camera(self)
	_setup_camera3d()
	call_deferred("_ensure_cognition_provider_registered")
	call_deferred("_ensure_shelter_resolver_registered")
	call_deferred("_setup_cleanup_mode")
	call_deferred("_setup_construction_mode")
	call_deferred("_setup_room_highlights")
	call_deferred("_setup_room_overlays")
	call_deferred("_setup_room_info_labels")
	call_deferred("_update_room_highlights")
	queue_redraw()


func _setup_camera3d() -> void:
	var cam: Camera3D = get_node_or_null("game_main_camera") as Camera3D
	if cam:
		_camera3d = cam
		_camera_distance = cam.global_position.z
		cam.make_current()


func _setup_room_highlights() -> void:
	var archives: Node3D = get_node_or_null("ArchivesBase0") as Node3D
	if not archives or _rooms.is_empty():
		return
	var scene: PackedScene = load("res://scenes/rooms/room_block_highlight.tscn") as PackedScene
	if not scene:
		return
	for i in _rooms.size():
		var room: RoomInfo = _rooms[i]
		var rid: String = room.id if room.id else room.json_room_id
		if rid.is_empty():
			continue
		var room_node: Node3D = _find_room_node_in_archives(archives, rid)
		if not room_node:
			continue
		var hl: Node = scene.instantiate()
		room_node.add_child(hl)
		_room_highlights[rid] = hl


func _setup_room_overlays() -> void:
	var archives: Node3D = get_node_or_null("ArchivesBase0") as Node3D
	if not archives or _rooms.is_empty():
		return
	var mat_black: Material = load("res://assets/materials/base_materials/mat_room_overlay_black.tres") as Material
	var mat_gray: Material = load("res://assets/materials/base_materials/mat_room_overlay_gray.tres") as Material
	var mat_blue: Material = load("res://assets/materials/base_materials/mat_room_overlay_blue.tres") as Material
	if not mat_black or not mat_gray or not mat_blue:
		return
	_room_overlay_mats["black"] = mat_black
	_room_overlay_mats["gray"] = mat_gray
	_room_overlay_mats["blue"] = mat_blue
	const GRID_SIZE := 0.5
	const THICKNESS_IN := 0.2
	const THICKNESS_OUT := 0.4
	for i in _rooms.size():
		var room: RoomInfo = _rooms[i]
		var rid: String = room.id if room.id else room.json_room_id
		if rid.is_empty():
			continue
		var room_node: Node3D = _find_room_node_in_archives(archives, rid)
		if not room_node:
			continue
		var room_info_3d: RoomInfo3D = room_node.get_node_or_null("RoomInfo") as RoomInfo3D
		if not room_info_3d:
			continue
		var v: Vector3 = room_info_3d.room_volume
		var xR: float = v.x
		var yR: float = v.y
		var zR: float = v.z
		if xR <= 0 or yR <= 0 or zR <= 0:
			continue
		var sz: Vector3 = Vector3(
			GRID_SIZE * xR + THICKNESS_IN + THICKNESS_OUT * 2,
			GRID_SIZE * yR + THICKNESS_IN + THICKNESS_OUT * 2,
			GRID_SIZE * zR + THICKNESS_IN / 2
		)
		var box: BoxMesh = BoxMesh.new()
		box.size = sz
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = box
		mi.material_override = mat_black
		mi.position = Vector3(0, sz.y / 2.0, 0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		room_node.add_child(mi)
		_room_overlays[rid] = mi


func _setup_room_info_labels() -> void:
	var archives: Node3D = get_node_or_null("ArchivesBase0") as Node3D
	if not archives or _rooms.is_empty():
		return
	const GRID_SIZE := 0.5
	const THICKNESS_IN := 0.2
	const THICKNESS_OUT := 0.4
	for i in _rooms.size():
		var room: RoomInfo = _rooms[i]
		var rid: String = room.id if room.id else room.json_room_id
		if rid.is_empty():
			continue
		var room_node: Node3D = _find_room_node_in_archives(archives, rid)
		if not room_node:
			continue
		var room_info_3d: RoomInfo3D = room_node.get_node_or_null("RoomInfo") as RoomInfo3D
		if not room_info_3d:
			continue
		var v: Vector3 = room_info_3d.room_volume
		var xR: float = v.x
		var yR: float = v.y
		var _zR: float = v.z  ## 未用于本次计算（深度方向），加下划线表示刻意未用
		var x_offset: float = (GRID_SIZE * xR + THICKNESS_IN + THICKNESS_OUT) / 2.0
		var sz_y: float = GRID_SIZE * yR + THICKNESS_IN + THICKNESS_OUT * 2
		## 向右、向下偏移，避免被房间边框遮住
		var pos_top_left: Vector3 = Vector3(-x_offset + 0.4, sz_y - 0.8, 0.5)
		var label: Label3D = Label3D.new()
		label.name = "DebugRoomInfoLabel"
		label.font_size = 48
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		label.modulate = Color(0.9, 0.95, 0.85, 1.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label.position = pos_top_left
		label.visible = false
		room_node.add_child(label)
		_room_info_labels[rid] = label


func _format_room_info_text(room: RoomInfo) -> String:
	var type_str: String = RoomInfo.get_room_type_name(room.room_type)
	var unlock_str: String = "已解锁" if room.unlocked else "未解锁"
	var clean_str: String = RoomInfo.get_clean_status_name(room.clean_status)
	var res_parts: Array = []
	for r in room.resources:
		if r is Dictionary:
			var rt: int = int(r.get("resource_type", RoomInfo.ResourceType.NONE))
			var amt: int = int(r.get("resource_amount", 0))
			if rt != RoomInfo.ResourceType.NONE and amt > 0:
				res_parts.append("%s %d" % [RoomInfo.get_resource_type_name(rt), amt])
	var res_str: String = (", ".join(res_parts)) if res_parts.size() > 0 else "无"
	return "类型: %s\n解锁: %s\n清理: %s\n资源: %s" % [type_str, unlock_str, clean_str, res_str]


func _update_room_info_labels() -> void:
	for rid in _room_info_labels:
		var label: Label3D = _room_info_labels[rid] as Label3D
		if not label:
			continue
		label.visible = _debug_show_room_info
		if _debug_show_room_info:
			var room: RoomInfo = null
			for r in _rooms:
				var rinfo: RoomInfo = r as RoomInfo
				var check_rid: String = rinfo.id if rinfo.id else rinfo.json_room_id
				if check_rid == rid:
					room = rinfo
					break
			if room:
				label.text = _format_room_info_text(room)


func _update_room_overlays() -> void:
	var cleanup_mode: int = _cleanup_mode
	var construction_mode: int = _construction_mode
	var in_cleanup_selecting: bool = (cleanup_mode == CleanupMode.SELECTING or cleanup_mode == CleanupMode.CONFIRMING)
	var in_construction_selecting: bool = (construction_mode == ConstructionMode.SELECTING_TARGET or construction_mode == ConstructionMode.CONFIRMING)
	for rid in _room_overlays:
		var mi: MeshInstance3D = _room_overlays[rid] as MeshInstance3D
		if not mi:
			continue
		var room: RoomInfo = null
		var room_index: int = -1
		for j in _rooms.size():
			var rinfo: RoomInfo = _rooms[j] as RoomInfo
			var check_rid: String = rinfo.id if rinfo.id else rinfo.json_room_id
			if check_rid == rid:
				room = rinfo
				room_index = j
				break
		if room == null:
			mi.visible = false
			continue
		var is_cleaning: bool = _cleanup_rooms_in_progress.has(room_index)
		var is_room_constructing: bool = _construction_rooms_in_progress.has(room_index)
		var mat_black: Material = _room_overlay_mats.get("black")
		var mat_gray: Material = _room_overlay_mats.get("gray")
		var mat_blue: Material = _room_overlay_mats.get("blue")
		if in_cleanup_selecting:
			var can_select: bool = room.unlocked and room.clean_status == RoomInfo.CleanStatus.UNCLEANED and not is_cleaning
			mi.visible = true
			mi.material_override = mat_blue if can_select else mat_black
		elif in_construction_selecting:
			var can_select: bool = room.can_build_zone(_construction_selected_zone) and not is_room_constructing
			mi.visible = true
			mi.material_override = mat_blue if can_select else mat_black
		else:
			if room.clean_status == RoomInfo.CleanStatus.CLEANED and room.unlocked:
				mi.visible = false
			else:
				mi.visible = true
				mi.material_override = mat_black if not room.unlocked else mat_gray


func _find_room_node_in_archives(archives: Node3D, room_id: String) -> Node3D:
	var found: Node3D = archives.get_node_or_null("archives_rooms/base_rooms/%s" % room_id) as Node3D
	if found:
		return found
	found = archives.get_node_or_null("archives_rooms/archives_pass/%s" % room_id) as Node3D
	if found:
		return found
	found = archives.get_node_or_null("archives_rooms/hall/%s" % room_id) as Node3D
	if found:
		return found
	return null


## 返回 { room_index: int, position: Vector3 }，无命中时 room_index=-1、position 为射线与平面的近似落点
func _raycast_mouse_3d() -> Dictionary:
	var out: Dictionary = {"room_index": -1, "position": Vector3.ZERO}
	var cam: Camera3D = _camera3d
	if not cam:
		return out
	var vp: Viewport = get_viewport()
	var mouse_pos: Vector2 = vp.get_mouse_position()
	var origin: Vector3 = cam.project_ray_origin(mouse_pos)
	var normal: Vector3 = cam.project_ray_normal(mouse_pos)
	var length: float = 500.0
	var archives: Node3D = get_node_or_null("ArchivesBase0") as Node3D
	if not archives:
		return out
	var space: PhysicsDirectSpaceState3D = archives.get_world_3d().direct_space_state
	if not space:
		return out
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + normal * length)
	query.collision_mask = 1
	query.collide_with_areas = true   # 默认不检测 Area3D，房间高亮用的是 Area3D
	query.collide_with_bodies = false # 只检测 Area，避免被墙体等碰撞体遮挡
	var result: Dictionary = space.intersect_ray(query)
	if result.is_empty():
		## 无命中时用 Y=0 平面求交作为近似落点，便于调试
		var dir: Vector3 = normal
		if abs(dir.y) > 0.0001:
			var t: float = -origin.y / dir.y
			if t > 0:
				out["position"] = origin + dir * t
		else:
			out["position"] = origin + normal * length
		return out
	var hit_pos: Vector3 = result.get("position", origin + normal * length)
	out["position"] = hit_pos
	var collider: Object = result.get("collider")
	if not collider:
		return out
	var area: Area3D = collider as Area3D
	if not area:
		return out
	var hl: Node = area.get_parent()
	var room_node: Node3D = hl.get_parent() as Node3D if hl else null
	if not room_node:
		return out
	var room_id: String = room_node.name
	for i in _rooms.size():
		var room: RoomInfo = _rooms[i]
		var rid: String = room.id if room.id else room.json_room_id
		if rid == room_id:
			## 未解锁房间视为不可悬停（设计：04-room-unlock-adjacency）；Debug 开关开启时可悬停
			if not room.unlocked and not _debug_hover_locked_rooms:
				out["room_index"] = -1
			else:
				out["room_index"] = i
			break
	return out


func _get_room_at_mouse_3d() -> int:
	var r: Dictionary = _raycast_mouse_3d()
	return int(r.get("room_index", -1))


func _update_room_highlights() -> void:
	for rid in _room_highlights:
		var hl: Node = _room_highlights[rid]
		if hl:
			hl.visible = false
	var in_cleanup_selecting: bool = (_cleanup_mode == CleanupMode.SELECTING or _cleanup_mode == CleanupMode.CONFIRMING)
	var in_construction_selecting: bool = (_construction_mode == ConstructionMode.SELECTING_TARGET or _construction_mode == ConstructionMode.CONFIRMING)
	var room_index: int = _hovered_room_index
	if room_index >= 0 and room_index < _rooms.size() and not in_cleanup_selecting and not in_construction_selecting:
		var room: RoomInfo = _rooms[room_index]
		var rid: String = room.id if room.id else room.json_room_id
		var hl: Node = _room_highlights.get(rid) as Node
		if hl:
			hl.visible = true
	_update_room_overlays()
	_update_room_info_labels()
	_update_debug_info()  # 无论是否悬停都更新，悬空时显示 "悬停: -"


func _update_debug_info() -> void:
	var lbl: Label = get_node_or_null("UIMain/DebugInfoPanel/Margin/VBox/Content") as Label
	if not lbl:
		return
	var room_index: int = _hovered_room_index
	if room_index >= 0 and room_index < _rooms.size():
		var room: RoomInfo = _rooms[room_index]
		var rid: String = room.id if room.id else room.json_room_id
		var name_str: String = room.room_name if room.room_name else room.get_display_name()
		lbl.text = "房间: %s\nid: %s" % [name_str, rid]
	else:
		lbl.text = "悬停: -"
	## 镜头缩放距离（3D 模式）
	var dist_lbl: Label = get_node_or_null("UIMain/DebugInfoPanel/Margin/VBox/CameraDistance") as Label
	if dist_lbl:
		if _camera3d:
			var d: float = _camera3d.global_position.z
			dist_lbl.text = "镜头距离: %.1f" % d
		else:
			dist_lbl.text = "镜头距离: --"


func _ensure_debug_ray_marker() -> MeshInstance3D:
	if _debug_ray_marker:
		return _debug_ray_marker
	var archives: Node3D = get_node_or_null("ArchivesBase0") as Node3D
	if not archives:
		return null
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	mi.mesh = sphere
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.2, 0.2, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.3, 0.3)
	mi.material_override = mat
	mi.visible = false
	archives.add_child(mi)
	_debug_ray_marker = mi
	return mi


func _debug_ray_marker_process(delta: float) -> void:
	if _debug_ray_hit_timer > 0:
		_debug_ray_hit_timer -= delta
		if _debug_ray_hit_timer <= 0:
			var m: MeshInstance3D = _debug_ray_marker
			if m:
				m.visible = false


func _update_debug_ray_hit() -> void:
	if not _debug_show_ray_hit:
		return
	var r: Dictionary = _raycast_mouse_3d()
	var pos: Vector3 = r.get("position", Vector3.ZERO)
	var marker: MeshInstance3D = _ensure_debug_ray_marker()
	if marker:
		marker.global_position = pos
		marker.visible = true
		_debug_ray_hit_timer = 2.0  # 每次鼠标移动更新落点，显示 2 秒后隐藏


func set_debug_show_ray_hit(enabled: bool) -> void:
	_debug_show_ray_hit = enabled
	if not enabled and _debug_ray_marker:
		_debug_ray_marker.visible = false
		_debug_ray_hit_timer = 0.0


func set_debug_hover_locked_rooms(enabled: bool) -> void:
	_debug_hover_locked_rooms = enabled
	_update_room_highlights()


func set_debug_show_room_info(enabled: bool) -> void:
	_debug_show_room_info = enabled
	_update_room_highlights()


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
		return
	if not (game_state is Dictionary):
		return
	var d: Dictionary = game_state as Dictionary
	GameMainSaveHelper.apply_map(self, d)
	GameMainSaveHelper.apply_time(d)
	GameMainSaveHelper.apply_resources(self, d)


func collect_game_state() -> Dictionary:
	return GameMainSaveHelper.collect_game_state(self)


func _process(delta: float) -> void:
	_debug_ray_marker_process(delta)
	var overlay: Node = _get_cleanup_overlay()
	var construction_overlay: Node = _get_construction_overlay()
	GameMainCleanupHelper.process_overlay(self, overlay, delta)
	GameMainConstructionHelper.process_overlay(self, construction_overlay, delta)
	if GameTime and GameTime.is_flowing:
		var game_hours_delta: float = (delta / GameTime.REAL_SECONDS_PER_GAME_HOUR) * GameTime.speed_multiplier
		GameMainBuiltRoomHelper.process_production(self, game_hours_delta)
		GameMainShelterHelper.process_shelter_tick(self, game_hours_delta, _shelter_level)
		_sync_resources_to_topbar()  ## 时间流逝时每帧刷新因子显示，确保各倍速下都能实时看到消耗
	_sync_cleanup_researchers_to_ui()
	_sync_construction_researchers_to_ui()
	queue_redraw()


func _draw() -> void:
	## 3D 档案馆模式下隐藏 2D 网格/房间遮罩层（该层为 2D 模式的地图位置参考，3D 场景中不需要）
	if _camera3d:
		return
	GameMainDrawHelper.draw_all(self, self)


func _input(event: InputEvent) -> void:
	GameMainInputHelper.process_input(self, event)


func _room_center_to_screen(room_index: int) -> Vector2:
	if room_index < 0 or room_index >= _rooms.size():
		return Vector2.ZERO
	var cam3d: Camera3D = _camera3d
	if cam3d:
		return _room_center_to_screen_3d(room_index)
	var room: RoomInfo = _rooms[room_index]
	var world_center: Vector2 = Vector2(
		(room.rect.position.x + room.rect.size.x / 2.0) * CELL_SIZE,
		(room.rect.position.y + room.rect.size.y / 2.0) * CELL_SIZE
	)
	return get_viewport().get_canvas_transform() * world_center


func _room_center_to_screen_3d(room_index: int) -> Vector2:
	if room_index < 0 or room_index >= _rooms.size() or not _camera3d:
		return Vector2.ZERO
	var room: RoomInfo = _rooms[room_index]
	var rid: String = room.id if room.id else room.json_room_id
	if rid.is_empty():
		return Vector2.ZERO
	var archives: Node3D = get_node_or_null("ArchivesBase0") as Node3D
	if not archives:
		return Vector2.ZERO
	var room_node: Node3D = _find_room_node_in_archives(archives, rid)
	if not room_node:
		return Vector2.ZERO
	var room_info_3d: RoomInfo3D = room_node.get_node_or_null("RoomInfo") as RoomInfo3D
	if not room_info_3d:
		return Vector2.ZERO
	const GRID_SIZE := 0.5
	const THICKNESS_IN := 0.2
	const THICKNESS_OUT := 0.4
	var v: Vector3 = room_info_3d.room_volume
	var sz_y: float = GRID_SIZE * v.y + THICKNESS_IN + THICKNESS_OUT * 2
	var local_center: Vector3 = Vector3(0, sz_y / 2.0, 0)
	var world_center: Vector3 = room_node.global_transform * local_center
	return _camera3d.unproject_position(world_center)


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
	var gv: Node = _GameValuesRef.get_singleton()
	for r in room.resources:
		if not (r is Dictionary):
			continue
		var rt: int = int(r.get("resource_type", RoomInfo.ResourceType.NONE))
		var amt: int = int(r.get("resource_amount", 0))
		if rt == RoomInfo.ResourceType.NONE or amt <= 0:
			continue
		var cap: int = 999999
		match rt:
			RoomInfo.ResourceType.COGNITION:
				cap = gv.get_factor_cap("cognition") if gv else 999999
				ui.cognition_amount = mini(ui.cognition_amount + amt, cap)
			RoomInfo.ResourceType.COMPUTATION:
				cap = gv.get_factor_cap("computation") if gv else 999999
				var cf_now: int = ui.get_computation() if ui.has_method("get_computation") else int(ui.get("computation_amount") or 0)
				ui.computation_amount = mini(cf_now + amt, cap)
			RoomInfo.ResourceType.WILL:
				cap = gv.get_factor_cap("willpower") if gv else 999999
				ui.will_amount = mini(ui.will_amount + amt, cap)
			RoomInfo.ResourceType.PERMISSION:
				cap = gv.get_factor_cap("permission") if gv else 999999
				ui.permission_amount = mini(ui.permission_amount + amt, cap)
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


## 获取因子消耗/产出细则，供 TopBar 因子悬停面板使用
func get_factor_breakdown(factor_key: String) -> Dictionary:
	return GameMainFactorBreakdownHelper.get_breakdown(self, factor_key)


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
	if ui.has_method("get_cognition"):
		PersonnelErosionCore.register_cognition_provider(
			func() -> int: return ui.get_cognition(),
			func(amt: int) -> void: ui.cognition_amount = maxi(0, amt)
		)


func _ensure_shelter_resolver_registered() -> void:
	if not PersonnelErosionCore:
		return
	PersonnelErosionCore.register_shelter_resolver(func(r: Dictionary) -> Dictionary:
		var enriched: Dictionary = GameMainShelterHelper.enrich_researcher_with_rooms(self, r)
		var level: int = GameMainShelterHelper.get_shelter_level_for_researcher(self, enriched)
		var no_housing: bool = GameMainShelterHelper.has_no_housing(enriched)
		return {"shelter_level": level, "has_no_housing": no_housing}
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
	_update_room_highlights()


func _on_construction_zone_selected(zone_type: int) -> void:
	GameMainConstructionHelper.on_zone_selected(self, zone_type)
	_update_room_highlights()


func _on_construction_confirm_pressed() -> void:
	GameMainConstructionHelper.on_confirm_pressed(self)
	_update_room_highlights()

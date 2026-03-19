extends Node2D

## 游戏主场景 - 展示存档槽位，通过 SaveManager 加载完整游戏状态
## 主场景入口：加载 slot_0（或后续由主菜单指定槽位）并渲染
## 模块拆分：绘制/存档/清理/建设/已建设产出/镜头/输入 见 game_main_*.gd

const _GameValuesRef = preload("res://scripts/core/game_values_ref.gd")
const _ResearcherLifecycle = preload("res://scripts/game/researcher_lifecycle.gd")
const ZoneTypeScript = preload("res://scripts/core/zone_type.gd")
const GRID_WIDTH := 80
const GRID_HEIGHT := 60
const CELL_SIZE := 20
const DEFAULT_SLOT := 0

var _tiles: Array[Array] = []
var _current_slot: int = 0
var _rooms: Array = []

@warning_ignore("unused_private_class_variable")
var _base_image_cache: Dictionary = {}
var _camera: Camera2D  ## 2D 备用，若存在 game_main_camera 则主要用 3D
var _camera3d: Camera3D  ## 场景中的 game_main_camera，用于 3D 主视图
var _camera_distance: float = 30.0  ## 3D 镜头与场景中心沿 -Z 的距离，基准与 game_main_camera 初始位置一致
@warning_ignore("unused_private_class_variable")
var _pan_speed: float = 0.02  ## 中键拖动镜头时的速度系数，可由 Debug 面板滑块调整
@warning_ignore("unused_private_class_variable")
var _is_panning := false
@warning_ignore("unused_private_class_variable")
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
@warning_ignore("unused_private_class_variable")
var _cleanup_confirm_room_index := -1
var _cleanup_rooms_in_progress: Dictionary = {}
@warning_ignore("unused_private_class_variable")
var _time_was_flowing_before_cleanup := false

## 建设模式（11-zone-construction）
enum ConstructionMode { NONE, SELECTING_ZONE, SELECTING_TARGET, CONFIRMING }
var _construction_mode: ConstructionMode = ConstructionMode.NONE
var _construction_selected_zone: int = 0
@warning_ignore("unused_private_class_variable")
var _construction_confirm_room_index := -1
var _construction_rooms_in_progress: Dictionary = {}
@warning_ignore("unused_private_class_variable")
var _time_was_flowing_before_construction := false

## 已建设房间产出
@warning_ignore("unused_private_class_variable")
var _built_room_production_accumulator: float = 0.0

## 庇护能量：核心等级 1～5，存档持久化
var _shelter_level: int = 1
@warning_ignore("unused_private_class_variable")
var _shelter_accumulator: float = 0.0
@warning_ignore("unused_private_class_variable")
var _shelter_helper: RefCounted = null

## 读档时待应用的研究员 3D 位置 [{id, room_id, pos}]，由 _setup_researchers 应用后清空
var _pending_researchers_3d: Array = []

const _CURSOR_IMAGE_PATH := "res://assets/icons/icon_game_cursor_0.png"

func _reset_cursor_to_standard() -> void:
	## 游戏中鼠标指针重置为标准大小（使用项目内箭头图片）
	var cursor_tex: Texture2D = load(_CURSOR_IMAGE_PATH) as Texture2D
	if cursor_tex:
		Input.set_custom_mouse_cursor(cursor_tex, Input.CURSOR_ARROW, Vector2(0, 0))
	else:
		Input.set_custom_mouse_cursor(null)
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)


func _exit_tree() -> void:
	## 切场景前断开 Autoload 连接，避免对已释放节点的回调导致崩溃
	if PersonnelErosionCore and PersonnelErosionCore.personnel_updated.is_connected(Callable(self, "_on_personnel_updated")):
		PersonnelErosionCore.personnel_updated.disconnect(Callable(self, "_on_personnel_updated"))


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
	call_deferred("_setup_researchers")
	call_deferred("_setup_researcher_lifecycle")
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
		var room: ArchivesRoomInfo = _rooms[i]
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
		var room: ArchivesRoomInfo = _rooms[i]
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
		var room: ArchivesRoomInfo = _rooms[i]
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


func _setup_researchers() -> void:
	## 在档案馆核心 room_00 生成研究员 3D 实例，数量取自 personnel.researcher
	var archives: Node3D = get_node_or_null("ArchivesBase0") as Node3D
	if not archives:
		return
	var room_node: Node3D = _find_room_node_in_archives(archives, "room_00")
	if not room_node:
		return
	var room_info_3d: RoomInfo3D = room_node.get_node_or_null("RoomInfo") as RoomInfo3D
	if not room_info_3d:
		return
	var researcher_count: int = 10
	if PersonnelErosionCore:
		var personnel: Dictionary = PersonnelErosionCore.get_personnel()
		researcher_count = int(personnel.get("researcher", 10))
	else:
		var ui: Node = get_node_or_null("UIMain")
		if ui and ui.get("researcher_count") != null:
			researcher_count = int(ui.researcher_count)
		if researcher_count <= 0:
			var base: Dictionary = GameMainSaveHelper._load_game_base()
			var init_res: Dictionary = base.get("initial_resources", {}) as Dictionary
			var pers: Dictionary = init_res.get("personnel", {}) as Dictionary
			researcher_count = int(pers.get("researcher", 10))
	if researcher_count <= 0:
		return
	var existing: Node = room_node.get_node_or_null("ResearchersContainer")
	if existing:
		room_node.remove_child(existing)
		existing.free()
	var container: Node3D = Node3D.new()
	container.name = "ResearchersContainer"
	room_node.add_child(container)
	var vol: Vector3 = room_info_3d.room_volume
	const GRID_CELL: float = 0.5
	var hx: float = vol.x * GRID_CELL * 0.5
	var hz: float = vol.z * GRID_CELL * 0.5
	var inset: float = GRID_CELL
	var x_min: float = -hx + inset
	var x_max: float = hx - inset
	var z_min: float = -hz + inset
	var z_max: float = hz - inset
	const FLOOR_Y: float = 0.5
	const MIN_SPACING: float = 0.6
	var researcher_scene: PackedScene = load("res://scenes/actors/researcher_3d.tscn") as PackedScene
	if not researcher_scene:
		return
	var placed_positions: Array[Vector3] = []
	for i in researcher_count:
		var r: Node = researcher_scene.instantiate()
		if not r.has_method("set_room_bounds"):
			r.queue_free()
			continue
		var researcher: Node3D = r as Node3D
		if researcher.has_method("set_researcher_id"):
			researcher.call("set_researcher_id", i)
		researcher.set_room_bounds(x_min, x_max, z_min, z_max, FLOOR_Y)
		var pos: Vector3 = _pick_researcher_spawn_pos(x_min, x_max, z_min, z_max, FLOOR_Y, placed_positions, MIN_SPACING)
		researcher.position = pos
		placed_positions.append(pos)
		container.add_child(researcher)
		if researcher.has_method("set_current_room_id"):
			researcher.set_current_room_id("room_00")
		if researcher.has_method("set_game_main"):
			researcher.set_game_main(self)
		researcher.call("start_idle")
	## 必须在 _setup_researcher_lifecycle 之前应用，否则 lifecycle 的 apply_phase 会触发 teleport tween，tween 完成后会覆盖我们的放置
	_apply_pending_researchers_3d()


func _apply_pending_researchers_3d() -> void:
	var archives: Node3D = get_node_or_null("ArchivesBase0") as Node3D
	if not archives:
		_pending_researchers_3d.clear()
		return
	for entry in _pending_researchers_3d:
		if not (entry is Dictionary):
			continue
		var e: Dictionary = entry as Dictionary
		var rid: int = int(e.get("id", -1))
		var room_id: String = str(e.get("room_id", ""))
		if room_id.is_empty():
			room_id = "room_00"  ## 兼容旧存档：room_id 为空时默认为档案馆核心
		var pos_arr: Variant = e.get("pos", null)
		if rid < 0 or pos_arr == null or not (pos_arr is Array):
			continue
		var parr: Array = pos_arr as Array
		if parr.size() < 3:
			continue
		var pos: Vector3 = Vector3(float(parr[0]), float(parr[1]), float(parr[2]))
		## 若直接 room_id 找不到节点，尝试从 _rooms 匹配 id/json_room_id 得到可用的场景节点名
		var resolved_id: String = room_id
		if _find_room_node_in_archives(archives, room_id) == null:
			for room in _rooms:
				var r: ArchivesRoomInfo = room as ArchivesRoomInfo
				if not r:
					continue
				if (r.id == room_id or r.json_room_id == room_id) and not r.id.is_empty():
					if _find_room_node_in_archives(archives, r.id) != null:
						resolved_id = r.id
						break
				if (r.id == room_id or r.json_room_id == room_id) and not r.json_room_id.is_empty():
					if _find_room_node_in_archives(archives, r.json_room_id) != null:
						resolved_id = r.json_room_id
						break
		var r3d: Node3D = get_researcher_3d_by_id(rid)
		if r3d and r3d.has_method("place_in_room"):
			r3d.call("place_in_room", resolved_id, pos)
	_pending_researchers_3d.clear()


func _pick_researcher_spawn_pos(x_min: float, x_max: float, z_min: float, z_max: float, floor_y: float, existing: Array, min_spacing: float) -> Vector3:
	for attempt in 20:
		var x: float = randf_range(x_min, x_max)
		var z: float = randf_range(z_min, z_max)
		var cand: Vector3 = Vector3(x, floor_y, z)
		var ok: bool = true
		for p in existing:
			var pxz: Vector3 = Vector3(p.x, 0, p.z)
			var cxz: Vector3 = Vector3(cand.x, 0, cand.z)
			if pxz.distance_to(cxz) < min_spacing:
				ok = false
				break
		if ok:
			return cand
	var fallback_x: float = (x_min + x_max) * 0.5
	var fallback_z: float = (z_min + z_max) * 0.5
	return Vector3(fallback_x, floor_y, fallback_z)


func _setup_researcher_lifecycle() -> void:
	var sim_root: Node = get_node_or_null("SimulationRoot")
	if not sim_root:
		push_warning("SimulationRoot not found, ResearcherLifecycle will be added to GameMain")
		sim_root = self
	var lifecycle: Node = _ResearcherLifecycle.new()
	lifecycle.name = "ResearcherLifecycle"
	if lifecycle.has_method("set_game_main"):
		lifecycle.set_game_main(self)
	sim_root.add_child(lifecycle)


func _format_room_info_text(room: ArchivesRoomInfo) -> String:
	var type_str: String = ArchivesRoomInfo.get_room_type_name(room.room_type)
	var unlock_str: String = "已解锁" if room.unlocked else "未解锁"
	var clean_str: String = ArchivesRoomInfo.get_clean_status_name(room.clean_status)
	var res_parts: Array = []
	for r in room.resources:
		if r is Dictionary:
			var rt: int = int(r.get("resource_type", ArchivesRoomInfo.ResourceType.NONE))
			var amt: int = int(r.get("resource_amount", 0))
			if rt != ArchivesRoomInfo.ResourceType.NONE and amt > 0:
				res_parts.append("%s %d" % [ArchivesRoomInfo.get_resource_type_name(rt), amt])
	var res_str: String = (", ".join(res_parts)) if res_parts.size() > 0 else "无"
	return "类型: %s\n解锁: %s\n清理: %s\n资源: %s" % [type_str, unlock_str, clean_str, res_str]


func _update_room_info_labels() -> void:
	for rid in _room_info_labels:
		var label: Label3D = _room_info_labels[rid] as Label3D
		if not label:
			continue
		label.visible = _debug_show_room_info
		if _debug_show_room_info:
			var room: ArchivesRoomInfo = null
			for r in _rooms:
				var rinfo: ArchivesRoomInfo = r as ArchivesRoomInfo
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
		var room: ArchivesRoomInfo = null
		var room_index: int = -1
		for j in _rooms.size():
			var rinfo: ArchivesRoomInfo = _rooms[j] as ArchivesRoomInfo
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
			var can_select: bool = room.unlocked and room.clean_status == ArchivesRoomInfo.CleanStatus.UNCLEANED and not is_cleaning
			mi.visible = true
			mi.material_override = mat_blue if can_select else mat_black
		elif in_construction_selecting:
			var can_select: bool = room.can_build_zone(_construction_selected_zone) and not is_room_constructing
			mi.visible = true
			mi.material_override = mat_blue if can_select else mat_black
		else:
			if room.clean_status == ArchivesRoomInfo.CleanStatus.CLEANED and room.unlocked:
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


## 获取房间门位通过点 world 坐标（供研究员跨房间行走用）
## door_side: "left" | "right" 对应 researcher_can_move_to / researcher_can_move_to2，或回退到 3ditem_door_left_0 / 3ditem_door_right_0
func get_room_door_passage_position(room_id: String, door_side: String) -> Vector3:
	var archives: Node3D = get_node_or_null("ArchivesBase0") as Node3D
	if not archives:
		return Vector3.ZERO
	var room_node: Node3D = _find_room_node_in_archives(archives, room_id) as Node3D
	if not room_node:
		return Vector3.ZERO
	var node_name: String = "researcher_can_move_to" if door_side == "left" else "researcher_can_move_to2"
	var marker: Node3D = room_node.get_node_or_null(node_name) as Node3D
	if marker:
		return marker.global_position
	## 档案馆房间没有 researcher_can_move_to 节点时，回退到门的位置（供研究员穿越门跨房间）
	var door_name: String = "3ditem_door_left_0" if door_side == "left" else "3ditem_door_right_0"
	var door: Node3D = room_node.get_node_or_null("RoomItems/doors/" + door_name) as Node3D
	if door:
		return door.global_position
	return Vector3.ZERO


## 按 room_id 获取 RoomInfo
func get_room_info_by_id(room_id: String) -> ArchivesRoomInfo:
	if room_id.is_empty():
		return null
	for room in _rooms:
		var r: ArchivesRoomInfo = room as ArchivesRoomInfo
		if not r:
			continue
		var rid: String = r.id if r.id else r.json_room_id
		if rid == room_id:
			return r
	return null


## 可闲逛房间：room_00 + 所有已解锁且已清理的房间（与 ResearcherLifecycle._build_wanderable_room_list 一致）
func get_wanderable_room_ids() -> Array[String]:
	var out: Array[String] = ["room_00"]
	for room in _rooms:
		var r: ArchivesRoomInfo = room as ArchivesRoomInfo
		if not r:
			continue
		if not r.unlocked or r.clean_status != ArchivesRoomInfo.CleanStatus.CLEANED:
			continue
		var rid: String = r.id if r.id else r.json_room_id
		if rid.is_empty():
			continue
		if rid != "room_00":
			out.append(rid)
	return out


## 按 researcher_id 查找 Researcher3D 节点。研究员可能被 teleport 到任意房间，故在所有房间的 ResearchersContainer 下查找。
func get_researcher_3d_by_id(researcher_id: int) -> Node3D:
	var archives: Node3D = get_node_or_null("ArchivesBase0") as Node3D
	if not archives or _rooms.is_empty():
		return null
	for room in _rooms:
		var rid: String = room.id if room.id else room.json_room_id
		if rid.is_empty():
			continue
		var room_node: Node3D = _find_room_node_in_archives(archives, rid)
		if not room_node:
			continue
		var container: Node = room_node.get_node_or_null("ResearchersContainer")
		if not container:
			continue
		for i in container.get_child_count():
			var child: Node = container.get_child(i)
			var r3d: Node3D = child as Node3D
			if not r3d:
				continue
			if r3d.get("researcher_id") != null and int(r3d.get("researcher_id")) == researcher_id:
				return r3d
	return null


## 镜头聚焦到指定研究员（UI 可调）
func focus_camera_on_researcher(researcher_id: int) -> void:
	GameMainCameraHelper.focus_camera_on_researcher(self, researcher_id)


## 研究员详情（供研究员列表面板使用）
## 返回: id, name, current_state, work_area, living_area, erosion_prob, recovery_prob, cognition_per_hour, info_output
func get_researcher_detail(researcher_id: int) -> Dictionary:
	var out: Dictionary = {
		"id": researcher_id,
		"name": "",
		"current_state": "Idle",
		"work_area": "",
		"living_area": "",
		"erosion_prob": 0,
		"recovery_prob": 0,
		"cognition_per_hour": 1,
		"info_output": "—",
	}
	out["name"] = "研究员 %d" % researcher_id
	out["cognition_per_hour"] = PersonnelErosionCore.COGNITION_PER_RESEARCHER_PER_HOUR if PersonnelErosionCore else 1

	var researchers: Array = []
	if PersonnelErosionCore:
		researchers = PersonnelErosionCore.get_researchers()
	var r_dict: Dictionary = researchers[researcher_id] if researcher_id >= 0 and researcher_id < researchers.size() else {}
	var enriched: Dictionary = GameMainShelterHelper.enrich_researcher_with_rooms(self, r_dict)
	var work_rid: String = str(enriched.get("work_room_id", ""))
	var housing_rid: String = str(enriched.get("housing_room_id", ""))

	## work_area / living_area: zone_type + room name
	var _room_by_id: Callable = func(rid: String) -> ArchivesRoomInfo:
		if rid.is_empty():
			return null
		for room in _rooms:
			var r: ArchivesRoomInfo = room as ArchivesRoomInfo
			if (r.id if r.id else r.json_room_id) == rid:
				return r
		return null
	var work_room: ArchivesRoomInfo = _room_by_id.call(work_rid)
	var living_room: ArchivesRoomInfo = _room_by_id.call(housing_rid)
	if work_room:
		var zname: String = ZoneTypeScript.get_zone_name(work_room.zone_type) if work_room.zone_type != 0 else tr("ZONE_NONE")
		out["work_area"] = "%s %s" % [zname, work_room.get_display_name()]
		if work_room.zone_type == ZoneTypeScript.Type.RESEARCH:
			out["info_output"] = tr("ZONE_RESEARCH")
		elif work_room.zone_type == ZoneTypeScript.Type.CREATION:
			out["info_output"] = tr("ZONE_CREATION")
		else:
			out["info_output"] = "—"
	else:
		out["work_area"] = "—"
	if living_room:
		var zname_l: String = ZoneTypeScript.get_zone_name(living_room.zone_type) if living_room.zone_type != 0 else tr("ZONE_NONE")
		out["living_area"] = "%s %s" % [zname_l, living_room.get_display_name()]
	else:
		out["living_area"] = "—"

	## 侵蚀概率：按庇护等级（07 文档）
	var shelter_level: int = GameMainShelterHelper.get_shelter_level_for_researcher(self, enriched)
	if shelter_level <= -5:
		out["erosion_prob"] = PersonnelErosionCore.EROSION_PROB_EXTREME if PersonnelErosionCore else 80
	elif shelter_level >= -4 and shelter_level <= -2:
		out["erosion_prob"] = PersonnelErosionCore.EROSION_PROB_EXPOSED if PersonnelErosionCore else 50
	elif shelter_level >= -1 and shelter_level <= 1:
		out["erosion_prob"] = PersonnelErosionCore.EROSION_PROB_WEAK if PersonnelErosionCore else 20
	else:
		out["erosion_prob"] = 0
	if GameMainShelterHelper.has_no_housing(enriched):
		out["erosion_prob"] = mini(100, out["erosion_prob"] * 2)

	## 治愈概率：无住房 0%，妥善 30%，完美 80%（07 文档）
	if GameMainShelterHelper.has_no_housing(enriched) or housing_rid.is_empty():
		out["recovery_prob"] = 0
	elif r_dict.get("is_eroded", false):
		var dorm_level: int = GameMainShelterHelper.get_room_shelter_level(self, housing_rid)
		if dorm_level < 2:
			out["recovery_prob"] = 0
		else:
			out["recovery_prob"] = PersonnelErosionCore.CURE_PROB_ADEQUATE if dorm_level < 5 else PersonnelErosionCore.CURE_PROB_PERFECT
		if not PersonnelErosionCore:
			out["recovery_prob"] = 30 if dorm_level < 5 else 80

	## 当前状态：由生命周期阶段 + 是否移动
	var life_phase: int = _ResearcherLifecycle.get_current_life_phase(self, researcher_id)
	var r3d: Node3D = get_researcher_3d_by_id(researcher_id)
	var is_moving: bool = (r3d != null and r3d.has_method("get_is_moving") and r3d.call("get_is_moving")) if r3d else false
	match life_phase:
		_ResearcherLifecycle.LifePhase.CLEANUP:
			out["current_state"] = "Working_Cleanup"
		_ResearcherLifecycle.LifePhase.CONSTRUCTION:
			out["current_state"] = "Working_Construction"
		_ResearcherLifecycle.LifePhase.WORK:
			out["current_state"] = "Working_ResearchOrCreation"
		_ResearcherLifecycle.LifePhase.SLEEP, _ResearcherLifecycle.LifePhase.SLEEP_IN_PLACE:
			out["current_state"] = "Sleeping"
		_ResearcherLifecycle.LifePhase.RETURN_HOME, _ResearcherLifecycle.LifePhase.MOVE_TO_WORK:
			out["current_state"] = "Moving"
		_ResearcherLifecycle.LifePhase.WAIT_AT_HOME:
			out["current_state"] = "Rest"
		_ResearcherLifecycle.LifePhase.WANDER_ARCHIVES, _ResearcherLifecycle.LifePhase.WANDER_NO_WORK:
			out["current_state"] = "Moving" if is_moving else "Idle"
		_:
			out["current_state"] = "Moving" if is_moving else "Idle"
	return out


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
		var room: ArchivesRoomInfo = _rooms[i]
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
		var room: ArchivesRoomInfo = _rooms[room_index]
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
		var room: ArchivesRoomInfo = _rooms[room_index]
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
	var d: Dictionary
	if game_state == null or not (game_state is Dictionary):
		d = SaveManager.create_new_game_state(tr("DEFAULT_NEW_GAME"))
	else:
		d = game_state as Dictionary
	_pending_researchers_3d = d.get("researchers_3d", [])
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


func _room_center_to_screen(room_index: int) -> Vector2:
	if room_index < 0 or room_index >= _rooms.size():
		return Vector2.ZERO
	var cam3d: Camera3D = _camera3d
	if cam3d:
		return _room_center_to_screen_3d(room_index)
	var room: ArchivesRoomInfo = _rooms[room_index]
	var world_center: Vector2 = Vector2(
		(room.rect.position.x + room.rect.size.x / 2.0) * CELL_SIZE,
		(room.rect.position.y + room.rect.size.y / 2.0) * CELL_SIZE
	)
	return get_viewport().get_canvas_transform() * world_center


func _get_room_center_3d(room_index: int) -> Vector3:
	## 获取房间在 3D 场景中的世界坐标中心，供镜头聚焦等使用
	if room_index < 0 or room_index >= _rooms.size():
		return Vector3.ZERO
	var room: ArchivesRoomInfo = _rooms[room_index]
	var rid: String = room.id if room.id else room.json_room_id
	if rid.is_empty():
		return Vector3.ZERO
	var archives: Node3D = get_node_or_null("ArchivesBase0") as Node3D
	if not archives:
		return Vector3.ZERO
	var room_node: Node3D = _find_room_node_in_archives(archives, rid)
	if not room_node:
		return Vector3.ZERO
	var room_info_3d: RoomInfo3D = room_node.get_node_or_null("RoomInfo") as RoomInfo3D
	if not room_info_3d:
		return Vector3.ZERO
	const GRID_SIZE := 0.5
	const THICKNESS_IN := 0.2
	const THICKNESS_OUT := 0.4
	var v: Vector3 = room_info_3d.room_volume
	var sz_y: float = GRID_SIZE * v.y + THICKNESS_IN + THICKNESS_OUT * 2
	var local_center: Vector3 = Vector3(0, sz_y / 2.0, 0)
	return room_node.global_transform * local_center


func _room_center_to_screen_3d(room_index: int) -> Vector2:
	if room_index < 0 or room_index >= _rooms.size() or not _camera3d:
		return Vector2.ZERO
	var world_center: Vector3 = _get_room_center_3d(room_index)
	if world_center == Vector3.ZERO:
		return Vector2.ZERO
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
		var room: ArchivesRoomInfo = _rooms[i]
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


func _grant_room_resources_to_player(room: ArchivesRoomInfo) -> void:
	var ui: Node = get_node_or_null("UIMain")
	if not ui:
		return
	for r in room.resources:
		if not (r is Dictionary):
			continue
		var rt: int = int(r.get("resource_type", ArchivesRoomInfo.ResourceType.NONE))
		var amt: int = int(r.get("resource_amount", 0))
		if rt == ArchivesRoomInfo.ResourceType.NONE or amt <= 0:
			continue
		ResourceLedger.add_by_type(ui, rt, amt)
	_sync_resources_to_topbar()


func _sync_resources_to_topbar() -> void:
	var ui: Node = get_node_or_null("UIMain")
	if ui and ui.has_method("refresh_display"):
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
		var weak_ui: WeakRef = weakref(ui)
		PersonnelErosionCore.register_cognition_provider(
			func() -> int:
				var u: Node = weak_ui.get_ref()
				if u == null:
					return 0
				return u.get_cognition(),
			func(amt: int) -> void:
				var u: Node = weak_ui.get_ref()
				if u != null:
					u.cognition_amount = maxi(0, amt)
		)


func _ensure_shelter_resolver_registered() -> void:
	if not PersonnelErosionCore:
		return
	var weak_gm: WeakRef = weakref(self)
	PersonnelErosionCore.register_shelter_resolver(func(r: Dictionary) -> Dictionary:
		var gm: Node2D = weak_gm.get_ref()
		if gm == null:
			return {"shelter_level": 1, "has_no_housing": false}
		var enriched: Dictionary = GameMainShelterHelper.enrich_researcher_with_rooms(gm, r)
		var level: int = GameMainShelterHelper.get_shelter_level_for_researcher(gm, enriched)
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


func _show_room_detail(room: ArchivesRoomInfo) -> void:
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

@tool
extends EditorPlugin

## RoomItems 网格对齐插件：在 preset_room_frame 场景中，移动 RoomItems 子节点时自动对齐到 0.5m 网格。
## 详见 docs/design/1-editor/05-room-items-grid-snap.md

const GRID_CELL_SIZE: float = 0.5  ## 与 preset_room_frame 中 grid_size 一致
const GRID_FLOOR_Y: float = 0.5   ## RoomItems 底面 y，= thickness_out(0.4) + thickness_in/2(0.1)，见 04-preset-room-frame.md
const SETTING_KEY: String = "old_archives/room_items_grid_snap_enabled"
const STABLE_FRAMES_REQUIRED: int = 2
## 预览盒体颜色（便于统一调整，避免魔法数字）
const PREVIEW_COLOR_SNAP: Color = Color(0.2, 0.9, 0.3, 0.65)
const PREVIEW_COLOR_ORIGIN: Color = Color(0.5, 0.5, 0.55, 0.18)

var _snap_menu: PopupMenu
var _last_transforms: Dictionary = {}  # instance_id -> Transform3D
var _stable_frames: Dictionary = {}    # instance_id -> int
var _had_drag: Dictionary = {}         # instance_id -> bool
var _drag_start_positions: Dictionary = {}  # instance_id -> Vector3
## 网格吸附目标预览：半透明绿色盒体，owner=null 不写入场景
var _preview_mesh: MeshInstance3D = null
## 原位置预览：半透明灰色盒体，拖动开始时显示
var _origin_preview_mesh: MeshInstance3D = null


func _enter_tree() -> void:
	_register_setting()
	_setup_menu()
	# 每帧检测拖拽结束
	set_process(true)


func _exit_tree() -> void:
	_hide_snap_preview()
	_hide_origin_preview()
	_dispose_preview_meshes()
	_remove_menu()
	set_process(false)


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if not _is_snap_enabled():
		return
	var selected: Array = _get_room_items_selected_nodes()
	if selected.is_empty():
		_cleanup_tracking(selected)
		_update_snap_preview([])
		return
	_cleanup_tracking(selected)
	for node in selected:
		if is_instance_valid(node):
			_process_node(node)
	_update_snap_preview(selected)


func _register_setting() -> void:
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings == null:
		return
	if not settings.has_setting(SETTING_KEY):
		settings.set_setting(SETTING_KEY, true)


func _setup_menu() -> void:
	_snap_menu = PopupMenu.new()
	_snap_menu.name = "RoomItemsGridSnapMenu"
	_snap_menu.add_check_item("RoomItems 网格对齐", 0)
	_snap_menu.id_pressed.connect(_on_menu_id_pressed)
	_snap_menu.about_to_popup.connect(_on_menu_about_to_popup)
	add_tool_submenu_item("RoomItems 网格对齐", _snap_menu)


func _remove_menu() -> void:
	if _snap_menu != null:
		if Engine.is_editor_hint():
			remove_tool_menu_item("RoomItems 网格对齐")
		## remove_tool_menu_item 可能已间接释放菜单，需二次校验后再手动 free。
		if is_instance_valid(_snap_menu):
			if _snap_menu.get_parent():
				_snap_menu.get_parent().remove_child(_snap_menu)
			_snap_menu.free()
	_snap_menu = null


func _on_menu_about_to_popup() -> void:
	if _snap_menu != null and is_instance_valid(_snap_menu):
		_snap_menu.set_item_checked(0, _is_snap_enabled())


func _on_menu_id_pressed(id: int) -> void:
	if id == 0:
		var settings: EditorSettings = EditorInterface.get_editor_settings()
		if settings == null or not settings.has_setting(SETTING_KEY):
			return
		var current: bool = settings.get_setting(SETTING_KEY)
		settings.set_setting(SETTING_KEY, not current)


func _is_snap_enabled() -> bool:
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings == null:
		return true
	if not settings.has_setting(SETTING_KEY):
		return true
	return settings.get_setting(SETTING_KEY)


func _is_mouse_release_valid() -> bool:
	## 左键已松开：用 Input 直接检测，比依赖 forward_3d_gui_input 更可靠。
	return not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _get_room_items_selected_nodes() -> Array:
	var result: Array[Node3D] = []
	var editor: EditorInterface = get_editor_interface()
	if editor == null:
		return result
	var selection: EditorSelection = editor.get_selection()
	if selection == null:
		return result
	var nodes: Array = selection.get_selected_nodes()
	for node in nodes:
		if not node is Node3D:
			continue
		var room_items: Node = _find_room_items_ancestor(node)
		if room_items == null:
			continue
		if node == room_items:
			continue
		if not _has_room_reference_grid(room_items):
			continue
		result.append(node)
	return result


func _find_room_items_ancestor(node: Node) -> Node:
	var current: Node = node
	while current != null and is_instance_valid(current):
		if current.name == "RoomItems":
			return current
		current = current.get_parent()
	return null


func _has_room_reference_grid(room_items: Node) -> bool:
	var parent: Node = room_items.get_parent()
	if parent == null:
		return false
	return parent.get_node_or_null("RoomReferenceGrid") != null


func _get_room_grid_origin(node: Node3D) -> Vector3:
	## RoomReferenceGrid 的世界原点（底面中心）
	var room_items: Node = _find_room_items_ancestor(node)
	if room_items == null:
		return Vector3(0.0, GRID_FLOOR_Y, 0.0)
	var parent: Node = room_items.get_parent()
	if parent == null:
		return Vector3(0.0, GRID_FLOOR_Y, 0.0)
	var grid: Node3D = parent.get_node_or_null("RoomReferenceGrid") as Node3D
	if grid == null or not is_instance_valid(grid):
		return Vector3(0.0, GRID_FLOOR_Y, 0.0)
	return grid.global_position


func _get_room_volume(node: Node3D) -> Vector3:
	## 从 RoomInfo 获取房间体积，用于计算房间网格的 min 角
	var room_items: Node = _find_room_items_ancestor(node)
	if room_items == null:
		return Vector3.ZERO
	var parent: Node = room_items.get_parent()
	if parent == null:
		return Vector3.ZERO
	var room_info: Node = parent.get_node_or_null("RoomInfo")
	if room_info == null or not is_instance_valid(room_info) or room_info.get("room_volume") == null:
		return Vector3.ZERO
	return room_info.get("room_volume")


func _update_snap_preview(selected: Array) -> void:
	## 拖动时：原位置显示灰色盒体；将吸附时，目标位置显示绿色盒体。
	var drag_node: Node3D = null
	var would_snap: bool = false
	for node in selected:
		if not is_instance_valid(node):
			continue
		var nid: int = node.get_instance_id()
		if not _had_drag.get(nid, false):
			continue
		if nid not in _drag_start_positions:
			continue
		drag_node = node
		var start_pos: Vector3 = _drag_start_positions[nid]
		var current_pos: Vector3 = node.global_position
		var start_cell: Vector3i = _world_to_grid_cell(_get_reference_point(node, start_pos), node)
		var current_cell: Vector3i = _world_to_grid_cell(_get_reference_point(node, current_pos), node)
		would_snap = (start_cell != current_cell)
		break
	if drag_node == null:
		_hide_snap_preview()
		_hide_origin_preview()
		return
	var scene_root: Node = drag_node.get_tree().edited_scene_root
	if scene_root == null or not is_instance_valid(scene_root):
		_hide_snap_preview()
		_hide_origin_preview()
		return
	var box_size: Vector3 = _get_preview_box_size(drag_node)
	var hy: float = box_size.y * 0.5
	# 原位置：灰色盒体（拖动时始终显示）
	var start_pos: Vector3 = _drag_start_positions[drag_node.get_instance_id()]
	var origin_mi: MeshInstance3D = _ensure_origin_preview_mesh(scene_root)
	if origin_mi != null:
		origin_mi.visible = true
		origin_mi.global_position = start_pos + Vector3(0.0, hy, 0.0)
		_set_preview_box_size(origin_mi, box_size)
	# 目标位置：绿色盒体（仅当将吸附时显示）
	if would_snap:
		var snapped_pos: Vector3 = _snap_position_for_node(drag_node, drag_node.global_position)
		var mi: MeshInstance3D = _ensure_preview_mesh(scene_root)
		if mi != null:
			mi.visible = true
			mi.global_position = snapped_pos + Vector3(0.0, hy, 0.0)
			_set_preview_box_size(mi, box_size)
	else:
		if _preview_mesh != null and is_instance_valid(_preview_mesh):
			_preview_mesh.visible = false


func _set_preview_box_size(mi: MeshInstance3D, box_size: Vector3) -> void:
	## 更新预览盒体的 BoxMesh 尺寸，避免重复创建逻辑。
	var box: BoxMesh = mi.mesh as BoxMesh
	if box == null or box.size != box_size:
		box = BoxMesh.new()
		box.size = box_size
		mi.mesh = box


func _get_preview_box_size(node: Node3D) -> Vector3:
	var vol: Vector3 = _get_volume_for_node(node)
	if vol.x <= 0 or vol.y <= 0 or vol.z <= 0:
		return Vector3(GRID_CELL_SIZE, GRID_CELL_SIZE, GRID_CELL_SIZE)
	return Vector3(
		vol.x * GRID_CELL_SIZE,
		vol.y * GRID_CELL_SIZE,
		vol.z * GRID_CELL_SIZE
	)


func _ensure_preview_mesh(scene_root: Node) -> MeshInstance3D:
	if _preview_mesh != null and is_instance_valid(_preview_mesh):
		if _preview_mesh.get_parent() != scene_root:
			_preview_mesh.reparent(scene_root)
		return _preview_mesh
	_preview_mesh = MeshInstance3D.new()
	_preview_mesh.name = "RoomItemsGridSnapPreview"
	_preview_mesh.owner = null
	scene_root.add_child(_preview_mesh)
	var mat: StandardMaterial3D = _preview_mesh.material_override as StandardMaterial3D
	if mat == null:
		mat = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = PREVIEW_COLOR_SNAP
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_preview_mesh.material_override = mat
	return _preview_mesh


func _hide_snap_preview() -> void:
	if _preview_mesh != null and is_instance_valid(_preview_mesh):
		_preview_mesh.visible = false


func _ensure_origin_preview_mesh(scene_root: Node) -> MeshInstance3D:
	if _origin_preview_mesh != null and is_instance_valid(_origin_preview_mesh):
		if _origin_preview_mesh.get_parent() != scene_root:
			_origin_preview_mesh.reparent(scene_root)
		return _origin_preview_mesh
	_origin_preview_mesh = MeshInstance3D.new()
	_origin_preview_mesh.name = "RoomItemsGridSnapOriginPreview"
	_origin_preview_mesh.owner = null
	scene_root.add_child(_origin_preview_mesh)
	var mat: StandardMaterial3D = _origin_preview_mesh.material_override as StandardMaterial3D
	if mat == null:
		mat = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = PREVIEW_COLOR_ORIGIN
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_origin_preview_mesh.material_override = mat
	return _origin_preview_mesh


func _hide_origin_preview() -> void:
	if _origin_preview_mesh != null and is_instance_valid(_origin_preview_mesh):
		_origin_preview_mesh.visible = false


func _dispose_preview_meshes() -> void:
	## 插件退出时释放预览节点，避免残留在场景中。
	if _preview_mesh != null and is_instance_valid(_preview_mesh):
		_preview_mesh.queue_free()
		_preview_mesh = null
	if _origin_preview_mesh != null and is_instance_valid(_origin_preview_mesh):
		_origin_preview_mesh.queue_free()
		_origin_preview_mesh = null


func _cleanup_tracking(valid_nodes: Array) -> void:
	var valid_ids: Dictionary = {}
	for node in valid_nodes:
		if is_instance_valid(node):
			valid_ids[node.get_instance_id()] = true
	var to_remove: Array = []
	for id in _last_transforms.keys():
		if id not in valid_ids:
			to_remove.append(id)
	for id in to_remove:
		_last_transforms.erase(id)
		_stable_frames.erase(id)
		_had_drag.erase(id)
		_drag_start_positions.erase(id)


func _process_node(node: Node3D) -> void:
	if not is_instance_valid(node):
		return
	var nid: int = node.get_instance_id()
	var current: Transform3D = node.global_transform
	var last: Variant = _last_transforms.get(nid)
	if last == null:
		_last_transforms[nid] = current
		_stable_frames[nid] = 0
		return
	if not current.is_equal_approx(last):
		if not _had_drag.get(nid, false):
			_drag_start_positions[nid] = last.origin
		_had_drag[nid] = true
		_last_transforms[nid] = current
		_stable_frames[nid] = 0
		return
	_stable_frames[nid] = _stable_frames.get(nid, 0) + 1
	# 需同时满足：transform 稳定、有过拖动、且鼠标已松开（近期内）
	if _stable_frames[nid] >= STABLE_FRAMES_REQUIRED and _had_drag.get(nid, false) and _is_mouse_release_valid():
		var current_pos: Vector3 = node.global_position
		var should_revert: bool = false
		var revert_target: Vector3 = Vector3.ZERO
		if nid in _drag_start_positions:
			var start_pos: Vector3 = _drag_start_positions[nid]
			# 按网格单位判断：参考点所在格是否变化（整数比较，无浮点误差）
			var start_cell: Vector3i = _world_to_grid_cell(_get_reference_point(node, start_pos), node)
			var current_cell: Vector3i = _world_to_grid_cell(_get_reference_point(node, current_pos), node)
			if start_cell == current_cell:
				should_revert = true
				revert_target = start_pos
		_had_drag.erase(nid)
		_last_transforms.erase(nid)
		_stable_frames.erase(nid)
		_drag_start_positions.erase(nid)
		if should_revert:
			_revert_to_position(node, revert_target)
		else:
			# 延后一帧执行吸附，避免与编辑器拖拽结束逻辑竞争
			_apply_snap_deferred(node)


func _revert_to_position(node: Node3D, target_pos: Vector3) -> void:
	if not is_instance_valid(node):
		return
	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	if undo_redo == null:
		return
	var current_pos: Vector3 = node.global_position
	if current_pos.is_equal_approx(target_pos):
		return
	undo_redo.create_action("RoomItems 取消微移")
	undo_redo.add_do_property(node, "global_position", target_pos)
	undo_redo.add_undo_property(node, "global_position", current_pos)
	undo_redo.commit_action()


func _apply_snap_deferred(node: Node3D) -> void:
	call_deferred("_apply_snap", node)


func _apply_snap(node: Node3D) -> void:
	if not is_instance_valid(node):
		return
	var current_pos: Vector3 = node.global_position
	var snapped_pos: Vector3 = _snap_position_for_node(node, current_pos)
	# 仅当吸附结果与当前位置差距超过 0.01 时才执行
	if current_pos.distance_to(snapped_pos) < 0.01:
		return
	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	if undo_redo == null:
		return
	undo_redo.create_action("RoomItems 网格对齐")
	undo_redo.add_do_property(node, "global_position", snapped_pos)
	undo_redo.add_undo_property(node, "global_position", current_pos)
	undo_redo.commit_action()


func _world_to_grid_cell(world_pos: Vector3, node: Node3D) -> Vector3i:
	## 将世界坐标转换为相对房间网格的格坐标，用于跨格判断。假设 RoomReferenceGrid 无旋转。
	var grid_origin: Vector3 = _get_room_grid_origin(node)
	var room_vol: Vector3 = _get_room_volume(node)
	var room_hx: float = room_vol.x * GRID_CELL_SIZE * 0.5 if room_vol.x > 0 else 0.0
	var room_hz: float = room_vol.z * GRID_CELL_SIZE * 0.5 if room_vol.z > 0 else 0.0
	var room_min_x: float = grid_origin.x - room_hx
	var room_min_z: float = grid_origin.z - room_hz
	return Vector3i(
		int(round((world_pos.x - room_min_x) / GRID_CELL_SIZE)),
		int(round((world_pos.y - grid_origin.y) / GRID_CELL_SIZE)),
		int(round((world_pos.z - room_min_z) / GRID_CELL_SIZE))
	)


func _get_volume_for_node(node: Node3D) -> Vector3:
	## 优先 ActorBox，其次 RoomInfo3D.room_volume，用于参考点与吸附。
	var actor_box: ActorBox = node.get_node_or_null("ActorBox") as ActorBox
	if actor_box != null and is_instance_valid(actor_box):
		return actor_box.volume
	var room_info: Node = node.get_node_or_null("RoomInfo")
	if room_info != null and is_instance_valid(room_info) and room_info.get("room_volume") != null:
		return room_info.get("room_volume")
	return Vector3.ZERO


func _get_reference_point(node: Node3D, pivot_pos: Vector3) -> Vector3:
	var vol: Vector3 = _get_volume_for_node(node)
	if vol.x <= 0 or vol.y <= 0 or vol.z <= 0:
		return pivot_pos
	var hx: float = vol.x * GRID_CELL_SIZE * 0.5
	var hz: float = vol.z * GRID_CELL_SIZE * 0.5
	return pivot_pos + Vector3(-hx, 0.0, -hz)


func _snap_position_for_node(node: Node3D, pivot_pos: Vector3) -> Vector3:
	## 将 item 的 min 角吸附到房间网格线，再反算 pivot。相对 RoomReferenceGrid 与 room_volume 计算。
	var vol: Vector3 = _get_volume_for_node(node)
	if vol.x <= 0 or vol.y <= 0 or vol.z <= 0:
		return _snap_center_relative(pivot_pos, node)
	var grid_origin: Vector3 = _get_room_grid_origin(node)
	var room_vol: Vector3 = _get_room_volume(node)
	if room_vol.x <= 0 or room_vol.z <= 0:
		# room_vol 无效时退化为相对 grid_origin 的 0.5 网格
		return _snap_center_relative(pivot_pos, node)
	var room_hx: float = room_vol.x * GRID_CELL_SIZE * 0.5
	var room_hz: float = room_vol.z * GRID_CELL_SIZE * 0.5
	var room_min_x: float = grid_origin.x - room_hx
	var room_min_z: float = grid_origin.z - room_hz
	var hx: float = vol.x * GRID_CELL_SIZE * 0.5
	var hz: float = vol.z * GRID_CELL_SIZE * 0.5
	var min_corner: Vector3 = pivot_pos + Vector3(-hx, 0.0, -hz)
	# 相对房间 min 角做格坐标吸附，支持房间 odd/even 任意组合
	var cell_x: int = int(round((min_corner.x - room_min_x) / GRID_CELL_SIZE))
	var cell_z: int = int(round((min_corner.z - room_min_z) / GRID_CELL_SIZE))
	var snapped_min_x: float = room_min_x + cell_x * GRID_CELL_SIZE
	var snapped_min_z: float = room_min_z + cell_z * GRID_CELL_SIZE
	var vx: float = snapped_min_x + hx
	var vz: float = snapped_min_z + hz
	var vy: float = snappedf(pivot_pos.y - grid_origin.y, GRID_CELL_SIZE) + grid_origin.y
	return Vector3(vx, vy, vz)


func _snap_center_relative(pos: Vector3, node: Node3D) -> Vector3:
	## 无 volume 或 room_vol 无效时，相对 grid_origin 将 pivot 吸附到 0.5m 网格。
	var grid_origin: Vector3 = _get_room_grid_origin(node)
	var local: Vector3 = pos - grid_origin
	return grid_origin + Vector3(
		snappedf(local.x, GRID_CELL_SIZE),
		snappedf(local.y, GRID_CELL_SIZE),
		snappedf(local.z, GRID_CELL_SIZE)
	)

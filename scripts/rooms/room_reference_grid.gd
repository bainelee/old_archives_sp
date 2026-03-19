@tool
class_name RoomReferenceGrid
extends Node3D

## 房间参考网格：根据 room_volume 绘制三面网格，中心位于底面中心。
## 从兄弟节点 RoomInfo3D 读取 room_volume。

const ProjectConstants = preload("res://scripts/core/project_constants.gd")
const GRID_CELL_SIZE: float = ProjectConstants.GRID_CELL_SIZE

## 材质资源：可在编辑器中调节颜色与透明度
const MAT_ROOM_GRID: StandardMaterial3D = preload("res://assets/materials/tools_materials/mat_room_reference_grid.tres")

@onready var _mesh_instance: MeshInstance3D = $MeshInstance3D

var _last_volume: Vector3 = Vector3.ZERO


func _ready() -> void:
	if Engine.is_editor_hint():
		_update_grid()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	var room_info: RoomInfo3D = _get_room_info()
	if room_info != null and _last_volume != room_info.room_volume:
		_update_grid()


func _update_grid() -> void:
	var room_info: RoomInfo3D = _get_room_info()
	if room_info == null:
		return
	var vol: Vector3 = room_info.room_volume
	if vol.x <= 0 or vol.y <= 0 or vol.z <= 0:
		return

	var hx: float = vol.x * GRID_CELL_SIZE * 0.5
	var hy: float = vol.y * GRID_CELL_SIZE * 0.5
	var hz: float = vol.z * GRID_CELL_SIZE * 0.5

	var mi: MeshInstance3D = _get_mesh_instance()
	if mi == null:
		return

	var imm: ImmediateMesh = ImmediateMesh.new()
	imm.surface_begin(Mesh.PRIMITIVE_LINES)

	var nx: int = int(vol.x)
	var ny: int = int(vol.y)
	var nz: int = int(vol.z)
	var cell: float = GRID_CELL_SIZE

	# 底面 (XZ, y=0)，左墙侧面 (YZ, x=-hx)，后方墙面 (XY, z=-hz)
	# 正常方向：Z 朝外，X 朝右，Y 朝上
	_draw_grid_xz(imm, -hx, 0.0, -hz, hx, hz, nx, nz, cell)
	_draw_grid_yz(imm, -hx, 0.0, -hz, 2.0 * hy, hz, ny, nz, cell)
	_draw_grid_xy(imm, -hx, 0.0, -hz, hx, 2.0 * hy, nx, ny, cell)

	imm.surface_end()
	_last_volume = vol
	mi.mesh = imm
	mi.material_override = MAT_ROOM_GRID


func _draw_grid_xz(imm: ImmediateMesh, x0: float, y: float, z0: float, x1: float, z1: float, nx: int, nz: int, cell: float) -> void:
	if nx <= 0 or nz <= 0:
		return
	for i in range(nz + 1):
		var z: float = z0 + i * cell
		imm.surface_add_vertex(Vector3(x0, y, z))
		imm.surface_add_vertex(Vector3(x1, y, z))
	for i in range(nx + 1):
		var x: float = x0 + i * cell
		imm.surface_add_vertex(Vector3(x, y, z0))
		imm.surface_add_vertex(Vector3(x, y, z1))


func _draw_grid_yz(imm: ImmediateMesh, x: float, y0: float, z0: float, y1: float, z1: float, ny: int, nz: int, cell: float) -> void:
	if ny <= 0 or nz <= 0:
		return
	for i in range(nz + 1):
		var z: float = z0 + i * cell
		imm.surface_add_vertex(Vector3(x, y0, z))
		imm.surface_add_vertex(Vector3(x, y1, z))
	for i in range(ny + 1):
		var y: float = y0 + i * cell
		imm.surface_add_vertex(Vector3(x, y, z0))
		imm.surface_add_vertex(Vector3(x, y, z1))


func _draw_grid_xy(imm: ImmediateMesh, x0: float, y0: float, z: float, x1: float, y1: float, nx: int, ny: int, cell: float) -> void:
	if nx <= 0 or ny <= 0:
		return
	for i in range(ny + 1):
		var y: float = y0 + i * cell
		imm.surface_add_vertex(Vector3(x0, y, z))
		imm.surface_add_vertex(Vector3(x1, y, z))
	for i in range(nx + 1):
		var x: float = x0 + i * cell
		imm.surface_add_vertex(Vector3(x, y0, z))
		imm.surface_add_vertex(Vector3(x, y1, z))


func _get_room_info() -> RoomInfo3D:
	return get_parent().get_node_or_null("RoomInfo") as RoomInfo3D


func _get_mesh_instance() -> MeshInstance3D:
	if _mesh_instance != null:
		return _mesh_instance
	var mi: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mi == null:
		mi = MeshInstance3D.new()
		mi.name = "MeshInstance3D"
		add_child(mi)
		mi.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self
	return mi

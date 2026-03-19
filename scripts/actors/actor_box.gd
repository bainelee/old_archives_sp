@tool
class_name ActorBox
extends Node3D

## 元件盒：定义 3D 元件的占用体积，在编辑器中以三面网格线框可视化。
## 挂载于 3d_actor 场景 root 下，volume 变化时自动更新 position 与网格。

const ProjectConstants = preload("res://scripts/core/project_constants.gd")
const GRID_CELL_SIZE: float = ProjectConstants.GRID_CELL_SIZE

## 材质资源：可在编辑器中调节颜色与透明度
const MAT_ACTOR_BOX_GRID: StandardMaterial3D = preload("res://assets/materials/tools_materials/mat_actor_box_grid.tres")

var _volume: Vector3 = Vector3(2, 2, 2)

@export var volume: Vector3:
	get:
		return _volume
	set(v):
		if _volume != v:
			_volume = v
			_update_from_volume()

@onready var _mesh_instance: MeshInstance3D = $MeshInstance3D

var _last_volume: Vector3 = Vector3.ZERO


func _ready() -> void:
	if Engine.is_editor_hint():
		_update_from_volume()
	else:
		# 游戏进程中默认不显示，仅建造模式时由外部设为 visible
		visible = false


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	# 编辑器内：仅 volume 变化时更新
	if _last_volume != _volume:
		_update_from_volume()


func _update_from_volume() -> void:
	if _volume.x <= 0 or _volume.y <= 0 or _volume.z <= 0:
		return

	# 半边长（米）
	var hx: float = _volume.x * GRID_CELL_SIZE * 0.5
	var hy: float = _volume.y * GRID_CELL_SIZE * 0.5
	var hz: float = _volume.z * GRID_CELL_SIZE * 0.5

	# position: 使底面贴合 y=0
	position = Vector3(0.0, hy, 0.0)

	# 更新网格
	var mi: MeshInstance3D = _get_mesh_instance()
	if mi == null:
		return

	var imm: ImmediateMesh = ImmediateMesh.new()
	imm.surface_begin(Mesh.PRIMITIVE_LINES)

	var nx: int = int(_volume.x)
	var ny: int = int(_volume.y)
	var nz: int = int(_volume.z)
	var cell: float = GRID_CELL_SIZE

	# 底面 (XZ, y=-hy)
	_draw_grid_xz(imm, -hx, -hy, -hz, hx, hz, nx, nz, cell)

	# 左墙侧面 (YZ, x=-hx)：X 为负值
	_draw_grid_yz(imm, -hx, -hy, -hz, hy, hz, ny, nz, cell)

	# 后方墙面 (XY, z=-hz)：Z 为负值
	_draw_grid_xy(imm, -hx, -hy, -hz, hx, hy, nx, ny, cell)

	imm.surface_end()

	_last_volume = _volume
	mi.mesh = imm
	mi.material_override = MAT_ACTOR_BOX_GRID


func _draw_grid_xz(imm: ImmediateMesh, x0: float, y: float, z0: float, x1: float, z1: float, nx: int, nz: int, cell: float) -> void:
	# 底面 XZ：沿 X 的线（固定 z）、沿 Z 的线（固定 x）
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
	# 后面 YZ：沿 Y 的线、沿 Z 的线
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
	# 侧面 XY：沿 X 的线、沿 Y 的线
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


func _get_mesh_instance() -> MeshInstance3D:
	if _mesh_instance != null:
		return _mesh_instance
	# 编辑器内可能尚未 ready，尝试查找子节点
	var mi: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mi == null:
		mi = MeshInstance3D.new()
		mi.name = "MeshInstance3D"
		add_child(mi)
		mi.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self
	return mi

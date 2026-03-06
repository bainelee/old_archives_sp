@tool
class_name RoomOutBlock
extends Node3D

## 房间外轮廓：根据 room_volume 生成四个黑色 Box。
## 从兄弟节点 RoomInfo3D 读取 room_volume。

@onready var _down: MeshInstance3D = $room_out_block_down
@onready var _up: MeshInstance3D = $room_out_block_up
@onready var _left: MeshInstance3D = $room_out_block_left
@onready var _right: MeshInstance3D = $room_out_block_right

var _last_volume: Vector3 = Vector3.ZERO


func _ready() -> void:
	if Engine.is_editor_hint():
		_update_blocks()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	var room_info: RoomInfo3D = _get_room_info()
	if room_info != null and _last_volume != room_info.room_volume:
		_update_blocks()


func _update_blocks() -> void:
	var room_info: RoomInfo3D = _get_room_info()
	if room_info == null:
		return
	var v: Vector3 = room_info.room_volume
	var xR: float = v.x
	var yR: float = v.y
	var zR: float = v.z
	if xR <= 0 or yR <= 0 or zR <= 0:
		return

	var size_lr: Vector3 = Vector3(0.5, 0.5 * yR + 1.2, 0.5 * zR + 1.2)
	var size_ud: Vector3 = Vector3(0.5 * xR + 1.2, 0.5, 0.5 * zR + 1.2)

	var pos_down: Vector3 = Vector3(0.0, 0.25, 0.0)
	var pos_up: Vector3 = Vector3(0.0, 0.5 * yR + 0.2 + 0.5 + 0.25, 0.0)
	var h_lr: float = (0.5 * yR + 1.2) / 2.0
	var x_offset: float = (xR * 0.5 + 0.2) / 2.0 + 0.25
	var pos_left: Vector3 = Vector3(-x_offset, h_lr, 0.0)
	var pos_right: Vector3 = Vector3(x_offset, h_lr, 0.0)

	_last_volume = v
	_set_box(_down, size_ud, pos_down)
	_set_box(_up, size_ud, pos_up)
	_set_box(_left, size_lr, pos_left)
	_set_box(_right, size_lr, pos_right)


func _set_box(mi: MeshInstance3D, size: Vector3, pos: Vector3) -> void:
	if mi == null:
		return
	# BoxMesh 默认为 1×1×1，scale = size 得到目标尺寸
	mi.transform = Transform3D(Basis.from_scale(size), pos)


func _get_room_info() -> RoomInfo3D:
	return get_parent().get_node_or_null("RoomInfo") as RoomInfo3D

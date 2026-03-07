@tool
class_name RoomOutBlock
extends Node3D

## 房间外轮廓：根据 room_volume 生成四个黑色 Box。
## 从兄弟节点 RoomInfo3D 读取 room_volume。
## 尺寸规范见 docs/design/1-editor/04-preset-room-frame.md

const GRID_SIZE: float = 0.5
const THICKNESS_OUT: float = 0.4  ## room_out_block 厚度（旧版 0.5，改为 0.4 以与格子对应）
const THICKNESS_IN: float = 0.2   ## 墙/地板厚度之和（左右墙各 0.1 或 天花板+地板各 0.1）

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

	var size_lr: Vector3 = Vector3(
		THICKNESS_OUT,
		GRID_SIZE * yR + THICKNESS_IN + THICKNESS_OUT * 2,
		GRID_SIZE * zR + THICKNESS_IN / 2
	)
	var size_ud: Vector3 = Vector3(
		GRID_SIZE * xR + THICKNESS_IN + THICKNESS_OUT * 2,
		THICKNESS_OUT,
		GRID_SIZE * zR + THICKNESS_IN / 2
	)

	var pos_down: Vector3 = Vector3(0.0, THICKNESS_OUT / 2, 0.0)
	var pos_up: Vector3 = Vector3(0.0, GRID_SIZE * yR + THICKNESS_IN + THICKNESS_OUT + THICKNESS_OUT / 2, 0.0)
	var h_lr: float = (GRID_SIZE * yR + THICKNESS_IN + THICKNESS_OUT * 2) / 2.0
	var x_offset: float = (GRID_SIZE * xR + THICKNESS_IN + THICKNESS_OUT) / 2.0
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

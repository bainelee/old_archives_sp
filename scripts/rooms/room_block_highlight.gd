class_name RoomBlockHighlight
extends Node3D

## 房间悬停高亮：半透明发光边框，结构与 RoomOutBlock 一致
## 从兄弟节点 RoomInfo3D 读取 room_volume；默认隐藏，主场景在悬停时设为可见
## Area3D 用于 3D 射线检测悬停

const GRID_SIZE: float = 0.5
const THICKNESS_OUT: float = 0.4
const THICKNESS_IN: float = 0.2
const PICK_MIN_HEIGHT: float = 0.8
const PICK_FOOTPRINT_MARGIN: float = 0.12

@onready var _down: MeshInstance3D = $room_block_down
@onready var _up: MeshInstance3D = $room_block_up
@onready var _left: MeshInstance3D = $room_block_left
@onready var _right: MeshInstance3D = $room_block_right
@onready var _collision_shape: CollisionShape3D = $Area3D/CollisionShape3D


func _ready() -> void:
	visible = true
	_update_blocks()
	_update_collision_shape()
	set_highlight_visible(false)


func _update_blocks() -> void:
	var room_info: RoomInfo3D = get_parent().get_node_or_null("RoomInfo") as RoomInfo3D
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

	_set_box(_down, size_ud, pos_down)
	_set_box(_up, size_ud, pos_up)
	_set_box(_left, size_lr, pos_left)
	_set_box(_right, size_lr, pos_right)


func _update_collision_shape() -> void:
	var room_info: RoomInfo3D = get_parent().get_node_or_null("RoomInfo") as RoomInfo3D
	if room_info == null or _collision_shape == null:
		return
	var v: Vector3 = room_info.room_volume
	var xR: float = v.x
	var yR: float = v.y
	var zR: float = v.z
	if xR <= 0 or yR <= 0 or zR <= 0:
		return
	var pick_height: float = maxf(PICK_MIN_HEIGHT, GRID_SIZE * yR + THICKNESS_IN + THICKNESS_OUT * 2)
	var sz: Vector3 = Vector3(
		GRID_SIZE * xR + PICK_FOOTPRINT_MARGIN * 2.0,
		pick_height,
		GRID_SIZE * zR + PICK_FOOTPRINT_MARGIN * 2.0
	)
	var box: BoxShape3D = (_collision_shape.shape as BoxShape3D).duplicate() as BoxShape3D
	if box:
		box.size = sz
		_collision_shape.shape = box
	## 命中层使用贴地薄层，避免前景房间高体积碰撞遮挡后景房间点击/悬停。
	_collision_shape.position = Vector3(0, sz.y / 2.0, 0)


func _set_box(mi: MeshInstance3D, size: Vector3, pos: Vector3) -> void:
	if mi == null:
		return
	mi.transform = Transform3D(Basis.from_scale(size), pos)


func set_highlight_visible(show_highlight: bool) -> void:
	if _down:
		_down.visible = show_highlight
	if _up:
		_up.visible = show_highlight
	if _left:
		_left.visible = show_highlight
	if _right:
		_right.visible = show_highlight

@tool
class_name RoomInfo3D
extends Node

## 3D 预设房间信息：供编辑器与游戏逻辑识别房间。
## 挂载于 preset_room_frame 场景 root 下。
## room_name 仅用于编辑器；游戏内名称通过 room_id 从房间表获得。

@export var room_volume: Vector3 = Vector3(20, 10, 10)

@export var room_id: String = ""

@export var room_name: String = ""

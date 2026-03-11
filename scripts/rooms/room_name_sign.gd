@tool
class_name RoomNameSign
extends Node3D

## 3D 房间名称标牌：在编辑器中于 3D 场景内显示房间中文名称。
## 挂载于房间根节点下，从兄弟节点 RoomInfo 读取 room_name 与 room_volume。

func _ready() -> void:
	_find_and_setup()


func _find_and_setup() -> bool:
	var parent := get_parent()
	if not parent:
		return false
	var room_info: RoomInfo3D = parent.get_node_or_null("RoomInfo") as RoomInfo3D
	if not room_info:
		return false

	var label: Label3D = get_node_or_null("Label3D") as Label3D
	if not label:
		label = Label3D.new()
		label.name = "Label3D"
		add_child(label)
		label.owner = owner if owner else get_tree().edited_root_scene

	label.text = room_info.room_name if room_info.room_name else room_info.room_id
	label.font_size = 160
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.outline_size = 0
	label.modulate = Color(0.95, 0.9, 0.85, 1.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# 标牌位置：房间开口（Z+）外侧居中
	position.x = 0
	position.y = 4
	position.z = 1
	return true

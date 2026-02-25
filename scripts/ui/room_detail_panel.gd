extends CanvasLayer
## 房间详情面板 - 游戏内只读展示房间信息
## 靠近屏幕右侧、垂直居中；约 600×1280 像素
## 由 game_main 在选中房间时调用 show_room，取消选中时调用 hide_panel

@onready var _panel: PanelContainer = $Panel
@onready var _label_name: Label = $Panel/Margin/Scroll/VBox/NameRow/Value
@onready var _label_type: Label = $Panel/Margin/Scroll/VBox/TypeRow/Value
@onready var _label_clean: Label = $Panel/Margin/Scroll/VBox/CleanRow/Value
@onready var _label_size: Label = $Panel/Margin/Scroll/VBox/SizeRow/Value
@onready var _label_desc: RichTextLabel = $Panel/Margin/Scroll/VBox/DescRow/Content
@onready var _resources_container: VBoxContainer = $Panel/Margin/Scroll/VBox/ResourcesRow/List


func _ready() -> void:
	visible = false


func show_room(room: RoomInfo) -> void:
	if room == null:
		hide_panel()
		return
	_label_name.text = room.room_name if room.room_name else "未命名"
	_label_type.text = RoomInfo.get_room_type_name(room.room_type)
	_label_clean.text = RoomInfo.get_clean_status_name(room.clean_status)
	_label_size.text = "%d×%d" % [room.rect.size.x, room.rect.size.y]
	_label_desc.text = room.desc if room.desc else "（无描述）"
	_update_resources(room.resources)
	visible = true


func _update_resources(resources: Array) -> void:
	for child in _resources_container.get_children():
		child.queue_free()
	if resources.is_empty():
		var lbl: Label = Label.new()
		lbl.text = "（无资源产出）"
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		_resources_container.add_child(lbl)
	else:
		for r in resources:
			if r is Dictionary:
				var rt: int = int(r.get("resource_type", RoomInfo.ResourceType.NONE))
				var amt: int = int(r.get("resource_amount", 0))
				var lbl: Label = Label.new()
				lbl.text = RoomInfo.get_resource_type_name(rt) + " +%d" % amt
				lbl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
				_resources_container.add_child(lbl)


func hide_panel() -> void:
	visible = false

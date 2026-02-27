extends CanvasLayer
## 房间详情面板 - 游戏内只读展示房间信息
## 靠近屏幕右侧、垂直居中；约 600×1280 像素
## 由 game_main 在选中房间时调用 show_room，取消选中时调用 hide_panel
## 已建设房间显示：存量、每小时产出、每小时消耗（12-built-room-system）

const ZoneTypeScript = preload("res://scripts/core/zone_type.gd")
const BuiltRoomHelper = preload("res://scripts/game/game_main_built_room.gd")
const _GameValuesRef = preload("res://scripts/core/game_values_ref.gd")

@onready var _panel: PanelContainer = $Panel
@onready var _label_name: Label = $Panel/Margin/Scroll/VBox/NameRow/Value
@onready var _label_type: Label = $Panel/Margin/Scroll/VBox/TypeRow/Value
@onready var _label_clean: Label = $Panel/Margin/Scroll/VBox/CleanRow/Value
@onready var _label_size: Label = $Panel/Margin/Scroll/VBox/SizeRow/Value
@onready var _zone_op_row: VBoxContainer = $Panel/Margin/Scroll/VBox/ZoneOpRow
@onready var _zone_op_content: VBoxContainer = $Panel/Margin/Scroll/VBox/ZoneOpRow/Content
@onready var _resources_container: VBoxContainer = $Panel/Margin/Scroll/VBox/ResourcesRow/List
@onready var _resources_label: Label = $Panel/Margin/Scroll/VBox/ResourcesRow/Label
@onready var _label_desc: RichTextLabel = $Panel/Margin/Scroll/VBox/DescRow/Content

## 当前显示的房间，用于实时刷新存量/产出/消耗
var _current_room: RoomInfo = null


func _ready() -> void:
	visible = false


func _process(_delta: float) -> void:
	## 面板可见时，实时刷新存量等数据（研究区存量每游戏小时变化）
	if visible and _current_room != null:
		_refresh_dynamic_data()


func _refresh_dynamic_data() -> void:
	if _current_room == null:
		return
	_update_zone_operation(_current_room)
	_update_resources(_current_room)


func show_room(room: RoomInfo) -> void:
	if room == null:
		hide_panel()
		return
	_current_room = room
	_label_name.text = room.get_display_name()
	_label_type.text = RoomInfo.get_room_type_name(room.room_type)
	_label_clean.text = RoomInfo.get_clean_status_name(room.clean_status)
	_label_size.text = "%d×%d" % [room.rect.size.x, room.rect.size.y]
	_label_desc.text = room.get_display_desc()
	_update_zone_operation(room)
	_update_resources(room)
	visible = true


func _update_zone_operation(room: RoomInfo) -> void:
	for child in _zone_op_content.get_children():
		child.queue_free()
	if room.zone_type == 0:
		_zone_op_row.visible = false
		return
	_zone_op_row.visible = true
	var zone_name: String = ZoneTypeScript.get_zone_name(room.zone_type)
	_add_zone_op_line(tr("LABEL_ZONE"), zone_name, Color(0.7, 0.75, 0.85))
	if room.zone_type == ZoneTypeScript.Type.RESEARCH:
		_add_research_zone_info(room)
	elif room.zone_type == ZoneTypeScript.Type.CREATION:
		_add_creation_zone_info(room)
	else:
		_add_zone_op_line(tr("LABEL_EXPLAIN"), tr("LABEL_NOTE"), Color(0.6, 0.6, 0.65))


static func _resource_name_to_type(res_name: String) -> int:
	match res_name:
		"cognition": return RoomInfo.ResourceType.COGNITION
		"computation": return RoomInfo.ResourceType.COMPUTATION
		"willpower": return RoomInfo.ResourceType.WILL
		"permission": return RoomInfo.ResourceType.PERMISSION
		_: return RoomInfo.ResourceType.NONE


func _add_research_zone_info(room: RoomInfo) -> void:
	## 研究区：存量、每小时产出
	var gv: Node = _GameValuesRef.get_singleton()
	if gv == null:
		return
	var amt_per_unit: int = gv.get_research_output_per_unit_per_hour(room.room_type)
	if amt_per_unit <= 0:
		return
	var rt: int = _resource_name_to_type(gv.get_research_output_resource(room.room_type))
	var units: int = BuiltRoomHelper.get_room_units(room)
	var output_hour: int = units * amt_per_unit
	var reserve_amt: int = 0
	for r in room.resources:
		if r is Dictionary and int(r.get("resource_type", -1)) == rt:
			reserve_amt = int(r.get("resource_amount", 0))
			break
	_add_zone_op_line(tr("LABEL_CURRENT_RESERVE"), "%s %d" % [RoomInfo.get_resource_type_name(rt), reserve_amt], Color(0.95, 0.9, 0.7))
	_add_zone_op_line(tr("LABEL_HOURLY_OUTPUT"), "%s +%d" % [RoomInfo.get_resource_type_name(rt), output_hour], Color(0.5, 0.9, 0.6))


func _add_creation_zone_info(room: RoomInfo) -> void:
	## 造物区：每小时消耗、产出；暂停研究时显示状态
	var gv: Node = _GameValuesRef.get_singleton()
	if gv == null:
		return
	var ui: Node = get_node_or_null("../UIMain")
	var is_paused: bool = ui != null and BuiltRoomHelper.is_creation_zone_paused(room, ui)
	if is_paused:
		_add_zone_op_line(tr("LABEL_STATUS"), tr("LABEL_STATUS_PAUSED"), Color(0.9, 0.3, 0.3))
	var will_per_unit: int = gv.get_creation_consume_per_unit_per_hour(room.room_type)
	var output_per_unit: int = gv.get_creation_produce_per_unit_per_hour(room.room_type)
	var units: int = BuiltRoomHelper.get_room_units(room)
	var will_hour: int = units * will_per_unit
	var output_hour: int = units * output_per_unit
	var need_24h: int = BuiltRoomHelper.get_creation_zone_24h_consumption(room)
	_add_zone_op_line(tr("LABEL_HOURLY_CONSUME"), tr("LABEL_WILL_H") % will_hour, Color(0.95, 0.7, 0.5))
	if is_paused:
		_add_zone_op_line(tr("LABEL_RECOVER_COND"), tr("WILL_24H_COND") % need_24h, Color(0.7, 0.75, 0.85))
	match room.room_type:
		RoomInfo.RoomType.SERVER_ROOM:
			_add_zone_op_line(tr("LABEL_HOURLY_OUTPUT"), tr("LABEL_PERMISSION_H") % output_hour, Color(0.5, 0.9, 0.6))
		RoomInfo.RoomType.REASONING:
			_add_zone_op_line(tr("LABEL_HOURLY_OUTPUT"), tr("LABEL_INFO_H") % output_hour, Color(0.5, 0.9, 0.6))
		_:
			pass


func _add_zone_op_line(label_text: String, value: String, value_color: Color) -> void:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var lbl: Label = Label.new()
	lbl.text = label_text + tr("LABEL_SUFFIX")
	lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	lbl.add_theme_font_size_override("font_size", 13)
	var val: Label = Label.new()
	val.text = value
	val.add_theme_color_override("font_color", value_color)
	val.add_theme_font_size_override("font_size", 13)
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(lbl)
	h.add_child(val)
	_zone_op_content.add_child(h)


func _update_resources(room: RoomInfo) -> void:
	for child in _resources_container.get_children():
		child.queue_free()
	if room.zone_type == ZoneTypeScript.Type.RESEARCH:
		_resources_label.text = tr("LABEL_CURRENT_RESERVE")
	else:
		_resources_label.text = tr("LABEL_RESOURCES")
	var resources: Array = room.resources
	if resources.is_empty():
		var lbl: Label = Label.new()
		lbl.text = tr("RESERVE_NONE") if room.zone_type != 0 else tr("RESERVE_NO_OUTPUT")
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		_resources_container.add_child(lbl)
	else:
		for r in resources:
			if r is Dictionary:
				var rt: int = int(r.get("resource_type", RoomInfo.ResourceType.NONE))
				var amt: int = int(r.get("resource_amount", 0))
				var lbl: Label = Label.new()
				lbl.text = RoomInfo.get_resource_type_name(rt) + "  %d" % amt
				lbl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
				_resources_container.add_child(lbl)


func hide_panel() -> void:
	_current_room = null
	visible = false

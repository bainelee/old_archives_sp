extends PanelContainer
## 建设房间悬停面板 - 显示在鼠标左侧
## 显示：房间名称、房间类型、建设后产出/消耗、建设花费、研究员占用、材料不足提示

const ZoneTypeScript = preload("res://scripts/core/zone_type.gd")
const _GameValuesRef = preload("res://scripts/core/game_values_ref.gd")

@onready var _label_name: Label = $Margin/VBox/Name
@onready var _label_room_type: Label = $Margin/VBox/RoomType
@onready var _label_output: Label = $Margin/VBox/Output
@onready var _label_consume: Label = $Margin/VBox/Consume
@onready var _label_cost: Label = $Margin/VBox/Cost
@onready var _label_researcher: Label = $Margin/VBox/Researcher
@onready var _label_insufficient: Label = $Margin/VBox/Insufficient

const LABEL_COLOR := Color(0.95, 0.9, 0.8, 1)
const LABEL_COLOR_DIM := Color(0.7, 0.75, 0.85, 1)
const INSUFFICIENT_COLOR := Color(0.95, 0.4, 0.35, 1)


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_for_room(room: RoomInfo, zone_type: int, player_resources: Dictionary, can_afford: bool, researchers_needed: int = 0, researchers_available: int = 0) -> void:
	if room == null:
		hide_panel()
		return
	_label_name.text = room.get_display_name()
	_label_room_type.text = tr("HOVER_ROOM_TYPE") % RoomInfo.get_room_type_name(room.room_type)
	var cost: Dictionary = room.get_construction_cost(zone_type)
	_label_cost.text = tr("HOVER_CONSTRUCTION_COST") % _format_cost_with_have(cost, player_resources)
	if _label_researcher:
		var needed: int = researchers_needed if researchers_needed > 0 else room.get_construction_researcher_count(zone_type)
		_label_researcher.text = tr("RESEARCHER_OCCUPANCY") % [needed, researchers_available]
		_label_researcher.visible = true
	_label_output.text = tr("HOVER_OUTPUT_HOUR") % _get_output_text(room, zone_type)
	_label_consume.text = tr("HOVER_CONSUME_HOUR") % _get_consume_text(room, zone_type)
	_label_consume.visible = zone_type == 2  ## CREATION
	_label_insufficient.visible = not can_afford
	_label_insufficient.text = tr("HOVER_INSUFFICIENT")
	_label_insufficient.add_theme_color_override("font_color", INSUFFICIENT_COLOR)
	visible = true


func _get_output_text(room: RoomInfo, zone_type: int) -> String:
	var gv: Node = _GameValuesRef.get_singleton()
	if gv == null:
		return tr("OUTPUT_NONE")
	var area: int = room.rect.size.x * room.rect.size.y
	var units: int = maxi(1, int(ceil(float(area) / 5.0)))
	if zone_type == 1:  ## RESEARCH
		var amt: int = gv.get_research_output_per_unit_per_hour(room.room_type)
		if amt <= 0:
			return tr("OUTPUT_NONE")
		var res: String = gv.get_research_output_resource(room.room_type)
		var res_key: String = _resource_key_for_name(res)
		return tr("OUTPUT_RES_H") % [tr(res_key), amt * units]
	elif zone_type == 2:  ## CREATION
		var output_per_unit: int = gv.get_creation_produce_per_unit_per_hour(room.room_type)
		if output_per_unit <= 0:
			return tr("OUTPUT_NONE")
		match room.room_type:
			RoomInfo.RoomType.SERVER_ROOM:
				return tr("LABEL_PERMISSION_H") % (output_per_unit * units)
			RoomInfo.RoomType.REASONING:
				return tr("LABEL_INFO_H") % (output_per_unit * units)
			_:
				return tr("OUTPUT_NONE")
	elif zone_type == 4:  ## LIVING
		return tr("LABEL_HOUSING") % gv.get_housing_per_dormitory()
	return tr("OUTPUT_NONE")


func _get_consume_text(room: RoomInfo, zone_type: int) -> String:
	if zone_type != 2:  ## CREATION
		return tr("OUTPUT_NONE")
	var gv: Node = _GameValuesRef.get_singleton()
	if gv == null:
		return tr("OUTPUT_NONE")
	var area: int = room.rect.size.x * room.rect.size.y
	var units: int = maxi(1, int(ceil(float(area) / 5.0)))
	var consume_per_unit: int = gv.get_creation_consume_per_unit_per_hour(room.room_type)
	return tr("LABEL_WILL_H") % (consume_per_unit * units)


func _resource_key_for_name(key: String) -> String:
	match key:
		"cognition": return "RESOURCE_COGNITION"
		"computation": return "RESOURCE_COMPUTATION"
		"willpower": return "RESOURCE_WILL"
		"permission": return "RESOURCE_PERMISSION"
		"info": return "RESOURCE_INFO"
		"truth": return "RESOURCE_TRUTH"
		_: return key


func _format_cost_with_have(cost: Dictionary, player_resources: Dictionary) -> String:
	if cost.is_empty():
		return tr("COST_NONE")
	var parts: PackedStringArray = []
	var key_tr: Dictionary = {
		"cognition": "RESOURCE_COGNITION",
		"computation": "RESOURCE_COMPUTATION",
		"willpower": "RESOURCE_WILL",
		"permission": "RESOURCE_PERMISSION",
		"info": "RESOURCE_INFO",
		"truth": "RESOURCE_TRUTH",
	}
	for key in cost:
		var amt: int = int(cost.get(key, 0))
		if amt > 0:
			var have: int = int(player_resources.get(key, 0))
			var name_str: String = tr(key_tr.get(key, key))
			parts.append(tr("COST_WITH_HAVE") % [name_str, amt, have])
	return ", ".join(parts) if parts.size() > 0 else tr("COST_NONE")


func hide_panel() -> void:
	visible = false


func update_position(mouse_pos: Vector2, viewport_size: Vector2) -> void:
	var panel_size: Vector2 = size
	var padding: float = 12.0
	var left_x: float = mouse_pos.x - panel_size.x - padding
	var y: float = clampf(mouse_pos.y - panel_size.y / 2.0, 0, viewport_size.y - panel_size.y)
	position = Vector2(left_x, y)

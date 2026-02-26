extends PanelContainer
## 建设房间悬停面板 - 显示在鼠标左侧
## 显示：房间名称、房间类型、建设后产出/消耗、建设花费、研究员占用、材料不足提示

const ZoneTypeScript = preload("res://scripts/core/zone_type.gd")

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

## 研究区：每单位每小时产出（08 6.1）
const RESEARCH_OUTPUT_PER_UNIT: Dictionary = {
	RoomInfo.RoomType.LIBRARY: {"cognition": 5},
	RoomInfo.RoomType.LAB: {"computation": 5},
	RoomInfo.RoomType.ARCHIVE: {"permission": 10},
	RoomInfo.RoomType.CLASSROOM: {"willpower": 10},
}
## 造物区：每单位每小时消耗与产出（08 7.1）
const CREATION_WILL_PER_UNIT := 15
const CREATION_OUTPUT_PER_UNIT := 15


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_for_room(room: RoomInfo, zone_type: int, player_resources: Dictionary, can_afford: bool, researchers_needed: int = 0, researchers_available: int = 0) -> void:
	if room == null:
		hide_panel()
		return
	_label_name.text = room.room_name if room.room_name else "未命名"
	_label_room_type.text = "房间类型：%s" % RoomInfo.get_room_type_name(room.room_type)
	var cost: Dictionary = room.get_construction_cost(zone_type)
	_label_cost.text = "建设花费：%s" % _format_cost_with_have(cost, player_resources)
	if _label_researcher:
		var needed: int = researchers_needed if researchers_needed > 0 else room.get_construction_researcher_count(zone_type)
		_label_researcher.text = "研究员占用：%d 人（可用 %d）" % [needed, researchers_available]
		_label_researcher.visible = true
	_label_output.text = "建设后每小时产出：%s" % _get_output_text(room, zone_type)
	_label_consume.text = "建设后每小时消耗：%s" % _get_consume_text(room, zone_type)
	_label_consume.visible = zone_type == 2  ## CREATION
	_label_insufficient.visible = not can_afford
	_label_insufficient.text = "当前资源不足"
	_label_insufficient.add_theme_color_override("font_color", INSUFFICIENT_COLOR)
	visible = true


func _get_output_text(room: RoomInfo, zone_type: int) -> String:
	var area: int = room.rect.size.x * room.rect.size.y
	var units: int = maxi(1, int(ceil(float(area) / 5.0)))
	if zone_type == 1:  ## RESEARCH
		var out: Dictionary = RESEARCH_OUTPUT_PER_UNIT.get(room.room_type, {})
		if out.is_empty():
			return "（无）"
		var parts: PackedStringArray = []
		for k in out:
			var name_map: Dictionary = {"cognition": "认知", "computation": "计算", "willpower": "意志", "permission": "权限"}
			parts.append("%s %d/h" % [name_map.get(k, k), out[k] * units])
		return ", ".join(parts)
	elif zone_type == 2:  ## CREATION
		match room.room_type:
			RoomInfo.RoomType.SERVER_ROOM:
				return "权限 %d/h" % (CREATION_OUTPUT_PER_UNIT * units)
			RoomInfo.RoomType.REASONING:
				return "信息 %d/h" % (CREATION_OUTPUT_PER_UNIT * units)
			_:
				return "（无）"
	elif zone_type == 4:  ## LIVING
		return "住房 4"  ## 08 5.4 宿舍 3 单位提供 4 住房
	return "（无）"


func _get_consume_text(room: RoomInfo, zone_type: int) -> String:
	if zone_type != 2:  ## CREATION
		return "（无）"
	var area: int = room.rect.size.x * room.rect.size.y
	var units: int = maxi(1, int(ceil(float(area) / 5.0)))
	return "意志 %d/h" % (CREATION_WILL_PER_UNIT * units)


func _format_cost_with_have(cost: Dictionary, player_resources: Dictionary) -> String:
	if cost.is_empty():
		return "无"
	var parts: PackedStringArray = []
	var key_names: Dictionary = {
		"cognition": "认知因子",
		"computation": "计算因子",
		"willpower": "意志因子",
		"permission": "权限因子",
		"info": "信息",
		"truth": "真相",
	}
	for key in cost:
		var amt: int = int(cost.get(key, 0))
		if amt > 0:
			var have: int = int(player_resources.get(key, 0))
			var name_str: String = key_names.get(key, key)
			parts.append("%s %d (拥有 %d)" % [name_str, amt, have])
	return ", ".join(parts) if parts.size() > 0 else "无"


func hide_panel() -> void:
	visible = false


func update_position(mouse_pos: Vector2, viewport_size: Vector2) -> void:
	var panel_size: Vector2 = size
	var padding: float = 12.0
	var left_x: float = mouse_pos.x - panel_size.x - padding
	var y: float = clampf(mouse_pos.y - panel_size.y / 2.0, 0, viewport_size.y - panel_size.y)
	position = Vector2(left_x, y)

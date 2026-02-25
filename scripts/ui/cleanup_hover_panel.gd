extends PanelContainer
## 清理房间悬停面板 - 显示在鼠标左侧
## 显示：房间名称、可建设区域、资源储量、清理花费、清理时间、资源不足提示

@onready var _label_name: Label = $Margin/VBox/Name
@onready var _label_build_area: Label = $Margin/VBox/BuildArea
@onready var _label_resources: Label = $Margin/VBox/Resources
@onready var _label_cost: Label = $Margin/VBox/Cost
@onready var _label_time: Label = $Margin/VBox/Time
@onready var _label_insufficient: Label = $Margin/VBox/Insufficient

const LABEL_COLOR := Color(0.95, 0.9, 0.8, 1)
const LABEL_COLOR_DIM := Color(0.7, 0.75, 0.85, 1)
const INSUFFICIENT_COLOR := Color(0.95, 0.4, 0.35, 1)


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_for_room(room: RoomInfo, _player_resources: Dictionary, can_afford: bool) -> void:
	if room == null:
		hide_panel()
		return
	_label_name.text = room.room_name if room.room_name else "未命名"
	_label_build_area.text = "可建设区域：%d×%d" % [room.rect.size.x, room.rect.size.y]
	_label_resources.text = _format_room_resources(room.resources)
	var cost: Dictionary = room.get_cleanup_cost()
	_label_cost.text = "清理花费：%s" % _format_cost(cost)
	_label_time.text = "清理时间：%.0f 小时" % room.get_cleanup_time_hours()
	_label_insufficient.visible = not can_afford
	_label_insufficient.text = "当前资源不足"
	_label_insufficient.add_theme_color_override("font_color", INSUFFICIENT_COLOR)
	visible = true


func _format_room_resources(resources: Array) -> String:
	if resources.is_empty():
		return "资源储量：（无）"
	var parts: PackedStringArray = []
	for r in resources:
		if r is Dictionary:
			var rt: int = int(r.get("resource_type", RoomInfo.ResourceType.NONE))
			var amt: int = int(r.get("resource_amount", 0))
			parts.append(RoomInfo.get_resource_type_name(rt) + " %d" % amt)
	return "资源储量：" + ", ".join(parts)


func _format_cost(cost: Dictionary) -> String:
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
			parts.append("%s %d" % [key_names.get(key, key), amt])
	return ", ".join(parts) if parts.size() > 0 else "无"


func hide_panel() -> void:
	visible = false


func update_position(mouse_pos: Vector2, viewport_size: Vector2) -> void:
	var panel_size: Vector2 = size
	var padding: float = 12.0
	var left_x: float = mouse_pos.x - panel_size.x - padding
	var y: float = clampf(mouse_pos.y - panel_size.y / 2.0, 0, viewport_size.y - panel_size.y)
	position = Vector2(left_x, y)

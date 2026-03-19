extends "res://scripts/ui/detail_hover_panel_base.gd"
## 清理房间悬停面板 - 显示在鼠标左侧
## 显示：房间名称、可建设区域、资源储量、清理花费、清理时间、资源不足提示

@onready var _label_name: Label = $Margin/VBox/Name
@onready var _label_build_area: Label = $Margin/VBox/BuildArea
@onready var _label_resources: Label = $Margin/VBox/Resources
@onready var _label_cost: Label = $Margin/VBox/Cost
@onready var _label_researcher: Label = $Margin/VBox/Researcher
@onready var _label_time: Label = $Margin/VBox/Time
@onready var _label_insufficient: Label = $Margin/VBox/Insufficient

const LABEL_COLOR := Color(0.95, 0.9, 0.8, 1)
const LABEL_COLOR_DIM := Color(0.7, 0.75, 0.85, 1)
const INSUFFICIENT_COLOR := Color(0.95, 0.4, 0.35, 1)


func show_for_room(room: ArchivesRoomInfo, player_resources: Dictionary, can_afford: bool, researchers_needed: int = 0, researchers_available: int = 0) -> void:
	if room == null:
		hide_panel()
		return
	_label_name.text = room.get_display_name()
	_label_build_area.text = tr("HOVER_BUILD_AREA") % [room.rect.size.x, room.rect.size.y]
	_label_resources.text = _format_room_resources(room.resources)
	var cost: Dictionary = room.get_cleanup_cost()
	_label_cost.text = tr("HOVER_CLEANUP_COST") % UIUtils.format_cost_with_have(cost, player_resources)
	if _label_researcher:
		var needed: int = researchers_needed if researchers_needed > 0 else room.get_cleanup_researcher_count()
		_label_researcher.text = tr("RESEARCHER_OCCUPANCY") % [needed, researchers_available]
		_label_researcher.visible = true
	_label_time.text = tr("HOVER_CLEANUP_TIME") % room.get_cleanup_time_hours()
	_label_insufficient.visible = not can_afford
	_label_insufficient.text = tr("HOVER_INSUFFICIENT")
	_label_insufficient.add_theme_color_override("font_color", INSUFFICIENT_COLOR)
	visible = true


func _format_room_resources(resources: Array) -> String:
	if resources.is_empty():
		return tr("HOVER_RESERVE_EMPTY")
	var parts: PackedStringArray = []
	for r in resources:
		if r is Dictionary:
			var rt: int = int(r.get("resource_type", ArchivesRoomInfo.ResourceType.NONE))
			var amt: int = int(r.get("resource_amount", 0))
			parts.append(ArchivesRoomInfo.get_resource_type_name(rt) + " %d" % amt)
	return tr("HOVER_RESERVE_LINE") % ", ".join(parts)

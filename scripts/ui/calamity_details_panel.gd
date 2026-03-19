@tool
extends "res://scripts/ui/detail_panel_base.gd"
## 灾厄值详细信息面板
## 设计来源：Figma old_archives_main_ui (67:346 / 122:23)
## 用于展示灾厄变化条目（上升/下降程度）

@export var title_state_label_path: NodePath = NodePath("DetailsVboxContainer/HeaderVbox/DetailsTitle/TitleLayout/TextTitleState")


func _enter_tree() -> void:
	super._enter_tree()
	_update_title_state(_status_from_ratio(0.0))


func _ready() -> void:
	super._ready()


func show_panel(data: Dictionary) -> void:
	super.show_panel(data)
	var current_value: float = float(data.get("current", 0.0))
	var max_value: float = float(data.get("max", 30000.0))
	var ratio: float = 0.0 if max_value <= 0.0 else clampf(current_value / max_value, 0.0, 1.0)
	var state_text: String = str(data.get("status", "")).strip_edges()
	if state_text.is_empty():
		state_text = _status_from_ratio(ratio)
	_update_title_state(state_text)


func _update_title_state(state_text: String) -> void:
	var label := get_node_or_null(title_state_label_path) as Label
	if not label:
		return
	label.text = state_text.to_upper()
	label.size_flags_horizontal = Control.SIZE_SHRINK_END


func _status_from_ratio(ratio: float) -> String:
	var p: float = clampf(ratio, 0.0, 1.0)
	if p <= 0.0:
		return "NULL"
	if p <= 0.10:
		return "MINIMAL"
	if p <= 0.30:
		return "WORSE"
	if p <= 0.80:
		return "CHECK"
	return "CHECKMATE"


func update_position(_mouse_pos: Vector2, viewport_size: Vector2) -> void:
	var panel_size := size
	var ui_root := get_parent()
	if not ui_root:
		super.update_position(_mouse_pos, viewport_size)
		return
	var calamity_inline := ui_root.get_node_or_null("BottomRightBar/Margin/Content/CalamityInline") as Control
	if not calamity_inline:
		super.update_position(_mouse_pos, viewport_size)
		return
	# 与灾厄值进度条组件垂直对齐（中心线对齐）
	var x: float = calamity_inline.global_position.x + (calamity_inline.size.x - panel_size.x) * 0.5
	x = clampf(x, 0.0, viewport_size.x - panel_size.x)
	var y: float = _get_position_y(_mouse_pos, panel_size, viewport_size)
	position = Vector2(x, y)


func _get_position_y(_mouse_pos: Vector2, panel_size: Vector2, viewport_size: Vector2) -> float:
	var ui_root := get_parent()
	if not ui_root:
		return super._get_position_y(_mouse_pos, panel_size, viewport_size)
	var bottom_bar := ui_root.get_node_or_null("BottomRightBar") as Control
	if not bottom_bar:
		return super._get_position_y(_mouse_pos, panel_size, viewport_size)
	# 面板底部到屏幕底部距离 = BottomBar 高度
	var y: float = viewport_size.y - panel_size.y - bottom_bar.size.y
	return clampf(y, 0.0, viewport_size.y - panel_size.y)

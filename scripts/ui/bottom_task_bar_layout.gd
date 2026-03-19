@tool
extends Control

## 底栏排版参数（单位：px）
## 左组：中枢与三重评议会
## 右组：区域建设/改造/清理/技术栈 + 灾厄条

@export var left_group_gap: int = 8:
	set(v):
		left_group_gap = max(0, v)
		_apply_layout()

@export var right_group_gap: int = 8:
	set(v):
		right_group_gap = max(0, v)
		_apply_layout()

@export var right_to_calamity_gap: int = 36:
	set(v):
		right_to_calamity_gap = max(0, v)
		_apply_layout()

@export var right_margin: int = 0:
	set(v):
		right_margin = max(0, v)
		_apply_layout()


func _enter_tree() -> void:
	_apply_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_layout()


func _apply_layout() -> void:
	var btn_center: Control = get_node_or_null("BtnCenter") as Control
	var btn_council: Control = get_node_or_null("BtnCouncil") as Control
	var btn_build: Control = get_node_or_null("BtnBuild") as Control
	var btn_renovate: Control = get_node_or_null("BtnRenovate") as Control
	var btn_cleanup: Control = get_node_or_null("BtnCleanup") as Control
	var btn_tech: Control = get_node_or_null("BtnTechStack") as Control
	var calamity: Control = get_node_or_null("CalamityInline") as Control

	if not btn_center or not btn_council or not btn_build or not btn_renovate or not btn_cleanup or not btn_tech or not calamity:
		return

	var w_center: float = _node_width(btn_center)
	var w_council: float = _node_width(btn_council)
	var w_build: float = _node_width(btn_build)
	var w_renovate: float = _node_width(btn_renovate)
	var w_cleanup: float = _node_width(btn_cleanup)
	var w_tech: float = _node_width(btn_tech)
	var w_calamity: float = _node_width(calamity)

	## 左组
	_set_x(btn_center, 0.0, w_center)
	_set_x(btn_council, w_center + float(left_group_gap), w_council)

	## 右组（从右向左锚定）
	var content_width: float = size.x
	if content_width <= 0.0:
		content_width = custom_minimum_size.x
	if content_width <= 0.0:
		return

	var calamity_x: float = content_width - float(right_margin) - w_calamity
	var tech_x: float = calamity_x - float(right_to_calamity_gap) - w_tech
	var cleanup_x: float = tech_x - float(right_group_gap) - w_cleanup
	var renovate_x: float = cleanup_x - float(right_group_gap) - w_renovate
	var build_x: float = renovate_x - float(right_group_gap) - w_build

	_set_x(calamity, calamity_x, w_calamity)
	_set_x(btn_tech, tech_x, w_tech)
	_set_x(btn_cleanup, cleanup_x, w_cleanup)
	_set_x(btn_renovate, renovate_x, w_renovate)
	_set_x(btn_build, build_x, w_build)

	## 保持统一高度 40
	_set_h40(btn_center)
	_set_h40(btn_council)
	_set_h40(btn_build)
	_set_h40(btn_renovate)
	_set_h40(btn_cleanup)
	_set_h40(btn_tech)
	_set_h40(calamity)


func _set_x(node: Control, left_x: float, width: float) -> void:
	node.offset_left = left_x
	node.offset_right = left_x + width


func _set_h40(node: Control) -> void:
	node.offset_top = 0.0
	node.offset_bottom = 40.0


func _node_width(node: Control) -> float:
	if node.custom_minimum_size.x > 0.0:
		return node.custom_minimum_size.x
	var w: float = node.offset_right - node.offset_left
	if w > 0.0:
		return w
	return 100.0

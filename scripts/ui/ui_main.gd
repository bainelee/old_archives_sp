extends CanvasLayer
## 主 UI 场景 - 顶层资源条
## 显示：资源-因子、资源-货币、人员 三类数据
## 可挂载至任意主场景，数据通过属性或 Autoload 注入

signal cleanup_button_pressed
signal build_button_pressed

@onready var _label_cognition: Label = $TopBar/Content/HBox/Factors/Cognition/Value
@onready var _label_computation: Label = $TopBar/Content/HBox/Factors/Computation/Value
@onready var _label_will: Label = $TopBar/Content/HBox/Factors/Will/Value
@onready var _label_permission: Label = $TopBar/Content/HBox/Factors/Permission/Value
@onready var _label_info: Label = $TopBar/Content/HBox/Currency/Info/Value
@onready var _label_truth: Label = $TopBar/Content/HBox/Currency/Truth/Value
@onready var _label_researcher: Label = $TopBar/Content/HBox/Personnel/Researcher/Value
@onready var _label_eroded: Label = $TopBar/Content/HBox/Personnel/Eroded/Value
@onready var _label_investigator: Label = $TopBar/Content/HBox/Personnel/Investigator/Value
@onready var _researcher_hover_area: Control = $TopBar/Content/HBox/Personnel/Researcher
@onready var _researcher_hover_panel: PanelContainer = $ResearcherHoverPanel
@onready var _factor_hover_panel: PanelContainer = $FactorHoverPanel
@onready var _factor_cognition: Control = $TopBar/Content/HBox/Factors/Cognition
@onready var _factor_computation: Control = $TopBar/Content/HBox/Factors/Computation
@onready var _factor_will: Control = $TopBar/Content/HBox/Factors/Will
@onready var _factor_permission: Control = $TopBar/Content/HBox/Factors/Permission
@onready var _pan_speed_slider: HSlider = $DebugInfoPanel/Margin/VBox/PanSpeedRow/PanSpeedSlider
@onready var _pan_speed_value_label: Label = $DebugInfoPanel/Margin/VBox/PanSpeedRow/Value

## 资源-因子（使用显式后备变量，避免 Node.get() 对自定义属性解析异常）
var _cognition_amount: int = 0
var cognition_amount: int:
	get: return _cognition_amount
	set(v):
		_cognition_amount = int(v) if v != null else 0
		_update_label(_label_cognition, _cognition_amount)
var _computation_amount: int = 0
var computation_amount: int:
	get: return _computation_amount
	set(v):
		var val: int = int(v) if v != null else 0
		_computation_amount = val
		_update_label(_label_computation, val)
var _will_amount: int = 0
var will_amount: int:
	get: return _will_amount
	set(v):
		_will_amount = int(v) if v != null else 0
		_update_label(_label_will, _will_amount)
var _permission_amount: int = 0
var permission_amount: int:
	get: return _permission_amount
	set(v):
		_permission_amount = int(v) if v != null else 0
		_update_label(_label_permission, _permission_amount)

## 资源-货币
var info_amount: int = 0:
	set(v):
		info_amount = v
		_update_label(_label_info, v)
var truth_amount: int = 0:
	set(v):
		truth_amount = v
		_update_label(_label_truth, v)

## 人员（researcher_count=总数，eroded_count=被侵蚀数；显示为 未侵蚀/总数）
var researcher_count: int = 0:
	set(v):
		researcher_count = v
		_update_researcher_display()
var eroded_count: int = 0:
	set(v):
		eroded_count = v
		_update_researcher_display()
		_update_label(_label_eroded, v)
## 清理中临时占用的研究员数（由 GameMain 同步，清理结束后返还）
var researchers_in_cleanup: int = 0:
	set(v):
		researchers_in_cleanup = v
		_update_researcher_display()
		_update_researcher_hover_if_visible()
## 建设中占用的研究员数（预留，暂为 0）
var researchers_in_construction: int = 0:
	set(v):
		researchers_in_construction = v
		_update_researcher_display()
		_update_researcher_hover_if_visible()
## 房间内工作的研究员数（预留，暂为 0）
var researchers_working_in_rooms: int = 0:
	set(v):
		researchers_working_in_rooms = v
		_update_researcher_display()
		_update_researcher_hover_if_visible()
var investigator_count: int = 0:
	set(v):
		investigator_count = v
		_update_label(_label_investigator, v)


func _ready() -> void:
	_refresh_all()
	var btn: Button = get_node_or_null("BottomRightBar/BtnCleanup")
	if btn:
		btn.pressed.connect(_on_cleanup_button_pressed)
	var build_btn: Button = get_node_or_null("BottomRightBar/BtnBuild")
	if build_btn:
		build_btn.pressed.connect(_on_build_button_pressed)
	var btn_researcher_list: Button = get_node_or_null("BarBelowTop/BtnResearcherList")
	if btn_researcher_list:
		btn_researcher_list.pressed.connect(_on_researcher_list_button_pressed)
	if _researcher_hover_area:
		_researcher_hover_area.mouse_filter = Control.MOUSE_FILTER_STOP
		_researcher_hover_area.mouse_entered.connect(_on_researcher_hover_entered)
		_researcher_hover_area.mouse_exited.connect(_on_researcher_hover_exited)
	_setup_factor_hover()
	if _pan_speed_slider:
		_pan_speed_slider.value_changed.connect(_on_pan_speed_changed)
		_on_pan_speed_changed(_pan_speed_slider.value)
	var pan_label: Label = get_node_or_null("DebugInfoPanel/Margin/VBox/PanSpeedRow/Label") as Label
	if pan_label:
		pan_label.text = tr("LABEL_PAN_SPEED")
	_setup_shelter_level_debug()
	var show_ray_btn: CheckButton = get_node_or_null("DebugInfoPanel/Margin/VBox/ShowRayHit") as CheckButton
	if show_ray_btn:
		show_ray_btn.toggled.connect(_on_show_ray_hit_toggled)
	var hover_locked_btn: CheckButton = get_node_or_null("DebugInfoPanel/Margin/VBox/HoverLockedRooms") as CheckButton
	if hover_locked_btn:
		hover_locked_btn.toggled.connect(_on_hover_locked_rooms_toggled)
	var show_room_info_btn: CheckButton = get_node_or_null("DebugInfoPanel/Margin/VBox/ShowRoomInfo") as CheckButton
	if show_room_info_btn:
		show_room_info_btn.toggled.connect(_on_show_room_info_toggled)


func _on_cleanup_button_pressed() -> void:
	cleanup_button_pressed.emit()


func _on_build_button_pressed() -> void:
	build_button_pressed.emit()


func _on_researcher_list_button_pressed() -> void:
	var panel: Node = get_node_or_null("ResearcherListPanel")
	if panel and panel.has_method("toggle_from_entry"):
		panel.toggle_from_entry()


func _setup_factor_hover() -> void:
	if _factor_cognition:
		_factor_cognition.mouse_filter = Control.MOUSE_FILTER_STOP
		_factor_cognition.mouse_entered.connect(_on_factor_hover_entered.bind("cognition"))
		_factor_cognition.mouse_exited.connect(_on_factor_hover_exited)
	if _factor_computation:
		_factor_computation.mouse_filter = Control.MOUSE_FILTER_STOP
		_factor_computation.mouse_entered.connect(_on_factor_hover_entered.bind("computation"))
		_factor_computation.mouse_exited.connect(_on_factor_hover_exited)
	if _factor_will:
		_factor_will.mouse_filter = Control.MOUSE_FILTER_STOP
		_factor_will.mouse_entered.connect(_on_factor_hover_entered.bind("willpower"))
		_factor_will.mouse_exited.connect(_on_factor_hover_exited)
	if _factor_permission:
		_factor_permission.mouse_filter = Control.MOUSE_FILTER_STOP
		_factor_permission.mouse_entered.connect(_on_factor_hover_entered.bind("permission"))
		_factor_permission.mouse_exited.connect(_on_factor_hover_exited)


func _on_factor_hover_entered(factor_key: String) -> void:
	var game_main: Node = get_parent()
	if not game_main or not game_main.has_method("get_factor_breakdown"):
		return
	var data: Dictionary = game_main.get_factor_breakdown(factor_key)
	var factor_name: String = ""
	match factor_key:
		"cognition": factor_name = tr("LABEL_COGNITION")
		"computation": factor_name = tr("LABEL_COMPUTATION")
		"willpower": factor_name = tr("LABEL_WILLPOWER")
		"permission": factor_name = tr("LABEL_PERMISSION")
		_: return
	if _factor_hover_panel and _factor_hover_panel.has_method("show_for_factor"):
		_factor_hover_panel.show_for_factor(factor_name, data)
		call_deferred("_update_factor_panel_position_once")


func _on_factor_hover_exited() -> void:
	## 不立即隐藏，由 _process 判断鼠标是否离开因子区域与面板
	pass


func _on_researcher_hover_entered() -> void:
	if _researcher_hover_panel and _researcher_hover_panel.has_method("show_panel"):
		_researcher_hover_panel.show_panel(
			researcher_count,
			eroded_count,
			researchers_in_cleanup,
			researchers_in_construction,
			researchers_working_in_rooms
		)


func _on_researcher_hover_exited() -> void:
	if _researcher_hover_panel and _researcher_hover_panel.has_method("hide_panel"):
		_researcher_hover_panel.hide_panel()


func _on_pan_speed_changed(value: float) -> void:
	if _pan_speed_value_label:
		_pan_speed_value_label.text = "%.2f" % value
	var game_main: Node = get_parent()
	if game_main:
		game_main.set("_pan_speed", value)


func _setup_shelter_level_debug() -> void:
	var btn_plus: Button = get_node_or_null("DebugInfoPanel/Margin/VBox/ShelterLevelRow/BtnPlus") as Button
	var btn_minus: Button = get_node_or_null("DebugInfoPanel/Margin/VBox/ShelterLevelRow/BtnMinus") as Button
	var _lbl: Label = get_node_or_null("DebugInfoPanel/Margin/VBox/ShelterLevelRow/ValueLabel") as Label
	if btn_plus:
		btn_plus.pressed.connect(_on_shelter_debug_plus)
	if btn_minus:
		btn_minus.pressed.connect(_on_shelter_debug_minus)
	_update_shelter_debug_display()


func _on_shelter_debug_plus() -> void:
	if ErosionCore:
		ErosionCore.shelter_bonus += 1
	_update_shelter_debug_display()


func _on_shelter_debug_minus() -> void:
	if ErosionCore:
		ErosionCore.shelter_bonus -= 1
	_update_shelter_debug_display()


func _update_shelter_debug_display() -> void:
	var lbl: Label = get_node_or_null("DebugInfoPanel/Margin/VBox/ShelterLevelRow/ValueLabel") as Label
	if lbl and ErosionCore:
		lbl.text = str(ErosionCore.shelter_bonus)


func _on_show_ray_hit_toggled(on: bool) -> void:
	var game_main: Node = get_parent()
	if game_main and game_main.has_method("set_debug_show_ray_hit"):
		game_main.set_debug_show_ray_hit(on)


func _on_hover_locked_rooms_toggled(on: bool) -> void:
	var game_main: Node = get_parent()
	if game_main and game_main.has_method("set_debug_hover_locked_rooms"):
		game_main.set_debug_hover_locked_rooms(on)


func _on_show_room_info_toggled(on: bool) -> void:
	var game_main: Node = get_parent()
	if game_main and game_main.has_method("set_debug_show_room_info"):
		game_main.set_debug_show_room_info(on)


func _process(_delta: float) -> void:
	var viewport: Viewport = get_viewport()
	if viewport:
		var mouse_pos: Vector2 = viewport.get_mouse_position()
		var vp_size: Vector2 = viewport.get_visible_rect().size
		if _researcher_hover_panel and _researcher_hover_panel.visible and _researcher_hover_panel.has_method("update_position"):
			_researcher_hover_panel.update_position(mouse_pos, vp_size)
		if _factor_hover_panel and _factor_hover_panel.visible:
			if not _is_mouse_over_factor_or_panel(mouse_pos):
				_factor_hover_panel.hide_panel()


func _update_factor_panel_position_once() -> void:
	var viewport: Viewport = get_viewport()
	if viewport and _factor_hover_panel and _factor_hover_panel.visible and _factor_hover_panel.has_method("update_position"):
		_factor_hover_panel.update_position(viewport.get_mouse_position(), viewport.get_visible_rect().size)


func _is_mouse_over_factor_or_panel(mouse_pos: Vector2) -> bool:
	if _factor_hover_panel and _factor_hover_panel.visible and _factor_hover_panel.get_global_rect().has_point(mouse_pos):
		return true
	for ctrl in [_factor_cognition, _factor_computation, _factor_will, _factor_permission]:
		if ctrl and ctrl.get_global_rect().has_point(mouse_pos):
			return true
	return false


func _update_researcher_hover_if_visible() -> void:
	if _researcher_hover_panel and _researcher_hover_panel.visible and _researcher_hover_panel.has_method("show_panel"):
		_researcher_hover_panel.show_panel(
			researcher_count,
			eroded_count,
			researchers_in_cleanup,
			researchers_in_construction,
			researchers_working_in_rooms
		)


## 建设选择模式下禁用其余 UI、隐藏灾厄
func set_construction_blocking(blocked: bool) -> void:
	if blocked:
		if _researcher_hover_panel and _researcher_hover_panel.has_method("hide_panel"):
			_researcher_hover_panel.hide_panel()
		if _factor_hover_panel and _factor_hover_panel.has_method("hide_panel"):
			_factor_hover_panel.hide_panel()
	_set_buttons_blocked($TopBar, blocked)
	_set_control_mouse_filter($TopBar, blocked)
	var cleanup_btn: Button = get_node_or_null("BottomRightBar/BtnCleanup") as Button
	if cleanup_btn:
		cleanup_btn.disabled = blocked
	var renovate_btn: Button = get_node_or_null("BottomRightBar/BtnRenovate") as Button
	if renovate_btn:
		renovate_btn.disabled = blocked
	var calamity: Control = get_node_or_null("CalamityBar") as Control
	if calamity:
		calamity.visible = not blocked


## 清理选择模式下禁用其余 UI 的悬停与点击
func set_cleanup_blocking(blocked: bool) -> void:
	if blocked:
		if _researcher_hover_panel and _researcher_hover_panel.has_method("hide_panel"):
			_researcher_hover_panel.hide_panel()
		if _factor_hover_panel and _factor_hover_panel.has_method("hide_panel"):
			_factor_hover_panel.hide_panel()
	_set_buttons_blocked($TopBar, blocked)
	_set_buttons_blocked($CalamityBar, blocked)
	_set_control_mouse_filter($TopBar, blocked)
	_set_control_mouse_filter($CalamityBar, blocked)
	var build_btn: Button = get_node_or_null("BottomRightBar/BtnBuild") as Button
	if build_btn:
		build_btn.disabled = blocked
	var renovate_btn: Button = get_node_or_null("BottomRightBar/BtnRenovate") as Button
	if renovate_btn:
		renovate_btn.disabled = blocked


func _set_buttons_blocked(node: Node, blocked: bool) -> void:
	if node is BaseButton:
		(node as BaseButton).disabled = blocked
	for c in node.get_children():
		_set_buttons_blocked(c, blocked)


func _set_control_mouse_filter(node: Node, ignore: bool) -> void:
	## 设为 IGNORE 时，该 Control 及其子节点不参与鼠标检测，悬停效果不触发
	if node is Control:
		var ctrl: Control = node as Control
		if ignore:
			ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			# 恢复：Button 需 STOP 以接收点击，Label 用 IGNORE，容器用 PASS
			if node is BaseButton:
				ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
			elif node is Label:
				ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			else:
				ctrl.mouse_filter = Control.MOUSE_FILTER_PASS
	for c in node.get_children():
		_set_control_mouse_filter(c, ignore)


func _update_label(lbl: Label, value: int) -> void:
	if lbl:
		lbl.text = str(value)


func _update_researcher_display() -> void:
	if _label_researcher:
		var idle: int = maxi(0, researcher_count - eroded_count - researchers_in_cleanup - researchers_in_construction - researchers_working_in_rooms)
		_label_researcher.text = "%d/%d" % [idle, researcher_count]


func _refresh_all() -> void:
	_update_label(_label_cognition, cognition_amount)
	_update_label(_label_computation, computation_amount)
	_update_label(_label_will, will_amount)
	_update_label(_label_permission, permission_amount)
	_update_label(_label_info, info_amount)
	_update_label(_label_truth, truth_amount)
	_update_researcher_display()
	_update_label(_label_eroded, eroded_count)
	_update_label(_label_investigator, investigator_count)


## 强制刷新 TopBar 显示（消耗/获得资源后调用，确保数值与 UI 一致）
func refresh_display() -> void:
	_refresh_all()


## 显式获取因子值，避免 Node.get() 对自定义属性解析异常
func get_cognition() -> int:
	return _cognition_amount
func get_computation() -> int:
	return _computation_amount
func get_willpower() -> int:
	return _will_amount
func get_permission() -> int:
	return _permission_amount


## 安全转换因子值为 int：防止 "60000/60000" 等字符串被误解析，或浮点/类型错误。
## 注意：UI 中的 "库存 X / Y" 格式，斜杠为显示用字符，不是除法运算。
static func _safe_factor_int(v: Variant, default_val: int = 0) -> int:
	if v is int:
		return int(v)
	if v is float:
		return int(v)
	if v is String:
		var s: String = v
		if "/" in s:
			var parts: PackedStringArray = s.split("/", true, 1)
			s = parts[0].strip_edges() if parts.size() > 0 else ""
		return int(s) if s.is_valid_int() else default_val
	return default_val


## 便捷：一次性更新所有数据（供游戏状态层调用）
func set_resources(factors: Dictionary, currency: Dictionary, personnel: Dictionary) -> void:
	cognition_amount = _safe_factor_int(factors.get("cognition", 0), 0)
	computation_amount = _safe_factor_int(factors.get("computation", 0), 0)
	will_amount = _safe_factor_int(factors.get("willpower", 0), 0)
	permission_amount = _safe_factor_int(factors.get("permission", 0), 0)
	info_amount = int(currency.get("info", 0))
	truth_amount = int(currency.get("truth", 0))
	researcher_count = int(personnel.get("researcher", 0))
	eroded_count = int(personnel.get("eroded", 0))
	investigator_count = int(personnel.get("investigator", 0))
	_refresh_all()  ## 确保 Label 与属性同步（应对 @onready 时序等边界情况）


## 获取当前资源数据（供存档保存调用）
func get_resources() -> Dictionary:
	return {
		"factors": {
			"cognition": cognition_amount,
			"computation": computation_amount,
			"willpower": will_amount,
			"permission": permission_amount,
		},
		"currency": {"info": info_amount, "truth": truth_amount},
		"personnel": {
			"researcher": researcher_count,
			"labor": 0,
			"eroded": eroded_count,
			"investigator": investigator_count,
		},
	}

extends CanvasLayer
## 主 UI 场景 - 顶层资源条
## 显示：资源-因子、资源-货币、人员 三类数据
## 可挂载至任意主场景，数据通过属性或 Autoload 注入

signal cleanup_button_pressed
signal build_button_pressed

@onready var _topbar_figma: Node = $TopBar/TopbarFigma
@onready var _researcher_hover_panel: PanelContainer = $ResearcherHoverPanel
@onready var _factor_hover_panel: PanelContainer = $FactorHoverPanel
@onready var _pan_speed_slider: HSlider = $DebugInfoPanel/Margin/VBox/PanSpeedRow/PanSpeedSlider
@onready var _pan_speed_value_label: Label = $DebugInfoPanel/Margin/VBox/PanSpeedRow/Value

## 资源-因子（使用显式后备变量，避免 Node.get() 对自定义属性解析异常）
var _cognition_amount: int = 0
var cognition_amount: int:
	get: return _cognition_amount
	set(v):
		_cognition_amount = int(v) if v != null else 0
var _computation_amount: int = 0
var computation_amount: int:
	get: return _computation_amount
	set(v):
		var val: int = int(v) if v != null else 0
		_computation_amount = val
var _will_amount: int = 0
var will_amount: int:
	get: return _will_amount
	set(v):
		_will_amount = int(v) if v != null else 0
var _permission_amount: int = 0
var permission_amount: int:
	get: return _permission_amount
	set(v):
		_permission_amount = int(v) if v != null else 0

## 资源-货币
var info_amount: int = 0
var truth_amount: int = 0

## 人员（researcher_count=总数，eroded_count=被侵蚀数；显示为 未侵蚀/总数）
var _researcher_count: int = 0
var researcher_count: int:
	get: return _researcher_count
	set(v):
		_researcher_count = int(v) if v != null else 0
		_update_researcher_display()
var _eroded_count: int = 0
var eroded_count: int:
	get: return _eroded_count
	set(v):
		_eroded_count = int(v) if v != null else 0
		_update_researcher_display()
## 清理中临时占用的研究员数（由 GameMain 同步，清理结束后返还）
var _researchers_in_cleanup: int = 0
var researchers_in_cleanup: int:
	get: return _researchers_in_cleanup
	set(v):
		_researchers_in_cleanup = int(v) if v != null else 0
		_update_researcher_display()
		_update_researcher_hover_if_visible()
## 建设中占用的研究员数（预留，暂为 0）
var _researchers_in_construction: int = 0
var researchers_in_construction: int:
	get: return _researchers_in_construction
	set(v):
		_researchers_in_construction = int(v) if v != null else 0
		_update_researcher_display()
		_update_researcher_hover_if_visible()
## 房间内工作的研究员数（预留，暂为 0）
var _researchers_working_in_rooms: int = 0
var researchers_working_in_rooms: int:
	get: return _researchers_working_in_rooms
	set(v):
		_researchers_working_in_rooms = int(v) if v != null else 0
		_update_researcher_display()
		_update_researcher_hover_if_visible()
var _investigator_count: int = 0
var investigator_count: int:
	get: return _investigator_count
	set(v):
		_investigator_count = int(v) if v != null else 0


func _ready() -> void:
	## 暂停时保持可点击，以便用户可通过时间面板播放按钮恢复时间
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	if _topbar_figma and _topbar_figma.has_signal("block_hovered"):
		_topbar_figma.block_hovered.connect(_on_topbar_block_hovered)
	if _topbar_figma and _topbar_figma.has_signal("block_unhovered"):
		_topbar_figma.block_unhovered.connect(_on_topbar_block_unhovered)
	if _pan_speed_slider:
		_pan_speed_slider.value_changed.connect(_on_pan_speed_changed)
		_on_pan_speed_changed(_pan_speed_slider.value)
	var pan_label: Label = get_node_or_null("DebugInfoPanel/Margin/VBox/PanSpeedRow/Label") as Label
	if pan_label:
		pan_label.text = tr("LABEL_PAN_SPEED")
	_setup_shelter_level_debug()
	var btn_96x: Button = get_node_or_null("DebugInfoPanel/Margin/VBox/Speed96xRow/BtnSet96x") as Button
	if btn_96x:
		btn_96x.pressed.connect(_on_speed_96x_pressed)
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


func _on_topbar_block_hovered(block_id: String) -> void:
	_hide_all_detail_panels()
	match block_id:
		"cognition", "computing_power", "willpower", "permission":
			var factor_key: String = "computation" if block_id == "computing_power" else block_id
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
				call_deferred("_update_detail_panel_position_once", _factor_hover_panel)
		"researcher", "eroded", "investigator", "shelter", "housing":
			if _researcher_hover_panel and _researcher_hover_panel.has_method("show_panel"):
				_researcher_hover_panel.show_panel(
					researcher_count,
					eroded_count,
					researchers_in_cleanup,
					researchers_in_construction,
					researchers_working_in_rooms
				)
				call_deferred("_update_detail_panel_position_once", _researcher_hover_panel)


func _on_topbar_block_unhovered(_block_id: String) -> void:
	## 不立即隐藏，由 _process 判断鼠标是否离开区域与面板
	pass


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


func _on_speed_96x_pressed() -> void:
	if GameTime:
		GameTime.set_speed_96x()


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
	if not viewport:
		return
	var mouse_pos: Vector2 = viewport.get_mouse_position()
	var vp_size: Vector2 = viewport.get_visible_rect().size
	var active_panel: Control = _get_visible_detail_panel()
	if active_panel:
		active_panel.update_position(mouse_pos, vp_size)
		if not _is_mouse_over_detail_source_or_panel(mouse_pos):
			active_panel.hide_panel()


func _hide_all_detail_panels() -> void:
	if _factor_hover_panel:
		_factor_hover_panel.hide_panel()
	if _researcher_hover_panel:
		_researcher_hover_panel.hide_panel()


func _get_visible_detail_panel() -> Control:
	if _factor_hover_panel and _factor_hover_panel.visible:
		return _factor_hover_panel
	if _researcher_hover_panel and _researcher_hover_panel.visible:
		return _researcher_hover_panel
	return null


func _update_detail_panel_position_once(panel: Control) -> void:
	var viewport: Viewport = get_viewport()
	if viewport and panel and panel.visible:
		panel.update_position(viewport.get_mouse_position(), viewport.get_visible_rect().size)


func _is_mouse_over_detail_source_or_panel(mouse_pos: Vector2) -> bool:
	if _factor_hover_panel and _factor_hover_panel.visible and _factor_hover_panel.get_global_rect().has_point(mouse_pos):
		return true
	if _researcher_hover_panel and _researcher_hover_panel.visible and _researcher_hover_panel.get_global_rect().has_point(mouse_pos):
		return true
	var top_bar: Control = get_node_or_null("TopBar") as Control
	if top_bar and top_bar.get_global_rect().has_point(mouse_pos):
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
		_hide_all_detail_panels()
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
		_hide_all_detail_panels()
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


func _update_researcher_display() -> void:
	_refresh_all()


func _refresh_all() -> void:
	if _topbar_figma and _topbar_figma.has_method("refresh_display"):
		_topbar_figma.refresh_display()


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

extends CanvasLayer
## 主 UI 场景 - 顶层资源条
## 显示：资源-因子、资源-货币、人员 三类数据
## 可挂载至任意主场景，数据通过属性或 Autoload 注入

signal cleanup_button_pressed
signal build_button_pressed
signal bottom_task_placeholder_pressed(button_id: String)

@onready var _topbar_figma: Node = $TopBar/TopbarFigma
@onready var _calamity_progress: ProgressBar = get_node_or_null("BottomRightBar/Margin/Content/CalamityInline/CalamityProgress") as ProgressBar
@onready var _calamity_value_label: Label = get_node_or_null("BottomRightBar/Margin/Content/CalamityInline/CalamityValue") as Label

## 详情面板（按资源类型）
@onready var _cognition_panel: PanelContainer = $CognitionDetailPanel
@onready var _willpower_panel: PanelContainer = $WillpowerDetailPanel
@onready var _permission_panel: PanelContainer = $PermissionDetailPanel
@onready var _computation_panel: PanelContainer = $ComputationDetailPanel
@onready var _shelter_panel: PanelContainer = $ShelterDetailPanel
@onready var _researcher_detail_panel: PanelContainer = $ResearcherDetailPanel
@onready var _housing_panel: PanelContainer = $HousingDetailPanel
@onready var _information_panel: PanelContainer = $InformationDetailPanel
@onready var _investigator_panel: PanelContainer = $InvestigatorDetailPanel
@onready var _truth_panel: PanelContainer = $TruthDetailPanel


func _all_detail_panels() -> Array[PanelContainer]:
	return [
		_cognition_panel, _willpower_panel, _permission_panel, _computation_panel,
		_shelter_panel, _researcher_detail_panel, _housing_panel,
		_information_panel, _investigator_panel, _truth_panel,
	]


func _get_panel_for_block(block_id: String) -> PanelContainer:
	match block_id:
		"cognition": return _cognition_panel
		"willpower": return _willpower_panel
		"permission": return _permission_panel
		"computing_power": return _computation_panel
		"researcher", "eroded": return _researcher_detail_panel
		"shelter": return _shelter_panel
		"housing": return _housing_panel
		"investigator": return _investigator_panel
		"info": return _information_panel
		"truth": return _truth_panel
	return null


func _fetch_panel_data(panel: PanelContainer) -> Dictionary:
	var dp: Node = _get_data_providers()
	if not dp:
		return {}
	if panel == _cognition_panel and dp.has_method("get_factor_breakdown"):
		return dp.get_factor_breakdown("cognition")
	if panel == _willpower_panel and dp.has_method("get_factor_breakdown"):
		return dp.get_factor_breakdown("willpower")
	if panel == _permission_panel and dp.has_method("get_factor_breakdown"):
		return dp.get_factor_breakdown("permission")
	if panel == _computation_panel and dp.has_method("get_factor_breakdown"):
		return dp.get_factor_breakdown("computation")
	if panel == _shelter_panel and dp.has_method("get_shelter_breakdown"):
		return dp.get_shelter_breakdown()
	if panel == _researcher_detail_panel and dp.has_method("get_researcher_breakdown"):
		return dp.get_researcher_breakdown()
	if panel == _housing_panel and dp.has_method("get_housing_breakdown"):
		return dp.get_housing_breakdown()
	if panel == _information_panel and dp.has_method("get_information_breakdown"):
		return dp.get_information_breakdown()
	if panel == _investigator_panel and dp.has_method("get_investigator_breakdown"):
		return dp.get_investigator_breakdown()
	if panel == _truth_panel and dp.has_method("get_truth_breakdown"):
		return dp.get_truth_breakdown()
	return {}


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

var _detail_panel_dirty: bool = false
var _refresh_all_queued: bool = false
var _suspend_auto_refresh: bool = false


func _ready() -> void:
	## 暂停时保持可点击，以便用户可通过时间面板播放按钮恢复时间
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _topbar_figma and _topbar_figma.has_method("set_ui_root"):
		_topbar_figma.set_ui_root(self)
	_refresh_all()
	var btn: Button = get_node_or_null("BottomRightBar/Margin/Content/BtnCleanup")
	if btn:
		btn.pressed.connect(_on_cleanup_button_pressed)
	var build_btn: Button = get_node_or_null("BottomRightBar/Margin/Content/BtnBuild")
	if build_btn:
		build_btn.pressed.connect(_on_build_button_pressed)
	_connect_bottom_placeholder_button("BottomRightBar/Margin/Content/BtnCenter", "center")
	_connect_bottom_placeholder_button("BottomRightBar/Margin/Content/BtnCouncil", "triple_council")
	_connect_bottom_placeholder_button("BottomRightBar/Margin/Content/BtnTechStack", "tech_stack")
	var btn_researcher_list: Button = get_node_or_null("BarBelowTop/BtnResearcherList")
	if btn_researcher_list:
		btn_researcher_list.pressed.connect(_on_researcher_list_button_pressed)
	if _topbar_figma and _topbar_figma.has_signal("block_hovered"):
		_topbar_figma.block_hovered.connect(_on_topbar_block_hovered)
	if _topbar_figma and _topbar_figma.has_signal("block_unhovered"):
		_topbar_figma.block_unhovered.connect(_on_topbar_block_unhovered)
	if PersonnelErosionCore and PersonnelErosionCore.has_signal("calamity_updated"):
		PersonnelErosionCore.calamity_updated.connect(_on_calamity_updated)
	_sync_calamity_inline()
	
	## 连接 DataProviders 信号实现实时刷新
	_connect_data_providers_signals()


func _on_cleanup_button_pressed() -> void:
	cleanup_button_pressed.emit()


func _on_build_button_pressed() -> void:
	build_button_pressed.emit()


func _connect_bottom_placeholder_button(node_path: String, button_id: String) -> void:
	var btn: Button = get_node_or_null(node_path) as Button
	if btn:
		btn.pressed.connect(func() -> void:
			_on_bottom_task_placeholder_button_pressed(button_id)
		)


func _on_bottom_task_placeholder_button_pressed(button_id: String) -> void:
	bottom_task_placeholder_pressed.emit(button_id)


func _on_researcher_list_button_pressed() -> void:
	var panel: Node = get_node_or_null("ResearcherListPanel")
	if panel and panel.has_method("toggle_from_entry"):
		panel.toggle_from_entry()


func _on_topbar_block_hovered(block_id: String) -> void:
	_hide_all_detail_panels()
	var panel: PanelContainer = _get_panel_for_block(block_id)
	if not panel or not panel.has_method("show_panel"):
		return
	var data: Dictionary = _fetch_panel_data(panel)
	if not data.is_empty():
		panel.show_panel(data)
		call_deferred("_update_detail_panel_position_once", panel)


func _on_topbar_block_unhovered(_block_id: String) -> void:
	## 鼠标离开资源块时立即隐藏所有详情面板
	_hide_all_detail_panels()


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
			_detail_panel_dirty = false
		else:
			## 改为脏标记刷新，避免每帧重建详情条目
			if _detail_panel_dirty:
				_refresh_visible_detail_panel(active_panel)
				_detail_panel_dirty = false


func _refresh_visible_detail_panel(panel: Control) -> void:
	if not panel or not panel.has_method("show_panel"):
		return
	var data: Dictionary = _fetch_panel_data(panel)
	if not data.is_empty():
		panel.show_panel(data)


func _hide_all_detail_panels() -> void:
	for panel in _all_detail_panels():
		if panel and panel.has_method("hide_panel"):
			panel.hide_panel()


func _get_visible_detail_panel() -> Control:
	for panel in _all_detail_panels():
		if panel and panel.visible:
			return panel
	return null


func _update_detail_panel_position_once(panel: Control) -> void:
	var viewport: Viewport = get_viewport()
	if viewport and panel and panel.visible:
		panel.update_position(viewport.get_mouse_position(), viewport.get_visible_rect().size)


func _is_mouse_over_detail_source_or_panel(mouse_pos: Vector2) -> bool:
	for panel in _all_detail_panels():
		if panel and panel.visible and panel.get_global_rect().has_point(mouse_pos):
			return true
	var top_bar: Control = get_node_or_null("TopBar") as Control
	if top_bar and top_bar.get_global_rect().has_point(mouse_pos):
		return true
	return false


func _update_researcher_hover_if_visible() -> void:
	## 如果研究员详情面板可见，刷新其数据
	if _researcher_detail_panel and _researcher_detail_panel.visible:
		var data_providers: Node = _get_data_providers()
		if data_providers and data_providers.has_method("get_researcher_breakdown"):
			var data: Dictionary = data_providers.get_researcher_breakdown()
			if _researcher_detail_panel.has_method("show_panel"):
				_researcher_detail_panel.show_panel(data)


## ============================================================================
## DataProviders 信号连接与实时刷新
## ============================================================================

func _get_data_providers() -> Node:
	## 获取 DataProviders Autoload 实例
	if Engine.has_singleton("DataProviders"):
		return Engine.get_singleton("DataProviders")
	## 尝试从场景树获取
	var root := get_tree().root if get_tree() else null
	if root:
		for child in root.get_children():
			if child.name == "DataProviders":
				return child
			for sub in child.get_children():
				if sub.name == "DataProviders":
					return sub
	return null


func _connect_data_providers_signals() -> void:
	## 连接 DataProviders 信号实现面板实时刷新
	var data_providers: Node = _get_data_providers()
	if not data_providers:
		return
	
	## 因子数据变化信号
	if data_providers.has_signal("factor_data_changed"):
		data_providers.factor_data_changed.connect(_on_factor_data_changed)
	
	## 庇护能量数据变化信号
	if data_providers.has_signal("shelter_data_changed"):
		data_providers.shelter_data_changed.connect(_on_shelter_data_changed)
	
	## 研究员数据变化信号
	if data_providers.has_signal("researcher_data_changed"):
		data_providers.researcher_data_changed.connect(_on_researcher_data_changed)
	
	## 住房数据变化信号
	if data_providers.has_signal("housing_data_changed"):
		data_providers.housing_data_changed.connect(_on_housing_data_changed)
	
	## 信息数据变化信号
	if data_providers.has_signal("information_data_changed"):
		data_providers.information_data_changed.connect(_on_information_data_changed)
	
	## 调查员数据变化信号
	if data_providers.has_signal("investigator_data_changed"):
		data_providers.investigator_data_changed.connect(_on_investigator_data_changed)
	
	## 真相数据变化信号
	if data_providers.has_signal("truth_data_changed"):
		data_providers.truth_data_changed.connect(_on_truth_data_changed)


## 因子数据变化时刷新对应面板
func _on_factor_data_changed(factor_key: String) -> void:
	## factor_key 可能是 "all" 或具体因子名
	var panels_to_refresh: Array[PanelContainer] = []
	
	if factor_key == "all" or factor_key == "cognition":
		panels_to_refresh.append(_cognition_panel)
	if factor_key == "all" or factor_key == "willpower":
		panels_to_refresh.append(_willpower_panel)
	if factor_key == "all" or factor_key == "permission":
		panels_to_refresh.append(_permission_panel)
	if factor_key == "all" or factor_key == "computation":
		panels_to_refresh.append(_computation_panel)
	
	_refresh_visible_panels(panels_to_refresh)


## 庇护数据变化时刷新面板
func _on_shelter_data_changed() -> void:
	_refresh_visible_panels([_shelter_panel])


## 研究员数据变化时刷新面板
func _on_researcher_data_changed() -> void:
	_refresh_visible_panels([_researcher_detail_panel])


## 住房数据变化时刷新面板
func _on_housing_data_changed() -> void:
	_refresh_visible_panels([_housing_panel])


## 信息数据变化时刷新面板
func _on_information_data_changed() -> void:
	_refresh_visible_panels([_information_panel])


## 调查员数据变化时刷新面板
func _on_investigator_data_changed() -> void:
	_refresh_visible_panels([_investigator_panel])


## 真相数据变化时刷新面板
func _on_truth_data_changed() -> void:
	_refresh_visible_panels([_truth_panel])


func _refresh_visible_panels(panels: Array[PanelContainer]) -> void:
	for panel in panels:
		if panel and panel.visible:
			_detail_panel_dirty = true


func _sync_calamity_inline() -> void:
	var value: float = 0.0
	if PersonnelErosionCore:
		value = PersonnelErosionCore.get_calamity_value()
	_on_calamity_updated(value)


func _on_calamity_updated(value: float) -> void:
	var max_val: float = float(PersonnelErosionCore.get_calamity_max()) if PersonnelErosionCore else 30000.0
	var ratio: float = clampf(value / max_val, 0.0, 1.0) if max_val > 0.0 else 0.0
	if _calamity_progress:
		_calamity_progress.value = ratio
	if _calamity_value_label:
		_calamity_value_label.text = str(int(value))


## 建设选择模式下禁用其余 UI、隐藏灾厄
func set_construction_blocking(blocked: bool) -> void:
	if blocked:
		_hide_all_detail_panels()
	_set_buttons_blocked($TopBar, blocked)
	_set_control_mouse_filter($TopBar, blocked)
	var cleanup_btn: Button = get_node_or_null("BottomRightBar/Margin/Content/BtnCleanup") as Button
	if cleanup_btn:
		cleanup_btn.disabled = blocked
	var renovate_btn: Button = get_node_or_null("BottomRightBar/Margin/Content/BtnRenovate") as Button
	if renovate_btn:
		renovate_btn.disabled = blocked
	var calamity: Control = get_node_or_null("BottomRightBar/Margin/Content/CalamityInline") as Control
	if calamity:
		calamity.visible = not blocked


## 清理选择模式下禁用其余 UI 的悬停与点击
func set_cleanup_blocking(blocked: bool) -> void:
	if blocked:
		_hide_all_detail_panels()
	_set_buttons_blocked($TopBar, blocked)
	var calamity_inline: Control = get_node_or_null("BottomRightBar/Margin/Content/CalamityInline") as Control
	if calamity_inline:
		_set_buttons_blocked(calamity_inline, blocked)
	_set_control_mouse_filter($TopBar, blocked)
	if calamity_inline:
		_set_control_mouse_filter(calamity_inline, blocked)
	var build_btn: Button = get_node_or_null("BottomRightBar/Margin/Content/BtnBuild") as Button
	if build_btn:
		build_btn.disabled = blocked
	var renovate_btn: Button = get_node_or_null("BottomRightBar/Margin/Content/BtnRenovate") as Button
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
	if _suspend_auto_refresh:
		return
	_request_refresh_all()


func _request_refresh_all() -> void:
	if _refresh_all_queued:
		return
	_refresh_all_queued = true
	call_deferred("_flush_refresh_all")


func _flush_refresh_all() -> void:
	_refresh_all_queued = false
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


## 便捷：一次性更新所有数据（供游戏状态层调用）
func set_resources(factors: Dictionary, currency: Dictionary, personnel: Dictionary) -> void:
	_suspend_auto_refresh = true
	cognition_amount = UIUtils.safe_int(factors.get("cognition", 0), 0)
	computation_amount = UIUtils.safe_int(factors.get("computation", 0), 0)
	will_amount = UIUtils.safe_int(factors.get("willpower", 0), 0)
	permission_amount = UIUtils.safe_int(factors.get("permission", 0), 0)
	info_amount = int(currency.get("info", 0))
	truth_amount = int(currency.get("truth", 0))
	researcher_count = int(personnel.get("researcher", 0))
	eroded_count = int(personnel.get("eroded", 0))
	investigator_count = int(personnel.get("investigator", 0))
	_suspend_auto_refresh = false
	_request_refresh_all()  ## 合并一帧内多次刷新请求，避免重复刷新


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

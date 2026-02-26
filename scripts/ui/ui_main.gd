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

## 资源-因子
var cognition_amount: int = 0:
	set(v):
		cognition_amount = v
		_update_label(_label_cognition, v)
var computation_amount: int = 0:
	set(v):
		computation_amount = v
		_update_label(_label_computation, v)
var will_amount: int = 0:
	set(v):
		will_amount = v
		_update_label(_label_will, v)
var permission_amount: int = 0:
	set(v):
		permission_amount = v
		_update_label(_label_permission, v)

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
	if _researcher_hover_area:
		_researcher_hover_area.mouse_filter = Control.MOUSE_FILTER_STOP
		_researcher_hover_area.mouse_entered.connect(_on_researcher_hover_entered)
		_researcher_hover_area.mouse_exited.connect(_on_researcher_hover_exited)


func _on_cleanup_button_pressed() -> void:
	cleanup_button_pressed.emit()


func _on_build_button_pressed() -> void:
	build_button_pressed.emit()


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


func _process(_delta: float) -> void:
	if _researcher_hover_panel and _researcher_hover_panel.visible and _researcher_hover_panel.has_method("update_position"):
		var viewport: Viewport = get_viewport()
		if viewport:
			_researcher_hover_panel.update_position(viewport.get_mouse_position(), viewport.get_visible_rect().size)


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
	if blocked and _researcher_hover_panel and _researcher_hover_panel.has_method("hide_panel"):
		_researcher_hover_panel.hide_panel()
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
	if blocked and _researcher_hover_panel and _researcher_hover_panel.has_method("hide_panel"):
		_researcher_hover_panel.hide_panel()
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


## 便捷：一次性更新所有数据（供游戏状态层调用）
func set_resources(factors: Dictionary, currency: Dictionary, personnel: Dictionary) -> void:
	cognition_amount = factors.get("cognition", 0)
	computation_amount = factors.get("computation", 0)
	will_amount = factors.get("willpower", 0)
	permission_amount = factors.get("permission", 0)
	info_amount = currency.get("info", 0)
	truth_amount = currency.get("truth", 0)
	researcher_count = personnel.get("researcher", 0)
	eroded_count = personnel.get("eroded", 0)
	investigator_count = personnel.get("investigator", 0)


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

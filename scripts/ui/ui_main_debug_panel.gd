extends PanelContainer
## Debug 信息面板 - 标题栏关闭、镜头控制、96x、庇护等级、射线/房间信息开关
## 挂载于 DebugInfoPanel 节点；通过 get_parent().get_parent() 获取 GameMain
## 热键：`（Tab 上方）切换显示，见 GameMainInputHelper.process_input

@onready var _pan_speed_slider: HSlider = $Margin/VBox/PanSpeedRow/PanSpeedSlider
@onready var _pan_speed_value_label: Label = $Margin/VBox/PanSpeedRow/Value


func _ready() -> void:
	var btn_close: Button = get_node_or_null("Margin/VBox/TitleBar/BtnClose") as Button
	if btn_close:
		btn_close.pressed.connect(_on_close_pressed)
	var pan_label: Label = get_node_or_null("Margin/VBox/PanSpeedRow/Label") as Label
	if pan_label:
		pan_label.text = tr("LABEL_PAN_SPEED")
	if _pan_speed_slider:
		_pan_speed_slider.value_changed.connect(_on_pan_speed_changed)
		_on_pan_speed_changed(_pan_speed_slider.value)
	_setup_shelter_level_debug()
	var btn_96x: Button = get_node_or_null("Margin/VBox/Speed96xRow/BtnSet96x") as Button
	if btn_96x:
		btn_96x.pressed.connect(_on_speed_96x_pressed)
	var show_ray_btn: CheckButton = get_node_or_null("Margin/VBox/ShowRayHit") as CheckButton
	if show_ray_btn:
		show_ray_btn.toggled.connect(_on_show_ray_hit_toggled)
	var hover_locked_btn: CheckButton = get_node_or_null("Margin/VBox/HoverLockedRooms") as CheckButton
	if hover_locked_btn:
		hover_locked_btn.toggled.connect(_on_hover_locked_rooms_toggled)
	var show_room_info_btn: CheckButton = get_node_or_null("Margin/VBox/ShowRoomInfo") as CheckButton
	if show_room_info_btn:
		show_room_info_btn.toggled.connect(_on_show_room_info_toggled)


func _on_close_pressed() -> void:
	visible = false


func _get_game_main() -> Node:
	var ui: Node = get_parent()
	return ui.get_parent() if ui else null


func _on_pan_speed_changed(value: float) -> void:
	if _pan_speed_value_label:
		_pan_speed_value_label.text = "%.2f" % value
	var gm: Node = _get_game_main()
	if gm:
		gm.set("_pan_speed", value)


func _setup_shelter_level_debug() -> void:
	var btn_plus: Button = get_node_or_null("Margin/VBox/ShelterLevelRow/BtnPlus") as Button
	var btn_minus: Button = get_node_or_null("Margin/VBox/ShelterLevelRow/BtnMinus") as Button
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
	var lbl: Label = get_node_or_null("Margin/VBox/ShelterLevelRow/ValueLabel") as Label
	if lbl and ErosionCore:
		lbl.text = str(ErosionCore.shelter_bonus)


func _on_show_ray_hit_toggled(on: bool) -> void:
	var gm: Node = _get_game_main()
	if gm and gm.has_method("set_debug_show_ray_hit"):
		gm.set_debug_show_ray_hit(on)


func _on_hover_locked_rooms_toggled(on: bool) -> void:
	var gm: Node = _get_game_main()
	if gm and gm.has_method("set_debug_hover_locked_rooms"):
		gm.set_debug_hover_locked_rooms(on)


func _on_show_room_info_toggled(on: bool) -> void:
	var gm: Node = _get_game_main()
	if gm and gm.has_method("set_debug_show_room_info"):
		gm.set_debug_show_room_info(on)

extends CanvasLayer

## 测试 Figma 同步的 UI 页面，按 F12 切换显示/隐藏
## 所有布局、颜色、样式均存储在 .tscn 中，由 Figma MCP 同步时直接写入场景
## 禁止使用截图或 JSON 运行时加载；同步时需读取 Figma 的 layout、fills、cornerRadius 等原始数据
## 鼠标悬停资源块会发出 hovered/unhovered，详细信息面板可连接（暂未实现新界面）
## 数据从 UIMain 同步，与主 TopBar 一致

const CANVAS_SIZE := Vector2(1920.0, 1080.0)
const _GameValuesRef = preload("res://scripts/core/game_values_ref.gd")
const ZoneTypeScript = preload("res://scripts/core/zone_type.gd")

var _design_canvas: Control


func _ready() -> void:
	_design_canvas = get_node_or_null("Content/Center/DesignCanvas") as Control
	if _design_canvas:
		_design_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# 设置按钮：点击等同 ESC，唤出暂停菜单
	var btn_settings: TextureButton = get_node_or_null("Content/Center/DesignCanvas/TopbarFull/Topbar0/BaseButtonSettings") as TextureButton
	if btn_settings:
		btn_settings.pressed.connect(_on_settings_pressed)
	# 连接所有 ResourceBlock 的悬停信号（详细信息面板待实现）
	_setup_resource_block_hover()
	# 侵蚀数字：订阅 ErosionCore，移除示例值
	_setup_corrosion_number()
	# 仅在作为子场景实例时隐藏；单独运行本场景时保持可见便于调试
	if get_tree().current_scene != self:
		visible = false
	_update_canvas_scale()
	get_viewport().size_changed.connect(_update_canvas_scale)
	# 延迟刷新，确保 UIMain 已加载
	call_deferred("refresh_display")


func _setup_resource_block_hover() -> void:
	var topbar: Node = get_node_or_null("Content/Center/DesignCanvas/TopbarFull/Topbar0")
	if not topbar:
		return
	for child in _collect_resource_blocks(topbar):
		if child.has_signal("hovered") and child.has_signal("unhovered"):
			child.hovered.connect(_on_resource_block_hovered)
			child.unhovered.connect(_on_resource_block_unhovered)


func _collect_resource_blocks(parent: Node) -> Array:
	var result: Array = []
	for node in parent.find_children("*", "ResourceBlock", true, false):
		result.append(node)
	return result


func _on_resource_block_hovered(_block_id: String) -> void:
	## 预留：显示资源块详细信息面板（新界面待实现）
	pass


func _on_resource_block_unhovered(_block_id: String) -> void:
	## 预留：隐藏资源块详细信息面板
	pass


func _setup_corrosion_number() -> void:
	var cn: Node = get_node_or_null("Content/Center/DesignCanvas/TopbarFull/Topbar1/CorrosionNumber")
	if not cn or not cn.has_method("set_corrosion_value"):
		return
	if ErosionCore:
		cn.set_corrosion_value(ErosionCore.current_erosion)
		if not ErosionCore.erosion_changed.is_connected(_on_erosion_changed):
			ErosionCore.erosion_changed.connect(_on_erosion_changed)


func _on_erosion_changed(new_value: int) -> void:
	var cn: Node = get_node_or_null("Content/Center/DesignCanvas/TopbarFull/Topbar1/CorrosionNumber")
	if cn and cn.has_method("set_corrosion_value"):
		cn.set_corrosion_value(new_value)


func _exit_tree() -> void:
	if ErosionCore and ErosionCore.erosion_changed.is_connected(_on_erosion_changed):
		ErosionCore.erosion_changed.disconnect(_on_erosion_changed)


## 设置侵蚀数字（供外部调用，如 GameMain 注入）
func set_corrosion_value(value: int) -> void:
	var cn: Node = get_node_or_null("Content/Center/DesignCanvas/TopbarFull/Topbar1/CorrosionNumber")
	if cn and cn.has_method("set_corrosion_value"):
		cn.set_corrosion_value(value)


func _on_settings_pressed() -> void:
	## 等同按 ESC，唤出暂停菜单
	var pause_menu: CanvasLayer = get_parent().get_node_or_null("PauseMenu") as CanvasLayer
	if pause_menu and pause_menu.has_method("show_menu"):
		pause_menu.show_menu()


func _update_canvas_scale() -> void:
	if not _design_canvas:
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var s := minf(vp_size.x / CANVAS_SIZE.x, vp_size.y / CANVAS_SIZE.y)
	_design_canvas.scale = Vector2(s, s)


func show_page() -> void:
	visible = true
	refresh_display()


func hide_page() -> void:
	visible = false


func toggle() -> void:
	visible = not visible
	if visible:
		refresh_display()


## 从 UIMain 同步资源数据到 ResourceBlock，与主 TopBar 逻辑一致
func set_resources(factors: Dictionary, currency: Dictionary, personnel: Dictionary) -> void:
	var topbar: Node = get_node_or_null("Content/Center/DesignCanvas/TopbarFull/Topbar0")
	if not topbar:
		return
	for rb in _collect_resource_blocks(topbar):
		if not rb is ResourceBlock:
			continue
		var block_id: String = rb.block_id
		match block_id:
			"cognition":
				rb.set_value(str(UIUtils.safe_int(factors.get("cognition", 0))))
			"computing_power":
				rb.set_value(str(UIUtils.safe_int(factors.get("computation", 0))))
			"willpower":
				rb.set_value(str(UIUtils.safe_int(factors.get("willpower", 0))))
			"permission":
				rb.set_value(str(UIUtils.safe_int(factors.get("permission", 0))))
			"info":
				rb.set_value(str(UIUtils.safe_int(currency.get("info", 0))))
			"truth":
				rb.set_value(str(UIUtils.safe_int(currency.get("truth", 0))))
			"investigator":
				rb.set_value(str(UIUtils.safe_int(personnel.get("investigator", 0))))
			"researcher":
				_apply_researcher_block(rb, personnel)
			"shelter":
				rb.set_value(str(_get_shelter_display_value()))
			"housing":
				rb.set_value(str(_get_housing_display_value()))


func _apply_researcher_block(rb: ResourceBlock, personnel: Dictionary) -> void:
	var total: int = UIUtils.safe_int(personnel.get("researcher", 0))
	var eroded: int = UIUtils.safe_int(personnel.get("eroded", 0))
	var ui: Node = get_parent().get_node_or_null("UIMain") if get_parent() else null
	var in_cleanup: int = int(ui.get("researchers_in_cleanup")) if ui and ui.get("researchers_in_cleanup") != null else 0
	var in_construction: int = int(ui.get("researchers_in_construction")) if ui and ui.get("researchers_in_construction") != null else 0
	var in_rooms: int = int(ui.get("researchers_working_in_rooms")) if ui and ui.get("researchers_working_in_rooms") != null else 0
	var idle: int = maxi(0, total - eroded - in_cleanup - in_construction - in_rooms)
	rb.set_researcher_progress(idle, eroded, total)
	rb.set_value("%d/%d" % [idle, total])


func _get_shelter_display_value() -> int:
	var gm: Node = get_parent()
	if gm and gm.get("_shelter_level") != null:
		return int(gm.get("_shelter_level"))
	return 1


func _get_housing_display_value() -> int:
	var gm: Node = get_parent()
	if not gm or gm.get("_rooms") == null:
		return 0
	var rooms: Array = gm.get("_rooms")
	var gv: Node = _GameValuesRef.get_singleton()
	var total: int = 0
	for room in rooms:
		if not room:
			continue
		var zt: int = int(room.get("zone_type")) if room.get("zone_type") != null else 0
		if zt != ZoneTypeScript.Type.LIVING:
			continue
		var units: int = 0
		if room.has_method("get_room_units"):
			units = room.get_room_units()
		total += gv.get_housing_for_room_units(units) if gv and gv.has_method("get_housing_for_room_units") else (units * 2)
	return total


## 从 UIMain 拉取数据并刷新显示；作为子场景时由 GameMain._sync_resources_to_topbar 调用
func refresh_display() -> void:
	var ui: Node = get_parent().get_node_or_null("UIMain") if get_parent() else null
	if not ui or not ui.has_method("get_resources"):
		return
	var res: Dictionary = ui.get_resources()
	var factors: Dictionary = res.get("factors", {})
	var currency: Dictionary = res.get("currency", {})
	var personnel: Dictionary = res.get("personnel", {})
	set_resources(factors, currency, personnel)

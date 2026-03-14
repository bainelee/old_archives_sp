extends Control
## UIMain 内嵌的 Figma 风格 TopBar
## 显示 ResourceBlock、TimeControlBar、CorrosionNumber、ForecastWarning
## 父节点为 UIMain，通过 get_parent() 获取 get_resources、researchers_in_*

const DESIGN_WIDTH := 1920.0
const _GameValuesRef = preload("res://scripts/core/game_values_ref.gd")
const ZoneTypeScript = preload("res://scripts/core/zone_type.gd")

signal block_hovered(block_id: String)
signal block_unhovered(block_id: String)

## 由 UIMain 在 _ready 时注入，避免 get_parent() 链
var _ui_root: Node = null


func set_ui_root(ui: Node) -> void:
	_ui_root = ui


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var btn_settings: TextureButton = get_node_or_null("Topbar0/BaseButtonSettings") as TextureButton
	if btn_settings:
		btn_settings.pressed.connect(_on_settings_pressed)
	_setup_resource_block_hover()
	_setup_corrosion_number()
	_update_scale()
	get_viewport().size_changed.connect(_update_scale)
	call_deferred("refresh_display")


func _exit_tree() -> void:
	if not is_instance_valid(ErosionCore):
		return
	if ErosionCore.is_connected("erosion_changed", _on_erosion_changed):
		ErosionCore.disconnect("erosion_changed", _on_erosion_changed)


func _update_scale() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var s := vp_size.x / DESIGN_WIDTH
	scale = Vector2(s, s)


func _setup_resource_block_hover() -> void:
	## 从根节点收集所有 ResourceBlock，支持 Topbar0、Topbar1 及未来扩展
	for child in _collect_resource_blocks(self):
		if child.has_signal("hovered") and child.has_signal("unhovered"):
			child.hovered.connect(_on_resource_block_hovered)
			child.unhovered.connect(_on_resource_block_unhovered)


func _collect_resource_blocks(parent: Node) -> Array:
	var result: Array = []
	for node in parent.find_children("*", "ResourceBlock", true, false):
		result.append(node)
	return result


func _on_resource_block_hovered(block_id: String) -> void:
	block_hovered.emit(block_id)


func _on_resource_block_unhovered(block_id: String) -> void:
	block_unhovered.emit(block_id)


func _setup_corrosion_number() -> void:
	var cn: Node = get_node_or_null("Topbar1/CorrosionNumber")
	if not cn or not cn.has_method("set_corrosion_value"):
		return
	if ErosionCore:
		cn.set_corrosion_value(ErosionCore.current_erosion)
		if not ErosionCore.is_connected("erosion_changed", _on_erosion_changed):
			ErosionCore.connect("erosion_changed", _on_erosion_changed)


func _on_erosion_changed(_new_value: int) -> void:
	var cn: Node = get_node_or_null("Topbar1/CorrosionNumber")
	if cn and cn.has_method("set_corrosion_value") and ErosionCore:
		cn.set_corrosion_value(ErosionCore.current_erosion)


func _on_settings_pressed() -> void:
	if _ui_root == null:
		_ui_root = get_parent().get_parent() if get_parent() else null
	var gm: Node = _ui_root.get_parent() if _ui_root else null
	var pause_menu: CanvasLayer = gm.get_node_or_null("PauseMenu") as CanvasLayer if gm else null
	if pause_menu and pause_menu.has_method("show_menu"):
		pause_menu.show_menu()


func set_resources(factors: Dictionary, currency: Dictionary, personnel: Dictionary) -> void:
	for rb in _collect_resource_blocks(self):
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
	var ui: Node = _ui_root if _ui_root else (get_parent().get_parent() if get_parent() else null)
	var in_cleanup: int = int(ui.get("researchers_in_cleanup")) if ui and ui.get("researchers_in_cleanup") != null else 0
	var in_construction: int = int(ui.get("researchers_in_construction")) if ui and ui.get("researchers_in_construction") != null else 0
	var in_rooms: int = int(ui.get("researchers_working_in_rooms")) if ui and ui.get("researchers_working_in_rooms") != null else 0
	var idle: int = maxi(0, total - eroded - in_cleanup - in_construction - in_rooms)
	rb.set_researcher_progress(idle, eroded, total)
	rb.set_value("%d/%d" % [idle, total])


func _get_shelter_display_value() -> int:
	var gm: Node = _ui_root.get_parent() if _ui_root else null
	if gm and gm.get("_shelter_level") != null:
		return int(gm.get("_shelter_level"))
	return 1


func _get_housing_display_value() -> int:
	var gm: Node = _ui_root.get_parent() if _ui_root else null
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


func refresh_display() -> void:
	var ui: Node = _ui_root if _ui_root else (get_parent().get_parent() if get_parent() else null)
	if not ui or not ui.has_method("get_resources"):
		return
	var res: Dictionary = ui.get_resources()
	var factors: Dictionary = res.get("factors", {})
	var currency: Dictionary = res.get("currency", {})
	var personnel: Dictionary = res.get("personnel", {})
	set_resources(factors, currency, personnel)

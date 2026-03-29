extends Control
## UIMain 内嵌的 Figma 风格 TopBar
## 显示 ResourceBlock、TimeControlBar、CorrosionNumber、ForecastWarning
## 数据逻辑委托给 TopbarDataHelper，消除与 test_figma_page 的重复

const DESIGN_WIDTH := 1920.0
const _Helper = preload("res://scripts/ui/topbar_data_helper.gd")

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
	if ErosionCore.erosion_changed.is_connected(_on_erosion_changed):
		ErosionCore.erosion_changed.disconnect(_on_erosion_changed)


func _update_scale() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var s := vp_size.x / DESIGN_WIDTH
	scale = Vector2(s, s)


func _setup_resource_block_hover() -> void:
	for child in _Helper.collect_resource_blocks(self):
		child.hovered.connect(_on_resource_block_hovered)
		child.unhovered.connect(_on_resource_block_unhovered)


func _on_resource_block_hovered(block_id: String) -> void:
	block_hovered.emit(block_id)


func _on_resource_block_unhovered(block_id: String) -> void:
	block_unhovered.emit(block_id)


func _setup_corrosion_number() -> void:
	var cn: Node = get_node_or_null("Topbar1/CorrosionNumber")
	if not cn or not cn.has_method("set_corrosion_value"):
		return
	if is_instance_valid(ErosionCore):
		cn.set_corrosion_value(ErosionCore.current_erosion)
		if not ErosionCore.erosion_changed.is_connected(_on_erosion_changed):
			ErosionCore.erosion_changed.connect(_on_erosion_changed)


func _on_erosion_changed(_new_value: int) -> void:
	var cn: Node = get_node_or_null("Topbar1/CorrosionNumber")
	if cn and cn.has_method("set_corrosion_value") and is_instance_valid(ErosionCore):
		cn.set_corrosion_value(ErosionCore.current_erosion)


func _on_settings_pressed() -> void:
	if _ui_root == null:
		_ui_root = get_parent().get_parent() if get_parent() else null
	var shell: Node = _ui_root.get_parent() if _ui_root else null
	## shell 为 InteractiveUiRoot，PauseMenu 为其子节点（非 GameMain 直系）
	var pause_menu: CanvasLayer = shell.get_node_or_null("PauseMenu") as CanvasLayer if shell else null
	if pause_menu and pause_menu.has_method("show_menu"):
		pause_menu.show_menu()


func set_resources(factors: Dictionary, currency: Dictionary, personnel: Dictionary) -> void:
	var gv: Node = GameValuesRef.get_singleton()
	var shell: Node = _ui_root.get_parent() if _ui_root else null
	var gm: Node = shell.get_parent() if shell else null
	_Helper.apply_resources(self, factors, currency, personnel, {
		"gv": gv, "gm": gm, "ui": _ui_root,
	})


func refresh_display() -> void:
	var ui: Node = _ui_root if _ui_root else (get_parent().get_parent() if get_parent() else null)
	if not ui or not ui.has_method("get_resources"):
		return
	var res: Dictionary = ui.get_resources()
	set_resources(res.get("factors", {}), res.get("currency", {}), res.get("personnel", {}))

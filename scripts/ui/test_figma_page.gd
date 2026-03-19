extends CanvasLayer

## 测试 Figma 同步的 UI 页面，按 F12 切换显示/隐藏
## 所有布局、颜色、样式均存储在 .tscn 中，由 Figma MCP 同步时直接写入场景
## 数据逻辑委托给 TopbarDataHelper，与主 TopBar 保持完全一致

const CANVAS_SIZE := Vector2(1920.0, 1080.0)
const _Helper = preload("res://scripts/ui/topbar_data_helper.gd")

var _design_canvas: Control


func _ready() -> void:
	_design_canvas = get_node_or_null("Content/Center/DesignCanvas") as Control
	if _design_canvas:
		_design_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var btn_settings: TextureButton = get_node_or_null("Content/Center/DesignCanvas/TopbarFull/Topbar0/BaseButtonSettings") as TextureButton
	if btn_settings:
		btn_settings.pressed.connect(_on_settings_pressed)
	_setup_corrosion_number()
	if get_tree().current_scene != self:
		visible = false
	_update_canvas_scale()
	get_viewport().size_changed.connect(_update_canvas_scale)
	call_deferred("refresh_display")


func _exit_tree() -> void:
	if not is_instance_valid(ErosionCore):
		return
	if ErosionCore.erosion_changed.is_connected(_on_erosion_changed):
		ErosionCore.erosion_changed.disconnect(_on_erosion_changed)


func _setup_corrosion_number() -> void:
	var cn: Node = get_node_or_null("Content/Center/DesignCanvas/TopbarFull/Topbar1/CorrosionNumber")
	if not cn or not cn.has_method("set_corrosion_value"):
		return
	if is_instance_valid(ErosionCore):
		cn.set_corrosion_value(ErosionCore.current_erosion)
		if not ErosionCore.erosion_changed.is_connected(_on_erosion_changed):
			ErosionCore.erosion_changed.connect(_on_erosion_changed)


func _on_erosion_changed(_new_value: int) -> void:
	var cn: Node = get_node_or_null("Content/Center/DesignCanvas/TopbarFull/Topbar1/CorrosionNumber")
	if cn and cn.has_method("set_corrosion_value") and is_instance_valid(ErosionCore):
		cn.set_corrosion_value(ErosionCore.current_erosion)


func set_corrosion_value(value: int) -> void:
	var cn: Node = get_node_or_null("Content/Center/DesignCanvas/TopbarFull/Topbar1/CorrosionNumber")
	if cn and cn.has_method("set_corrosion_value"):
		cn.set_corrosion_value(value)


func _on_settings_pressed() -> void:
	var pause_menu: CanvasLayer = get_parent().get_node_or_null("PauseMenu") as CanvasLayer if get_parent() else null
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


func set_resources(factors: Dictionary, currency: Dictionary, personnel: Dictionary) -> void:
	var topbar: Node = get_node_or_null("Content/Center/DesignCanvas/TopbarFull")
	if not topbar:
		return
	var gv: Node = GameValuesRef.get_singleton()
	var gm: Node = get_parent()
	var ui: Node = get_parent().get_node_or_null("UIMain") if get_parent() else null
	_Helper.apply_resources(topbar, factors, currency, personnel, {
		"gv": gv, "gm": gm, "ui": ui,
	})


func refresh_display() -> void:
	var ui: Node = get_parent().get_node_or_null("UIMain") if get_parent() else null
	if not ui or not ui.has_method("get_resources"):
		return
	var res: Dictionary = ui.get_resources()
	set_resources(res.get("factors", {}), res.get("currency", {}), res.get("personnel", {}))

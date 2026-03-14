extends CanvasLayer

## 测试 Figma 同步的 UI 页面，按 F12 切换显示/隐藏
## 所有布局、颜色、样式均存储在 .tscn 中，由 Figma MCP 同步时直接写入场景
## 禁止使用截图或 JSON 运行时加载；同步时需读取 Figma 的 layout、fills、cornerRadius 等原始数据
## 鼠标悬停资源块会发出 hovered/unhovered，详细信息面板可连接（暂未实现新界面）

const CANVAS_SIZE := Vector2(1920.0, 1080.0)

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
	# 侵蚀数字控件初始化（示例值，可由外部调用 set_corrosion_value 更新）
	_setup_corrosion_number()
	# 仅在作为子场景实例时隐藏；单独运行本场景时保持可见便于调试
	if get_tree().current_scene != self:
		visible = false
	_update_canvas_scale()
	get_viewport().size_changed.connect(_update_canvas_scale)


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
	if cn and cn.has_method("set_corrosion_value"):
		cn.set_corrosion_value(4)  # 示例：显示 004


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


func hide_page() -> void:
	visible = false


func toggle() -> void:
	visible = not visible

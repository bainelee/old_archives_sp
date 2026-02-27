extends CanvasLayer

## 测试 Figma 同步的 UI 页面，按 F12 切换显示/隐藏
## 所有布局、颜色、样式均存储在 .tscn 中，由 Figma MCP 同步时直接写入场景
## 禁止使用截图或 JSON 运行时加载；同步时需读取 Figma 的 layout、fills、cornerRadius 等原始数据

const CANVAS_SIZE := Vector2(1920.0, 1080.0)

var _design_canvas: Control


func _ready() -> void:
	_design_canvas = get_node_or_null("Content/Center/DesignCanvas") as Control
	# 仅在作为子场景实例时隐藏；单独运行本场景时保持可见便于调试
	if get_tree().current_scene != self:
		visible = false
	_update_canvas_scale()
	get_viewport().size_changed.connect(_update_canvas_scale)


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

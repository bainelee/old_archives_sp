class_name DetailHoverPanelBase
extends PanelContainer
## 详细信息悬停面板基类
## 因子、研究员等 TopBar block 的悬停详情共用：显示在鼠标左侧、离开区域时隐藏
## 子类实现具体展示内容（show_for_factor、show_panel 等），继承 hide_panel、update_position

const PADDING := 12.0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func hide_panel() -> void:
	visible = false


func update_position(mouse_pos: Vector2, viewport_size: Vector2) -> void:
	var panel_size: Vector2 = size
	var left_x: float = mouse_pos.x - panel_size.x - PADDING
	left_x = clampf(left_x, 0, viewport_size.x - panel_size.x)
	var y: float = _get_position_y(mouse_pos, panel_size, viewport_size)
	position = Vector2(left_x, y)


## 子类可重写以自定义垂直位置。默认：以鼠标为中心
func _get_position_y(mouse_pos: Vector2, panel_size: Vector2, viewport_size: Vector2) -> float:
	return clampf(mouse_pos.y - panel_size.y / 2.0, 0, viewport_size.y - panel_size.y)

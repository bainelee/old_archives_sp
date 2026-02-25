extends PanelContainer
## 研究员悬停面板 - 显示在鼠标左侧
## 显示：总数、被侵蚀、清理中、建设中、房间工作、空闲

@onready var _label_total: Label = $Margin/VBox/Total
@onready var _label_eroded: Label = $Margin/VBox/Eroded
@onready var _label_in_cleanup: Label = $Margin/VBox/InCleanup
@onready var _label_in_construction: Label = $Margin/VBox/InConstruction
@onready var _label_working: Label = $Margin/VBox/Working
@onready var _label_idle: Label = $Margin/VBox/Idle


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_panel(total: int, eroded: int, in_cleanup: int, in_construction: int, working: int) -> void:
	var idle: int = maxi(0, total - eroded - in_cleanup - in_construction - working)
	_label_total.text = "研究员总数：%d" % total
	_label_eroded.text = "被侵蚀：%d" % eroded
	_label_in_cleanup.text = "清理中：%d" % in_cleanup
	_label_in_construction.text = "建设中：%d" % in_construction
	_label_working.text = "房间内工作：%d" % working
	_label_idle.text = "空闲：%d" % idle
	visible = true


func hide_panel() -> void:
	visible = false


func update_position(mouse_pos: Vector2, viewport_size: Vector2) -> void:
	var panel_size: Vector2 = size
	var padding: float = 12.0
	var left_x: float = mouse_pos.x - panel_size.x - padding
	var y: float = clampf(mouse_pos.y - panel_size.y / 2.0, 0, viewport_size.y - panel_size.y)
	position = Vector2(left_x, y)

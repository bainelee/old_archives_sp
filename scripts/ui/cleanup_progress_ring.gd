extends Control
## 环形清理进度条 - 显示 0~1 进度

var progress_ratio: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(80, 80)
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size / 2.0
	var radius: float = minf(size.x, size.y) / 2.0 - 4.0
	# 背景环
	draw_arc(center, radius, 0, TAU, 32, Color(0.2, 0.2, 0.25, 0.9), 4.0)
	# 进度弧（从顶部顺时针，progress=1 时满圈）
	var start_angle: float = -PI / 2.0  # 顶部 = -90°
	var end_angle: float = start_angle + TAU * progress_ratio
	draw_arc(center, radius, start_angle, end_angle, 32, Color(0.5, 0.75, 0.95, 1.0), 4.0)

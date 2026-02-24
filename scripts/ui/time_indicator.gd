extends Control
## 时间流逝指示器 - 当时间流动时循环旋转的图元
## 使用简单多边形作为占位，可后续替换为纹理

var _color: Color = Color(0.7, 0.85, 0.95, 0.9)


func _ready() -> void:
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and size.x > 0 and size.y > 0:
		pivot_offset = size / 2.0  # 绕中心旋转，避免越界


func _draw() -> void:
	var center := size / 2.0
	var r := minf(size.x, size.y) * 0.32  # 缩小半径，确保旋转时完全在边界内
	# 绘制一个简单箭头/扇形表示「时间流逝」
	var points := PackedVector2Array()
	for i in 4:
		var angle := TAU * float(i) / 4.0 - TAU / 8.0
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(points, _color)
	# 中心圆点
	draw_arc(center, r * 0.3, 0, TAU, 16, _color.darkened(0.2))

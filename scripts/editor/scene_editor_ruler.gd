extends Control
class_name SceneEditorRuler

## 标尺网格 - 显示网格坐标，固定于屏幕左侧和顶部

var _editor: Node2D
var _cell_size: int = 20
var _grid_width: int = 80
var _grid_height: int = 40
var _ruler_w: int = 36
var _ruler_h: int = 24


func setup(editor: Node2D, cell_size: int, grid_w: int, grid_h: int) -> void:
	_editor = editor
	_cell_size = cell_size
	_grid_width = grid_w
	_grid_height = grid_h
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if not _editor:
		return
	var camera: Camera2D = _editor.get_node_or_null("Camera2D")
	if not camera:
		return
	var vp_size: Vector2 = get_viewport_rect().size
	var zoom: Vector2 = camera.zoom
	var cam_pos: Vector2 = camera.position
	
	# 世界坐标转屏幕坐标: screen = (world - cam) * zoom + vp/2
	var to_screen_x := func(world_x: float) -> float:
		return (world_x - cam_pos.x) * zoom.x + vp_size.x / 2.0
	var to_screen_y := func(world_y: float) -> float:
		return (world_y - cam_pos.y) * zoom.y + vp_size.y / 2.0
	
	var font_size: int = 12
	var tick_color: Color = Color(0.6, 0.6, 0.65, 0.9)
	
	# 顶部横向标尺
	draw_rect(Rect2(0, 0, vp_size.x, _ruler_h), Color(0.15, 0.15, 0.2, 0.85))
	draw_line(Vector2(_ruler_w, _ruler_h), Vector2(vp_size.x, _ruler_h), tick_color)
	
	for gx in range(0, _grid_width + 1, 5):
		var wx: float = gx * _cell_size
		var sx: float = to_screen_x.call(wx)
		if sx >= _ruler_w and sx <= vp_size.x:
			draw_line(Vector2(sx, _ruler_h - 4), Vector2(sx, _ruler_h), tick_color)
			draw_string(ThemeDB.fallback_font, Vector2(sx - 4, _ruler_h - 8), str(gx), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	
	# 左侧纵向标尺
	draw_rect(Rect2(0, _ruler_h, _ruler_w, vp_size.y - _ruler_h), Color(0.15, 0.15, 0.2, 0.85))
	draw_line(Vector2(_ruler_w, _ruler_h), Vector2(_ruler_w, vp_size.y), tick_color)
	
	for gy in range(0, _grid_height + 1, 5):
		var wy: float = gy * _cell_size
		var sy: float = to_screen_y.call(wy)
		if sy >= _ruler_h and sy <= vp_size.y:
			draw_line(Vector2(_ruler_w - 4, sy), Vector2(_ruler_w, sy), tick_color)
			draw_string(ThemeDB.fallback_font, Vector2(2, sy + 4), str(gy), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	
	# 左上角
	draw_rect(Rect2(0, 0, _ruler_w, _ruler_h), Color(0.12, 0.12, 0.18, 0.95))

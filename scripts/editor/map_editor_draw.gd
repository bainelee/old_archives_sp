class_name MapEditorDrawHelper
extends RefCounted

## 地图编辑器绘制逻辑 - 网格、底板、房间、框选预览
## 接收 CanvasItem 与编辑器引用，将绘制逻辑与主类解耦

const TILE_COLORS := {
	FloorTileType.Type.EMPTY: Color(0.15, 0.15, 0.2),
	FloorTileType.Type.WALL: Color(0.4, 0.4, 0.45),
	FloorTileType.Type.ROOM_FLOOR: Color(0.55, 0.45, 0.35),
}


static func draw_single_base_image(canvas: CanvasItem, tex: Texture2D, room_rect: Rect2i, cell_size: int) -> void:
	var tw: float = tex.get_width()
	var th: float = tex.get_height()
	if tw <= 0 or th <= 0:
		return
	var px: float = room_rect.position.x * cell_size
	var py: float = room_rect.position.y * cell_size
	var room_px: Rect2 = Rect2(px, py, room_rect.size.x * cell_size, room_rect.size.y * cell_size)
	var img_rect: Rect2 = Rect2(px, py, tw, th)
	var clip: Rect2 = room_px.intersection(img_rect)
	if not clip.has_area():
		return
	var src_rect: Rect2 = Rect2(
		clip.position.x - img_rect.position.x,
		clip.position.y - img_rect.position.y,
		clip.size.x, clip.size.y
	)
	canvas.draw_texture_rect_region(tex, clip, src_rect)


static func draw_all(canvas: CanvasItem, editor: Node) -> void:
	var grid_w: int = editor.get("GRID_WIDTH")
	var grid_h: int = editor.get("GRID_HEIGHT")
	var cell_size: int = editor.get("CELL_SIZE")
	var tiles: Array = editor.get("_tiles")
	var rooms: Array = editor.get("_rooms")
	var selected_idx: int = editor.get("_selected_room_index")
	var edit_level: int = editor.get("_edit_level")
	var floor_sel: Rect2i = editor.get("_floor_selection")
	var floor_move_drag: bool = editor.get("_floor_move_dragging")
	var floor_drag_start: Vector2i = editor.get("_floor_move_drag_start")
	var box_start: Vector2i = editor.get("_box_start")
	var select_mode: int = editor.get("_select_mode")
	var quick_room_size: Vector2i = editor.get("_quick_room_size")
	var is_drawing: bool = editor.get("_is_drawing")
	var base_image_cache: Dictionary = editor.get("_base_image_cache")
	var tile_colors: Dictionary = editor.get("TILE_COLORS") if editor.get("TILE_COLORS") else TILE_COLORS

	var hide_source: bool = floor_move_drag and floor_sel.position.x >= 0
	for x in grid_w:
		for y in grid_h:
			var tile_rect: Rect2 = Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
			if hide_source and editor._is_point_in_floor_selection(Vector2i(x, y)):
				canvas.draw_rect(tile_rect, tile_colors[FloorTileType.Type.EMPTY])
				canvas.draw_rect(tile_rect, Color(0.2, 0.2, 0.25), false)
				continue
			var tile_type: int = tiles[x][y] as int
			var color: Color = tile_colors.get(tile_type, tile_colors[FloorTileType.Type.EMPTY]) as Color
			canvas.draw_rect(tile_rect, color)
			canvas.draw_rect(tile_rect, Color(0.2, 0.2, 0.25), false)

	for x in grid_w + 1:
		canvas.draw_line(
			Vector2(x * cell_size, 0),
			Vector2(x * cell_size, grid_h * cell_size),
			Color(0.25, 0.25, 0.3, 0.5)
		)
	for y in grid_h + 1:
		canvas.draw_line(
			Vector2(0, y * cell_size),
			Vector2(grid_w * cell_size, y * cell_size),
			Color(0.25, 0.25, 0.3, 0.5)
		)

	for room in rooms:
		if room.base_image_path.is_empty():
			continue
		var tex: Texture2D
		if base_image_cache.has(room.base_image_path):
			tex = base_image_cache[room.base_image_path] as Texture2D
		else:
			tex = load(room.base_image_path) as Texture2D
			if tex:
				base_image_cache[room.base_image_path] = tex
		if tex:
			draw_single_base_image(canvas, tex, room.rect, cell_size)

	for i in rooms.size():
		var room: RoomInfo = rooms[i]
		var r: Rect2i = room.rect
		var border_color: Color = Color(0.2, 0.6, 1, 0.8)
		if i == selected_idx:
			border_color = Color(1, 0.8, 0.2, 0.9)
		var px: float = r.position.x * cell_size
		var py: float = r.position.y * cell_size
		var pw: float = r.size.x * cell_size
		var ph: float = r.size.y * cell_size
		canvas.draw_rect(Rect2(px - 2, py - 2, pw + 4, ph + 4), border_color, false)

	if edit_level == FloorTileType.EditLevel.FLOOR or edit_level == FloorTileType.EditLevel.ROOM:
		var font: Font = ThemeDB.fallback_font
		var font_size: int = 12
		var padding: int = 2
		for room in rooms:
			var name_text: String = room.get_display_name()
			if name_text.is_empty():
				name_text = (editor as Node).tr("DEFAULT_UNTITLED")
			var txt_size: Vector2 = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var rx: float = room.rect.position.x * cell_size
			var ry: float = room.rect.position.y * cell_size
			var bg_rect: Rect2 = Rect2(rx + padding, ry + padding, txt_size.x + padding * 2, txt_size.y + padding * 2)
			canvas.draw_rect(bg_rect, Color(0, 0, 0, 0.6))
			canvas.draw_string(font, Vector2(rx + padding * 2, ry + padding + font.get_ascent(font_size)), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)

	if (select_mode == FloorTileType.SelectMode.BOX or select_mode == FloorTileType.SelectMode.FLOOR_SELECT) and is_drawing:
		var start: Vector2i
		var end: Vector2i
		if quick_room_size != Vector2i.ZERO:
			start = editor._get_mouse_grid()
			end = start + quick_room_size - Vector2i(1, 1)
		elif box_start.x >= 0:
			start = box_start
			end = editor._get_mouse_grid()
		else:
			start = Vector2i.ZERO
			end = Vector2i.ZERO
		if quick_room_size != Vector2i.ZERO or box_start.x >= 0:
			var x_min: int = mini(start.x, end.x)
			var x_max: int = maxi(start.x, end.x)
			var y_min: int = mini(start.y, end.y)
			var y_max: int = maxi(start.y, end.y)
			if x_max >= x_min and y_max >= y_min:
				var preview_rect: Rect2 = Rect2(
					x_min * cell_size, y_min * cell_size,
					(x_max - x_min + 1) * cell_size, (y_max - y_min + 1) * cell_size
				)
				var is_valid: bool = true
				if edit_level == FloorTileType.EditLevel.ROOM:
					is_valid = editor._is_room_box_valid(start, end)
				if is_valid:
					canvas.draw_rect(preview_rect, Color(1, 1, 1, 0.2))
					canvas.draw_rect(preview_rect, Color(1, 1, 1, 0.5), false)
				else:
					canvas.draw_rect(preview_rect, Color(1, 0.2, 0.2, 0.3))
					canvas.draw_rect(preview_rect, Color(1, 0.3, 0.3, 0.9), false)

	if edit_level == FloorTileType.EditLevel.FLOOR and floor_sel.position.x >= 0:
		var sel: Rect2i = floor_sel
		var px: float = sel.position.x * cell_size
		var py: float = sel.position.y * cell_size
		var pw: float = sel.size.x * cell_size
		var ph: float = sel.size.y * cell_size
		var draw_rect_pos: Rect2 = Rect2(px, py, pw, ph)
		if floor_move_drag:
			var mouse_grid: Vector2i = editor._get_mouse_grid()
			var offset: Vector2i = mouse_grid - floor_drag_start
			var dst_x: int = sel.position.x + offset.x
			var dst_y: int = sel.position.y + offset.y
			draw_rect_pos = Rect2(dst_x * cell_size, dst_y * cell_size, pw, ph)
			for i in sel.size.x:
				for j in sel.size.y:
					var src_gx: int = sel.position.x + i
					var src_gy: int = sel.position.y + j
					if src_gx >= 0 and src_gx < grid_w and src_gy >= 0 and src_gy < grid_h:
						var tile_type: int = tiles[src_gx][src_gy] as int
						var color: Color = tile_colors.get(tile_type, tile_colors[FloorTileType.Type.EMPTY]) as Color
						var cell_rect: Rect2 = Rect2((dst_x + i) * cell_size, (dst_y + j) * cell_size, cell_size, cell_size)
						canvas.draw_rect(cell_rect, color)
						canvas.draw_rect(cell_rect, Color(0.2, 0.2, 0.25), false)
		canvas.draw_rect(Rect2(draw_rect_pos.position.x - 2, draw_rect_pos.position.y - 2, draw_rect_pos.size.x + 4, draw_rect_pos.size.y + 4), Color(0.2, 1, 0.4, 0.9), false)

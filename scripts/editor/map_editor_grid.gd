class_name MapEditorGridHelper
extends RefCounted

## 地图编辑器网格、底板、房间交互逻辑 - 绘制、框选、房间创建
## 与输入处理解耦，接收 editor 引用操作状态

static func get_tile_type_from_tool(editor: Node) -> int:
	var paint_tool: int = editor.get("_paint_tool")
	match paint_tool:
		FloorTileType.PaintTool.ERASER, FloorTileType.PaintTool.EMPTY:
			return FloorTileType.Type.EMPTY
		FloorTileType.PaintTool.WALL:
			return FloorTileType.Type.WALL
		FloorTileType.PaintTool.ROOM_FLOOR:
			return FloorTileType.Type.ROOM_FLOOR
		_:
			return FloorTileType.Type.EMPTY


static func is_room_box_valid(editor: Node, start: Vector2i, end: Vector2i) -> bool:
	var grid_w: int = editor.get("GRID_WIDTH")
	var grid_h: int = editor.get("GRID_HEIGHT")
	var tiles: Array = editor.get("_tiles")
	var room_ids: Array = editor.get("_room_ids")
	var x_min: int = mini(start.x, end.x)
	var x_max: int = maxi(start.x, end.x)
	var y_min: int = mini(start.y, end.y)
	var y_max: int = maxi(start.y, end.y)
	for gx in range(x_min, x_max + 1):
		for gy in range(y_min, y_max + 1):
			if gx < 0 or gx >= grid_w or gy < 0 or gy >= grid_h:
				return false
			if tiles[gx][gy] != FloorTileType.Type.ROOM_FLOOR:
				return false
			if room_ids[gx][gy] >= 0:
				return false
	return true


static func try_create_room(editor: Node, start: Vector2i, end: Vector2i) -> void:
	var grid_w: int = editor.get("GRID_WIDTH")
	var grid_h: int = editor.get("GRID_HEIGHT")
	var tiles: Array = editor.get("_tiles")
	var room_ids: Array = editor.get("_room_ids")
	var rooms: Array = editor.get("_rooms")
	var x_min: int = mini(start.x, end.x)
	var x_max: int = maxi(start.x, end.x)
	var y_min: int = mini(start.y, end.y)
	var y_max: int = maxi(start.y, end.y)
	for gx in range(x_min, x_max + 1):
		for gy in range(y_min, y_max + 1):
			if gx < 0 or gx >= grid_w or gy < 0 or gy >= grid_h:
				return
			if tiles[gx][gy] != FloorTileType.Type.ROOM_FLOOR:
				print(TranslationServer.translate("ERROR_CREATE_ROOM_NON_FLOOR"))
				return
			if room_ids[gx][gy] >= 0:
				print(TranslationServer.translate("ERROR_CREATE_ROOM_OVERLAP"))
				return
	var w: int = x_max - x_min + 1
	var h: int = y_max - y_min + 1
	var room: RoomInfo = RoomInfo.new()
	var next_id: int = editor.get("_next_room_id")
	room.id = "room_%d" % next_id
	editor.set("_next_room_id", next_id + 1)
	room.room_name = TranslationServer.translate("DEFAULT_UNTITLED")
	room.rect = Rect2i(x_min, y_min, w, h)
	room.room_type = RoomInfo.RoomType.EMPTY_ROOM
	room.clean_status = RoomInfo.CleanStatus.UNCLEANED
	room.pre_clean_text = TranslationServer.translate("DEFAULT_PRE_CLEAN")
	room.resources = []
	rooms.append(room)
	for gx in range(x_min, x_max + 1):
		for gy in range(y_min, y_max + 1):
			room_ids[gx][gy] = rooms.size() - 1
	editor.set("_selected_room_index", rooms.size() - 1)
	editor.call("_refresh_room_panel")
	editor.call("_refresh_room_list")
	editor.queue_redraw()
	print(TranslationServer.translate("INFO_ROOM_CREATED") % [room.room_name, w, h])


static func apply_paint_at_mouse(editor: Node) -> void:
	var grid: Vector2i = editor.call("_get_mouse_grid")
	var grid_w: int = editor.get("GRID_WIDTH")
	var grid_h: int = editor.get("GRID_HEIGHT")
	if grid.x >= 0 and grid.x < grid_w and grid.y >= 0 and grid.y < grid_h:
		editor.call("_set_tile", grid.x, grid.y, get_tile_type_from_tool(editor))


static func try_select_room_at_mouse(editor: Node) -> void:
	var grid: Vector2i = editor.call("_get_mouse_grid")
	var grid_w: int = editor.get("GRID_WIDTH")
	var grid_h: int = editor.get("GRID_HEIGHT")
	if grid.x >= 0 and grid.x < grid_w and grid.y >= 0 and grid.y < grid_h:
		var room_ids: Array = editor.get("_room_ids")
		var rooms: Array = editor.get("_rooms")
		var rid: int = room_ids[grid.x][grid.y] as int
		if rid >= 0 and rid < rooms.size():
			editor.set("_selected_room_index", rid)
		else:
			editor.set("_selected_room_index", -1)
		editor.call("_refresh_room_panel")
		editor.queue_redraw()


static func fill_box(editor: Node, start: Vector2i, end: Vector2i) -> void:
	var x_min: int = mini(start.x, end.x)
	var x_max: int = maxi(start.x, end.x)
	var y_min: int = mini(start.y, end.y)
	var y_max: int = maxi(start.y, end.y)
	var paint_type: int = get_tile_type_from_tool(editor)
	for gx in range(x_min, x_max + 1):
		for gy in range(y_min, y_max + 1):
			editor.call("_set_tile", gx, gy, paint_type)


static func is_point_in_floor_selection(editor: Node, p: Vector2i) -> bool:
	var floor_sel: Rect2i = editor.get("_floor_selection")
	if floor_sel.position.x < 0:
		return false
	var r: Rect2i = floor_sel
	return p.x >= r.position.x and p.x < r.position.x + r.size.x and p.y >= r.position.y and p.y < r.position.y + r.size.y


static func set_floor_selection(editor: Node, start: Vector2i, end: Vector2i) -> void:
	var x_min: int = mini(start.x, end.x)
	var x_max: int = maxi(start.x, end.x)
	var y_min: int = mini(start.y, end.y)
	var y_max: int = maxi(start.y, end.y)
	editor.set("_floor_selection", Rect2i(x_min, y_min, x_max - x_min + 1, y_max - y_min + 1))
	editor.call("_update_room_panel_visibility")
	editor.queue_redraw()


static func apply_floor_move(editor: Node, release_grid: Vector2i) -> void:
	var grid_w: int = editor.get("GRID_WIDTH")
	var grid_h: int = editor.get("GRID_HEIGHT")
	var floor_sel: Rect2i = editor.get("_floor_selection")
	var floor_drag_start: Vector2i = editor.get("_floor_move_drag_start")
	var tiles: Array = editor.get("_tiles")
	var room_ids: Array = editor.get("_room_ids")
	var r: Rect2i = floor_sel
	if r.position.x < 0:
		return
	var offset: Vector2i = release_grid - floor_drag_start
	var new_x: int = r.position.x + offset.x
	var new_y: int = r.position.y + offset.y
	if new_x == r.position.x and new_y == r.position.y:
		return
	if new_x < 0 or new_y < 0 or new_x + r.size.x > grid_w or new_y + r.size.y > grid_h:
		return
	var temp: Array = []
	for gx in range(r.position.x, r.position.x + r.size.x):
		var col: Array = []
		for gy in range(r.position.y, r.position.y + r.size.y):
			col.append(tiles[gx][gy])
		temp.append(col)
	for gx in range(r.position.x, r.position.x + r.size.x):
		for gy in range(r.position.y, r.position.y + r.size.y):
			tiles[gx][gy] = FloorTileType.Type.EMPTY
			room_ids[gx][gy] = -1
	for i in r.size.x:
		for j in r.size.y:
			var gx: int = new_x + i
			var gy: int = new_y + j
			tiles[gx][gy] = temp[i][j]
			room_ids[gx][gy] = -1
	editor.set("_floor_selection", Rect2i(new_x, new_y, r.size.x, r.size.y))
	editor.queue_redraw()


static func clear_floor_selection(editor: Node) -> void:
	editor.set("_floor_selection", Rect2i(-1, -1, -1, -1))
	editor.set("_floor_move_mode", false)
	editor.set("_floor_move_dragging", false)
	editor.call("_update_room_panel_visibility")
	editor.queue_redraw()

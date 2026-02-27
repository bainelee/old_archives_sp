class_name GameMainDrawHelper
extends RefCounted

## 游戏主场景绘制逻辑 - 底板、房间底图、房间遮罩、边框、暂停研究标记
## 接收 CanvasItem 与 game_main，将绘制逻辑与主类解耦

const BuiltRoomHelper = preload("res://scripts/game/game_main_built_room.gd")
const TILE_COLORS := {
	FloorTileType.Type.EMPTY: Color(0.15, 0.15, 0.2),
	FloorTileType.Type.WALL: Color(0.4, 0.4, 0.45),
	FloorTileType.Type.ROOM_FLOOR: Color(0.55, 0.45, 0.35),
}

## CleanupMode 值（与 game_main.gd 一致）
const CLEANUP_NONE := 0
const CLEANUP_SELECTING := 1
const CLEANUP_CONFIRMING := 2

## ConstructionMode 值（与 game_main.gd 一致）
const CONSTRUCTION_SELECTING_TARGET := 2
const CONSTRUCTION_CONFIRMING := 3


static func get_base_image_texture(game_main: Node2D, path: String) -> Texture2D:
	if path.is_empty():
		return null
	var cache: Dictionary = game_main.get("_base_image_cache")
	if cache.has(path):
		return cache[path] as Texture2D
	var tex: Texture2D = load(path) as Texture2D
	if tex:
		cache[path] = tex
	return tex


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


static func draw_all(canvas: CanvasItem, game_main: Node2D) -> void:
	var grid_width: int = game_main.get("GRID_WIDTH")
	var grid_height: int = game_main.get("GRID_HEIGHT")
	var cell_size: int = game_main.get("CELL_SIZE")
	var tiles: Array = game_main.get("_tiles")
	var rooms: Array = game_main.get("_rooms")
	var cleanup_mode: int = game_main.get("_cleanup_mode")
	var construction_mode: int = game_main.get("_construction_mode")
	var construction_selected_zone: int = game_main.get("_construction_selected_zone")
	var selected_room_index: int = game_main.get("_selected_room_index")
	var hovered_room_index: int = game_main.get("_hovered_room_index")
	var cleanup_rooms: Dictionary = game_main.get("_cleanup_rooms_in_progress")
	var construction_rooms: Dictionary = game_main.get("_construction_rooms_in_progress")

	# 底板
	for x in grid_width:
		for y in grid_height:
			var tile_type: int = tiles[x][y] as int
			if tile_type == FloorTileType.Type.EMPTY:
				continue
			var color: Color = TILE_COLORS.get(tile_type, TILE_COLORS[FloorTileType.Type.EMPTY]) as Color
			var rect: Rect2 = Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
			canvas.draw_rect(rect, color)

	# 房间底图
	for room in rooms:
		if room.base_image_path.is_empty():
			continue
		var tex: Texture2D = get_base_image_texture(game_main, room.base_image_path)
		if tex == null:
			continue
		draw_single_base_image(canvas, tex, room.rect, cell_size)

	# 房间遮罩
	var in_cleanup_selecting: bool = (cleanup_mode == CLEANUP_SELECTING or cleanup_mode == CLEANUP_CONFIRMING)
	var in_construction_selecting: bool = (construction_mode == CONSTRUCTION_SELECTING_TARGET or construction_mode == CONSTRUCTION_CONFIRMING)
	for i in rooms.size():
		var room: RoomInfo = rooms[i]
		var px: float = room.rect.position.x * cell_size
		var py: float = room.rect.position.y * cell_size
		var pw: float = room.rect.size.x * cell_size
		var ph: float = room.rect.size.y * cell_size
		var rect: Rect2 = Rect2(px, py, pw, ph)
		var is_room_cleaning: bool = cleanup_rooms.has(i)
		var is_room_constructing: bool = construction_rooms.has(i)
		if in_cleanup_selecting:
			if room.clean_status == RoomInfo.CleanStatus.UNCLEANED and not is_room_cleaning:
				canvas.draw_rect(rect, Color(1, 1, 1, 0.4), true)
			else:
				canvas.draw_rect(rect, Color(0, 0, 0, 0.6), true)
		elif in_construction_selecting:
			if room.can_build_zone(construction_selected_zone) and not is_room_constructing:
				canvas.draw_rect(rect, Color(0.2, 0.5, 1.0, 0.4), true)
			else:
				canvas.draw_rect(rect, Color(0, 0, 0, 0.6), true)
		elif room.clean_status == RoomInfo.CleanStatus.UNCLEANED:
			canvas.draw_rect(rect, Color(0, 0, 0, 0.4), true)
		# 已建设房间：30% 透明度绿色遮罩，提示可辨识
		elif room.zone_type != 0:
			canvas.draw_rect(rect, Color(0.2, 0.8, 0.3, 0.3), true)

	# 暂停研究标记（造物区、玩家意志不足 24h 消耗，12-built-room-system 3）
	var ui: Node = game_main.get_node_or_null("UIMain")
	if ui:
		var font: Font = ThemeDB.fallback_font
		var font_size: int = 12
		for i in rooms.size():
			var room: RoomInfo = rooms[i]
			if BuiltRoomHelper.is_creation_zone_paused(room, ui):
				var px: float = room.rect.position.x * cell_size
				var py: float = room.rect.position.y * cell_size
				var badge_size: float = 18.0
				var badge_rect: Rect2 = Rect2(px + 4, py + 4, badge_size, badge_size)
				canvas.draw_rect(badge_rect, Color(0.9, 0.2, 0.2, 0.95), true)
				canvas.draw_rect(badge_rect, Color(1, 0.3, 0.3, 1), false)
				canvas.draw_string(font, Vector2(px + 7, py + 4 + font.get_ascent(font_size)), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
				var label_text: String = "暂停研究"
				var txt_size: Vector2 = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
				canvas.draw_rect(Rect2(px + 4, py + 4 + badge_size + 2, txt_size.x + 8, txt_size.y + 4), Color(0.1, 0.1, 0.12, 0.9), true)
				canvas.draw_string(font, Vector2(px + 8, py + 4 + badge_size + 2 + font.get_ascent(font_size) + 2), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)

	# 房间边框（清理/建设模式下不显示）
	if cleanup_mode != CLEANUP_SELECTING and cleanup_mode != CLEANUP_CONFIRMING and construction_mode != CONSTRUCTION_SELECTING_TARGET and construction_mode != CONSTRUCTION_CONFIRMING:
		for i in rooms.size():
			var room: RoomInfo = rooms[i]
			var r: Rect2i = room.rect
			var px: float = r.position.x * cell_size
			var py: float = r.position.y * cell_size
			var pw: float = r.size.x * cell_size
			var ph: float = r.size.y * cell_size
			var border_rect: Rect2 = Rect2(px - 2, py - 2, pw + 4, ph + 4)
			if i == selected_room_index:
				canvas.draw_rect(border_rect, Color(1, 0.85, 0.3, 0.95), false)
			elif i == hovered_room_index:
				canvas.draw_rect(border_rect, Color(0.4, 0.75, 1, 0.85), false)

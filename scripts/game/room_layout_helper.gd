class_name RoomLayoutHelper
extends RefCounted

## 房间布局格与邻接推导
## 真源：每间房占用的 1×1 整数格集合 `layout_cells`（馆内坐标，原点为 room_00 左下角格）；
## 两房相邻 ⇔ 各自格集中存在一对格，曼哈顿距离为 1。
## 若 `layout_cells` 为空，则回退为 grid_x/grid_y + 3d_size 矩形展开（与旧数据兼容）。
## 详见 docs/design/4-archives_rooms/04-room-unlock-adjacency.md

## 3d_size → 网格占位 (宽, 高)
const SIZE_TO_GRID := {
	"base": Vector2i(2, 1),
	"small": Vector2i(1, 1),
	"tall": Vector2i(2, 2),
	"small_tall": Vector2i(1, 2),
	"long": Vector2i(4, 1),
}


## 根据 3d_size 获取网格占位，未知尺寸默认 1×1
static func get_grid_size(size_id: String) -> Vector2i:
	return SIZE_TO_GRID.get(size_id, Vector2i(1, 1))


## 房间占用的格列表（Vector2i）；优先 layout_cells，否则由 grid+尺寸展开
static func get_occupancy_cells(room: ArchivesRoomInfo, room_3d_size_by_id: Dictionary = {}) -> Array:
	if room.layout_cells.size() > 0:
		var dup: Array = []
		for c in room.layout_cells:
			if c is Vector2i:
				dup.append(c as Vector2i)
		return dup
	var rid: String = room.id if room.id else room.json_room_id
	var size_id: String = room.size_3d if room.size_3d else str(room_3d_size_by_id.get(rid, "base"))
	size_id = size_id.to_lower()
	var sz: Vector2i = get_grid_size(size_id)
	var out: Array = []
	for dx in sz.x:
		for dy in sz.y:
			out.append(Vector2i(room.grid_x + dx, room.grid_y + dy))
	return out


## 两格集是否坐标相邻（存在一对格曼哈顿距离为 1）
static func cells_coordinate_adjacent(cells_a: Array, cells_b: Array) -> bool:
	for ca in cells_a:
		if not (ca is Vector2i):
			continue
		var a: Vector2i = ca as Vector2i
		for cb in cells_b:
			if not (cb is Vector2i):
				continue
			var b: Vector2i = cb as Vector2i
			if absi(a.x - b.x) + absi(a.y - b.y) == 1:
				return true
	return false


## 格集的轴对齐包围盒（用于门向等）
static func bounds_from_cells(cells: Array) -> Rect2i:
	if cells.is_empty():
		return Rect2i(0, 0, 0, 0)
	var min_x: int = 2147483647
	var min_y: int = 2147483647
	var max_x: int = -2147483648
	var max_y: int = -2147483648
	for c in cells:
		if not (c is Vector2i):
			continue
		var v: Vector2i = c as Vector2i
		min_x = mini(min_x, v.x)
		min_y = mini(min_y, v.y)
		max_x = maxi(max_x, v.x)
		max_y = maxi(max_y, v.y)
	var w: int = max_x - min_x + 1
	var h: int = max_y - min_y + 1
	return Rect2i(min_x, min_y, w, h)


## 两矩形邻接类型："horizontal"（X 方向共边）| "vertical"（Y 方向共边）| ""
## 若未邻接返回空串。horizontal = 左右门；vertical = 楼梯传送
static func get_adjacency_type(room_a: ArchivesRoomInfo, room_b: ArchivesRoomInfo) -> String:
	var cells_a: Array = get_occupancy_cells(room_a)
	var cells_b: Array = get_occupancy_cells(room_b)
	if not cells_coordinate_adjacent(cells_a, cells_b):
		return ""
	var ra: Rect2i = bounds_from_cells(cells_a)
	var rb: Rect2i = bounds_from_cells(cells_b)
	var ax1: int = ra.position.x
	var ay1: int = ra.position.y
	var aw: int = ra.size.x
	var ah: int = ra.size.y
	var ax2: int = ax1 + aw
	var ay2: int = ay1 + ah
	var bx1: int = rb.position.x
	var by1: int = rb.position.y
	var bw: int = rb.size.x
	var bh: int = rb.size.y
	var bx2: int = bx1 + bw
	var by2: int = by1 + bh
	if not rects_adjacent(ax1, ay1, aw, ah, bx1, by1, bw, bh):
		return ""
	if ax2 == bx1 or bx2 == ax1:
		return "horizontal"
	if ay2 == by1 or by2 == ay1:
		return "vertical"
	return ""


## 返回 room_a 通往 room_b 时使用的门："left" | "right"（仅 horizontal 邻接有效）
## B 在 A 右侧 → right；B 在 A 左侧 → left
static func get_door_side_to_adjacent(room_a: ArchivesRoomInfo, room_b: ArchivesRoomInfo) -> String:
	var cells_a: Array = get_occupancy_cells(room_a)
	var cells_b: Array = get_occupancy_cells(room_b)
	if not cells_coordinate_adjacent(cells_a, cells_b):
		return "right"
	var ra: Rect2i = bounds_from_cells(cells_a)
	var rb: Rect2i = bounds_from_cells(cells_b)
	var ax1: int = ra.position.x
	var ay1: int = ra.position.y
	var aw: int = ra.size.x
	var ah: int = ra.size.y
	var ax2: int = ax1 + aw
	var bx1: int = rb.position.x
	var by1: int = rb.position.y
	var bw: int = rb.size.x
	var bh: int = rb.size.y
	var bx2: int = bx1 + bw
	if not rects_adjacent(ax1, ay1, aw, ah, bx1, by1, bw, bh):
		return "right"
	if ax2 == bx1:
		return "right"
	if bx2 == ax1:
		return "left"
	return "right"


## 两矩形是否共边（邻接）
## A: [ax1, ax2) × [ay1, ay2), B: [bx1, bx2) × [by1, by2)
## 共边 = 不重叠 且 边界相邻（共享一条边）
static func rects_adjacent(ax1: int, ay1: int, aw: int, ah: int, bx1: int, by1: int, bw: int, bh: int) -> bool:
	var ax2: int = ax1 + aw
	var ay2: int = ay1 + ah
	var bx2: int = bx1 + bw
	var by2: int = by1 + bh
	# 重叠则不算邻接
	if ax1 >= bx2 or bx1 >= ax2 or ay1 >= by2 or by1 >= ay2:
		pass
	else:
		return false
	# 水平相邻：X 区间有重叠，Y 边界相邻
	if ax1 < bx2 and bx1 < ax2:
		if ay2 == by1 or by2 == ay1:
			return true
	# 垂直相邻：Y 区间有重叠，X 边界相邻
	if ay1 < by2 and by1 < ay2:
		if ax2 == bx1 or bx2 == ax1:
			return true
	return false


## 为房间数组计算邻接关系，写入各 room.adjacent_ids（由格集坐标相邻派生）
## rooms: Array[ArchivesRoomInfo]
## room_3d_size_by_id: 可选，仅用于无 layout_cells 时补全 size
static func compute_adjacency(rooms: Array, room_3d_size_by_id: Dictionary = {}) -> void:
	var n: int = rooms.size()
	var occupancies: Array = []
	for i in n:
		var room: ArchivesRoomInfo = rooms[i]
		room.adjacent_ids.clear()
		occupancies.append(get_occupancy_cells(room, room_3d_size_by_id))
	for i in n:
		var room_a: ArchivesRoomInfo = rooms[i]
		var rid_a: String = room_a.id if room_a.id else room_a.json_room_id
		if rid_a.is_empty():
			rid_a = "room_%d" % i
		var cells_a: Array = occupancies[i]
		for j in n:
			if i == j:
				continue
			var room_b: ArchivesRoomInfo = rooms[j]
			var rid_b: String = room_b.id if room_b.id else room_b.json_room_id
			if rid_b.is_empty():
				rid_b = "room_%d" % j
			if cells_coordinate_adjacent(cells_a, occupancies[j]):
				if rid_b not in room_a.adjacent_ids:
					room_a.adjacent_ids.append(rid_b)


## 构建 id -> index 映射
static func build_id_to_index(rooms: Array) -> Dictionary:
	var id_to_index: Dictionary = {}
	for i in rooms.size():
		var room: ArchivesRoomInfo = rooms[i]
		var rid: String = room.id if room.id else room.json_room_id
		if rid.is_empty():
			rid = "room_%d" % i
		id_to_index[rid] = i
	return id_to_index


## 应用开篇配置：开篇房间及其邻接房间设为已解锁；开篇房间设为已清理
## prologue_ids: Array[String] 如 ["room_00"]
## rooms: Array[ArchivesRoomInfo]
## id_to_index: Dictionary id -> int，用于按 id 查找房间
static func apply_prologue(rooms: Array, prologue_ids: Array, id_to_index: Dictionary) -> void:
	var unlocked_ids: Dictionary = {}
	for pid in prologue_ids:
		unlocked_ids[pid] = true
		var idx: Variant = id_to_index.get(pid)
		if idx != null and idx >= 0 and idx < rooms.size():
			var room: ArchivesRoomInfo = rooms[idx]
			room.unlocked = true
			room.clean_status = ArchivesRoomInfo.CleanStatus.CLEANED
			for adj_id in room.adjacent_ids:
				unlocked_ids[adj_id] = true
	for pid in unlocked_ids:
		var idx: Variant = id_to_index.get(pid)
		if idx != null and idx >= 0 and idx < rooms.size():
			rooms[idx].unlocked = true
	for i in rooms.size():
		var room: ArchivesRoomInfo = rooms[i]
		var rid: String = room.id if room.id else room.json_room_id
		if rid.is_empty():
			rid = "room_%d" % i
		if not unlocked_ids.has(rid):
			room.unlocked = false

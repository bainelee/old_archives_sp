class_name RoomLayoutHelper
extends RefCounted

## 房间布局网格与邻接推导
## 根据 3d_size、grid_x、grid_y 计算房间邻接关系
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


## 为房间数组计算邻接关系，写入各 room.adjacent_ids
## rooms: Array[RoomInfo]，每个 room 需有 id、grid_x、grid_y、3d_size
## room_3d_size_by_id: Optional Dictionary id -> "base"|"small" 等，若 room 无 3d_size 则从此表读取
static func compute_adjacency(rooms: Array, room_3d_size_by_id: Dictionary = {}) -> void:
	var n: int = rooms.size()
	for i in n:
		var room: RoomInfo = rooms[i]
		room.adjacent_ids.clear()
	var id_to_index: Dictionary = {}
	for i in n:
		var room: RoomInfo = rooms[i]
		var rid: String = room.id if room.id else room.json_room_id
		if rid.is_empty():
			rid = "room_%d" % i
		id_to_index[rid] = i
	for i in n:
		var room_a: RoomInfo = rooms[i]
		var rid_a: String = room_a.id if room_a.id else room_a.json_room_id
		if rid_a.is_empty():
			rid_a = "room_%d" % i
		var gx_a: int = room_a.grid_x
		var gy_a: int = room_a.grid_y
		var size_id: String = room_a.size_3d if room_a.size_3d else str(room_3d_size_by_id.get(rid_a, "base"))
		size_id = size_id.to_lower()
		var sz: Vector2i = get_grid_size(size_id)
		var aw: int = sz.x
		var ah: int = sz.y
		for j in n:
			if i == j:
				continue
			var room_b: RoomInfo = rooms[j]
			var rid_b: String = room_b.id if room_b.id else room_b.json_room_id
			if rid_b.is_empty():
				rid_b = "room_%d" % j
			var gx_b: int = room_b.grid_x
			var gy_b: int = room_b.grid_y
			var size_b: String = room_b.size_3d if room_b.size_3d else str(room_3d_size_by_id.get(rid_b, "base"))
			size_b = size_b.to_lower()
			var sz_b: Vector2i = get_grid_size(size_b)
			var bw: int = sz_b.x
			var bh: int = sz_b.y
			if rects_adjacent(gx_a, gy_a, aw, ah, gx_b, gy_b, bw, bh):
				if rid_b not in room_a.adjacent_ids:
					room_a.adjacent_ids.append(rid_b)


## 构建 id -> index 映射
static func build_id_to_index(rooms: Array) -> Dictionary:
	var id_to_index: Dictionary = {}
	for i in rooms.size():
		var room: RoomInfo = rooms[i]
		var rid: String = room.id if room.id else room.json_room_id
		if rid.is_empty():
			rid = "room_%d" % i
		id_to_index[rid] = i
	return id_to_index


## 应用开篇配置：开篇房间及其邻接房间设为已解锁；开篇房间设为已清理
## prologue_ids: Array[String] 如 ["room_00"]
## rooms: Array[RoomInfo]
## id_to_index: Dictionary id -> int，用于按 id 查找房间
static func apply_prologue(rooms: Array, prologue_ids: Array, id_to_index: Dictionary) -> void:
	var unlocked_ids: Dictionary = {}
	for pid in prologue_ids:
		unlocked_ids[pid] = true
		var idx: Variant = id_to_index.get(pid)
		if idx != null and idx >= 0 and idx < rooms.size():
			var room: RoomInfo = rooms[idx]
			room.unlocked = true
			room.clean_status = RoomInfo.CleanStatus.CLEANED
			for adj_id in room.adjacent_ids:
				unlocked_ids[adj_id] = true
	for pid in unlocked_ids:
		var idx: Variant = id_to_index.get(pid)
		if idx != null and idx >= 0 and idx < rooms.size():
			rooms[idx].unlocked = true
	for i in rooms.size():
		var room: RoomInfo = rooms[i]
		var rid: String = room.id if room.id else room.json_room_id
		if rid.is_empty():
			rid = "room_%d" % i
		if not unlocked_ids.has(rid):
			room.unlocked = false

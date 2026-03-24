class_name RoomInfoLoader
extends RefCounted

## 从 room_info.json 加载房间列表，供 archives 模式新游戏使用
## 详见 docs/design/4-archives_rooms/04-room-unlock-adjacency.md

const ROOM_INFO_PATH := "res://datas/room_info.json"


## 从 room_info.json 加载房间并转为 RoomInfo 数组
## 仅解析 id、room_name、3d_size、grid_x、grid_y、clean_status、room_resources 等
##
## filter_grid_only: 若 true，仅返回在 JSON 中显式含 grid_x、grid_y 的房间（用于 archives 模式）
static func load_rooms_from_room_info(filter_grid_only: bool = false) -> Array:
	var file: FileAccess = FileAccess.open(ROOM_INFO_PATH, FileAccess.READ)
	if not file:
		push_error("[RoomInfoLoader] 无法打开 %s" % ROOM_INFO_PATH)
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return []
	var d: Dictionary = parsed as Dictionary
	var rooms_arr: Variant = d.get("rooms", [])
	if not (rooms_arr is Array):
		return []
	var result: Array = []
	for item in rooms_arr:
		if not (item is Dictionary):
			continue
		var r: Dictionary = item as Dictionary
		if filter_grid_only and (not r.has("grid_x") or not r.has("grid_y")):
			continue
		var info: ArchivesRoomInfo = _dict_to_room_info(r)
		result.append(info)
	return result


static func _dict_to_room_info(r: Dictionary) -> ArchivesRoomInfo:
	var info: ArchivesRoomInfo = ArchivesRoomInfo.new()
	info.id = str(r.get("id", ""))
	info.room_name = str(r.get("room_name", ""))
	info.size_3d = str(r.get("3d_size", r.get("size_3d", "")))
	info.grid_x = int(r.get("grid_x", 0))
	info.grid_y = int(r.get("grid_y", 0))
	info.clean_status = int(r.get("clean_status", ArchivesRoomInfo.CleanStatus.UNCLEANED))
	if r.has("room_resources") and r.get("room_resources") is Array:
		for res_item in r.room_resources:
			if res_item is Dictionary:
				var ri: Dictionary = res_item as Dictionary
				info.resources.append({
					"resource_type": int(ri.get("type", ri.get("resource_type", ArchivesRoomInfo.ResourceType.NONE))),
					"resource_amount": int(ri.get("amount", ri.get("resource_amount", 0)))
				})
	info.pre_clean_text = ArchivesRoomInfo.parse_text_field(r.get("pre_clean_text"), "")
	info.desc = ArchivesRoomInfo.parse_text_field(r.get("desc"), "")
	info.remodel_slot_count = clampi(int(r.get("remodel_slot_count", 1)), 1, 3)
	info.json_room_id = info.id
	var room_type_str: String = str(r.get("room_type", ""))
	info.room_type = _room_type_from_string(room_type_str)
	if r.has("rect_x"):
		info.rect = Rect2i(
			int(r.get("rect_x", 0)),
			int(r.get("rect_y", 0)),
			int(r.get("rect_w", 1)),
			int(r.get("rect_h", 1))
		)
	else:
		var sz: Vector2i = RoomLayoutHelper.get_grid_size(info.size_3d.to_lower())
		info.rect = Rect2i(info.grid_x, info.grid_y, sz.x, sz.y)
	return info


static func _room_type_from_string(s: String) -> int:
	var lower: String = s.to_lower()
	match lower:
		"核心", "core": return ArchivesRoomInfo.RoomType.ARCHIVE_CORE
		"资料库", "archive": return ArchivesRoomInfo.RoomType.ARCHIVE
		"图书室", "library": return ArchivesRoomInfo.RoomType.LIBRARY
		"机房", "lab", "server room": return ArchivesRoomInfo.RoomType.LAB
		"教学室", "classroom": return ArchivesRoomInfo.RoomType.CLASSROOM
		"实验室", "server_room": return ArchivesRoomInfo.RoomType.SERVER_ROOM
		"推理室", "reasoning": return ArchivesRoomInfo.RoomType.REASONING
		"事务所遗址", "office_site": return ArchivesRoomInfo.RoomType.OFFICE_SITE
		"宿舍", "dormitory": return ArchivesRoomInfo.RoomType.DORMITORY
		"通道", "corridor": return ArchivesRoomInfo.RoomType.CORRIDOR
		"检修室", "maintenance": return ArchivesRoomInfo.RoomType.MAINTENANCE
		"庭院", "courtyard": return ArchivesRoomInfo.RoomType.COURTYARD
		_: return ArchivesRoomInfo.RoomType.EMPTY_ROOM

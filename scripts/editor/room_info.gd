class_name RoomInfo
extends RefCounted

## 房间基础信息结构体

## 房间类型（对应名词解释）
enum RoomType {
	LIBRARY,       ## 图书室
	LAB,           ## 实验室
	CLASSROOM,     ## 教学室
	ARCHIVE,       ## 资料库
	SERVER_ROOM,   ## 机房
	REASONING,     ## 推理室
	OFFICE_SITE,   ## 事务所遗址
	DORMITORY,     ## 宿舍
	EMPTY_ROOM     ## 空房间
}

## 房间产出资源类型
enum ResourceType {
	NONE,           ## 无
	COGNITION,      ## 认知因子
	COMPUTATION,    ## 计算因子
	WILL,           ## 意志因子
	PERMISSION,     ## 权限因子
	INFO,           ## 信息
	TRUTH           ## 真相
}

var id: String = ""
var room_name: String = ""
var rect: Rect2i = Rect2i(0, 0, 0, 0)  ## 房间在网格中的范围 (x, y, w, h)
var room_type: int = RoomType.EMPTY_ROOM
var resource_type: int = ResourceType.NONE
var resource_total: int = 0


func get_size() -> Vector2i:
	return Vector2i(rect.size.x, rect.size.y)


static func get_room_type_name(t: int) -> String:
	match t:
		RoomType.LIBRARY: return "图书室"
		RoomType.LAB: return "实验室"
		RoomType.CLASSROOM: return "教学室"
		RoomType.ARCHIVE: return "资料库"
		RoomType.SERVER_ROOM: return "机房"
		RoomType.REASONING: return "推理室"
		RoomType.OFFICE_SITE: return "事务所遗址"
		RoomType.DORMITORY: return "宿舍"
		RoomType.EMPTY_ROOM: return "空房间"
		_: return "未知"


static func get_resource_type_name(t: int) -> String:
	match t:
		ResourceType.NONE: return "无"
		ResourceType.COGNITION: return "认知因子"
		ResourceType.COMPUTATION: return "计算因子"
		ResourceType.WILL: return "意志因子"
		ResourceType.PERMISSION: return "权限因子"
		ResourceType.INFO: return "信息"
		ResourceType.TRUTH: return "真相"
		_: return "未知"


func to_dict() -> Dictionary:
	return {
		"id": id,
		"room_name": room_name,
		"rect_x": rect.position.x,
		"rect_y": rect.position.y,
		"rect_w": rect.size.x,
		"rect_h": rect.size.y,
		"room_type": room_type,
		"resource_type": resource_type,
		"resource_total": resource_total,
	}


static func from_dict(d: Dictionary) -> RoomInfo:
	var info: RoomInfo = RoomInfo.new()
	info.id = d.get("id", "")
	info.room_name = d.get("room_name", "")
	info.rect = Rect2i(
		int(d.get("rect_x", 0)),
		int(d.get("rect_y", 0)),
		int(d.get("rect_w", 0)),
		int(d.get("rect_h", 0))
	)
	info.room_type = int(d.get("room_type", RoomType.EMPTY_ROOM))
	info.resource_type = int(d.get("resource_type", ResourceType.NONE))
	info.resource_total = int(d.get("resource_total", 0))
	return info

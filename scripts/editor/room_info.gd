class_name RoomInfo
extends RefCounted

## 房间基础信息结构体

## 房间类型（对应名词解释）
enum RoomType {
	LIBRARY,       ## 图书室
	LAB,           ## 机房（研究区→计算因子）
	CLASSROOM,     ## 教学室
	ARCHIVE,       ## 资料库
	ARCHIVE_CORE,  ## 档案馆核心
	SERVER_ROOM,   ## 实验室（造物区→权限因子）
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

## 清理状态
enum CleanStatus {
	UNCLEANED,  ## 未清理
	CLEANED     ## 已清理
}

var id: String = ""
var room_name: String = ""
var rect: Rect2i = Rect2i(0, 0, 0, 0)  ## 房间在网格中的范围 (x, y, w, h)
var room_type: int = RoomType.EMPTY_ROOM
var clean_status: int = CleanStatus.UNCLEANED
var resources: Array = []  ## 资源列表，每项为 {"resource_type": int, "resource_amount": int}
var base_image_path: String = ""  ## 底图路径，相对于 res://，例如 res://assets/tiles/floor/xxx.png
var pre_clean_text: String = "默认清理前文本"  ## 清理前文本
var json_room_id: String = ""  ## 关联的 JSON 模板 id（如 ROOM_001），空表示编辑器新建未同步
var desc: String = ""  ## 房间描述（与 room_info.json 的 desc 对应）


func get_size() -> Vector2i:
	return Vector2i(rect.size.x, rect.size.y)


## 转为 room_info.json 中的房间条目格式
func to_json_room_dict(json_id: String) -> Dictionary:
	var res_list: Array = []
	for r in resources:
		if r is Dictionary:
			res_list.append({"resource_type": r.get("resource_type", ResourceType.NONE), "resource_amount": r.get("resource_amount", 0)})
	return {
		"id": json_id,
		"room_name": room_name,
		"size": "%d×%d" % [rect.size.x, rect.size.y],
		"room_type": get_room_type_name(room_type),
		"room_type_id": room_type,
		"clean_status": clean_status,
		"base_image_path": base_image_path,
		"resources": res_list,
		"pre_clean_text": pre_clean_text,
		"desc": desc,
	}


static func get_room_type_name(t: int) -> String:
	match t:
		RoomType.LIBRARY: return "图书室"
		RoomType.LAB: return "机房"
		RoomType.CLASSROOM: return "教学室"
		RoomType.ARCHIVE: return "资料库"
		RoomType.ARCHIVE_CORE: return "档案馆核心"
		RoomType.SERVER_ROOM: return "实验室"
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


static func get_clean_status_name(t: int) -> String:
	match t:
		CleanStatus.UNCLEANED: return "未清理"
		CleanStatus.CLEANED: return "已清理"
		_: return "未知"


func to_dict() -> Dictionary:
	var res_list: Array = []
	for r in resources:
		if r is Dictionary:
			res_list.append({"resource_type": r.get("resource_type", ResourceType.NONE), "resource_amount": r.get("resource_amount", 0)})
	return {
		"id": id,
		"room_name": room_name,
		"rect_x": rect.position.x,
		"rect_y": rect.position.y,
		"rect_w": rect.size.x,
		"rect_h": rect.size.y,
		"room_type": room_type,
		"clean_status": clean_status,
		"resources": res_list,
		"base_image_path": base_image_path,
		"pre_clean_text": pre_clean_text,
		"json_room_id": json_room_id,
		"desc": desc,
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
	info.clean_status = int(d.get("clean_status", CleanStatus.UNCLEANED))
	if d.has("resources"):
		var res_arr: Array = d.get("resources", []) as Array
		for r in res_arr:
			if r is Dictionary:
				info.resources.append({
					"resource_type": int(r.get("resource_type", ResourceType.NONE)),
					"resource_amount": int(r.get("resource_amount", 0))
				})
	else:
		# 向后兼容：旧格式 resource_type + resource_total
		var rt: int = int(d.get("resource_type", ResourceType.NONE))
		var amt: int = int(d.get("resource_total", 0))
		if rt != ResourceType.NONE or amt > 0:
			info.resources.append({"resource_type": rt, "resource_amount": amt})
	info.base_image_path = str(d.get("base_image_path", ""))
	info.pre_clean_text = str(d.get("pre_clean_text", "默认清理前文本"))
	info.json_room_id = str(d.get("json_room_id", ""))
	info.desc = str(d.get("desc", ""))
	return info

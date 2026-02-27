class_name RoomInfo
extends RefCounted

const ZoneTypeScript = preload("res://scripts/core/zone_type.gd")
const _GameValuesRef = preload("res://scripts/core/game_values_ref.gd")

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

## 清理花费（可选，空则按 08-game-values 4.1 默认公式）
var cleanup_cost: Dictionary = {}  ## {"info": 20, ...}
var cleanup_time_hours: float = -1.0  ## -1 表示用默认公式

## 区域建设（0=无，见 ZoneType）
var zone_type: int = 0


func get_size() -> Vector2i:
	return Vector2i(rect.size.x, rect.size.y)


## 房间单位数（5 格 = 1 单位，如 5×3=15 格 = 3 单位）
func _get_room_units() -> int:
	var area: int = rect.size.x * rect.size.y
	return maxi(1, int(ceil(float(area) / 5.0)))


## 获取清理此房间所需资源（未配置则从 game_values.json 读取）
func get_cleanup_cost() -> Dictionary:
	if not cleanup_cost.is_empty():
		return cleanup_cost.duplicate()
	var gv: Node = _GameValuesRef.get_singleton()
	var cfg: Variant = gv.get_cleanup_for_units(_get_room_units()) if gv else null
	if cfg is Dictionary and cfg.has("info"):
		return {"info": int(cfg.info)}
	return {"info": 20}


## 获取清理此房间需占用的研究员数量
func get_cleanup_researcher_count() -> int:
	var gv: Node = _GameValuesRef.get_singleton()
	var cfg: Variant = gv.get_cleanup_for_units(_get_room_units()) if gv else null
	if cfg is Dictionary and cfg.has("researchers"):
		return int(cfg.researchers)
	return 2


## 获取清理此房间所需时间（小时）
func get_cleanup_time_hours() -> float:
	if cleanup_time_hours > 0:
		return cleanup_time_hours
	var gv: Node = _GameValuesRef.get_singleton()
	var cfg: Variant = gv.get_cleanup_for_units(_get_room_units()) if gv else null
	if cfg is Dictionary and cfg.has("hours"):
		return float(cfg.hours)
	return 3.0


## 建设指定区域类型所需的资源消耗（08-game-values 5.1）
func get_construction_cost(construction_zone_type: int) -> Dictionary:
	return ZoneTypeScript.get_construction_cost(construction_zone_type).duplicate()


## 建设指定区域类型需占用的研究员数
func get_construction_researcher_count(construction_zone_type: int) -> int:
	return ZoneTypeScript.get_construction_researcher_count(construction_zone_type)


## 建设指定区域类型所需时间（小时）= 房间单位数 × 每单位耗时
func get_construction_time_hours(construction_zone_type: int) -> float:
	var units: int = _get_room_units()
	var per_unit: float = ZoneTypeScript.get_construction_time_per_unit_hours(construction_zone_type)
	return units * per_unit


## 该房间是否可建设指定区域类型（已清理、未建设、房间类型匹配）
func can_build_zone(construction_zone_type: int) -> bool:
	if construction_zone_type == 0:
		return false
	if room_type == RoomType.ARCHIVE_CORE:
		return false  ## 档案馆核心不参与区域建设
	if clean_status != CleanStatus.CLEANED:
		return false
	if zone_type != 0:
		return false
	var allowed: Array = ZoneTypeScript.get_rooms_for_zone(construction_zone_type)
	return room_type in allowed


## 解析 desc/pre_clean_text：支持字符串或数组（数组合并便于阅读），返回字符串
## 数组形式：每项之间自动插入换行，无需在 JSON 中写 \n；\n 仍可用于段落空行等
static func parse_text_field(v: Variant, default_val: String = "") -> String:
	if v is Array:
		var arr: Array = v as Array
		var parts: PackedStringArray = []
		for item in arr:
			parts.append(str(item))
		return "\n".join(parts)
	if v == null:
		return default_val
	return str(v)


## 将长文本格式化为 JSON 数组（方便阅读、修改）；短文本或空串保持字符串
## 每行作为数组一项，读取时 parse_text_field 会以 \n 拼接，无需在元素内写 \n
static func format_text_for_json(s: String, min_len_for_array: int = 30) -> Variant:
	if s.is_empty():
		return ""
	if s.length() < min_len_for_array and not "\n" in s:
		return s
	var split_arr: PackedStringArray = s.split("\n")
	if split_arr.size() <= 1:
		return s
	var parts: Array = []
	for line in split_arr:
		parts.append(line)
	return parts


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
		"pre_clean_text": format_text_for_json(pre_clean_text),
		"desc": format_text_for_json(desc),
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
		"cleanup_cost": cleanup_cost,
		"cleanup_time_hours": cleanup_time_hours,
		"zone_type": zone_type,
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
	info.pre_clean_text = parse_text_field(d.get("pre_clean_text"), "默认清理前文本")
	info.json_room_id = str(d.get("json_room_id", ""))
	info.desc = parse_text_field(d.get("desc"), "")
	if d.has("cleanup_cost") and d.get("cleanup_cost") is Dictionary:
		info.cleanup_cost = (d.get("cleanup_cost") as Dictionary).duplicate()
	if d.has("cleanup_time_hours"):
		info.cleanup_time_hours = float(d.get("cleanup_time_hours", -1))
	info.zone_type = int(d.get("zone_type", 0))
	return info

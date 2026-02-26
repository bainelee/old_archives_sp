class_name ZoneType
extends RefCounted

const _GameValuesRef := preload("res://scripts/core/game_values_ref.gd")

## 区域类型枚举与建设数值
## 房间类型→区域映射见 11-zone-construction.md 1.1；建设消耗见 08-game-values 5.1

enum Type {
	NONE,       ## 无
	RESEARCH,   ## 研究区
	CREATION,   ## 造物区
	OFFICE,     ## 事务所区
	LIVING,     ## 生活区
	## 以下暂未实现，get_rooms_for_zone 返回空数组
	MEDICAL,    ## 医疗区
	ENTERTAINMENT,  ## 娱乐区
	RELIGION,   ## 宗教区
	WONDER      ## 奇观区
}

## 分类 tag（工作类/后勤类/秘迹类）
const CATEGORY_WORK := "工作类"
const CATEGORY_LOGISTICS := "后勤类"
const CATEGORY_MYSTERY := "秘迹类"

## RoomType 数值（与 RoomInfo.RoomType 对应，避免循环依赖）
const RT_LIBRARY := 0
const RT_LAB := 1
const RT_CLASSROOM := 2
const RT_ARCHIVE := 3
const RT_ARCHIVE_CORE := 4
const RT_SERVER_ROOM := 5
const RT_REASONING := 6
const RT_OFFICE_SITE := 7
const RT_DORMITORY := 8
const RT_EMPTY_ROOM := 9


## 返回可建设该区域的房间类型数组（RoomType 枚举值）
static func get_rooms_for_zone(zone: int) -> Array[int]:
	match zone:
		Type.RESEARCH:
			return [RT_LIBRARY, RT_LAB, RT_ARCHIVE, RT_CLASSROOM]
		Type.CREATION:
			return [RT_SERVER_ROOM, RT_REASONING]
		Type.OFFICE:
			return [RT_OFFICE_SITE]
		Type.LIVING:
			return [RT_DORMITORY]
		Type.MEDICAL, Type.ENTERTAINMENT, Type.RELIGION, Type.WONDER:
			return []  ## 待扩展
		_:
			return []


static func get_zone_name(zone: int) -> String:
	match zone:
		Type.NONE: return "无"
		Type.RESEARCH: return "研究区"
		Type.CREATION: return "造物区"
		Type.OFFICE: return "事务所区"
		Type.LIVING: return "生活区"
		Type.MEDICAL: return "医疗区"
		Type.ENTERTAINMENT: return "娱乐区"
		Type.RELIGION: return "宗教区"
		Type.WONDER: return "奇观区"
		_: return "未知"


static func get_category_for_zone(zone: int) -> String:
	match zone:
		Type.RESEARCH, Type.CREATION, Type.OFFICE:
			return CATEGORY_WORK
		Type.LIVING, Type.MEDICAL, Type.ENTERTAINMENT:
			return CATEGORY_LOGISTICS
		Type.RELIGION, Type.WONDER:
			return CATEGORY_MYSTERY
		_:
			return ""


## 建设消耗（info, permission 等），源自 game_values.json
static func get_construction_cost(zone: int) -> Dictionary:
	var gv: Node = _GameValuesRef.get_singleton()
	return gv.get_construction_cost(zone) if gv else {}


## 建设需占用的研究员数
static func get_construction_researcher_count(zone: int) -> int:
	var gv: Node = _GameValuesRef.get_singleton()
	return gv.get_construction_researcher_count(zone) if gv else 0


## 每单位耗时（小时）
static func get_construction_time_per_unit_hours(zone: int) -> float:
	var gv: Node = _GameValuesRef.get_singleton()
	return gv.get_construction_hours_per_unit(zone) if gv else 2.0

class_name GameMainBuiltRoomHelper
extends RefCounted

## 已建设房间持续产出 - 研究区消耗存量、造物区消耗意志
## 详见 docs/design/12-built-room-system.md

const ZoneTypeScript = preload("res://scripts/core/zone_type.gd")
const _GameValuesRef = preload("res://scripts/core/game_values_ref.gd")


static func is_research_zone_room(room: RoomInfo) -> bool:
	## 研究区/造物区可建设房间：清理完成时不一次性授予
	var rt: int = room.room_type
	return (rt == RoomInfo.RoomType.LIBRARY or rt == RoomInfo.RoomType.LAB or rt == RoomInfo.RoomType.ARCHIVE or rt == RoomInfo.RoomType.CLASSROOM
		or rt == RoomInfo.RoomType.SERVER_ROOM or rt == RoomInfo.RoomType.REASONING)


static func get_room_units(room: RoomInfo) -> int:
	var area: int = room.rect.size.x * room.rect.size.y
	return maxi(1, int(ceil(float(area) / 5.0)))


## 造物区 24 小时消耗量（意志）
static func get_creation_zone_24h_consumption(room: RoomInfo) -> int:
	if room.zone_type != ZoneTypeScript.Type.CREATION:
		return 0
	var gv: Node = _GameValuesRef.get_singleton()
	var consume_per_unit: int = gv.get_creation_consume_per_unit_per_hour(room.room_type) if gv else 5
	return get_room_units(room) * consume_per_unit * 24


## 造物区是否暂停研究：玩家意志不足 24h 消耗
static func is_creation_zone_paused(room: RoomInfo, ui: Node) -> bool:
	if room.zone_type != ZoneTypeScript.Type.CREATION:
		return false
	if room.room_type != RoomInfo.RoomType.SERVER_ROOM and room.room_type != RoomInfo.RoomType.REASONING:
		return false
	var need: int = get_creation_zone_24h_consumption(room)
	var pw: Variant = ui.get("will_amount")
	var have: int = int(pw) if pw != null else 0
	return have < need


static func process_production(game_main: Node2D, game_hours_delta: float) -> void:
	var rooms: Array = game_main.get("_rooms")
	var accumulator: float = game_main.get("_built_room_production_accumulator")
	accumulator += game_hours_delta
	var hours_to_process: int = int(accumulator)
	if hours_to_process <= 0:
		game_main.set("_built_room_production_accumulator", accumulator)
		return
	accumulator -= float(hours_to_process)
	game_main.set("_built_room_production_accumulator", accumulator)
	var ui: Node = game_main.get_node_or_null("UIMain")
	if not ui:
		return
	for _h in hours_to_process:
		for i in rooms.size():
			var room: RoomInfo = rooms[i]
			if room.zone_type == ZoneTypeScript.Type.RESEARCH:
				_produce_research_zone_hour(room, ui, game_main)
			elif room.zone_type == ZoneTypeScript.Type.CREATION:
				if not is_creation_zone_paused(room, ui):
					_produce_creation_zone_hour(room, ui, game_main)


static func _resource_name_to_type(name: String) -> int:
	match name:
		"cognition": return RoomInfo.ResourceType.COGNITION
		"computation": return RoomInfo.ResourceType.COMPUTATION
		"willpower": return RoomInfo.ResourceType.WILL
		"permission": return RoomInfo.ResourceType.PERMISSION
		_: return RoomInfo.ResourceType.NONE


static func _produce_research_zone_hour(room: RoomInfo, ui: Node, game_main: Node2D) -> void:
	var gv: Node = _GameValuesRef.get_singleton()
	if gv == null:
		return
	var units: int = get_room_units(room)
	var amt_per_unit: int = gv.get_research_output_per_unit_per_hour(room.room_type)
	if amt_per_unit <= 0:
		return
	var rt: int = _resource_name_to_type(gv.get_research_output_resource(room.room_type))
	if rt == RoomInfo.ResourceType.NONE:
		return
	var output_this_hour: int = units * amt_per_unit
	var reserve_idx: int = -1
	var reserve_amt: int = 0
	for j in room.resources.size():
		var r: Variant = room.resources[j]
		if r is Dictionary and int(r.get("resource_type", -1)) == rt:
			reserve_idx = j
			reserve_amt = int(r.get("resource_amount", 0))
			break
	if reserve_idx < 0 or reserve_amt <= 0:
		_deplete_research_room(room, game_main)
		return
	var actual_output: int = mini(output_this_hour, reserve_amt)
	_reserve_subtract(room, reserve_idx, actual_output)
	_add_factor_to_player(ui, rt, actual_output, game_main)
	if reserve_amt <= actual_output:
		_deplete_research_room(room, game_main)


static func _deplete_research_room(room: RoomInfo, game_main: Node2D) -> void:
	var n: int = room.get_construction_researcher_count(ZoneTypeScript.Type.RESEARCH)
	room.zone_type = 0
	room.room_type = RoomInfo.RoomType.EMPTY_ROOM
	room.resources.clear()
	var ui_node: Node = game_main.get_node_or_null("UIMain")
	if ui_node and ui_node.get("researchers_working_in_rooms") != null:
		ui_node.researchers_working_in_rooms = maxi(0, ui_node.researchers_working_in_rooms - n)


static func _reserve_subtract(room: RoomInfo, reserve_idx: int, amt: int) -> void:
	var r: Dictionary = room.resources[reserve_idx]
	var cur: int = int(r.get("resource_amount", 0))
	r["resource_amount"] = maxi(0, cur - amt)


static func _add_factor_to_player(ui: Node, resource_type: int, amt: int, game_main: Node2D) -> void:
	match resource_type:
		RoomInfo.ResourceType.COGNITION:
			ui.cognition_amount = ui.cognition_amount + amt
		RoomInfo.ResourceType.COMPUTATION:
			ui.computation_amount = ui.computation_amount + amt
		RoomInfo.ResourceType.WILL:
			ui.will_amount = ui.will_amount + amt
		RoomInfo.ResourceType.PERMISSION:
			ui.permission_amount = ui.permission_amount + amt
		_:
			return
	game_main.call("_sync_resources_to_topbar")


static func _produce_creation_zone_hour(room: RoomInfo, ui: Node, game_main: Node2D) -> void:
	var gv: Node = _GameValuesRef.get_singleton()
	if gv == null:
		return
	var units: int = get_room_units(room)
	var will_per_unit: int = gv.get_creation_consume_per_unit_per_hour(room.room_type)
	var will_needed: int = units * will_per_unit
	## 已由 process_production 在入口处检查 24h 暂停，此处仅做本小时兜底
	var pw: Variant = ui.get("will_amount")
	var player_will: int = int(pw) if pw != null else 0
	if player_will < will_needed:
		return
	var output_per_unit: int = gv.get_creation_produce_per_unit_per_hour(room.room_type)
	var output_amt: int = units * output_per_unit
	ui.will_amount = maxi(0, player_will - will_needed)
	match room.room_type:
		RoomInfo.RoomType.SERVER_ROOM:
			ui.permission_amount = ui.permission_amount + output_amt
		RoomInfo.RoomType.REASONING:
			ui.info_amount = ui.info_amount + output_amt
		_:
			return
	game_main.call("_sync_resources_to_topbar")

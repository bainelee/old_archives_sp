class_name GameMainFactorBreakdownHelper
extends RefCounted

## 因子消耗/产出细则计算，供 TopBar 因子悬停面板使用
## 与 game_main_shelter、game_main_built_room 协作

const ZoneTypeScript = preload("res://scripts/core/zone_type.gd")
const _GameValuesRef = preload("res://scripts/core/game_values_ref.gd")
const GameMainShelterHelper = preload("res://scripts/game/game_main_shelter.gd")
const GameMainBuiltRoomHelper = preload("res://scripts/game/game_main_built_room.gd")


static func get_breakdown(game_main: Node2D, factor_key: String) -> Dictionary:
	var ui: Node = game_main.get_node_or_null("UIMain")
	var gv: Node = _GameValuesRef.get_singleton()
	if not ui or not gv:
		return _empty_breakdown(ui, gv, factor_key)

	var stock: int = _get_stock(ui, factor_key)
	if stock < 0:
		return _empty_breakdown(ui, gv, factor_key)

	var cap: int = gv.get_factor_cap(factor_key) if gv else 999999
	var consume: Array = []
	var produce: Array = []
	var daily_consume: int = 0
	var daily_produce: int = 0

	match factor_key:
		"computation":
			consume = GameMainShelterHelper.get_shelter_consumption_breakdown(game_main, _get_shelter_level(game_main))
			for c in consume:
				daily_consume += floori(c.get("per_day", 0))
			produce = _get_research_production(game_main, "computation")
			for p in produce:
				daily_produce += floori(p.get("per_day", 0))
		"cognition":
			daily_consume = _get_personnel_cognition_daily(game_main, ui)
			if daily_consume > 0:
				consume.append({
					"zone_name": TranslationServer.translate("HOVER_FACTOR_PERSONNEL_ZONE"),
					"room_name": TranslationServer.translate("HOVER_FACTOR_PERSONNEL_ROOM"),
					"per_day": daily_consume
				})
			produce = _get_research_production(game_main, "cognition")
			for p in produce:
				daily_produce += floori(p.get("per_day", 0))
		"willpower":
			consume = _get_creation_consumption(game_main)
			for c in consume:
				daily_consume += floori(c.get("per_day", 0))
			produce = _get_research_production(game_main, "willpower")
			for p in produce:
				daily_produce += floori(p.get("per_day", 0))
		"permission":
			produce = _get_research_production(game_main, "permission")
			for p in _get_creation_production_permission(game_main):
				produce.append(p)
			for p in produce:
				daily_produce += floori(p.get("per_day", 0))
		_:
			return _empty_breakdown(ui, gv, factor_key)

	return {
		"stock": stock,
		"cap": cap,
		"daily_consume": daily_consume,
		"consume_details": consume,
		"daily_produce": daily_produce,
		"produce_details": produce,
	}


static func _get_stock(ui: Node, factor_key: String) -> int:
	if not ui:
		return -1
	match factor_key:
		"cognition": return ui.get_cognition() if ui.has_method("get_cognition") else floori(ui.get("cognition_amount") or 0)
		"computation": return ui.get_computation() if ui.has_method("get_computation") else floori(ui.get("computation_amount") or 0)
		"willpower": return ui.get_willpower() if ui.has_method("get_willpower") else floori(ui.get("will_amount") or 0)
		"permission": return ui.get_permission() if ui.has_method("get_permission") else floori(ui.get("permission_amount") or 0)
	return -1


static func _get_shelter_level(game_main: Node2D) -> int:
	return int(game_main.get("_shelter_level") or 1)


static func _get_personnel_cognition_daily(_game_main: Node2D, ui: Node) -> int:
	var researchers: int = floori(ui.get("researcher_count") or 0)
	var investigators: int = floori(ui.get("investigator_count") or 0)
	return (researchers + investigators) * 24


static func _empty_breakdown(ui: Node, gv: Node, factor_key: String) -> Dictionary:
	var stock: int = 0
	var cap: int = 999999
	if ui:
		stock = maxi(0, _get_stock(ui, factor_key))
	if gv:
		cap = gv.get_factor_cap(factor_key) if gv else 999999
	return {"stock": stock, "cap": cap, "daily_consume": 0, "consume_details": [], "daily_produce": 0, "produce_details": []}


static func _get_research_production(game_main: Node2D, resource_key: String) -> Array:
	var gv: Node = _GameValuesRef.get_singleton()
	if not gv:
		return []
	var rooms: Array = game_main.get("_rooms")
	var rt_map: Dictionary = {"cognition": 0, "computation": 1, "willpower": 2, "permission": 3}
	var room_type: int = rt_map.get(resource_key, -1)
	if room_type < 0:
		return []
	var res_type: int = _resource_key_to_type(resource_key)
	var result: Array = []
	for room in rooms:
		if not (room is RoomInfo):
			continue
		var r: RoomInfo = room as RoomInfo
		if r.room_type != room_type or r.zone_type != ZoneTypeScript.Type.RESEARCH:
			continue
		if not _research_room_has_reserve(r, res_type):
			continue
		var units: int = GameMainBuiltRoomHelper.get_room_units(r)
		var rate: int = gv.get_research_output_per_unit_per_hour(room_type)
		var per_day: int = units * rate * 24
		if per_day > 0:
			result.append({
				"zone_name": ZoneTypeScript.get_zone_name(ZoneTypeScript.Type.RESEARCH),
				"room_name": r.get_display_name(),
				"per_day": per_day,
			})
	return result


static func _research_room_has_reserve(room: RoomInfo, res_type: int) -> bool:
	for res in room.resources:
		if res is Dictionary and int(res.get("resource_type", -1)) == res_type:
			return int(res.get("resource_amount", 0)) > 0
	return false


static func _get_creation_consumption(game_main: Node2D) -> Array:
	var gv: Node = _GameValuesRef.get_singleton()
	var ui: Node = game_main.get_node_or_null("UIMain")
	if not gv or not ui:
		return []
	var rooms: Array = game_main.get("_rooms")
	var result: Array = []
	for room in rooms:
		if not (room is RoomInfo):
			continue
		var r: RoomInfo = room as RoomInfo
		if r.zone_type != ZoneTypeScript.Type.CREATION:
			continue
		if GameMainBuiltRoomHelper.is_creation_zone_paused(r, ui):
			continue
		var per_day: int = GameMainBuiltRoomHelper.get_creation_zone_24h_consumption(r)
		if per_day > 0:
			result.append({
				"zone_name": ZoneTypeScript.get_zone_name(ZoneTypeScript.Type.CREATION),
				"room_name": r.get_display_name(),
				"per_day": per_day,
			})
	return result


static func _get_creation_production_permission(game_main: Node2D) -> Array:
	var gv: Node = _GameValuesRef.get_singleton()
	var ui: Node = game_main.get_node_or_null("UIMain")
	if not gv or not ui:
		return []
	var rooms: Array = game_main.get("_rooms")
	var result: Array = []
	for room in rooms:
		if not (room is RoomInfo):
			continue
		var r: RoomInfo = room as RoomInfo
		if r.room_type != RoomInfo.RoomType.SERVER_ROOM or r.zone_type != ZoneTypeScript.Type.CREATION:
			continue
		if GameMainBuiltRoomHelper.is_creation_zone_paused(r, ui):
			continue
		var units: int = GameMainBuiltRoomHelper.get_room_units(r)
		var rate: int = gv.get_creation_produce_per_unit_per_hour(RoomInfo.RoomType.SERVER_ROOM)
		var per_day: int = units * rate * 24
		if per_day > 0:
			result.append({
				"zone_name": ZoneTypeScript.get_zone_name(ZoneTypeScript.Type.CREATION),
				"room_name": r.get_display_name(),
				"per_day": per_day,
			})
	return result


static func _resource_key_to_type(key: String) -> int:
	match key:
		"cognition": return RoomInfo.ResourceType.COGNITION
		"computation": return RoomInfo.ResourceType.COMPUTATION
		"willpower": return RoomInfo.ResourceType.WILL
		"permission": return RoomInfo.ResourceType.PERMISSION
	return RoomInfo.ResourceType.NONE

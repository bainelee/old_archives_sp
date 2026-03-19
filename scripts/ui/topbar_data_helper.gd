class_name TopbarDataHelper
extends RefCounted

## TopBar 数据逻辑共享模块
## 供 topbar_figma.gd 和 test_figma_page.gd 共用，消除重复代码

const FACTOR_CAPS := {
	"cognition": 6000,
	"computation": 60000,
	"willpower": 6000,
	"permission": 6000,
}

const BLOCK_TO_FACTOR := {
	"cognition": "cognition",
	"computing_power": "computation",
	"willpower": "willpower",
	"permission": "permission",
}


static func collect_resource_blocks(parent: Node) -> Array[ResourceBlock]:
	var result: Array[ResourceBlock] = []
	for node in parent.find_children("*", "ResourceBlock", true, false):
		result.append(node as ResourceBlock)
	return result


## ctx = { "gv": GameValues, "gm": GameMain, "ui": UIMain }
static func apply_resources(
	search_root: Node,
	factors: Dictionary,
	currency: Dictionary,
	personnel: Dictionary,
	ctx: Dictionary,
) -> void:
	var gv: Node = ctx.get("gv")
	var gm: Node = ctx.get("gm")
	var ui: Node = ctx.get("ui")
	for rb in collect_resource_blocks(search_root):
		var bid: String = rb.block_id
		if BLOCK_TO_FACTOR.has(bid):
			_apply_factor(rb, BLOCK_TO_FACTOR[bid], factors, gv)
		else:
			match bid:
				"info":
					rb.set_value(str(UIUtils.safe_int(currency.get("info", 0))))
				"truth":
					rb.set_value(str(UIUtils.safe_int(currency.get("truth", 0))))
				"investigator":
					_apply_investigator(rb, personnel, gm)
				"researcher":
					_apply_researcher(rb, personnel, ui)
				"shelter":
					_apply_shelter(rb, gm, gv)
				"housing":
					_apply_housing(rb, gm, gv, ui)


static func _apply_factor(rb: ResourceBlock, key: String, factors: Dictionary, gv: Node) -> void:
	var current: int = UIUtils.safe_int(factors.get(key, 0))
	var default_cap: int = FACTOR_CAPS.get(key, 6000)
	var cap: int = gv.get_factor_cap(key) if gv and gv.has_method("get_factor_cap") else default_cap
	rb.set_value(str(current))
	rb.set_progress(current, float(cap))


static func _apply_investigator(rb: ResourceBlock, personnel: Dictionary, gm: Node) -> void:
	var total: int = UIUtils.safe_int(personnel.get("investigator", 0))
	var deployed: int = 0
	if gm and gm.get("_deployed_investigators") != null:
		deployed = int(gm.get("_deployed_investigators"))
	rb.set_value(str(maxi(0, total - deployed)))


static func _apply_researcher(rb: ResourceBlock, personnel: Dictionary, ui: Node) -> void:
	var total: int = UIUtils.safe_int(personnel.get("researcher", 0))
	var eroded: int = UIUtils.safe_int(personnel.get("eroded", 0))
	var in_cleanup: int = int(ui.get("researchers_in_cleanup")) if ui and ui.get("researchers_in_cleanup") != null else 0
	var in_construction: int = int(ui.get("researchers_in_construction")) if ui and ui.get("researchers_in_construction") != null else 0
	var in_rooms: int = int(ui.get("researchers_working_in_rooms")) if ui and ui.get("researchers_working_in_rooms") != null else 0
	var idle: int = maxi(0, total - eroded - in_cleanup - in_construction - in_rooms)
	rb.set_researcher_progress(idle, eroded, total)
	rb.set_value("%d/%d" % [idle, total])


static func _apply_shelter(rb: ResourceBlock, gm: Node, gv: Node) -> void:
	var data: Dictionary = get_shelter_data(gm, gv)
	rb.set_shelter_progress(data.get("allocated", 0), data.get("cap", 30), data.get("shortage", 0))
	rb.set_value(str(data.get("level", 1)))


static func _apply_housing(rb: ResourceBlock, gm: Node, gv: Node, ui: Node) -> void:
	var data: Dictionary = get_housing_data(gm, gv, ui)
	rb.set_housing_progress(data.get("provided", 0), data.get("shortage", 0))
	rb.set_value("%d/%d" % [data.get("provided", 0), data.get("demand", 0)])


static func get_shelter_data(gm: Node, gv: Node) -> Dictionary:
	var result := {"level": 1, "allocated": 0, "cap": 30, "shortage": 0}
	if not gm:
		return result
	if gm.get("_shelter_level") != null:
		result.level = int(gm.get("_shelter_level"))
	if gm.get("_shelter_energy") != null:
		result.allocated = int(gm.get("_shelter_energy"))
	if gv and gv.has_method("get_shelter_cf_and_cap_for_level"):
		var level_data: Dictionary = gv.get_shelter_cf_and_cap_for_level(result.level)
		result.cap = level_data.get("energy_cap", 30)
	if gm.get("_shelter_demand") != null:
		var demand: int = int(gm.get("_shelter_demand"))
		result.shortage = maxi(0, demand - result.allocated)
	elif gm.get("_shelter_shortage") != null:
		result.shortage = int(gm.get("_shelter_shortage"))
	return result


static func get_housing_data(gm: Node, gv: Node, ui: Node) -> Dictionary:
	var result := {"provided": 0, "shortage": 0, "demand": 0}
	if not gm:
		return result
	result.provided = get_housing_provided(gm, gv)
	if ui and ui.has_method("get_resources"):
		var res: Dictionary = ui.get_resources()
		var personnel: Dictionary = res.get("personnel", {})
		result.demand = UIUtils.safe_int(personnel.get("researcher", 0)) + UIUtils.safe_int(personnel.get("investigator", 0))
	result.shortage = maxi(0, result.demand - result.provided)
	return result


static func get_housing_provided(gm: Node, gv: Node) -> int:
	if not gm or gm.get("_rooms") == null:
		return 0
	var rooms: Array = gm.get("_rooms")
	var total: int = 0
	for room in rooms:
		if not room:
			continue
		var zt: int = int(room.get("zone_type")) if room.get("zone_type") != null else 0
		if zt != ZoneType.Type.LIVING:
			continue
		var units: int = room.get_room_units() if room.has_method("get_room_units") else 0
		total += gv.get_housing_for_room_units(units) if gv and gv.has_method("get_housing_for_room_units") else (units * 2)
	return total

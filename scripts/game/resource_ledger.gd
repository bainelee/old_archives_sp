class_name ResourceLedger
extends RefCounted

const _GameValuesRef = preload("res://scripts/core/game_values_ref.gd")


static func consume_cost(ui: Node, cost: Dictionary) -> void:
	if not ui:
		return
	for key in cost:
		var amt: int = int(cost.get(key, 0))
		match key:
			"cognition":
				ui.cognition_amount = maxi(0, ui.cognition_amount - amt)
			"computation":
				var cf_before: int = ui.get_computation() if ui.has_method("get_computation") else int(ui.get("computation_amount") or 0)
				ui.computation_amount = maxi(0, cf_before - amt)
			"willpower":
				ui.will_amount = maxi(0, ui.will_amount - amt)
			"permission":
				ui.permission_amount = maxi(0, ui.permission_amount - amt)
			"info":
				ui.info_amount = maxi(0, ui.info_amount - amt)
			"truth":
				ui.truth_amount = maxi(0, ui.truth_amount - amt)


static func add_by_type(ui: Node, resource_type: int, amount: int) -> void:
	if not ui or amount <= 0:
		return
	var gv: Node = _GameValuesRef.get_singleton()
	var cap: int = 999999
	match resource_type:
		ArchivesRoomInfo.ResourceType.COGNITION:
			cap = gv.get_factor_cap("cognition") if gv else 999999
			ui.cognition_amount = mini(ui.cognition_amount + amount, cap)
		ArchivesRoomInfo.ResourceType.COMPUTATION:
			cap = gv.get_factor_cap("computation") if gv else 999999
			var cf_now: int = ui.get_computation() if ui.has_method("get_computation") else int(ui.get("computation_amount") or 0)
			ui.computation_amount = mini(cf_now + amount, cap)
		ArchivesRoomInfo.ResourceType.WILL:
			cap = gv.get_factor_cap("willpower") if gv else 999999
			ui.will_amount = mini(ui.will_amount + amount, cap)
		ArchivesRoomInfo.ResourceType.PERMISSION:
			cap = gv.get_factor_cap("permission") if gv else 999999
			ui.permission_amount = mini(ui.permission_amount + amount, cap)
		ArchivesRoomInfo.ResourceType.INFO:
			ui.info_amount = ui.info_amount + amount
		ArchivesRoomInfo.ResourceType.TRUTH:
			ui.truth_amount = ui.truth_amount + amount

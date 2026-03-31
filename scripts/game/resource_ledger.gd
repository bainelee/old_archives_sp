class_name ResourceLedger
extends RefCounted

const _GameValuesRef = preload("res://scripts/core/game_values_ref.gd")


static func can_afford_cost(ui: Node, cost: Dictionary) -> bool:
	if not ui:
		return false
	for key in cost:
		var amt: int = int(cost.get(key, 0))
		if amt <= 0:
			continue
		match key:
			"cognition":
				if ui.cognition_amount < amt:
					return false
			"computation":
				var cf: int = ui.get_computation() if ui.has_method("get_computation") else int(ui.get("computation_amount") or 0)
				if cf < amt:
					return false
			"willpower":
				if ui.will_amount < amt:
					return false
			"permission":
				if ui.permission_amount < amt:
					return false
			"info":
				if ui.info_amount < amt:
					return false
			"truth":
				if ui.truth_amount < amt:
					return false
			_:
				return false
	return true


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


## 与 game_values 产出键一致：cognition / computation / willpower / permission
static func resource_key_string_to_type(key: String) -> int:
	match key:
		"cognition":
			return ArchivesRoomInfo.ResourceType.COGNITION
		"computation":
			return ArchivesRoomInfo.ResourceType.COMPUTATION
		"willpower":
			return ArchivesRoomInfo.ResourceType.WILL
		"permission":
			return ArchivesRoomInfo.ResourceType.PERMISSION
		"info":
			return ArchivesRoomInfo.ResourceType.INFO
		"truth":
			return ArchivesRoomInfo.ResourceType.TRUTH
		_:
			return ArchivesRoomInfo.ResourceType.NONE


## 将房间 resources 条目按类型授予 UI（清理完成奖励等）
static func grant_room_resource_entries(ui: Node, room: ArchivesRoomInfo, game_main: Node2D = null) -> void:
	if not ui or room == null:
		return
	for r in room.resources:
		if not (r is Dictionary):
			continue
		var rt: int = int(r.get("resource_type", ArchivesRoomInfo.ResourceType.NONE))
		var amt: int = int(r.get("resource_amount", 0))
		if rt == ArchivesRoomInfo.ResourceType.NONE or amt <= 0:
			continue
		add_by_type(ui, rt, amt)
	if game_main and game_main.has_method("_sync_resources_to_topbar"):
		game_main.call("_sync_resources_to_topbar")


## 探索调查点等：键名为 cognition / computation / willpower / permission / info / truth
static func grant_string_dict(ui: Node, reward: Dictionary, game_main: Node2D = null) -> void:
	if not ui:
		return
	for key in reward:
		var amt: int = int(reward.get(key, 0))
		if amt <= 0:
			continue
		var rt: int = resource_key_string_to_type(str(key))
		if rt == ArchivesRoomInfo.ResourceType.NONE:
			continue
		add_by_type(ui, rt, amt)
	if game_main and game_main.has_method("_sync_resources_to_topbar"):
		game_main.call("_sync_resources_to_topbar")

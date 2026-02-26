class_name GameMainConstructionHelper
extends RefCounted

## 建设模式逻辑 - 选择区域、选择房间、确认、进度、消耗
## 详见 docs/design/11-zone-construction.md

const CONSTRUCTION_NONE := 0
const CONSTRUCTION_SELECTING_ZONE := 1
const CONSTRUCTION_SELECTING_TARGET := 2
const CONSTRUCTION_CONFIRMING := 3


static func on_build_button_pressed(game_main: Node2D) -> void:
	var cleanup_mode: int = game_main.get("_cleanup_mode")
	if cleanup_mode != 0:  # CleanupMode.NONE
		return
	var construction_mode: int = game_main.get("_construction_mode")
	if construction_mode == CONSTRUCTION_NONE:
		enter_selecting_zone_mode(game_main)
	else:
		exit_mode(game_main)


static func on_zone_selected(game_main: Node2D, zone_type: int) -> void:
	if zone_type == 0:
		game_main.set("_construction_selected_zone", 0)
		game_main.set("_construction_mode", CONSTRUCTION_SELECTING_ZONE)
	else:
		game_main.set("_construction_selected_zone", zone_type)
		game_main.set("_construction_mode", CONSTRUCTION_SELECTING_TARGET)
	game_main.queue_redraw()


static func get_construction_researchers_occupied(game_main: Node2D) -> int:
	var construction_rooms: Dictionary = game_main.get("_construction_rooms_in_progress")
	var rooms: Array = game_main.get("_rooms")
	var total: int = 0
	for room_idx in construction_rooms:
		var data: Dictionary = construction_rooms[room_idx]
		var zt: int = int(data.get("zone_type", 0))
		if room_idx >= 0 and room_idx < rooms.size():
			total += rooms[room_idx].get_construction_researcher_count(zt)
	return total


static func is_room_constructing(game_main: Node2D, room_index: int) -> bool:
	return game_main.get("_construction_rooms_in_progress").has(room_index)


static func can_afford_construction(room: RoomInfo, zone_type: int, resources: Dictionary, game_main: Node2D) -> bool:
	var cost: Dictionary = room.get_construction_cost(zone_type)
	for key in cost:
		var have: int = int(resources.get(key, 0))
		if have < int(cost.get(key, 0)):
			return false
	var researcher_available: int = maxi(0, int(resources.get("researcher", 0)) - int(resources.get("eroded", 0)) - GameMainCleanupHelper.get_cleanup_researchers_occupied(game_main) - get_construction_researchers_occupied(game_main))
	if researcher_available < room.get_construction_researcher_count(zone_type):
		return false
	return true


static func consume_construction_cost(game_main: Node2D, room: RoomInfo, zone_type: int) -> void:
	var cost: Dictionary = room.get_construction_cost(zone_type)
	var ui: Node = game_main.get_node_or_null("UIMain")
	if not ui:
		return
	for key in cost:
		var amt: int = int(cost.get(key, 0))
		if key == "cognition":
			ui.cognition_amount = maxi(0, ui.cognition_amount - amt)
		elif key == "computation":
			ui.computation_amount = maxi(0, ui.computation_amount - amt)
		elif key == "willpower":
			ui.will_amount = maxi(0, ui.will_amount - amt)
		elif key == "permission":
			ui.permission_amount = maxi(0, ui.permission_amount - amt)
		elif key == "info":
			ui.info_amount = maxi(0, ui.info_amount - amt)
		elif key == "truth":
			ui.truth_amount = maxi(0, ui.truth_amount - amt)
	game_main.call("_sync_resources_to_topbar")


static func is_click_over_construction_allowed_ui(game_main: Node2D, mouse_pos: Vector2) -> bool:
	var build_btn: Control = game_main.get_node_or_null("UIMain/BottomRightBar/BtnBuild") as Control
	if build_btn and build_btn.get_global_rect().has_point(mouse_pos):
		return true
	var construction_overlay: Node = game_main.call("_get_construction_overlay")
	if construction_overlay:
		var category_tags: Control = construction_overlay.get_node_or_null("ConstructionCategoryTags") as Control
		if category_tags and category_tags.visible and category_tags.get_global_rect().has_point(mouse_pos):
			return true
		var zone_buttons: Control = construction_overlay.get_node_or_null("ConstructionZoneButtons") as Control
		if zone_buttons and zone_buttons.visible and zone_buttons.get_global_rect().has_point(mouse_pos):
			return true
		var confirm_ctrl: Control = construction_overlay.get_node_or_null("ConfirmContainer") as Control
		if confirm_ctrl and confirm_ctrl.visible and confirm_ctrl.get_global_rect().has_point(mouse_pos):
			return true
	return false


static func process_overlay(game_main: Node2D, construction_overlay: Node, delta: float) -> void:
	var construction_mode: int = game_main.get("_construction_mode")
	var construction_selected_zone: int = game_main.get("_construction_selected_zone")
	var rooms: Array = game_main.get("_rooms")
	var hovered_room_index: int = game_main.get("_hovered_room_index")
	var construction_confirm_room_index: int = game_main.get("_construction_confirm_room_index")
	var construction_rooms: Dictionary = game_main.get("_construction_rooms_in_progress")
	var room_center_to_screen: Callable = Callable(game_main, "_room_center_to_screen")
	var get_player_resources: Callable = Callable(game_main, "_get_player_resources")
	var get_construction_overlay: Callable = Callable(game_main, "_get_construction_overlay")

	# 悬停与确认位置
	if construction_mode == CONSTRUCTION_SELECTING_TARGET or construction_mode == CONSTRUCTION_CONFIRMING:
		if construction_selected_zone != 0 and hovered_room_index >= 0 and hovered_room_index < rooms.size():
			var room: RoomInfo = rooms[hovered_room_index]
			if room.can_build_zone(construction_selected_zone) and not is_room_constructing(game_main, hovered_room_index):
				var resources: Dictionary = get_player_resources.call()
				var can_afford: bool = can_afford_construction(room, construction_selected_zone, resources, game_main)
				var researchers_available: int = maxi(0, int(resources.get("researcher", 0)) - int(resources.get("eroded", 0)) - GameMainCleanupHelper.get_cleanup_researchers_occupied(game_main) - get_construction_researchers_occupied(game_main))
				if construction_overlay and construction_overlay.has_method("show_hover_for_room"):
					construction_overlay.show_hover_for_room(room, construction_selected_zone, resources, can_afford, room.get_construction_researcher_count(construction_selected_zone), researchers_available)
			else:
				if construction_overlay:
					construction_overlay.hide_hover()
		else:
			if construction_overlay:
				construction_overlay.hide_hover()
		if construction_overlay and construction_overlay.has_method("update_hover_position"):
			var mouse_pos: Vector2 = game_main.get_viewport().get_mouse_position()
			var vp_size: Vector2 = game_main.get_viewport().get_visible_rect().size
			construction_overlay.update_hover_position(mouse_pos, vp_size)
		if construction_mode == CONSTRUCTION_CONFIRMING and construction_confirm_room_index >= 0 and construction_overlay and construction_overlay.has_method("update_confirm_position"):
			construction_overlay.update_confirm_position(room_center_to_screen.call(construction_confirm_room_index))

	# 多房间建设进度 tick
	var construction_to_remove: Array[int] = []
	for room_idx in construction_rooms:
		var data: Dictionary = construction_rooms[room_idx]
		if GameTime and GameTime.is_flowing:
			var game_hours_delta: float = (delta / GameTime.REAL_SECONDS_PER_GAME_HOUR) * GameTime.speed_multiplier
			data["elapsed"] = data.get("elapsed", 0.0) + game_hours_delta
		var total: float = data.get("total", 1.0)
		var elapsed: float = data.get("elapsed", 0.0)
		var ratio: float = clampf(elapsed / total, 0.0, 1.0)
		if ratio >= 1.0:
			var zt: int = int(data.get("zone_type", 0))
			rooms[room_idx].zone_type = zt
			var n: int = rooms[room_idx].get_construction_researcher_count(zt)
			construction_to_remove.append(room_idx)
			var ui_node: Node = game_main.get_node_or_null("UIMain")
			if ui_node and ui_node.get("researchers_in_construction") != null and ui_node.get("researchers_working_in_rooms") != null:
				ui_node.researchers_in_construction = maxi(0, ui_node.researchers_in_construction - n)
				ui_node.researchers_working_in_rooms = ui_node.researchers_working_in_rooms + n
	for idx in construction_to_remove:
		construction_rooms.erase(idx)

	var construction_progress_data: Array = []
	for room_idx in construction_rooms:
		var data: Dictionary = construction_rooms[room_idx]
		var total: float = data.get("total", 1.0)
		var ratio: float = clampf(data.get("elapsed", 0.0) / total, 0.0, 1.0)
		construction_progress_data.append({"room_index": room_idx, "position": room_center_to_screen.call(room_idx), "ratio": ratio})
	if construction_overlay and construction_overlay.has_method("update_progress_rooms"):
		construction_overlay.update_progress_rooms(construction_progress_data)
	if construction_rooms.is_empty():
		get_construction_overlay.call().hide_progress()


static func enter_selecting_zone_mode(game_main: Node2D) -> void:
	game_main.set("_construction_mode", CONSTRUCTION_SELECTING_ZONE)
	game_main.set("_construction_selected_zone", 0)
	game_main.set("_construction_confirm_room_index", -1)
	if GameTime:
		game_main.set("_time_was_flowing_before_construction", GameTime.is_flowing)
		GameTime.is_flowing = false
	var overlay: Node = game_main.call("_get_construction_overlay")
	if overlay and overlay.has_method("show_construction_selecting_ui"):
		overlay.show_construction_selecting_ui()
	var ui: Node = game_main.get_node_or_null("UIMain")
	if ui and ui.has_method("set_construction_blocking"):
		ui.set_construction_blocking(true)
	game_main.queue_redraw()


static func exit_mode(game_main: Node2D) -> void:
	game_main.set("_construction_mode", CONSTRUCTION_NONE)
	game_main.set("_construction_selected_zone", 0)
	game_main.set("_construction_confirm_room_index", -1)
	var overlay: Node = game_main.call("_get_construction_overlay")
	if overlay and overlay.has_method("hide_construction_selecting_ui"):
		overlay.hide_construction_selecting_ui()
	overlay.hide_hover()
	overlay.hide_confirm()
	var ui: Node = game_main.get_node_or_null("UIMain")
	if ui and ui.has_method("set_construction_blocking"):
		ui.set_construction_blocking(false)
	if GameTime and game_main.get("_time_was_flowing_before_construction"):
		GameTime.is_flowing = true
	game_main.queue_redraw()


static func on_confirm_pressed(game_main: Node2D) -> void:
	var construction_mode: int = game_main.get("_construction_mode")
	var construction_confirm_room_index: int = game_main.get("_construction_confirm_room_index")
	var construction_selected_zone: int = game_main.get("_construction_selected_zone")
	var rooms: Array = game_main.get("_rooms")
	if construction_mode != CONSTRUCTION_CONFIRMING or construction_confirm_room_index < 0:
		return
	var room: RoomInfo = rooms[construction_confirm_room_index]
	var zone_type: int = construction_selected_zone
	var resources: Dictionary = game_main.call("_get_player_resources")
	if not can_afford_construction(room, zone_type, resources, game_main):
		return
	consume_construction_cost(game_main, room, zone_type)
	var n_researchers: int = room.get_construction_researcher_count(zone_type)
	var construction_rooms: Dictionary = game_main.get("_construction_rooms_in_progress")
	construction_rooms[construction_confirm_room_index] = {
		"elapsed": 0.0,
		"total": room.get_construction_time_hours(zone_type),
		"zone_type": zone_type
	}
	var ui_node: Node = game_main.get_node_or_null("UIMain")
	if ui_node and ui_node.get("researchers_in_construction") != null:
		ui_node.researchers_in_construction = ui_node.researchers_in_construction + n_researchers
	game_main.set("_construction_confirm_room_index", -1)
	exit_mode(game_main)


static func handle_left_click(game_main: Node2D, rid: int) -> void:
	var rooms: Array = game_main.get("_rooms")
	var construction_selected_zone: int = game_main.get("_construction_selected_zone")
	var room_center_to_screen: Callable = Callable(game_main, "_room_center_to_screen")
	var get_player_resources: Callable = Callable(game_main, "_get_player_resources")
	var get_construction_overlay: Callable = Callable(game_main, "_get_construction_overlay")
	var focus_camera: Callable = Callable(game_main, "_focus_camera_on_room")

	if rid >= 0:
		var room: RoomInfo = rooms[rid]
		if room.can_build_zone(construction_selected_zone) and not is_room_constructing(game_main, rid):
			var resources: Dictionary = get_player_resources.call()
			var can_afford: bool = can_afford_construction(room, construction_selected_zone, resources, game_main)
			if can_afford:
				game_main.set("_construction_mode", CONSTRUCTION_CONFIRMING)
				game_main.set("_construction_confirm_room_index", rid)
				focus_camera.call(rid)
				get_construction_overlay.call().show_confirm_at(room_center_to_screen.call(rid))
			else:
				game_main.set("_construction_confirm_room_index", -1)
				get_construction_overlay.call().hide_confirm()
		else:
			game_main.set("_construction_confirm_room_index", -1)
			get_construction_overlay.call().hide_confirm()
	else:
		game_main.set("_construction_confirm_room_index", -1)
		get_construction_overlay.call().hide_confirm()

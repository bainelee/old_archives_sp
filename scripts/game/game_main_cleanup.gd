class_name GameMainCleanupHelper
extends RefCounted

## 清理房间模式逻辑 - 选择、确认、进度、消耗
## 详见 docs/design/2-gameplay/04-room-cleanup-system.md

const CLEANUP_NONE := 0
const CLEANUP_SELECTING := 1
const CLEANUP_CONFIRMING := 2

const DEBUG_CLEANUP_INPUT := false


static func on_button_pressed(game_main: Node2D) -> void:
	if DEBUG_CLEANUP_INPUT:
		print("[Cleanup] _on_cleanup_button_pressed 被调用, mode=%s" % game_main.get("_cleanup_mode"))
	var cleanup_mode: int = game_main.get("_cleanup_mode")
	if cleanup_mode == CLEANUP_NONE:
		enter_selecting_mode(game_main)
	elif cleanup_mode == CLEANUP_SELECTING:
		exit_mode(game_main)
	elif cleanup_mode == CLEANUP_CONFIRMING:
		game_main.set("_cleanup_confirm_room_index", -1)
		game_main.set("_cleanup_mode", CLEANUP_SELECTING)
		game_main.call("_get_cleanup_overlay").hide_confirm()
		game_main.queue_redraw()


static func get_cleanup_researchers_occupied(game_main: Node2D) -> int:
	var cleanup_rooms: Dictionary = game_main.get("_cleanup_rooms_in_progress")
	var rooms: Array = game_main.get("_rooms")
	var total: int = 0
	for room_idx in cleanup_rooms:
		if room_idx >= 0 and room_idx < rooms.size():
			total += rooms[room_idx].get_cleanup_researcher_count()
	return total


static func is_room_cleaning(game_main: Node2D, room_index: int) -> bool:
	return game_main.get("_cleanup_rooms_in_progress").has(room_index)


static func can_afford_cleanup(room: RoomInfo, resources: Dictionary, game_main: Node2D) -> bool:
	var cost: Dictionary = room.get_cleanup_cost()
	for key in cost:
		var have: int = int(resources.get(key, 0))
		if have < int(cost.get(key, 0)):
			return false
	var researcher_available: int = maxi(0, int(resources.get("researcher", 0)) - int(resources.get("eroded", 0)) - get_cleanup_researchers_occupied(game_main))
	if researcher_available < room.get_cleanup_researcher_count():
		return false
	return true


static func consume_cleanup_cost(game_main: Node2D, room: RoomInfo) -> void:
	var cost: Dictionary = room.get_cleanup_cost()
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


static func is_click_over_cleanup_allowed_ui(game_main: Node2D, mouse_pos: Vector2) -> bool:
	var btn: Control = game_main.get_node_or_null("UIMain/BottomRightBar/BtnCleanup") as Control
	if btn and btn.get_global_rect().has_point(mouse_pos):
		return true
	var cheat_panel: Control = game_main.get_node_or_null("CheatShelterPanel/Panel") as Control
	if cheat_panel and cheat_panel.get_global_rect().has_point(mouse_pos):
		return true
	var overlay: Node = game_main.call("_get_cleanup_overlay")
	if overlay:
		var confirm_ctrl: Control = overlay.get_node_or_null("ConfirmContainer") as Control
		if confirm_ctrl and confirm_ctrl.visible and confirm_ctrl.get_global_rect().has_point(mouse_pos):
			return true
	return false


static func process_overlay(game_main: Node2D, overlay: Node, delta: float) -> void:
	var cleanup_mode: int = game_main.get("_cleanup_mode")
	var rooms: Array = game_main.get("_rooms")
	var hovered_room_index: int = game_main.get("_hovered_room_index")
	var cleanup_confirm_room_index: int = game_main.get("_cleanup_confirm_room_index")
	var cleanup_rooms: Dictionary = game_main.get("_cleanup_rooms_in_progress")
	var room_center_to_screen: Callable = Callable(game_main, "_room_center_to_screen")
	var get_player_resources: Callable = Callable(game_main, "_get_player_resources")
	var grant_room_resources: Callable = Callable(game_main, "_grant_room_resources_to_player")
	var get_cleanup_overlay: Callable = Callable(game_main, "_get_cleanup_overlay")

	# 悬停与确认位置更新
	if cleanup_mode == CLEANUP_SELECTING or cleanup_mode == CLEANUP_CONFIRMING:
		if hovered_room_index >= 0 and hovered_room_index < rooms.size():
			var room: RoomInfo = rooms[hovered_room_index]
			if room.clean_status == RoomInfo.CleanStatus.UNCLEANED and not is_room_cleaning(game_main, hovered_room_index):
				var resources: Dictionary = get_player_resources.call()
				var can_afford: bool = can_afford_cleanup(room, resources, game_main)
				var researchers_available: int = maxi(0, int(resources.get("researcher", 0)) - int(resources.get("eroded", 0)) - get_cleanup_researchers_occupied(game_main))
				if overlay.has_method("show_hover_for_room"):
					overlay.show_hover_for_room(room, resources, can_afford, room.get_cleanup_researcher_count(), researchers_available)
			else:
				overlay.hide_hover()
		else:
			overlay.hide_hover()
		if overlay.has_method("update_hover_position"):
			var mouse_pos: Vector2 = game_main.get_viewport().get_mouse_position()
			var vp_size: Vector2 = game_main.get_viewport().get_visible_rect().size
			overlay.update_hover_position(mouse_pos, vp_size)
		if cleanup_mode == CLEANUP_CONFIRMING and cleanup_confirm_room_index >= 0 and overlay.has_method("update_confirm_position"):
			overlay.update_confirm_position(room_center_to_screen.call(cleanup_confirm_room_index))

	# 多房间清理进度 tick
	var to_remove: Array[int] = []
	for room_idx in cleanup_rooms:
		var data: Dictionary = cleanup_rooms[room_idx]
		if GameTime and GameTime.is_flowing:
			var game_hours_delta: float = (delta / GameTime.REAL_SECONDS_PER_GAME_HOUR) * GameTime.speed_multiplier
			data["elapsed"] = data.get("elapsed", 0.0) + game_hours_delta
		var total: float = data.get("total", 1.0)
		var elapsed: float = data.get("elapsed", 0.0)
		var ratio: float = clampf(elapsed / total, 0.0, 1.0)
		if ratio >= 1.0:
			rooms[room_idx].clean_status = RoomInfo.CleanStatus.CLEANED
			if not GameMainBuiltRoomHelper.is_research_zone_room(rooms[room_idx]):
				grant_room_resources.call(rooms[room_idx])
			to_remove.append(room_idx)
	for idx in to_remove:
		cleanup_rooms.erase(idx)

	var progress_data: Array = []
	for room_idx in cleanup_rooms:
		var data: Dictionary = cleanup_rooms[room_idx]
		var total: float = data.get("total", 1.0)
		var ratio: float = clampf(data.get("elapsed", 0.0) / total, 0.0, 1.0)
		progress_data.append({"room_index": room_idx, "position": room_center_to_screen.call(room_idx), "ratio": ratio})
	if overlay.has_method("update_progress_rooms"):
		overlay.update_progress_rooms(progress_data)
	if cleanup_rooms.is_empty():
		get_cleanup_overlay.call().hide_progress()


static func enter_selecting_mode(game_main: Node2D) -> void:
	game_main.set("_time_was_flowing_before_cleanup", GameTime.is_flowing if GameTime else false)
	if GameTime and GameTime.is_flowing:
		GameTime.is_flowing = false
	game_main.set("_cleanup_mode", CLEANUP_SELECTING)
	game_main.set("_cleanup_confirm_room_index", -1)
	game_main.call("_clear_room_selection")
	var overlay: Node = game_main.call("_get_cleanup_overlay")
	overlay.hide_hover()
	overlay.hide_confirm()
	if overlay.has_method("show_cleanup_selecting_ui"):
		overlay.show_cleanup_selecting_ui()
	var ui: Node = game_main.get_node_or_null("UIMain")
	if ui and ui.has_method("set_cleanup_blocking"):
		ui.set_cleanup_blocking(true)
	game_main.queue_redraw()


static func exit_mode(game_main: Node2D) -> void:
	game_main.set("_cleanup_mode", CLEANUP_NONE)
	game_main.set("_cleanup_confirm_room_index", -1)
	var cleanup_rooms: Dictionary = game_main.get("_cleanup_rooms_in_progress")
	if cleanup_rooms.is_empty():
		game_main.call("_get_cleanup_overlay").hide_progress()
	var overlay: Node = game_main.call("_get_cleanup_overlay")
	if overlay.has_method("hide_cleanup_selecting_ui"):
		overlay.hide_cleanup_selecting_ui()
	var ui: Node = game_main.get_node_or_null("UIMain")
	if ui and ui.has_method("set_cleanup_blocking"):
		ui.set_cleanup_blocking(false)
	if GameTime and game_main.get("_time_was_flowing_before_cleanup"):
		GameTime.is_flowing = true
	overlay.hide_hover()
	overlay.hide_confirm()
	game_main.queue_redraw()


static func on_confirm_pressed(game_main: Node2D) -> void:
	if DEBUG_CLEANUP_INPUT:
		print("[Cleanup] _on_cleanup_confirm_pressed 被调用")
	var cleanup_mode: int = game_main.get("_cleanup_mode")
	var cleanup_confirm_room_index: int = game_main.get("_cleanup_confirm_room_index")
	var rooms: Array = game_main.get("_rooms")
	if cleanup_mode != CLEANUP_CONFIRMING or cleanup_confirm_room_index < 0:
		return
	var room: RoomInfo = rooms[cleanup_confirm_room_index]
	var resources: Dictionary = game_main.call("_get_player_resources")
	if not can_afford_cleanup(room, resources, game_main):
		return
	consume_cleanup_cost(game_main, room)
	var cleanup_rooms: Dictionary = game_main.get("_cleanup_rooms_in_progress")
	cleanup_rooms[cleanup_confirm_room_index] = {
		"elapsed": 0.0,
		"total": room.get_cleanup_time_hours()
	}
	game_main.set("_cleanup_confirm_room_index", -1)
	exit_mode(game_main)


static func handle_left_click(game_main: Node2D, rid: int) -> void:
	var rooms: Array = game_main.get("_rooms")
	var room_center_to_screen: Callable = Callable(game_main, "_room_center_to_screen")
	var get_player_resources: Callable = Callable(game_main, "_get_player_resources")
	var get_cleanup_overlay: Callable = Callable(game_main, "_get_cleanup_overlay")
	var focus_camera: Callable = Callable(game_main, "_focus_camera_on_room")

	if rid >= 0:
		var room: RoomInfo = rooms[rid]
		var is_uncleaned: bool = room.clean_status == RoomInfo.CleanStatus.UNCLEANED
		var not_cleaning: bool = not is_room_cleaning(game_main, rid)
		if DEBUG_CLEANUP_INPUT:
			print("[Cleanup] rid=%s clean_status=%s is_uncleaned=%s not_cleaning=%s" % [rid, room.clean_status, is_uncleaned, not_cleaning])
		if is_uncleaned and not_cleaning:
			var resources: Dictionary = get_player_resources.call()
			var can_afford: bool = can_afford_cleanup(room, resources, game_main)
			if DEBUG_CLEANUP_INPUT:
				print("[Cleanup] can_afford=%s cost=%s" % [can_afford, room.get_cleanup_cost()])
			if can_afford:
				game_main.set("_cleanup_mode", CLEANUP_CONFIRMING)
				game_main.set("_cleanup_confirm_room_index", rid)
				focus_camera.call(rid)
				var screen_pos: Vector2 = room_center_to_screen.call(rid)
				if DEBUG_CLEANUP_INPUT:
					print("[Cleanup] show_confirm_at screen_pos=%s" % screen_pos)
				get_cleanup_overlay.call().show_confirm_at(screen_pos)
			else:
				game_main.set("_cleanup_confirm_room_index", -1)
				get_cleanup_overlay.call().hide_confirm()
		else:
			game_main.set("_cleanup_confirm_room_index", -1)
			get_cleanup_overlay.call().hide_confirm()
	else:
		game_main.set("_cleanup_confirm_room_index", -1)
		get_cleanup_overlay.call().hide_confirm()

class_name GameMainCleanupHelper
extends RefCounted

const _GameModeEnums := preload("res://scripts/game/game_mode_enums.gd")

## 清理房间模式逻辑 - 选择、确认、进度、消耗

## 调试：暂停时研究员 emoji/移动 问题，输出 [ResearcherPause] 日志
const RESEARCHER_PAUSE_DEBUG := false
## 详见 docs/design/2-gameplay/04-room-cleanup-system.md
## 解锁：仅 unlocked 房间可选中；清理完成时解锁邻接房间（04-room-unlock-adjacency）

static func on_button_pressed(game_main: Node2D) -> void:
	## 清理/建设模式互斥，避免两套模式状态同时进入
	if game_main.get_construction_mode_int() != _GameModeEnums.ConstructionMode.NONE:
		return
	var cleanup_mode: int = game_main.get_cleanup_mode_int()
	if cleanup_mode == _GameModeEnums.CleanupMode.NONE:
		enter_selecting_mode(game_main)
	elif cleanup_mode == _GameModeEnums.CleanupMode.SELECTING:
		exit_mode(game_main)
	elif cleanup_mode == _GameModeEnums.CleanupMode.CONFIRMING:
		game_main.set("_cleanup_confirm_room_index", -1)
		game_main.set("_cleanup_mode", _GameModeEnums.CleanupMode.SELECTING)
		game_main.call("_get_cleanup_overlay").hide_confirm()
		game_main.queue_redraw()


static func get_cleanup_researchers_occupied(game_main: Node2D) -> int:
	var cleanup_rooms: Dictionary = game_main.get("_cleanup_rooms_in_progress")
	var rooms: Array = game_main.get_game_rooms()
	var total: int = 0
	for room_idx in cleanup_rooms:
		if room_idx >= 0 and room_idx < rooms.size():
			total += rooms[room_idx].get_cleanup_researcher_count()
	return total


static func is_room_cleaning(game_main: Node2D, room_index: int) -> bool:
	return game_main.get("_cleanup_rooms_in_progress").has(room_index)


static func can_afford_cleanup(room: ArchivesRoomInfo, resources: Dictionary, game_main: Node2D) -> bool:
	var cost: Dictionary = room.get_cleanup_cost()
	for key in cost:
		var have: int = int(resources.get(key, 0))
		if have < int(cost.get(key, 0)):
			return false
	var researcher_available: int = maxi(0, int(resources.get("researcher", 0)) - int(resources.get("eroded", 0)) - get_cleanup_researchers_occupied(game_main))
	if researcher_available < room.get_cleanup_researcher_count():
		return false
	return true


static func consume_cleanup_cost(game_main: Node2D, room: ArchivesRoomInfo) -> void:
	var cost: Dictionary = room.get_cleanup_cost()
	var ui: Node = game_main.get_node_or_null("InteractiveUiRoot/UIMain")
	if not ui:
		return
	ResourceLedger.consume_cost(ui, cost)
	game_main.call("_sync_resources_to_topbar")


static func is_click_over_cleanup_allowed_ui(game_main: Node2D, mouse_pos: Vector2) -> bool:
	var btn: Control = game_main.get_node_or_null("InteractiveUiRoot/UIMain/BottomRightBar/Margin/Content/BtnCleanup") as Control
	if btn and btn.get_global_rect().has_point(mouse_pos):
		return true
	var debug_panel: Control = game_main.get_node_or_null("InteractiveUiRoot/UIMain/DebugInfoPanel") as Control
	if debug_panel and debug_panel.visible and debug_panel.get_global_rect().has_point(mouse_pos):
		return true
	var overlay: Node = game_main.call("_get_cleanup_overlay")
	if overlay:
		var confirm_ctrl: Control = overlay.get_node_or_null("ConfirmContainer") as Control
		if confirm_ctrl and confirm_ctrl.visible and confirm_ctrl.get_global_rect().has_point(mouse_pos):
			return true
	return false


static func process_overlay(game_main: Node2D, overlay: Node, delta: float) -> void:
	var cleanup_mode: int = game_main.get_cleanup_mode_int()
	var rooms: Array = game_main.get_game_rooms()
	var hovered_room_index: int = game_main.get("_hovered_room_index")
	var cleanup_confirm_room_index: int = game_main.get("_cleanup_confirm_room_index")
	var cleanup_rooms: Dictionary = game_main.get("_cleanup_rooms_in_progress")
	var room_center_to_screen: Callable = Callable(game_main, "_room_center_to_screen")
	var get_player_resources: Callable = Callable(game_main, "_get_player_resources")
	var grant_room_resources: Callable = Callable(game_main, "_grant_room_resources_to_player")
	var get_cleanup_overlay: Callable = Callable(game_main, "_get_cleanup_overlay")

	# 悬停与确认位置更新
	if cleanup_mode == _GameModeEnums.CleanupMode.SELECTING or cleanup_mode == _GameModeEnums.CleanupMode.CONFIRMING:
		if hovered_room_index >= 0 and hovered_room_index < rooms.size():
			var room: ArchivesRoomInfo = rooms[hovered_room_index]
			if room.unlocked and room.clean_status == ArchivesRoomInfo.CleanStatus.UNCLEANED and not is_room_cleaning(game_main, hovered_room_index):
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
		if cleanup_mode == _GameModeEnums.CleanupMode.CONFIRMING and cleanup_confirm_room_index >= 0 and overlay.has_method("update_confirm_position"):
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
			var cleaned_room: ArchivesRoomInfo = rooms[room_idx]
			cleaned_room.clean_status = ArchivesRoomInfo.CleanStatus.CLEANED
			unlock_adjacent_rooms(game_main, cleaned_room)
			if not GameMainBuiltRoomHelper.is_research_zone_room(cleaned_room):
				grant_room_resources.call(cleaned_room)
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
	var was_flowing: bool = GameTime.is_flowing if GameTime else false
	game_main.set("_time_was_flowing_before_cleanup", was_flowing)
	var will_set: bool = GameTime != null and GameTime.is_flowing
	if RESEARCHER_PAUSE_DEBUG:
		print("[ResearcherPause] enter_cleanup is_flowing_before=%s will_set=%s" % [was_flowing, will_set])
	if GameTime and GameTime.is_flowing:
		GameTime.is_flowing = false
	## 强制同步所有研究员的暂停状态，弥补 flowing_changed 可能未到达部分节点（如 reparent 后连接顺序变化）的情况
	for node in game_main.get_tree().get_nodes_in_group("researcher"):
		if node.has_method("force_sync_flowing_state"):
			node.call("force_sync_flowing_state")
	game_main.get_tree().paused = false
	var sim_root: Node = game_main.get_node_or_null("SimulationRoot")
	if sim_root:
		sim_root.process_mode = Node.PROCESS_MODE_DISABLED
	game_main.set("_cleanup_mode", _GameModeEnums.CleanupMode.SELECTING)
	game_main.set("_cleanup_confirm_room_index", -1)
	game_main.call("_clear_room_selection")
	var overlay: Node = game_main.call("_get_cleanup_overlay")
	overlay.hide_hover()
	overlay.hide_confirm()
	if overlay.has_method("show_cleanup_selecting_ui"):
		overlay.show_cleanup_selecting_ui()
	game_main.call("_update_room_overlays")
	var ui: Node = game_main.get_node_or_null("InteractiveUiRoot/UIMain")
	if ui and ui.has_method("set_cleanup_blocking"):
		ui.set_cleanup_blocking(true)
	game_main.queue_redraw()


static func exit_mode(game_main: Node2D) -> void:
	game_main.set("_cleanup_mode", _GameModeEnums.CleanupMode.NONE)
	game_main.set("_cleanup_confirm_room_index", -1)
	var cleanup_rooms: Dictionary = game_main.get("_cleanup_rooms_in_progress")
	if cleanup_rooms.is_empty():
		game_main.call("_get_cleanup_overlay").hide_progress()
	var overlay: Node = game_main.call("_get_cleanup_overlay")
	if overlay.has_method("hide_cleanup_selecting_ui"):
		overlay.hide_cleanup_selecting_ui()
	var ui: Node = game_main.get_node_or_null("InteractiveUiRoot/UIMain")
	if ui and ui.has_method("set_cleanup_blocking"):
		ui.set_cleanup_blocking(false)
	if GameTime and game_main.get("_time_was_flowing_before_cleanup"):
		GameTime.is_flowing = true
	for node in game_main.get_tree().get_nodes_in_group("researcher"):
		if node.has_method("force_sync_flowing_state"):
			node.call("force_sync_flowing_state")
	game_main.get_tree().paused = not (GameTime and GameTime.is_flowing)
	var sim_root: Node = game_main.get_node_or_null("SimulationRoot")
	if sim_root:
		sim_root.process_mode = Node.PROCESS_MODE_INHERIT
	overlay.hide_hover()
	overlay.hide_confirm()
	game_main.call("_update_room_overlays")
	game_main.queue_redraw()


static func on_confirm_pressed(game_main: Node2D) -> void:
	var cleanup_mode: int = game_main.get_cleanup_mode_int()
	var cleanup_confirm_room_index: int = game_main.get("_cleanup_confirm_room_index")
	var rooms: Array = game_main.get_game_rooms()
	if cleanup_mode != _GameModeEnums.CleanupMode.CONFIRMING or cleanup_confirm_room_index < 0:
		return
	var room: ArchivesRoomInfo = rooms[cleanup_confirm_room_index]
	var resources: Dictionary = game_main.call("_get_player_resources")
	if not can_afford_cleanup(room, resources, game_main):
		return
	consume_cleanup_cost(game_main, room)
	var cleanup_rooms: Dictionary = game_main.get("_cleanup_rooms_in_progress")
	var n: int = room.get_cleanup_researcher_count()
	var free_ids: Array = GameMainShelterHelper.get_free_researcher_ids(game_main)
	var researcher_ids: Array = []
	for i in mini(n, free_ids.size()):
		researcher_ids.append(free_ids[i])
	cleanup_rooms[cleanup_confirm_room_index] = {
		"elapsed": 0.0,
		"total": room.get_cleanup_time_hours(),
		"researcher_ids": researcher_ids
	}
	game_main.set("_cleanup_confirm_room_index", -1)
	exit_mode(game_main)


static func unlock_adjacent_rooms(game_main: Node2D, room: ArchivesRoomInfo) -> void:
	var rooms: Array = game_main.get_game_rooms()
	var id_to_index: Dictionary = RoomLayoutHelper.build_id_to_index(rooms)
	for adj_id in room.adjacent_ids:
		var idx: Variant = id_to_index.get(adj_id)
		if idx != null and idx >= 0 and idx < rooms.size():
			rooms[idx].unlocked = true
	game_main.call("_update_room_overlays")
	game_main.call("_update_room_info_labels")


static func handle_left_click(game_main: Node2D, rid: int) -> void:
	var rooms: Array = game_main.get_game_rooms()
	var room_center_to_screen: Callable = Callable(game_main, "_room_center_to_screen")
	var get_player_resources: Callable = Callable(game_main, "_get_player_resources")
	var get_cleanup_overlay: Callable = Callable(game_main, "_get_cleanup_overlay")
	var focus_camera: Callable = Callable(game_main, "_focus_camera_on_room")

	if rid >= 0:
		var room: ArchivesRoomInfo = rooms[rid]
		var is_selectable: bool = room.unlocked and room.clean_status == ArchivesRoomInfo.CleanStatus.UNCLEANED
		var not_cleaning: bool = not is_room_cleaning(game_main, rid)
		if is_selectable and not_cleaning:
			var resources: Dictionary = get_player_resources.call()
			var can_afford: bool = can_afford_cleanup(room, resources, game_main)
			if can_afford:
				game_main.set("_cleanup_mode", _GameModeEnums.CleanupMode.CONFIRMING)
				game_main.set("_cleanup_confirm_room_index", rid)
				focus_camera.call(rid)
				var screen_pos: Vector2 = room_center_to_screen.call(rid)
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

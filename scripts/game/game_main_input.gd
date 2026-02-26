class_name GameMainInputHelper
extends RefCounted

## 输入分发与 UI 点击检测
## 处理鼠标左/中/右键、滚轮、移动

const CLEANUP_SELECTING := 1
const CLEANUP_CONFIRMING := 2
const CONSTRUCTION_SELECTING_ZONE := 1
const CONSTRUCTION_SELECTING_TARGET := 2
const CONSTRUCTION_CONFIRMING := 3

const DEBUG_CLEANUP_INPUT := false


static func is_click_over_ui_buttons(game_main: Node2D, mouse_pos: Vector2) -> bool:
	var top_bar: Control = game_main.get_node_or_null("UIMain/TopBar") as Control
	if top_bar and top_bar.get_global_rect().has_point(mouse_pos):
		return true
	var cheat_panel: Control = game_main.get_node_or_null("CheatShelterPanel/Panel") as Control
	if cheat_panel and cheat_panel.get_global_rect().has_point(mouse_pos):
		return true
	var bar: Control = game_main.get_node_or_null("UIMain/BottomRightBar") as Control
	if bar and bar.get_global_rect().has_point(mouse_pos):
		return true
	var calamity: Control = game_main.get_node_or_null("UIMain/CalamityBar") as Control
	if calamity and calamity.get_global_rect().has_point(mouse_pos):
		return true
	var overlay: Node = game_main.call("_get_cleanup_overlay")
	if overlay:
		var confirm_ctrl: Control = overlay.get_node_or_null("ConfirmContainer") as Control
		if confirm_ctrl and confirm_ctrl.visible and confirm_ctrl.get_global_rect().has_point(mouse_pos):
			return true
	return false


static func process_input(game_main: Node2D, event: InputEvent) -> void:
	if DEBUG_CLEANUP_INPUT and event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var cleanup_mode: int = game_main.get("_cleanup_mode")
			var in_sel: bool = (cleanup_mode == CLEANUP_SELECTING or cleanup_mode == CLEANUP_CONFIRMING)
			if in_sel:
				print("[Cleanup] _input 收到左键 (清理模式)")

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			game_main.set("_is_panning", mb.pressed)
			if mb.pressed:
				game_main.set("_pan_start", game_main.get_viewport().get_mouse_position())
				game_main.call("_clear_room_selection")
			game_main.get_viewport().set_input_as_handled()

		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and not game_main.get("_is_panning"):
			var mouse_pos: Vector2 = game_main.get_viewport().get_mouse_position()
			var cleanup_mode: int = game_main.get("_cleanup_mode")
			var construction_mode: int = game_main.get("_construction_mode")
			var in_cleanup: bool = (cleanup_mode == CLEANUP_SELECTING or cleanup_mode == CLEANUP_CONFIRMING)
			var in_construction: bool = (construction_mode == CONSTRUCTION_SELECTING_ZONE or construction_mode == CONSTRUCTION_SELECTING_TARGET or construction_mode == CONSTRUCTION_CONFIRMING)

			if in_cleanup:
				if GameMainCleanupHelper.is_click_over_cleanup_allowed_ui(game_main, mouse_pos):
					return
				if is_click_over_ui_buttons(game_main, mouse_pos):
					game_main.get_viewport().set_input_as_handled()
					return
			elif in_construction:
				if GameMainConstructionHelper.is_click_over_construction_allowed_ui(game_main, mouse_pos):
					return
				if is_click_over_ui_buttons(game_main, mouse_pos):
					game_main.get_viewport().set_input_as_handled()
					return
			else:
				if is_click_over_ui_buttons(game_main, mouse_pos):
					return

			if DEBUG_CLEANUP_INPUT:
				print("[Cleanup] 左键点击 pos=%s mode=%s" % [mouse_pos, cleanup_mode])
			var grid: Vector2i = game_main.call("_get_mouse_grid")
			var rid: int = game_main.call("_get_room_at_grid", grid.x, grid.y)
			if DEBUG_CLEANUP_INPUT:
				print("[Cleanup] 左键 grid=%s rid=%s" % [grid, rid])

			if cleanup_mode == CLEANUP_SELECTING or cleanup_mode == CLEANUP_CONFIRMING:
				GameMainCleanupHelper.handle_left_click(game_main, rid)
			elif construction_mode == CONSTRUCTION_SELECTING_TARGET or construction_mode == CONSTRUCTION_CONFIRMING:
				GameMainConstructionHelper.handle_left_click(game_main, rid)
			else:
				var rooms: Array = game_main.get("_rooms")
				game_main.set("_selected_room_index", rid)
				if rid >= 0:
					GameMainCameraHelper.focus_camera_on_room(game_main, rid)
					game_main.call("_show_room_detail", rooms[rid])
				else:
					game_main.call("_hide_room_detail")
			game_main.queue_redraw()
			game_main.get_viewport().set_input_as_handled()

		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var cleanup_mode: int = game_main.get("_cleanup_mode")
			var construction_mode: int = game_main.get("_construction_mode")
			if cleanup_mode == CLEANUP_SELECTING or cleanup_mode == CLEANUP_CONFIRMING:
				game_main.set("_cleanup_confirm_room_index", -1)
				game_main.call("_get_cleanup_overlay").hide_confirm()
				GameMainCleanupHelper.exit_mode(game_main)
				game_main.get_viewport().set_input_as_handled()
			elif construction_mode != 0:  # CONSTRUCTION_NONE
				game_main.set("_construction_confirm_room_index", -1)
				game_main.call("_get_construction_overlay").hide_confirm()
				GameMainConstructionHelper.exit_mode(game_main)
				game_main.get_viewport().set_input_as_handled()

		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			GameMainCameraHelper.apply_zoom(game_main, true)
			game_main.get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			GameMainCameraHelper.apply_zoom(game_main, false)
			game_main.get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion:
		if game_main.get("_is_panning") and game_main.get("_camera"):
			var current_pos: Vector2 = game_main.get_viewport().get_mouse_position()
			GameMainCameraHelper.apply_pan(game_main, current_pos)
			game_main.get_viewport().set_input_as_handled()
		else:
			var grid: Vector2i = game_main.call("_get_mouse_grid")
			var new_hover: int = game_main.call("_get_room_at_grid", grid.x, grid.y)
			var hovered: int = game_main.get("_hovered_room_index")
			if new_hover != hovered:
				game_main.set("_hovered_room_index", new_hover)
				game_main.queue_redraw()

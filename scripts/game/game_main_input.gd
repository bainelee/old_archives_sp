class_name GameMainInputHelper
extends RefCounted

const _GameModeEnums := preload("res://scripts/game/game_mode_enums.gd")

## 输入分发与 UI 点击检测
## 处理鼠标左/中/右键、滚轮、移动

static func is_exploration_map_overlay_open(game_main: Node2D) -> bool:
	var exploration_overlay: CanvasLayer = game_main.get("_exploration_map_overlay")
	return exploration_overlay != null and exploration_overlay.visible


static func is_click_over_ui_buttons(game_main: Node2D, mouse_pos: Vector2) -> bool:
	var exploration_overlay: CanvasLayer = game_main.get("_exploration_map_overlay")
	if exploration_overlay and exploration_overlay.visible:
		var overlay_root: Control = exploration_overlay.get_node_or_null("OverlayRoot") as Control
		if overlay_root and overlay_root.visible and overlay_root.get_global_rect().has_point(mouse_pos):
			return true
	var figma_panel_root: Control = game_main.get_node_or_null("InteractiveUiRoot/RoomDetailPanelFigma/PanelRoot") as Control
	if figma_panel_root and figma_panel_root.visible and figma_panel_root.get_global_rect().has_point(mouse_pos):
		return true
	var legacy_panel: Control = game_main.get_node_or_null("InteractiveUiRoot/RoomDetailPanel/Panel") as Control
	if legacy_panel and legacy_panel.visible and legacy_panel.get_global_rect().has_point(mouse_pos):
		return true
	var top_bar: Control = game_main.get_node_or_null("InteractiveUiRoot/UIMain/TopBar") as Control
	if top_bar and top_bar.get_global_rect().has_point(mouse_pos):
		return true
	var researcher_panel: Control = game_main.get_node_or_null("InteractiveUiRoot/UIMain/DebugInfoPanel/Margin/VBox/ResearcherListPanel") as Control
	if researcher_panel and researcher_panel.visible and researcher_panel.get_global_rect().has_point(mouse_pos):
		return true
	var bar: Control = game_main.get_node_or_null("InteractiveUiRoot/UIMain/BottomRightBar") as Control
	if bar and bar.get_global_rect().has_point(mouse_pos):
		return true
	var calamity: Control = game_main.get_node_or_null("InteractiveUiRoot/UIMain/BottomRightBar/Margin/Content/CalamityInline") as Control
	if calamity and calamity.visible and calamity.get_global_rect().has_point(mouse_pos):
		return true
	var debug_info: Control = game_main.get_node_or_null("InteractiveUiRoot/UIMain/DebugInfoPanel") as Control
	if debug_info and debug_info.visible and debug_info.get_global_rect().has_point(mouse_pos):
		return true
	var overlay: Node = game_main.call("_get_cleanup_overlay")
	if overlay:
		var confirm_ctrl: Control = overlay.get_node_or_null("ConfirmContainer") as Control
		if confirm_ctrl and confirm_ctrl.visible and confirm_ctrl.get_global_rect().has_point(mouse_pos):
			return true
	return false


static func process_input(game_main: Node2D, event: InputEvent) -> void:
	## Tab 上方 ` 键：切换 Debug 面板显示（与标题栏关闭一致）；文本框聚焦时不触发
	if event is InputEventKey and event.pressed and not event.echo:
		var k: Key = event.keycode as Key
		var pk: Key = event.physical_keycode as Key
		if k == KEY_QUOTELEFT or pk == KEY_QUOTELEFT:
			var vp: Viewport = game_main.get_viewport()
			var focus_owner: Control = vp.gui_get_focus_owner() as Control
			if focus_owner and (focus_owner is LineEdit or focus_owner is TextEdit):
				pass
			else:
				var debug_panel: Control = game_main.get_node_or_null("InteractiveUiRoot/UIMain/DebugInfoPanel") as Control
				if debug_panel:
					debug_panel.visible = not debug_panel.visible
					vp.set_input_as_handled()
					return

	## 暂停菜单打开时完全跳过游戏输入，避免点击穿透到底层 UI/游戏世界
	var pause_menu: CanvasLayer = game_main.get_node_or_null("InteractiveUiRoot/PauseMenu") as CanvasLayer
	if pause_menu and pause_menu.visible:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			if is_exploration_map_overlay_open(game_main):
				return
			game_main.set("_is_panning", mb.pressed)
			if mb.pressed:
				game_main.set("_pan_start", game_main.get_viewport().get_mouse_position())
				game_main.call("_clear_room_selection")
			game_main.get_viewport().set_input_as_handled()

		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and not game_main.get("_is_panning"):
			var mouse_pos: Vector2 = game_main.get_viewport().get_mouse_position()
			var cleanup_mode: int = game_main.get_cleanup_mode_int()
			var construction_mode: int = game_main.get_construction_mode_int()
			var in_cleanup: bool = (cleanup_mode == _GameModeEnums.CleanupMode.SELECTING or cleanup_mode == _GameModeEnums.CleanupMode.CONFIRMING)
			var in_construction: bool = (
				construction_mode == _GameModeEnums.ConstructionMode.SELECTING_ZONE
				or construction_mode == _GameModeEnums.ConstructionMode.SELECTING_TARGET
				or construction_mode == _GameModeEnums.ConstructionMode.CONFIRMING
			)

			if in_cleanup:
				if GameMainCleanupHelper.is_click_over_cleanup_allowed_ui(game_main, mouse_pos):
					return
				if is_click_over_ui_buttons(game_main, mouse_pos):
					return  ## 仅跳过游戏逻辑，不消费事件，让 UI 按钮能接收点击
			elif in_construction:
				if GameMainConstructionHelper.is_click_over_construction_allowed_ui(game_main, mouse_pos):
					return
				if is_click_over_ui_buttons(game_main, mouse_pos):
					return  ## 同上
			else:
				if is_click_over_ui_buttons(game_main, mouse_pos):
					return  ## 同上

			var rid: int = -1
			var camera3d: Camera3D = game_main.get("_camera3d")
			if camera3d:
				rid = game_main.call("_get_room_at_mouse_3d")
				if rid < 0:
					rid = int(game_main.call("_pick_nearest_room_index_by_screen_center", mouse_pos, 420.0))
			else:
				var grid: Vector2i = game_main.call("_get_mouse_grid")
				rid = game_main.call("_get_room_at_grid", grid.x, grid.y)

			if cleanup_mode == _GameModeEnums.CleanupMode.SELECTING or cleanup_mode == _GameModeEnums.CleanupMode.CONFIRMING:
				GameMainCleanupHelper.handle_left_click(game_main, rid)
			elif construction_mode == _GameModeEnums.ConstructionMode.SELECTING_TARGET or construction_mode == _GameModeEnums.ConstructionMode.CONFIRMING:
				GameMainConstructionHelper.handle_left_click(game_main, rid)
				game_main.call("_update_room_highlights")
			else:
				var rooms: Array = game_main.get_game_rooms()
				game_main.set("_selected_room_index", rid)
				if rid >= 0:
					GameMainCameraHelper.focus_camera_on_room(game_main, rid)
					game_main.call("_show_room_detail", rooms[rid])
				else:
					game_main.call("_hide_room_detail")
			game_main.queue_redraw()
			game_main.get_viewport().set_input_as_handled()

		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var cleanup_mode: int = game_main.get_cleanup_mode_int()
			var construction_mode: int = game_main.get_construction_mode_int()
			if cleanup_mode == _GameModeEnums.CleanupMode.SELECTING or cleanup_mode == _GameModeEnums.CleanupMode.CONFIRMING:
				game_main.set("_cleanup_confirm_room_index", -1)
				game_main.call("_get_cleanup_overlay").hide_confirm()
				GameMainCleanupHelper.exit_mode(game_main)
				game_main.get_viewport().set_input_as_handled()
			elif construction_mode != _GameModeEnums.ConstructionMode.NONE:
				game_main.set("_construction_confirm_room_index", -1)
				game_main.call("_get_construction_overlay").hide_confirm()
				GameMainConstructionHelper.exit_mode(game_main)
				game_main.call("_update_room_highlights")
				game_main.get_viewport().set_input_as_handled()

		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			if is_exploration_map_overlay_open(game_main):
				return
			GameMainCameraHelper.apply_zoom(game_main, true)
			game_main.call("_update_debug_info")
			game_main.get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if is_exploration_map_overlay_open(game_main):
				return
			GameMainCameraHelper.apply_zoom(game_main, false)
			game_main.call("_update_debug_info")
			game_main.get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion:
		if game_main.get("_is_panning") and not is_exploration_map_overlay_open(game_main) and (game_main.get("_camera3d") or game_main.get("_camera")):
			var current_pos: Vector2 = game_main.get_viewport().get_mouse_position()
			GameMainCameraHelper.apply_pan(game_main, current_pos)
			game_main.get_viewport().set_input_as_handled()
		else:
			var new_hover: int = -1
			var mouse_pos: Vector2 = game_main.get_viewport().get_mouse_position()
			var camera3d: Camera3D = game_main.get("_camera3d")
			if not is_click_over_ui_buttons(game_main, mouse_pos):
				if camera3d:
					new_hover = game_main.call("_get_room_at_mouse_3d")
					if new_hover < 0:
						new_hover = int(game_main.call("_pick_nearest_room_index_by_screen_center", mouse_pos, 320.0))
				else:
					var grid: Vector2i = game_main.call("_get_mouse_grid")
					new_hover = game_main.call("_get_room_at_grid", grid.x, grid.y)
			var hovered: int = game_main.get("_hovered_room_index")
			if new_hover != hovered:
				game_main.set("_hovered_room_index", new_hover)
				game_main.call("_update_room_highlights")
				game_main.queue_redraw()
			if game_main.get("_debug_show_ray_hit") and camera3d:
				game_main.call("_update_debug_ray_hit")

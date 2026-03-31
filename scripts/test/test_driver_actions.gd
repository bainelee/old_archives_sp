extends RefCounted

## TestDriver 命令实现：input / query / game / scene（含 await）

const _ExplorationCodec := preload("res://scripts/game/exploration/exploration_state_codec.gd")
const _GameValuesRef := preload("res://scripts/core/game_values_ref.gd")

var _host: Node
var _ctx: RefCounted


func _init(host: Node, ctx: RefCounted) -> void:
	_host = host
	_ctx = ctx


func dispatch(action: String, params: Dictionary, out: Dictionary) -> void:
	match action:
		"sleep":
			await handle_sleep(params, out)
		"click":
			handle_click(params, out)
		"dragCamera":
			handle_drag_camera(params, out)
		"wait":
			await handle_wait(params, out)
		"screenshot":
			handle_screenshot(params, out)
		"queryTree":
			handle_query_tree(params, out)
		"queryNode":
			handle_query_node(params, out)
		"getState":
			handle_get_state(params, out)
		"exportUiSpec":
			handle_export_ui_spec(params, out)
		"check":
			await handle_check(params, out)
		"saveGame":
			handle_save_game(params, out)
		"setGameTimeSpeed":
			handle_set_game_time_speed(params, out)
		"setGlobalPause":
			handle_set_global_pause(params, out)
		"setFault":
			handle_set_fault(params, out)
		"exploreRegion":
			handle_explore_region(params, out)
		"advanceGameHours":
			handle_advance_game_hours(params, out)
		"changeScene":
			await handle_change_scene(params, out)
		"verifySaveSlotExploration":
			handle_verify_save_slot_exploration(params, out)
		"loadGameMainFromSlot":
			await handle_load_game_main_from_slot(params, out)
		_:
			_ctx.fail_out(out, "UNSUPPORTED_ACTION", "unsupported action: %s" % action)


func handle_sleep(params: Dictionary, _out: Dictionary) -> void:
	var ms: int = maxi(0, int(params.get("ms", 0)))
	if ms <= 0:
		return
	await _host.get_tree().create_timer(float(ms) / 1000.0).timeout


func handle_click(params: Dictionary, out: Dictionary) -> void:
	var target: Dictionary = params.get("target", {})
	var node: Node = _ctx.resolve_target(target)
	if node == null:
		_ctx.fail_out(out, "TARGET_NOT_FOUND", "click target not found")
		return
	if node is BaseButton:
		if not _ctx.is_clickable_canvas_item(node):
			_ctx.fail_out(out, "TARGET_NOT_VISIBLE", "button target not visible in tree")
			return
		if (node as BaseButton).disabled:
			_ctx.fail_out(out, "TARGET_DISABLED", "button target disabled")
			return
		(node as BaseButton).pressed.emit()
		out["data"] = {"node_path": _ctx.safe_node_path(node)}
		return
	if node is Control:
		var ctrl: Control = node as Control
		if not _ctx.is_clickable_canvas_item(ctrl):
			_ctx.fail_out(out, "TARGET_NOT_VISIBLE", "control target not visible in tree")
			return
		var center: Vector2 = ctrl.get_global_rect().get_center()
		inject_left_click(center)
		out["data"] = {"node_path": _ctx.safe_node_path(node), "position": [center.x, center.y]}
		return
	if node is Node2D:
		var p2: Vector2 = (node as Node2D).global_position
		inject_left_click(p2)
		out["data"] = {"node_path": _ctx.safe_node_path(node), "position": [p2.x, p2.y]}
		return
	if node is Node3D:
		var room_mode_active := is_room_selection_mode_active()
		if try_click_room_via_game_logic(node as Node3D):
			out["data"] = {"node_path": _ctx.safe_node_path(node), "strategy": "game_logic"}
			return
		if room_mode_active:
			_ctx.fail_out(out, "ROOM_SELECTION_FAILED", "room click did not enter confirm state")
			return
		var cam: Camera3D = _host.get_viewport().get_camera_3d()
		if cam == null:
			_ctx.fail_out(out, "UNSUPPORTED_TARGET", "click target is Node3D but no active camera")
			return
		var p3: Vector3 = (node as Node3D).global_transform.origin
		if cam.is_position_behind(p3):
			_ctx.fail_out(out, "UNSUPPORTED_TARGET", "click target is behind camera")
			return
		var p3_screen: Vector2 = cam.unproject_position(p3)
		inject_left_click(p3_screen)
		out["data"] = {"node_path": _ctx.safe_node_path(node), "position": [p3_screen.x, p3_screen.y]}
		return
	_ctx.fail_out(out, "UNSUPPORTED_TARGET", "click target is not Button/Control")


func handle_drag_camera(params: Dictionary, out: Dictionary) -> void:
	var delta: Array = params.get("delta", [0, 0])
	if delta.size() < 2:
		_ctx.fail_out(out, "INVALID_ARGUMENT", "dragCamera requires delta [x,y]")
		return
	var dx: float = float(delta[0])
	var dy: float = float(delta[1])
	var vp: Viewport = _host.get_tree().root.get_viewport()
	var start: Vector2 = vp.get_visible_rect().size * 0.5
	var mid: Vector2 = start + Vector2(dx, dy)

	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_MIDDLE
	down.pressed = true
	down.position = start
	Input.parse_input_event(down)

	var motion := InputEventMouseMotion.new()
	motion.position = mid
	motion.relative = Vector2(dx, dy)
	Input.parse_input_event(motion)

	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_MIDDLE
	up.pressed = false
	up.position = mid
	Input.parse_input_event(up)

	out["data"] = {"start": [start.x, start.y], "end": [mid.x, mid.y]}


func inject_left_click(position: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = position
	Input.parse_input_event(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = position
	Input.parse_input_event(up)


func is_room_selection_mode_active() -> bool:
	var gm: Node2D = _ctx.get_game_main()
	if gm == null:
		return false
	var cleanup_mode: int = gm.get_cleanup_mode_int()
	var construction_mode: int = gm.get_construction_mode_int()
	return cleanup_mode == 1 or cleanup_mode == 2 or construction_mode == 2 or construction_mode == 3


func try_click_room_via_game_logic(room_node: Node3D) -> bool:
	var gm: Node2D = _ctx.get_game_main()
	if gm == null:
		return false
	var room_index: int = _ctx.find_room_index_by_node_name(gm, room_node.name)
	if room_index < 0:
		return false
	var cleanup_mode: int = gm.get_cleanup_mode_int()
	if cleanup_mode == 1 or cleanup_mode == 2:
		var cleanup_helper := load("res://scripts/game/game_main_cleanup.gd")
		if cleanup_helper and cleanup_helper.has_method("handle_left_click"):
			cleanup_helper.handle_left_click(gm, room_index)
			var cleanup_confirm_idx: int = int(gm.get("_cleanup_confirm_room_index"))
			var cleanup_now_mode: int = gm.get_cleanup_mode_int()
			return cleanup_confirm_idx == room_index or cleanup_now_mode == 2
	var construction_mode: int = gm.get_construction_mode_int()
	if construction_mode == 2 or construction_mode == 3:
		var construction_helper := load("res://scripts/game/game_main_construction.gd")
		if construction_helper and construction_helper.has_method("handle_left_click"):
			construction_helper.handle_left_click(gm, room_index)
			var construction_confirm_idx: int = int(gm.get("_construction_confirm_room_index"))
			var construction_now_mode: int = gm.get_construction_mode_int()
			return construction_confirm_idx == room_index or construction_now_mode == 3
	return false


func handle_wait(params: Dictionary, out: Dictionary) -> void:
	var timeout_ms: int = maxi(1, int(params.get("timeoutMs", 10000)))
	var min_wait_ms: int = maxi(0, int(params.get("minWaitMs", 0)))
	var until: Dictionary = params.get("until", {})
	if min_wait_ms > 0:
		await _host.get_tree().create_timer(float(min_wait_ms) / 1000.0).timeout
	var ok: bool = await wait_until(until, timeout_ms)
	if not ok:
		_ctx.fail_out(out, "TIMEOUT", "wait condition timeout")


func before_step(action: String, params: Dictionary, step_pre_delay_ms: int) -> void:
	if step_pre_delay_ms <= 0:
		return
	if action != "click" and action != "dragCamera":
		return
	var marker_layer := CanvasLayer.new()
	marker_layer.layer = 200
	var marker := ColorRect.new()
	marker.size = Vector2(14, 14)
	marker.color = Color(1.0, 0.1, 0.1, 0.9)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p: Vector2 = preview_position_for_action(action, params)
	marker.position = p - marker.size * 0.5
	marker_layer.add_child(marker)
	_host.get_tree().root.add_child(marker_layer)
	await _host.get_tree().create_timer(float(step_pre_delay_ms) / 1000.0).timeout
	if is_instance_valid(marker_layer):
		marker_layer.queue_free()


func preview_position_for_action(action: String, params: Dictionary) -> Vector2:
	var vp: Viewport = _host.get_tree().root.get_viewport()
	var center: Vector2 = vp.get_visible_rect().size * 0.5
	if action == "click":
		var target: Dictionary = params.get("target", {})
		var node: Node = _ctx.resolve_target(target)
		if node is Control:
			return (node as Control).get_global_rect().get_center()
		if node is Node2D:
			return (node as Node2D).global_position
		if node is Node3D:
			var cam: Camera3D = vp.get_camera_3d()
			if cam and not cam.is_position_behind((node as Node3D).global_transform.origin):
				return cam.unproject_position((node as Node3D).global_transform.origin)
	if action == "dragCamera":
		return center
	return center


func handle_screenshot(params: Dictionary, out: Dictionary) -> void:
	var shot_name: String = str(params.get("name", "shot"))
	var safe_name: String = shot_name.replace(" ", "_")
	var path: String = "user://test_screenshots/%s.png" % safe_name
	_ctx.ensure_dir("user://test_screenshots")
	var tex: Texture2D = _host.get_viewport().get_texture()
	if tex == null:
		_ctx.fail_out(out, "SCREENSHOT_FAILED", "viewport texture is null")
		return
	var img: Image = tex.get_image()
	if img == null:
		_ctx.fail_out(out, "SCREENSHOT_FAILED", "viewport image is null")
		return
	var err: Error = img.save_png(path)
	if err != OK:
		_ctx.fail_out(out, "SCREENSHOT_FAILED", "save_png failed: %s" % str(err))
		return
	out["screenshot"] = path
	out["data"] = {"path": path}


func handle_query_tree(params: Dictionary, out: Dictionary) -> void:
	var root_path: String = str(params.get("rootPath", "/root"))
	var depth: int = maxi(0, int(params.get("depth", 3)))
	var root_node: Node = _host.get_node_or_null(root_path) if root_path != "/root" else _host.get_tree().root
	if root_node == null:
		_ctx.fail_out(out, "TARGET_NOT_FOUND", "queryTree root not found: %s" % root_path)
		return
	out["data"] = {"tree": _ctx.dump_tree(root_node, depth)}


func handle_query_node(params: Dictionary, out: Dictionary) -> void:
	var node_path: String = str(params.get("path", ""))
	if node_path.is_empty():
		_ctx.fail_out(out, "INVALID_ARGUMENT", "queryNode requires path")
		return
	var node: Node = _host.get_node_or_null(node_path)
	if node == null:
		_ctx.fail_out(out, "TARGET_NOT_FOUND", "node not found: %s" % node_path)
		return
	var props: Array = params.get("properties", [])
	var data: Dictionary = {"path": str(node.get_path()), "class": node.get_class()}
	for p in props:
		var key: String = str(p)
		data[key] = node.get(key)
	out["data"] = data


func handle_get_state(params: Dictionary, out: Dictionary) -> void:
	var gm: Node2D = _ctx.get_game_main()
	if gm == null:
		_ctx.fail_out(out, "GAME_MAIN_NOT_FOUND", "game main not found")
		return
	var keys: Array = params.get("keys", [])
	var data: Dictionary = {}
	for k in keys:
		var key: String = str(k)
		match key:
			"room_clean_status":
				var rid: String = str(params.get("roomId", ""))
				data[key] = _ctx.get_room_clean_status(gm, rid)
			"room_clean_progress":
				var rid_progress: String = str(params.get("roomId", ""))
				data[key] = _ctx.get_room_clean_progress(gm, rid_progress)
			"build_status":
				var rid_build: String = str(params.get("roomId", ""))
				data[key] = _ctx.get_build_status(gm, rid_build)
			"resources":
				if gm.has_method("_get_player_resources"):
					data[key] = _ctx.canonical_resources(gm.call("_get_player_resources"))
			"cognition_amount":
				var ui_main: Node = gm.get_node_or_null("InteractiveUiRoot/UIMain")
				if ui_main and ui_main.has_method("get_cognition"):
					data[key] = int(ui_main.call("get_cognition"))
				else:
					data[key] = 0
			"game_total_hours":
				if GameTime and GameTime.has_method("get_total_hours"):
					data[key] = float(GameTime.get_total_hours())
			"game_hour":
				if GameTime and GameTime.has_method("get_hour"):
					data[key] = int(GameTime.get_hour())
			"settlement_clock":
				data[key] = _ctx.build_settlement_clock()
			"resource_ledger":
				data[key] = _ctx.build_resource_ledger(_host, gm)
			"tree_paused":
				var tree := _host.get_tree()
				data[key] = bool(tree and tree.paused)
			"game_speed_multiplier":
				if GameTime and ("speed_multiplier" in GameTime):
					data[key] = float(GameTime.speed_multiplier)
				else:
					data[key] = null
			"info_amount":
				var ui_info: Node = gm.get_node_or_null("InteractiveUiRoot/UIMain")
				if ui_info and ui_info.get("info_amount") != null:
					data[key] = int(ui_info.info_amount)
				else:
					data[key] = 0
			"researcher_daily_info_theoretical_total":
				if PersonnelErosionCore and PersonnelErosionCore.has_method("get_researcher_daily_info_theoretical_total"):
					data[key] = int(PersonnelErosionCore.get_researcher_daily_info_theoretical_total())
				else:
					data[key] = 0
			"selected_room_index":
				data[key] = int(gm.get("_selected_room_index"))
			"selected_room_id":
				var selected_index: int = int(gm.get("_selected_room_index"))
				var rooms: Array = gm.get_game_rooms()
				if selected_index >= 0 and selected_index < rooms.size():
					var room: ArchivesRoomInfo = rooms[selected_index]
					data[key] = room.id if room.id != "" else room.json_room_id
				else:
					data[key] = ""
			"exploration_overlay_visible":
				var overlay: CanvasLayer = gm.get("_exploration_map_overlay")
				data[key] = bool(overlay and overlay.visible)
			"exploration_explored_ids":
				data[key] = exploration_sorted_explored_ids(gm)
			"game_main_camera_distance":
				data[key] = float(gm.get("_camera_distance"))
			"game_main_camera_zoom":
				var cam2d_state: Camera2D = gm.get("_camera")
				if cam2d_state:
					data[key] = float(cam2d_state.zoom.x)
				else:
					data[key] = null
			_:
				data[key] = null
	out["data"] = data


func exploration_sorted_explored_ids(gm: Node2D) -> Array:
	var svc: Variant = gm.get("_exploration_service")
	if svc == null or not svc.has_method("get_runtime_state_readonly"):
		return []
	var st: Dictionary = svc.call("get_runtime_state_readonly") as Dictionary
	var arr: Array[String] = _ExplorationCodec.normalize_string_id_array(st.get(_ExplorationCodec.KEY_EXPLORED_REGION_IDS, []))
	var dup: Array = []
	for x in arr:
		dup.append(str(x))
	dup.sort()
	return dup


func handle_export_ui_spec(params: Dictionary, out: Dictionary) -> void:
	var cmd_dir: String = str(_host.call("test_driver_cmd_dir"))
	var target: Dictionary = params.get("target", {})
	var spec_name: String = str(params.get("name", "ui_spec"))
	var node: Node = _ctx.resolve_target(target)
	if node == null:
		_ctx.fail_out(out, "TARGET_NOT_FOUND", "exportUiSpec target not found")
		return
	var spec: Dictionary = {"root_path": str(node.get_path()), "controls": []}
	_ctx.collect_controls(node, spec["controls"])
	_ctx.ensure_dir(cmd_dir)
	var path: String = "%s/%s.json" % [cmd_dir, spec_name]
	_ctx.write_json(path, spec)
	out["data"] = {"path": path, "count": (spec["controls"] as Array).size()}


func handle_check(params: Dictionary, out: Dictionary) -> void:
	var kind: String = str(params.get("kind", ""))
	var expect: Dictionary = params.get("expect", {})
	match kind:
		"logic_state":
			var keys: Array = []
			for k in expect.keys():
				if str(k) in ["progressIncreased", "nextInteractionUnlocked", "btnDisabled", "nodeVisible"]:
					continue
				keys.append(str(k))
			var timeout_ms: int = maxi(1, int(params.get("timeoutMs", 1200)))
			var deadline: int = Time.get_ticks_msec() + timeout_ms
			while true:
				var state_out: Dictionary = {"status": "ok", "data": {}}
				handle_get_state({"keys": keys, "roomId": params.get("roomId", "")}, state_out)
				if state_out.get("status", "ok") != "ok":
					_ctx.fail_out(out, "CHECK_FAILED", "logic_state state query failed")
					return
				var all_match := true
				for k in keys:
					if state_out["data"].get(k) != expect.get(k):
						all_match = false
						break
				if all_match:
					break
				if Time.get_ticks_msec() > deadline:
					_ctx.fail_out(out, "CHECK_FAILED", "logic_state mismatch for %s" % (keys[0] if keys.size() > 0 else "unknown"))
					return
				await _host.get_tree().create_timer(0.05).timeout
		"info_currency_week_design":
			## 断言：推进若干游戏日后，信息货币增量落在「每人每日 [minimum, base] × 人数 × 天数」区间内（见 researcher_system.info_daily）
			if _ctx.get_game_main() == null:
				_ctx.fail_out(out, "GAME_MAIN_NOT_FOUND", "game main not found")
				return
			var baseline_info_ic: int = int(expect.get("baseline_info", -1))
			if baseline_info_ic < 0:
				_ctx.fail_out(out, "INVALID_ARGUMENT", "info_currency_week_design requires expect.baseline_info")
				return
			var days_ic: int = maxi(1, int(expect.get("days", 7)))
			var min_hours_ic: float = float(expect.get("min_game_total_hours", 168.0))
			if bool(expect.get("require_speed_multiplier_2", false)):
				if GameTime == null:
					_ctx.fail_out(out, "GAME_TIME_NOT_FOUND", "GameTime missing for speed check")
					return
				if not is_equal_approx(float(GameTime.speed_multiplier), 2.0):
					_ctx.fail_out(out, "CHECK_FAILED", "expected game speed 2.0, got %s" % str(GameTime.speed_multiplier))
					return
			var st_ic: Dictionary = {"status": "ok", "data": {}}
			handle_get_state({"keys": ["game_total_hours", "info_amount", "researcher_daily_info_theoretical_total"]}, st_ic)
			if st_ic.get("status", "ok") != "ok":
				_ctx.fail_out(out, "CHECK_FAILED", "info_currency_week_design state query failed")
				return
			var hours_ic: float = float(st_ic["data"].get("game_total_hours", 0.0))
			var info_ic: int = int(st_ic["data"].get("info_amount", 0))
			var theo_ic: int = int(st_ic["data"].get("researcher_daily_info_theoretical_total", 0))
			if hours_ic + 0.0001 < min_hours_ic:
				_ctx.fail_out(out, "CHECK_FAILED", "game_total_hours %s < min %s" % [str(hours_ic), str(min_hours_ic)])
				return
			var gv_ic: Node = _GameValuesRef.get_singleton()
			var base_amt_ic: int = 3
			var min_amt_ic: int = 1
			if gv_ic:
				if gv_ic.has_method("get_researcher_info_daily_base"):
					base_amt_ic = int(gv_ic.get_researcher_info_daily_base())
				if gv_ic.has_method("get_researcher_info_daily_minimum_if_not_eroded"):
					min_amt_ic = int(gv_ic.get_researcher_info_daily_minimum_if_not_eroded())
			var rc_ic: int = 10
			if PersonnelErosionCore and PersonnelErosionCore.has_method("get_researchers"):
				rc_ic = (PersonnelErosionCore.get_researchers() as Array).size()
			rc_ic = maxi(rc_ic, 1)
			## 上限按配置人数 cap：周内有减员时，实际增量可能仍接近「满编 × 天数」的前段日结之和
			var roster_cap_ic: int = maxi(1, int(expect.get("researcher_count_cap", 10)))
			if PersonnelErosionCore and PersonnelErosionCore.has_method("get_personnel"):
				roster_cap_ic = maxi(roster_cap_ic, int(PersonnelErosionCore.get_personnel().get("researcher", roster_cap_ic)))
			var max_delta_ic: int = days_ic * roster_cap_ic * base_amt_ic
			var min_delta_ic: int = days_ic * rc_ic * min_amt_ic
			var delta_ic: int = info_ic - baseline_info_ic
			if delta_ic < min_delta_ic:
				_ctx.fail_out(
					out,
					"CHECK_FAILED",
					"info delta %d < min %d (baseline %d -> %d, theo_daily %d, hours %s)" % [delta_ic, min_delta_ic, baseline_info_ic, info_ic, theo_ic, str(hours_ic)]
				)
				return
			if delta_ic > max_delta_ic:
				_ctx.fail_out(out, "CHECK_FAILED", "info delta %d > max %d (theo_daily %d)" % [delta_ic, max_delta_ic, theo_ic])
				return
			out["data"] = {
				"kind": kind,
				"expect": expect,
				"game_total_hours": hours_ic,
				"info_amount": info_ic,
				"info_delta": delta_ic,
				"researcher_daily_info_theoretical_total": theo_ic,
				"bounds": {"min_delta": min_delta_ic, "max_delta": max_delta_ic},
			}
		"researcher_no_housing_info_penalty":
			var gm_nh: Node2D = _ctx.get_game_main()
			if gm_nh == null:
				_ctx.fail_out(out, "GAME_MAIN_NOT_FOUND", "game main not found")
				return
			if PersonnelErosionCore == null:
				_ctx.fail_out(out, "CORE_NOT_FOUND", "PersonnelErosionCore missing")
				return
			var gv_nh: Node = _GameValuesRef.get_singleton()
			if gv_nh == null:
				_ctx.fail_out(out, "GAME_VALUES_NOT_FOUND", "GameValues singleton missing")
				return
			var helper_nh := load("res://scripts/game/game_main_shelter.gd")
			if helper_nh == null:
				_ctx.fail_out(out, "HELPER_NOT_FOUND", "GameMainShelterHelper script missing")
				return
			var base_nh: int = int(gv_nh.get_researcher_info_daily_base())
			var pen_h_nh: int = int(gv_nh.get_researcher_info_daily_penalty_no_housing())
			var pen_c_nh: int = int(gv_nh.get_researcher_info_daily_penalty_cognition_crisis())
			var min_nh: int = int(gv_nh.get_researcher_info_daily_minimum_if_not_eroded())
			var researchers_nh: Array = PersonnelErosionCore.get_researchers()
			var total_no_housing: int = 0
			var no_housing_working: int = 0
			var no_housing_no_work: int = 0
			for r_nh in researchers_nh:
				if not (r_nh is Dictionary):
					continue
				var raw_nh: Dictionary = r_nh as Dictionary
				if bool(raw_nh.get("is_eroded", false)):
					continue
				var enriched_nh: Dictionary = helper_nh.enrich_researcher_with_rooms(gm_nh, raw_nh)
				var housing_missing: bool = str(enriched_nh.get("housing_room_id", "")).is_empty()
				if not housing_missing:
					continue
				total_no_housing += 1
				var work_missing: bool = str(enriched_nh.get("work_room_id", "")).is_empty()
				if work_missing:
					no_housing_no_work += 1
				else:
					no_housing_working += 1
				var expected_nh: int = base_nh - pen_h_nh
				if int(raw_nh.get("cognition_crisis", 0)) >= 1:
					expected_nh -= pen_c_nh
				expected_nh = maxi(min_nh, expected_nh)
				var actual_nh: int = int(PersonnelErosionCore.compute_daily_info_for_researcher(raw_nh))
				if actual_nh != expected_nh:
					_ctx.fail_out(
						out,
						"CHECK_FAILED",
						"researcher id=%s no housing daily info mismatch: expected=%d actual=%d work_room_id=%s" % [
							str(raw_nh.get("id", -1)),
							expected_nh,
							actual_nh,
							str(enriched_nh.get("work_room_id", "")),
						]
					)
					return
			if total_no_housing <= 0:
				_ctx.fail_out(out, "CHECK_FAILED", "no non-eroded no-housing researcher found for validation")
				return
			out["data"] = {
				"kind": kind,
				"expect": expect,
				"total_no_housing_checked": total_no_housing,
				"no_housing_working_checked": no_housing_working,
				"no_housing_no_work_checked": no_housing_no_work,
				"formula": {
					"base": base_nh,
					"penalty_no_housing": pen_h_nh,
					"penalty_cognition_crisis": pen_c_nh,
					"minimum_if_not_eroded": min_nh,
				},
			}
		"visual_hard":
			if expect.has("nodeVisible"):
				var target: Dictionary = {"testId": str(expect.get("nodeVisible", ""))}
				var node: Node = _ctx.resolve_target(target)
				if not (node is CanvasItem and (node as CanvasItem).visible):
					_ctx.fail_out(out, "CHECK_FAILED", "expected node visible: %s" % str(expect.get("nodeVisible", "")))
					return
			if expect.has("btnDisabled"):
				var btn_target: Dictionary = {"testId": str(expect.get("btnDisabled", ""))}
				var btn_node: Node = _ctx.resolve_target(btn_target)
				if not (btn_node is BaseButton and (btn_node as BaseButton).disabled):
					_ctx.fail_out(out, "CHECK_FAILED", "expected button disabled: %s" % str(expect.get("btnDisabled", "")))
					return
		"camera_unchanged_after_wheel":
			var gm_wheel: Node2D = _ctx.get_game_main()
			if gm_wheel == null:
				_ctx.fail_out(out, "GAME_MAIN_NOT_FOUND", "game main not found")
				return
			if bool(expect.get("requireExplorationOverlay", true)):
				var ovl: CanvasLayer = gm_wheel.get("_exploration_map_overlay")
				if ovl == null or not ovl.visible:
					_ctx.fail_out(out, "CHECK_FAILED", "exploration overlay must be open for camera_unchanged_after_wheel")
					return
			var steps_n: int = maxi(1, int(expect.get("steps", 6)))
			var dir_str: String = str(expect.get("direction", "up"))
			var camera3d_n: Camera3D = gm_wheel.get("_camera3d")
			var dist_before: float = float(gm_wheel.get("_camera_distance"))
			var zoom_before: float = -1.0
			var cam2d_n: Camera2D = gm_wheel.get("_camera")
			if cam2d_n:
				zoom_before = float(cam2d_n.zoom.x)
			var vp_wheel: Viewport = _host.get_tree().root.get_viewport()
			var pos_wheel: Vector2 = vp_wheel.get_visible_rect().get_center()
			for _i in steps_n:
				var w_ev := InputEventMouseButton.new()
				w_ev.position = pos_wheel
				if dir_str.to_lower() == "down":
					w_ev.button_index = MOUSE_BUTTON_WHEEL_DOWN
				else:
					w_ev.button_index = MOUSE_BUTTON_WHEEL_UP
				w_ev.pressed = true
				w_ev.factor = 1.0
				Input.parse_input_event(w_ev)
			if camera3d_n:
				var dist_after: float = float(gm_wheel.get("_camera_distance"))
				if not is_equal_approx(dist_before, dist_after):
					_ctx.fail_out(
						out,
						"CHECK_FAILED",
						"camera distance changed after wheel (overlay open): before=%s after=%s" % [str(dist_before), str(dist_after)]
					)
					return
			elif cam2d_n:
				var zoom_after: float = float(cam2d_n.zoom.x)
				if not is_equal_approx(zoom_before, zoom_after):
					_ctx.fail_out(
						out,
						"CHECK_FAILED",
						"camera zoom changed after wheel (overlay open): before=%s after=%s" % [str(zoom_before), str(zoom_after)]
					)
					return
		_:
			_ctx.fail_out(out, "INVALID_ARGUMENT", "unsupported check kind: %s" % kind)
			return
	if kind != "info_currency_week_design":
		out["data"] = {"kind": kind, "expect": expect}


func handle_save_game(_params: Dictionary, out: Dictionary) -> void:
	var gm: Node2D = _ctx.get_game_main()
	if gm == null:
		_ctx.fail_out(out, "GAME_MAIN_NOT_FOUND", "game main not found")
		return
	if not gm.has_method("save_current_slot_quiet"):
		_ctx.fail_out(out, "UNSUPPORTED_TARGET", "game main has no save_current_slot_quiet")
		return
	gm.call("save_current_slot_quiet")
	out["data"] = {"saved": true}


func handle_set_game_time_speed(params: Dictionary, out: Dictionary) -> void:
	var speed: float = float(params.get("speed", 1.0))
	speed = maxf(0.1, speed)
	if GameTime == null:
		_ctx.fail_out(out, "GAME_TIME_NOT_FOUND", "GameTime autoload not found")
		return
	GameTime.speed_multiplier = speed
	GameTime.is_flowing = true
	if GameTime.get_tree():
		GameTime.get_tree().paused = false
	out["data"] = {"speed_multiplier": speed}


func handle_set_global_pause(params: Dictionary, out: Dictionary) -> void:
	var paused: bool = bool(params.get("paused", true))
	var tree := _host.get_tree()
	if tree == null:
		_ctx.fail_out(out, "TREE_NOT_FOUND", "scene tree not found")
		return
	tree.paused = paused
	out["data"] = {"tree_paused": tree.paused}


func handle_explore_region(params: Dictionary, out: Dictionary) -> void:
	var rid: String = str(params.get("regionId", "")).strip_edges()
	if rid.is_empty():
		_ctx.fail_out(out, "INVALID_ARGUMENT", "exploreRegion requires regionId")
		return
	var gm: Node2D = _ctx.get_game_main()
	if gm == null:
		_ctx.fail_out(out, "GAME_MAIN_NOT_FOUND", "game main not found")
		return
	var svc: Variant = gm.get("_exploration_service")
	if svc == null or not svc.has_method("explore_region"):
		_ctx.fail_out(out, "NO_EXPLORATION_SERVICE", "exploration service missing")
		return
	svc.call("ensure_first_open_initialized")
	var res: Variant = svc.call("explore_region", rid)
	if not (res is Dictionary) or not bool((res as Dictionary).get("ok", false)):
		var reason: String = str((res as Dictionary).get("reason", "unknown")) if res is Dictionary else "bad_result"
		_ctx.fail_out(out, "EXPLORE_FAILED", "explore_region failed: %s" % reason)
		return
	out["data"] = res


func handle_advance_game_hours(params: Dictionary, out: Dictionary) -> void:
	var hours: float = maxf(0.0, float(params.get("hours", 0.0)))
	if hours <= 0.0:
		out["data"] = {"advanced": 0.0}
		return
	if GameTime and GameTime.has_method("set_total_hours") and GameTime.has_method("get_total_hours"):
		GameTime.set_total_hours(GameTime.get_total_hours() + hours)
	var gm: Node2D = _ctx.get_game_main()
	if gm == null:
		_ctx.fail_out(out, "GAME_MAIN_NOT_FOUND", "game main not found")
		return
	var svc: Variant = gm.get("_exploration_service")
	if svc != null and svc.has_method("tick"):
		svc.call("tick", hours)
	out["data"] = {"advanced": hours}


func handle_load_game_main_from_slot(params: Dictionary, out: Dictionary) -> void:
	var slot: int = int(params.get("slot", 0))
	if SaveManager == null:
		_ctx.fail_out(out, "SAVE_MANAGER_MISSING", "SaveManager autoload missing")
		return
	SaveManager.pending_load_slot = slot
	const GAME_MAIN_SCENE := "res://scenes/game/game_main.tscn"
	var err: Error = _host.get_tree().change_scene_to_file(GAME_MAIN_SCENE)
	if err != OK:
		_ctx.fail_out(out, "SCENE_CHANGE_FAILED", "change_scene_to_file failed: %s" % error_string(err))
		return
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
	out["data"] = {"slot": slot, "scene": GAME_MAIN_SCENE}


func handle_change_scene(params: Dictionary, out: Dictionary) -> void:
	var path: String = str(params.get("path", "")).strip_edges()
	if path.is_empty():
		_ctx.fail_out(out, "INVALID_ARGUMENT", "changeScene requires path")
		return
	var err: Error = _host.get_tree().change_scene_to_file(path)
	if err != OK:
		_ctx.fail_out(out, "SCENE_CHANGE_FAILED", "change_scene_to_file failed: %s" % error_string(err))
		return
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
	out["data"] = {"path": path}


func handle_verify_save_slot_exploration(params: Dictionary, out: Dictionary) -> void:
	var slot: int = int(params.get("slot", 0))
	var must: Variant = params.get("mustContainExplored", [])
	if not (must is Array):
		_ctx.fail_out(out, "INVALID_ARGUMENT", "mustContainExplored must be array")
		return
	if SaveManager == null:
		_ctx.fail_out(out, "SAVE_MANAGER_MISSING", "SaveManager autoload missing")
		return
	var save_path: String = SaveManager.get_slot_path(slot)
	if not FileAccess.file_exists(save_path):
		_ctx.fail_out(out, "SAVE_NOT_FOUND", "no save at %s" % save_path)
		return
	var f: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		_ctx.fail_out(out, "SAVE_READ_FAILED", save_path)
		return
	var txt: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if not (parsed is Dictionary):
		_ctx.fail_out(out, "SAVE_PARSE_FAILED", "invalid json")
		return
	var root: Dictionary = parsed as Dictionary
	var ex: Variant = root.get("exploration", {})
	if not (ex is Dictionary):
		_ctx.fail_out(out, "SAVE_NO_EXPLORATION", "root has no exploration block")
		return
	var explored_raw: Variant = (ex as Dictionary).get("explored_region_ids", [])
	var explored: Array = explored_raw if explored_raw is Array else []
	for id in must as Array:
		var sid: String = str(id)
		if not explored.has(sid):
			_ctx.fail_out(out, "EXPLORE_STATE_MISMATCH", "save missing explored id: %s (have %s)" % [sid, JSON.stringify(explored)])
			return
	out["data"] = {
		"explored_region_ids": explored,
		"save_version": (ex as Dictionary).get("save_version"),
	}


func handle_set_fault(params: Dictionary, out: Dictionary) -> void:
	var gm: Node2D = _ctx.get_game_main()
	if gm == null:
		_ctx.fail_out(out, "GAME_MAIN_NOT_FOUND", "game main not found")
		return
	var fault_name: String = str(params.get("name", "")).strip_edges()
	if fault_name.is_empty():
		_ctx.fail_out(out, "INVALID_ARGUMENT", "setFault requires name")
		return
	var enabled: bool = bool(params.get("enabled", true))
	var faults: Dictionary = {}
	if gm.has_meta("_test_faults"):
		var v: Variant = gm.get_meta("_test_faults")
		if v is Dictionary:
			faults = (v as Dictionary).duplicate(true)
	if enabled:
		faults[fault_name] = true
	else:
		faults.erase(fault_name)
	gm.set_meta("_test_faults", faults)
	out["data"] = {"name": fault_name, "enabled": enabled}


func wait_until(until: Dictionary, timeout_ms: int) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() <= deadline:
		if eval_wait_condition(until):
			return true
		await _host.get_tree().create_timer(0.05).timeout
	return eval_wait_condition(until)


func eval_wait_condition(until: Dictionary) -> bool:
	if until.has("scene"):
		var scene_name: String = str(until.get("scene", ""))
		var current_scene: Node = _host.get_tree().current_scene
		if current_scene == null:
			return false
		return scene_name in str(current_scene.scene_file_path) or scene_name in current_scene.name
	if until.has("nodeVisible"):
		var target: Dictionary = until.get("nodeVisible", {})
		var node: Node = _ctx.resolve_target(target)
		return _ctx.is_clickable_canvas_item(node)
	if until.has("stateEquals"):
		var expect: Dictionary = until.get("stateEquals", {})
		var key: String = str(expect.get("key", ""))
		var value: Variant = expect.get("value", null)
		if key.is_empty():
			return false
		var state_out: Dictionary = {"status": "ok", "data": {}}
		handle_get_state({"keys": [key], "roomId": expect.get("roomId", "")}, state_out)
		if state_out.get("status", "ok") != "ok":
			return false
		return state_out["data"].get(key) == value
	return false

extends Node

const DRIVER_ROOT_DIR := "user://test_driver"

var _enabled: bool = false
var _busy: bool = false
var _session: String = "default"
var _cmd_dir: String = ""
var _cmd_file: String = ""
var _resp_file: String = ""
var _step_pre_delay_ms: int = 100
var _resource_probe_initialized: bool = false
var _resource_probe_baseline: Dictionary = {}
var _resource_probe_last: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var session_arg: String = _get_user_arg_value("--test-driver-session", "")
	_enabled = _has_flag("--test-driver") or not session_arg.is_empty()
	if not _enabled:
		return
	_session = _sanitize_session(session_arg if not session_arg.is_empty() else "default")
	_cmd_dir = "%s/%s" % [DRIVER_ROOT_DIR, _session]
	_cmd_file = "%s/command.json" % _cmd_dir
	_resp_file = "%s/response.json" % _cmd_dir
	_ensure_driver_dir()
	_write_json(_resp_file, {"status": "ready", "pid": OS.get_process_id(), "session": _session})


func _process(_delta: float) -> void:
	if not _enabled or _busy:
		return
	if not FileAccess.file_exists(_cmd_file):
		return
	_busy = true
	var cmd: Dictionary = _read_json(_cmd_file)
	DirAccess.remove_absolute(_cmd_file)
	var result: Dictionary = await _execute_command(cmd)
	_write_json(_resp_file, result)
	_busy = false


func _execute_command(cmd: Dictionary) -> Dictionary:
	var seq: int = int(cmd.get("seq", -1))
	var action: String = str(cmd.get("action", ""))
	var params: Dictionary = cmd.get("params", {})
	var started_ms: int = Time.get_ticks_msec()
	var out: Dictionary = {
		"seq": seq,
		"action": action,
		"status": "ok",
		"data": {},
		"elapsed_ms": 0,
	}
	await _before_step(action, params)

	match action:
		"sleep":
			await _handle_sleep(params, out)
		"click":
			_handle_click(params, out)
		"dragCamera":
			_handle_drag_camera(params, out)
		"wait":
			await _handle_wait(params, out)
		"screenshot":
			_handle_screenshot(params, out)
		"queryTree":
			_handle_query_tree(params, out)
		"queryNode":
			_handle_query_node(params, out)
		"getState":
			_handle_get_state(params, out)
		"exportUiSpec":
			_handle_export_ui_spec(params, out)
		"check":
			await _handle_check(params, out)
		"saveGame":
			_handle_save_game(params, out)
		"setGameTimeSpeed":
			_handle_set_game_time_speed(params, out)
		"setGlobalPause":
			_handle_set_global_pause(params, out)
		"setFault":
			_handle_set_fault(params, out)
		_:
			_fail(out, "UNSUPPORTED_ACTION", "unsupported action: %s" % action)

	out["elapsed_ms"] = Time.get_ticks_msec() - started_ms
	return out


func _handle_sleep(params: Dictionary, _out: Dictionary) -> void:
	var ms: int = maxi(0, int(params.get("ms", 0)))
	if ms <= 0:
		return
	await get_tree().create_timer(float(ms) / 1000.0).timeout


func _handle_click(params: Dictionary, out: Dictionary) -> void:
	var target: Dictionary = params.get("target", {})
	var node: Node = _resolve_target(target)
	if node == null:
		_fail(out, "TARGET_NOT_FOUND", "click target not found")
		return
	if node is BaseButton:
		if not _is_clickable_canvas_item(node):
			_fail(out, "TARGET_NOT_VISIBLE", "button target not visible in tree")
			return
		if (node as BaseButton).disabled:
			_fail(out, "TARGET_DISABLED", "button target disabled")
			return
		(node as BaseButton).pressed.emit()
		out["data"] = {"node_path": _safe_node_path(node)}
		return
	if node is Control:
		var ctrl: Control = node as Control
		if not _is_clickable_canvas_item(ctrl):
			_fail(out, "TARGET_NOT_VISIBLE", "control target not visible in tree")
			return
		var center: Vector2 = ctrl.get_global_rect().get_center()
		_inject_left_click(center)
		out["data"] = {"node_path": _safe_node_path(node), "position": [center.x, center.y]}
		return
	if node is Node2D:
		var p2: Vector2 = (node as Node2D).global_position
		_inject_left_click(p2)
		out["data"] = {"node_path": _safe_node_path(node), "position": [p2.x, p2.y]}
		return
	if node is Node3D:
		var room_mode_active := _is_room_selection_mode_active()
		if _try_click_room_via_game_logic(node as Node3D):
			out["data"] = {"node_path": _safe_node_path(node), "strategy": "game_logic"}
			return
		if room_mode_active:
			_fail(out, "ROOM_SELECTION_FAILED", "room click did not enter confirm state")
			return
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam == null:
			_fail(out, "UNSUPPORTED_TARGET", "click target is Node3D but no active camera")
			return
		var p3: Vector3 = (node as Node3D).global_transform.origin
		if cam.is_position_behind(p3):
			_fail(out, "UNSUPPORTED_TARGET", "click target is behind camera")
			return
		var p3_screen: Vector2 = cam.unproject_position(p3)
		_inject_left_click(p3_screen)
		out["data"] = {"node_path": _safe_node_path(node), "position": [p3_screen.x, p3_screen.y]}
		return
	_fail(out, "UNSUPPORTED_TARGET", "click target is not Button/Control")


func _handle_drag_camera(params: Dictionary, out: Dictionary) -> void:
	var delta: Array = params.get("delta", [0, 0])
	if delta.size() < 2:
		_fail(out, "INVALID_ARGUMENT", "dragCamera requires delta [x,y]")
		return
	var dx: float = float(delta[0])
	var dy: float = float(delta[1])
	var vp: Viewport = get_tree().root.get_viewport()
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


func _inject_left_click(position: Vector2) -> void:
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


func _safe_node_path(node: Node) -> String:
	if node == null:
		return ""
	return str(node.get_path()) if node.is_inside_tree() else ""


func _is_clickable_canvas_item(node: Node) -> bool:
	if not (node is CanvasItem):
		return true
	var canvas_item: CanvasItem = node as CanvasItem
	return canvas_item.is_visible_in_tree()


func _is_room_selection_mode_active() -> bool:
	var gm: Node2D = _get_game_main()
	if gm == null:
		return false
	var cleanup_mode: int = int(gm.get("_cleanup_mode"))
	var construction_mode: int = int(gm.get("_construction_mode"))
	return cleanup_mode == 1 or cleanup_mode == 2 or construction_mode == 2 or construction_mode == 3


func _try_click_room_via_game_logic(room_node: Node3D) -> bool:
	var gm: Node2D = _get_game_main()
	if gm == null:
		return false
	var room_index: int = _find_room_index_by_node_name(gm, room_node.name)
	if room_index < 0:
		return false
	var cleanup_mode: int = int(gm.get("_cleanup_mode"))
	if cleanup_mode == 1 or cleanup_mode == 2:
		var cleanup_helper := load("res://scripts/game/game_main_cleanup.gd")
		if cleanup_helper and cleanup_helper.has_method("handle_left_click"):
			cleanup_helper.handle_left_click(gm, room_index)
			var cleanup_confirm_idx: int = int(gm.get("_cleanup_confirm_room_index"))
			var cleanup_now_mode: int = int(gm.get("_cleanup_mode"))
			return cleanup_confirm_idx == room_index or cleanup_now_mode == 2
	var construction_mode: int = int(gm.get("_construction_mode"))
	if construction_mode == 2 or construction_mode == 3:
		var construction_helper := load("res://scripts/game/game_main_construction.gd")
		if construction_helper and construction_helper.has_method("handle_left_click"):
			construction_helper.handle_left_click(gm, room_index)
			var construction_confirm_idx: int = int(gm.get("_construction_confirm_room_index"))
			var construction_now_mode: int = int(gm.get("_construction_mode"))
			return construction_confirm_idx == room_index or construction_now_mode == 3
	return false


func _find_room_index_by_node_name(gm: Node2D, node_name: String) -> int:
	var rooms: Array = gm.get("_rooms")
	for i in rooms.size():
		var room: ArchivesRoomInfo = rooms[i]
		var rid: String = room.id if room.id != "" else room.json_room_id
		if rid == node_name:
			return i
	return -1


func _handle_wait(params: Dictionary, out: Dictionary) -> void:
	var timeout_ms: int = maxi(1, int(params.get("timeoutMs", 10000)))
	var min_wait_ms: int = maxi(0, int(params.get("minWaitMs", 0)))
	var until: Dictionary = params.get("until", {})
	if min_wait_ms > 0:
		await get_tree().create_timer(float(min_wait_ms) / 1000.0).timeout
	var ok: bool = await _wait_until(until, timeout_ms)
	if not ok:
		_fail(out, "TIMEOUT", "wait condition timeout")


func _before_step(action: String, params: Dictionary) -> void:
	if _step_pre_delay_ms <= 0:
		return
	# 预延迟仅用于可视交互步骤，避免在验证/存档/状态读取期间引入额外运行时长
	if action != "click" and action != "dragCamera":
		return
	var marker_layer := CanvasLayer.new()
	marker_layer.layer = 200
	var marker := ColorRect.new()
	marker.size = Vector2(14, 14)
	marker.color = Color(1.0, 0.1, 0.1, 0.9)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p: Vector2 = _preview_position_for_action(action, params)
	marker.position = p - marker.size * 0.5
	marker_layer.add_child(marker)
	get_tree().root.add_child(marker_layer)
	await get_tree().create_timer(float(_step_pre_delay_ms) / 1000.0).timeout
	if is_instance_valid(marker_layer):
		marker_layer.queue_free()


func _preview_position_for_action(action: String, params: Dictionary) -> Vector2:
	var vp: Viewport = get_tree().root.get_viewport()
	var center: Vector2 = vp.get_visible_rect().size * 0.5
	if action == "click":
		var target: Dictionary = params.get("target", {})
		var node: Node = _resolve_target(target)
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


func _handle_screenshot(params: Dictionary, out: Dictionary) -> void:
	var shot_name: String = str(params.get("name", "shot"))
	var safe_name: String = shot_name.replace(" ", "_")
	var path: String = "user://test_screenshots/%s.png" % safe_name
	_ensure_dir("user://test_screenshots")
	var tex: Texture2D = get_viewport().get_texture()
	if tex == null:
		_fail(out, "SCREENSHOT_FAILED", "viewport texture is null")
		return
	var img: Image = tex.get_image()
	if img == null:
		_fail(out, "SCREENSHOT_FAILED", "viewport image is null")
		return
	var err: Error = img.save_png(path)
	if err != OK:
		_fail(out, "SCREENSHOT_FAILED", "save_png failed: %s" % str(err))
		return
	out["screenshot"] = path
	out["data"] = {"path": path}


func _handle_query_tree(params: Dictionary, out: Dictionary) -> void:
	var root_path: String = str(params.get("rootPath", "/root"))
	var depth: int = maxi(0, int(params.get("depth", 3)))
	var root_node: Node = get_node_or_null(root_path) if root_path != "/root" else get_tree().root
	if root_node == null:
		_fail(out, "TARGET_NOT_FOUND", "queryTree root not found: %s" % root_path)
		return
	out["data"] = {"tree": _dump_tree(root_node, depth)}


func _handle_query_node(params: Dictionary, out: Dictionary) -> void:
	var node_path: String = str(params.get("path", ""))
	if node_path.is_empty():
		_fail(out, "INVALID_ARGUMENT", "queryNode requires path")
		return
	var node: Node = get_node_or_null(node_path)
	if node == null:
		_fail(out, "TARGET_NOT_FOUND", "node not found: %s" % node_path)
		return
	var props: Array = params.get("properties", [])
	var data: Dictionary = {"path": str(node.get_path()), "class": node.get_class()}
	for p in props:
		var key: String = str(p)
		data[key] = node.get(key)
	out["data"] = data


func _handle_get_state(params: Dictionary, out: Dictionary) -> void:
	var gm: Node2D = _get_game_main()
	if gm == null:
		_fail(out, "GAME_MAIN_NOT_FOUND", "game main not found")
		return
	var keys: Array = params.get("keys", [])
	var data: Dictionary = {}
	for k in keys:
		var key: String = str(k)
		match key:
			"room_clean_status":
				var rid: String = str(params.get("roomId", ""))
				data[key] = _get_room_clean_status(gm, rid)
			"room_clean_progress":
				var rid_progress: String = str(params.get("roomId", ""))
				data[key] = _get_room_clean_progress(gm, rid_progress)
			"build_status":
				var rid_build: String = str(params.get("roomId", ""))
				data[key] = _get_build_status(gm, rid_build)
			"resources":
				if gm.has_method("_get_player_resources"):
					data[key] = _canonical_resources(gm.call("_get_player_resources"))
			"cognition_amount":
				var ui_main: Node = gm.get_node_or_null("UIMain")
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
				data[key] = _build_settlement_clock()
			"resource_ledger":
				data[key] = _build_resource_ledger(gm)
			"tree_paused":
				var tree := get_tree()
				data[key] = bool(tree and tree.paused)
			"game_speed_multiplier":
				if GameTime and ("speed_multiplier" in GameTime):
					data[key] = float(GameTime.speed_multiplier)
				else:
					data[key] = null
			"selected_room_index":
				data[key] = int(gm.get("_selected_room_index"))
			"selected_room_id":
				var selected_index: int = int(gm.get("_selected_room_index"))
				var rooms: Array = gm.get("_rooms")
				if selected_index >= 0 and selected_index < rooms.size():
					var room: ArchivesRoomInfo = rooms[selected_index]
					data[key] = room.id if room.id != "" else room.json_room_id
				else:
					data[key] = ""
			"exploration_overlay_visible":
				var overlay: CanvasLayer = gm.get("_exploration_map_overlay")
				data[key] = bool(overlay and overlay.visible)
			_:
				data[key] = null
	out["data"] = data


func _build_settlement_clock() -> Dictionary:
	var total_hours: float = 0.0
	if GameTime and GameTime.has_method("get_total_hours"):
		total_hours = float(GameTime.get_total_hours())
	var settled_ticks: int = int(floor(total_hours))
	var settled_hours: float = float(settled_ticks)
	var unsettled_fraction_hours: float = total_hours - settled_hours
	return {
		"tick_hours": 1.0,
		"total_hours": total_hours,
		"settled_ticks": settled_ticks,
		"settled_hours": settled_hours,
		"unsettled_fraction_hours": unsettled_fraction_hours,
	}


func _build_resource_ledger(gm: Node2D) -> Dictionary:
	if not gm.has_method("_get_player_resources"):
		return {}
	var current: Dictionary = _canonical_resources(gm.call("_get_player_resources"))
	if not _resource_probe_initialized:
		_resource_probe_initialized = true
		_resource_probe_baseline = current.duplicate(true)
		_resource_probe_last = current.duplicate(true)
	var delta_from_baseline: Dictionary = _resource_delta(_resource_probe_baseline, current)
	var delta_from_last: Dictionary = _resource_delta(_resource_probe_last, current)
	_resource_probe_last = current.duplicate(true)
	return {
		"baseline": _resource_probe_baseline.duplicate(true),
		"current": current.duplicate(true),
		"delta_from_baseline": delta_from_baseline,
		"delta_from_last": delta_from_last,
	}


func _canonical_resources(raw: Variant) -> Dictionary:
	var src: Dictionary = raw if raw is Dictionary else {}
	return {
		"cognition": src.get("cognition"),
		"computation": src.get("computation"),
		"willpower": src.get("willpower"),
		"permission": src.get("permission"),
		"info": src.get("info"),
		"truth": src.get("truth"),
		"researcher": src.get("researcher"),
		"labor": src.get("labor", 0),
		"eroded": src.get("eroded", 0),
		"investigator": src.get("investigator", 0),
	}


func _resource_delta(old_value: Dictionary, new_value: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var keys: Array = []
	for key in old_value.keys():
		if not keys.has(key):
			keys.append(key)
	for key in new_value.keys():
		if not keys.has(key):
			keys.append(key)
	for key in keys:
		var a: Variant = old_value.get(key, null)
		var b: Variant = new_value.get(key, null)
		if a is int or a is float:
			if b is int or b is float:
				out[key] = float(b) - float(a)
			else:
				out[key] = null
		else:
			out[key] = null
	return out


func _handle_export_ui_spec(params: Dictionary, out: Dictionary) -> void:
	var target: Dictionary = params.get("target", {})
	var spec_name: String = str(params.get("name", "ui_spec"))
	var node: Node = _resolve_target(target)
	if node == null:
		_fail(out, "TARGET_NOT_FOUND", "exportUiSpec target not found")
		return
	var spec: Dictionary = {"root_path": str(node.get_path()), "controls": []}
	_collect_controls(node, spec["controls"])
	_ensure_dir(_cmd_dir)
	var path: String = "%s/%s.json" % [_cmd_dir, spec_name]
	_write_json(path, spec)
	out["data"] = {"path": path, "count": (spec["controls"] as Array).size()}


func _handle_check(params: Dictionary, out: Dictionary) -> void:
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
				_handle_get_state({"keys": keys, "roomId": params.get("roomId", "")}, state_out)
				if state_out.get("status", "ok") != "ok":
					_fail(out, "CHECK_FAILED", "logic_state state query failed")
					return
				var all_match := true
				for k in keys:
					if state_out["data"].get(k) != expect.get(k):
						all_match = false
						break
				if all_match:
					break
				if Time.get_ticks_msec() > deadline:
					_fail(out, "CHECK_FAILED", "logic_state mismatch for %s" % (keys[0] if keys.size() > 0 else "unknown"))
					return
				await get_tree().create_timer(0.05).timeout
		"visual_hard":
			if expect.has("nodeVisible"):
				var target: Dictionary = {"testId": str(expect.get("nodeVisible", ""))}
				var node: Node = _resolve_target(target)
				if not (node is CanvasItem and (node as CanvasItem).visible):
					_fail(out, "CHECK_FAILED", "expected node visible: %s" % str(expect.get("nodeVisible", "")))
					return
			if expect.has("btnDisabled"):
				var btn_target: Dictionary = {"testId": str(expect.get("btnDisabled", ""))}
				var btn_node: Node = _resolve_target(btn_target)
				if not (btn_node is BaseButton and (btn_node as BaseButton).disabled):
					_fail(out, "CHECK_FAILED", "expected button disabled: %s" % str(expect.get("btnDisabled", "")))
					return
		_:
			_fail(out, "INVALID_ARGUMENT", "unsupported check kind: %s" % kind)
			return
	out["data"] = {"kind": kind, "expect": expect}


func _handle_save_game(_params: Dictionary, out: Dictionary) -> void:
	var gm: Node2D = _get_game_main()
	if gm == null:
		_fail(out, "GAME_MAIN_NOT_FOUND", "game main not found")
		return
	if not gm.has_method("save_current_slot_quiet"):
		_fail(out, "UNSUPPORTED_TARGET", "game main has no save_current_slot_quiet")
		return
	gm.call("save_current_slot_quiet")
	out["data"] = {"saved": true}


func _handle_set_game_time_speed(params: Dictionary, out: Dictionary) -> void:
	var speed: float = float(params.get("speed", 1.0))
	speed = maxf(0.1, speed)
	if GameTime == null:
		_fail(out, "GAME_TIME_NOT_FOUND", "GameTime autoload not found")
		return
	GameTime.speed_multiplier = speed
	GameTime.is_flowing = true
	if GameTime.get_tree():
		GameTime.get_tree().paused = false
	out["data"] = {"speed_multiplier": speed}


func _handle_set_global_pause(params: Dictionary, out: Dictionary) -> void:
	var paused: bool = bool(params.get("paused", true))
	var tree := get_tree()
	if tree == null:
		_fail(out, "TREE_NOT_FOUND", "scene tree not found")
		return
	tree.paused = paused
	out["data"] = {"tree_paused": tree.paused}


func _handle_set_fault(params: Dictionary, out: Dictionary) -> void:
	var gm: Node2D = _get_game_main()
	if gm == null:
		_fail(out, "GAME_MAIN_NOT_FOUND", "game main not found")
		return
	var fault_name: String = str(params.get("name", "")).strip_edges()
	if fault_name.is_empty():
		_fail(out, "INVALID_ARGUMENT", "setFault requires name")
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


func _wait_until(until: Dictionary, timeout_ms: int) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() <= deadline:
		if _eval_wait_condition(until):
			return true
		await get_tree().create_timer(0.05).timeout
	return _eval_wait_condition(until)


func _eval_wait_condition(until: Dictionary) -> bool:
	if until.has("scene"):
		var scene_name: String = str(until.get("scene", ""))
		var current_scene: Node = get_tree().current_scene
		if current_scene == null:
			return false
		return scene_name in str(current_scene.scene_file_path) or scene_name in current_scene.name
	if until.has("nodeVisible"):
		var target: Dictionary = until.get("nodeVisible", {})
		var node: Node = _resolve_target(target)
		return _is_clickable_canvas_item(node)
	if until.has("stateEquals"):
		var expect: Dictionary = until.get("stateEquals", {})
		var key: String = str(expect.get("key", ""))
		var value: Variant = expect.get("value", null)
		if key.is_empty():
			return false
		var state_out: Dictionary = {"status": "ok", "data": {}}
		_handle_get_state({"keys": [key], "roomId": expect.get("roomId", "")}, state_out)
		if state_out.get("status", "ok") != "ok":
			return false
		return state_out["data"].get(key) == value
	return false


func _resolve_target(target: Dictionary) -> Node:
	if target.has("nodePath"):
		return get_node_or_null(str(target.get("nodePath", "")))
	if target.has("testId"):
		return _find_by_test_id(get_tree().root, str(target.get("testId", "")))
	if target.has("text"):
		return _find_by_text(get_tree().root, str(target.get("text", "")))
	return null


func _find_by_test_id(node: Node, test_id: String) -> Node:
	if test_id.is_empty():
		return null
	if node.has_meta("test_id") and str(node.get_meta("test_id")) == test_id:
		return node
	for child in node.get_children():
		var hit: Node = _find_by_test_id(child, test_id)
		if hit != null:
			return hit
	return null


func _find_by_text(node: Node, text: String) -> Node:
	if text.is_empty():
		return null
	if node is Label and (node as Label).text == text:
		return node
	if node is Button and (node as Button).text == text:
		return node
	for child in node.get_children():
		var hit: Node = _find_by_text(child, text)
		if hit != null:
			return hit
	return null


func _collect_controls(node: Node, out: Array) -> void:
	if node is Control:
		var c: Control = node as Control
		out.append({
			"path": str(c.get_path()),
			"class": c.get_class(),
			"visible": c.visible,
			"position": [c.position.x, c.position.y],
			"size": [c.size.x, c.size.y],
			"global_position": [c.global_position.x, c.global_position.y],
			"meta_test_id": str(c.get_meta("test_id")) if c.has_meta("test_id") else "",
		})
	for child in node.get_children():
		_collect_controls(child, out)


func _dump_tree(node: Node, depth: int) -> Dictionary:
	var item: Dictionary = {
		"name": node.name,
		"path": str(node.get_path()),
		"class": node.get_class(),
	}
	if node is CanvasItem:
		item["visible"] = (node as CanvasItem).visible
	if depth <= 0:
		item["children"] = []
		return item
	var children: Array = []
	for child in node.get_children():
		children.append(_dump_tree(child, depth - 1))
	item["children"] = children
	return item


func _get_game_main() -> Node2D:
	var current_scene: Node = get_tree().current_scene
	if current_scene is Node2D and current_scene.name == "GameMain":
		return current_scene as Node2D
	return get_tree().root.get_node_or_null("GameMain") as Node2D


func _get_room_clean_status(gm: Node2D, room_id: String) -> String:
	var room_index: int = _find_room_index(gm, room_id)
	if room_index < 0:
		return "unknown"
	var room: ArchivesRoomInfo = gm.get("_rooms")[room_index]
	var in_progress: Dictionary = gm.get("_cleanup_rooms_in_progress")
	if in_progress.has(room_index):
		return "cleaning"
	if int(room.clean_status) == ArchivesRoomInfo.CleanStatus.CLEANED:
		return "cleaned"
	return "uncleaned"


func _get_room_clean_progress(gm: Node2D, room_id: String) -> float:
	var room_index: int = _find_room_index(gm, room_id)
	if room_index < 0:
		return 0.0
	var in_progress: Dictionary = gm.get("_cleanup_rooms_in_progress")
	if not in_progress.has(room_index):
		return 0.0
	var v: Dictionary = in_progress.get(room_index, {})
	return float(v.get("progress", 0.0))


func _get_build_status(gm: Node2D, room_id: String) -> String:
	var room_index: int = _find_room_index(gm, room_id)
	if room_index < 0:
		return "unknown"
	var in_progress: Dictionary = gm.get("_construction_rooms_in_progress")
	if in_progress.has(room_index):
		return "building"
	var room: ArchivesRoomInfo = gm.get("_rooms")[room_index]
	return "built" if int(room.zone_type) != 0 else "not_built"


func _find_room_index(gm: Node2D, room_id: String) -> int:
	var rooms: Array = gm.get("_rooms")
	if room_id.is_empty():
		return -1
	for i in rooms.size():
		var room: ArchivesRoomInfo = rooms[i]
		var rid: String = room.id if room.id != "" else room.json_room_id
		if rid == room_id:
			return i
	return -1


func _has_flag(flag: String) -> bool:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg).strip_edges().trim_prefix("\"").trim_suffix("\"")
		if text == flag or text.begins_with("%s=" % flag):
			return true
	return false


func _get_user_arg_value(key: String, default_value: String = "") -> String:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg).strip_edges().trim_prefix("\"").trim_suffix("\"")
		var prefix := "%s=" % key
		if text.begins_with(prefix):
			return text.substr(prefix.length())
	return default_value


func _sanitize_session(raw_value: String) -> String:
	var source := raw_value.strip_edges()
	if source.is_empty():
		return "default"
	var out := ""
	for i in source.length():
		var ch := source.unicode_at(i)
		var ok := (
			(ch >= 48 and ch <= 57) # 0-9
			or (ch >= 65 and ch <= 90) # A-Z
			or (ch >= 97 and ch <= 122) # a-z
			or ch == 45 # -
			or ch == 46 # .
			or ch == 95 # _
		)
		out += source.substr(i, 1) if ok else "_"
	return out if not out.is_empty() else "default"


func _ensure_driver_dir() -> void:
	_ensure_dir(_cmd_dir)
	DirAccess.remove_absolute(_cmd_file)
	DirAccess.remove_absolute(_resp_file)


func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func _write_json(path: String, payload: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload))


func _fail(out: Dictionary, code: String, message: String) -> void:
	out["status"] = "error"
	out["error"] = {"code": code, "message": message}

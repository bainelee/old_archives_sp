extends RefCounted

## TestDriver 同步工具：解析目标、场景树、房间状态、JSON、资源探针快照等（无 await）

var _host: Node


func _init(host: Node) -> void:
	_host = host


func fail_out(out: Dictionary, code: String, message: String) -> void:
	out["status"] = "error"
	out["error"] = {"code": code, "message": message}


func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func write_json(path: String, payload: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload))


func ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)


func has_flag(flag: String) -> bool:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg).strip_edges().trim_prefix("\"").trim_suffix("\"")
		if text == flag or text.begins_with("%s=" % flag):
			return true
	return false


func get_user_arg_value(key: String, default_value: String = "") -> String:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg).strip_edges().trim_prefix("\"").trim_suffix("\"")
		var prefix := "%s=" % key
		if text.begins_with(prefix):
			return text.substr(prefix.length())
	return default_value


func sanitize_session(raw_value: String) -> String:
	var source := raw_value.strip_edges()
	if source.is_empty():
		return "default"
	var out := ""
	for i in source.length():
		var ch := source.unicode_at(i)
		var ok := (
			(ch >= 48 and ch <= 57)
			or (ch >= 65 and ch <= 90)
			or (ch >= 97 and ch <= 122)
			or ch == 45
			or ch == 46
			or ch == 95
		)
		out += source.substr(i, 1) if ok else "_"
	return out if not out.is_empty() else "default"


func safe_node_path(node: Node) -> String:
	if node == null:
		return ""
	return str(node.get_path()) if node.is_inside_tree() else ""


func is_clickable_canvas_item(node: Node) -> bool:
	if not (node is CanvasItem):
		return true
	var canvas_item: CanvasItem = node as CanvasItem
	return canvas_item.is_visible_in_tree()


func get_game_main() -> Node2D:
	var current_scene: Node = _host.get_tree().current_scene
	if current_scene is Node2D and current_scene.name == "GameMain":
		return current_scene as Node2D
	return _host.get_tree().root.get_node_or_null("GameMain") as Node2D


func resolve_target(target: Dictionary) -> Node:
	if target.has("nodePath"):
		return _host.get_node_or_null(str(target.get("nodePath", "")))
	if target.has("testId"):
		return find_by_test_id(_host.get_tree().root, str(target.get("testId", "")))
	if target.has("text"):
		return find_by_text(_host.get_tree().root, str(target.get("text", "")))
	return null


func find_by_test_id(node: Node, test_id: String) -> Node:
	if test_id.is_empty():
		return null
	if node.has_meta("test_id") and str(node.get_meta("test_id")) == test_id:
		return node
	for child in node.get_children():
		var hit: Node = find_by_test_id(child, test_id)
		if hit != null:
			return hit
	return null


func find_by_text(node: Node, text: String) -> Node:
	if text.is_empty():
		return null
	if node is Label and (node as Label).text == text:
		return node
	if node is Button and (node as Button).text == text:
		return node
	for child in node.get_children():
		var hit: Node = find_by_text(child, text)
		if hit != null:
			return hit
	return null


func collect_controls(node: Node, out: Array) -> void:
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
		collect_controls(child, out)


func dump_tree(node: Node, depth: int) -> Dictionary:
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
		children.append(dump_tree(child, depth - 1))
	item["children"] = children
	return item


func find_room_index_by_node_name(gm: Node2D, node_name: String) -> int:
	var rooms: Array = gm.get_game_rooms()
	for i in rooms.size():
		var room: ArchivesRoomInfo = rooms[i]
		var rid: String = room.id if room.id != "" else room.json_room_id
		if rid == node_name:
			return i
	return -1


func find_room_index(gm: Node2D, room_id: String) -> int:
	var rooms: Array = gm.get_game_rooms()
	if room_id.is_empty():
		return -1
	for i in rooms.size():
		var room: ArchivesRoomInfo = rooms[i]
		var rid: String = room.id if room.id != "" else room.json_room_id
		if rid == room_id:
			return i
	return -1


func get_room_clean_status(gm: Node2D, room_id: String) -> String:
	var room_index: int = find_room_index(gm, room_id)
	if room_index < 0:
		return "unknown"
	var room: ArchivesRoomInfo = gm.get_game_rooms()[room_index]
	var in_progress: Dictionary = gm.get("_cleanup_rooms_in_progress")
	if in_progress.has(room_index):
		return "cleaning"
	if int(room.clean_status) == ArchivesRoomInfo.CleanStatus.CLEANED:
		return "cleaned"
	return "uncleaned"


func get_room_clean_progress(gm: Node2D, room_id: String) -> float:
	var room_index: int = find_room_index(gm, room_id)
	if room_index < 0:
		return 0.0
	var in_progress: Dictionary = gm.get("_cleanup_rooms_in_progress")
	if not in_progress.has(room_index):
		return 0.0
	var v: Dictionary = in_progress.get(room_index, {})
	return float(v.get("progress", 0.0))


func get_build_status(gm: Node2D, room_id: String) -> String:
	var room_index: int = find_room_index(gm, room_id)
	if room_index < 0:
		return "unknown"
	var in_progress: Dictionary = gm.get("_construction_rooms_in_progress")
	if in_progress.has(room_index):
		return "building"
	var room: ArchivesRoomInfo = gm.get_game_rooms()[room_index]
	return "built" if int(room.zone_type) != 0 else "not_built"


func canonical_resources(raw: Variant) -> Dictionary:
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


func resource_delta(old_value: Dictionary, new_value: Dictionary) -> Dictionary:
	var out_dict: Dictionary = {}
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
				out_dict[key] = float(b) - float(a)
			else:
				out_dict[key] = null
		else:
			out_dict[key] = null
	return out_dict


func build_settlement_clock() -> Dictionary:
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


func build_resource_ledger(host: Node, gm: Node2D) -> Dictionary:
	if not gm.has_method("_get_player_resources"):
		return {}
	var current: Dictionary = canonical_resources(gm.call("_get_player_resources"))
	if not bool(host.get("resource_probe_initialized")):
		host.set("resource_probe_initialized", true)
		host.set("resource_probe_baseline", current.duplicate(true))
		host.set("resource_probe_last", current.duplicate(true))
	var baseline: Dictionary = host.get("resource_probe_baseline")
	var last: Dictionary = host.get("resource_probe_last")
	var delta_from_baseline: Dictionary = resource_delta(baseline, current)
	var delta_from_last: Dictionary = resource_delta(last, current)
	host.set("resource_probe_last", current.duplicate(true))
	return {
		"baseline": baseline.duplicate(true),
		"current": current.duplicate(true),
		"delta_from_baseline": delta_from_baseline,
		"delta_from_last": delta_from_last,
	}

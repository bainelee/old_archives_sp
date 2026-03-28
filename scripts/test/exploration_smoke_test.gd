extends Node

const ExplorationServiceScript := preload("res://scripts/game/exploration/exploration_service.gd")
const ExplorationRulesScript := preload("res://scripts/game/exploration/exploration_rules.gd")
const CodecScript := preload("res://scripts/game/exploration/exploration_state_codec.gd")


func _ready() -> void:
	var service = ExplorationServiceScript.new()
	service.init_default_state()
	service.ensure_first_open_initialized()

	var config: Dictionary = service.get_config_readonly()
	var state: Dictionary = service.get_runtime_state_readonly()

	var hub: String = ExplorationRulesScript.get_hub_region_id(config)
	var initial_ids: Array[String] = ExplorationRulesScript.get_initial_unlock_region_ids(config)
	var expected_dbg_count: int = ExplorationRulesScript.get_default_debug_investigator_count(config)

	if not bool(state.get(CodecScript.KEY_FIRST_OPEN_DONE, false)):
		_fail("first_open_done should be true after initialization")
		return

	var unlocked: Array[String] = CodecScript.normalize_string_id_array(state.get(CodecScript.KEY_UNLOCKED_REGION_IDS, []))
	var explored: Array[String] = CodecScript.normalize_string_id_array(state.get(CodecScript.KEY_EXPLORED_REGION_IDS, []))
	if not unlocked.has(hub):
		_fail("hub should be unlocked")
		return
	if not explored.has(hub):
		_fail("hub should be explored")
		return
	for rid in initial_ids:
		if not unlocked.has(rid):
			_fail("missing initial unlocked region: %s" % rid)
			return
	if int(state.get(CodecScript.KEY_DEBUG_INVESTIGATOR_POOL, -1)) != expected_dbg_count:
		_fail("debug investigator pool mismatch")
		return

	var save_blob: Dictionary = service.to_save_dict()
	var service_restored = ExplorationServiceScript.new()
	service_restored.load_from_save_dict(save_blob)
	var restored: Dictionary = service_restored.get_runtime_state_readonly()
	if CodecScript.normalize_string_id_array(restored.get(CodecScript.KEY_UNLOCKED_REGION_IDS, [])) != unlocked:
		_fail("restored unlocked list mismatch")
		return
	if CodecScript.normalize_string_id_array(restored.get(CodecScript.KEY_EXPLORED_REGION_IDS, [])) != explored:
		_fail("restored explored list mismatch")
		return

	var er: Dictionary = service.explore_region("white_cliff")
	if not bool(er.get("ok", false)):
		_fail("explore_region failed: %s" % str(er.get("reason", "")))
		return
	service.tick(30.0)
	var st2: Dictionary = service.get_runtime_state_readonly()
	var explored_after: Array[String] = CodecScript.normalize_string_id_array(st2.get(CodecScript.KEY_EXPLORED_REGION_IDS, []))
	if not explored_after.has("white_cliff"):
		_fail("white_cliff should be explored after tick")
		return
	var unlocked_after: Array[String] = CodecScript.normalize_string_id_array(st2.get(CodecScript.KEY_UNLOCKED_REGION_IDS, []))
	if not unlocked_after.has("saint_river_afv"):
		_fail("neighbor saint_river_afv should unlock after white_cliff explored")
		return

	var s_mid = ExplorationServiceScript.new()
	s_mid.init_default_state()
	s_mid.ensure_first_open_initialized()
	var er2: Dictionary = s_mid.explore_region("durkin_mine")
	if not bool(er2.get("ok", false)):
		_fail("explore durkin_mine for mid-save: %s" % str(er2.get("reason", "")))
		return
	var blob_mid: Dictionary = s_mid.to_save_dict()
	var s_restore = ExplorationServiceScript.new()
	s_restore.load_from_save_dict(blob_mid)
	var st_mid: Dictionary = s_restore.get_runtime_state_readonly()
	var ex_mid: Variant = st_mid.get(CodecScript.KEY_EXPLORING_BY_REGION, {})
	if not (ex_mid is Dictionary) or not (ex_mid as Dictionary).has("durkin_mine"):
		_fail("restored state should keep durkin_mine exploring")
		return
	s_restore.tick(100.0)
	var st_fin: Dictionary = s_restore.get_runtime_state_readonly()
	var explored_fin: Array[String] = CodecScript.normalize_string_id_array(st_fin.get(CodecScript.KEY_EXPLORED_REGION_IDS, []))
	if not explored_fin.has("durkin_mine"):
		_fail("durkin_mine should complete after restore+tick")
		return

	print("[ExplorationSmokeTest] PASS")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("[ExplorationSmokeTest] FAIL: %s" % message)
	get_tree().quit(1)

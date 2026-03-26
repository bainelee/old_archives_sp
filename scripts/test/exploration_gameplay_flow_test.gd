extends Node

const ExplorationServiceScript := preload("res://scripts/game/exploration/exploration_service.gd")
const ExplorationRulesScript := preload("res://scripts/game/exploration/exploration_rules.gd")
const CodecScript := preload("res://scripts/game/exploration/exploration_state_codec.gd")

const SHOT_STEP_1 := "user://test_screenshots/flow_exploration_step_01_bootstrap.png"
const SHOT_STEP_2 := "user://test_screenshots/flow_exploration_step_02_enter_map.png"
const SHOT_STEP_3 := "user://test_screenshots/flow_exploration_step_03_explore_action.png"

const MARKER_PREFIX := "[GameplayFlowV1]"

var _canvas: CanvasLayer
var _root: Control
var _card: PanelContainer
var _title_label: Label
var _step_label: Label
var _detail_label: Label
var _badge_label: Label


func _enter_tree() -> void:
	_build_debug_canvas()


func _ready() -> void:
	_update_debug_canvas(
		"Step 1/3 Bootstrap",
		"Load exploration service and initialize state.",
		"BOOTSTRAP"
	)
	await _render_settle()

	_mark("STEP bootstrap PASS")
	_capture_step(SHOT_STEP_1)

	var service = ExplorationServiceScript.new()
	service.init_default_state()
	service.ensure_first_open_initialized()
	var config: Dictionary = service.get_config_readonly()
	var state: Dictionary = service.get_runtime_state_readonly()

	var hub: String = ExplorationRulesScript.get_hub_region_id(config)
	var unlocked: Array[String] = CodecScript.normalize_string_id_array(state.get(CodecScript.KEY_UNLOCKED_REGION_IDS, []))
	var explored: Array[String] = CodecScript.normalize_string_id_array(state.get(CodecScript.KEY_EXPLORED_REGION_IDS, []))
	if not bool(state.get(CodecScript.KEY_FIRST_OPEN_DONE, false)):
		_fail("first_open_done expected true after map enter")
		return
	if not unlocked.has(hub) or not explored.has(hub):
		_fail("hub should be unlocked and explored after first enter")
		return

	_update_debug_canvas(
		"Step 2/3 Enter Exploration Map",
		"Hub=%s | unlocked=%d | explored=%d" % [hub, unlocked.size(), explored.size()],
		"MAP READY"
	)
	await _render_settle()

	_mark("STEP enter_exploration_map PASS")
	_capture_step(SHOT_STEP_2)

	var chosen_region := _pick_next_region_to_explore(config, unlocked, explored, hub)
	if chosen_region.is_empty():
		_fail("no candidate region found for exploration action")
		return

	# 使用 save blob 进行状态迁移，模拟一次探索动作被提交并可恢复。
	var save_blob: Dictionary = service.to_save_dict()
	var explored_save: Array[String] = CodecScript.normalize_string_id_array(
		save_blob.get(CodecScript.KEY_EXPLORED_REGION_IDS, [])
	)
	if not explored_save.has(chosen_region):
		explored_save.append(chosen_region)
	save_blob[CodecScript.KEY_EXPLORED_REGION_IDS] = explored_save
	service.load_from_save_dict(save_blob)

	var after_action: Dictionary = service.get_runtime_state_readonly()
	var explored_after: Array[String] = CodecScript.normalize_string_id_array(
		after_action.get(CodecScript.KEY_EXPLORED_REGION_IDS, [])
	)
	if not explored_after.has(chosen_region):
		_fail("exploration action result not persisted for region: %s" % chosen_region)
		return

	_update_debug_canvas(
		"Step 3/3 Execute Exploration Action",
		"Simulated explore region=%s | explored_after=%d" % [chosen_region, explored_after.size()],
		"ACTION COMMIT"
	)
	await _render_settle()

	_mark("STEP execute_exploration_action PASS region=%s" % chosen_region)
	_capture_step(SHOT_STEP_3)
	_mark("FLOW PASS")
	get_tree().quit(0)


func _pick_next_region_to_explore(
	config: Dictionary,
	unlocked: Array[String],
	explored: Array[String],
	hub_region: String
) -> String:
	for region_id in unlocked:
		if region_id == hub_region:
			continue
		if not ExplorationRulesScript.catalog_has_region_id(config, region_id):
			continue
		if explored.has(region_id):
			continue
		return region_id
	for region_id in unlocked:
		if region_id != hub_region and ExplorationRulesScript.catalog_has_region_id(config, region_id):
			return region_id
	return ""


func _capture_step(path: String) -> void:
	_ensure_parent_dir(path)
	var tex := get_viewport().get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return
	img.save_png(path)


func _build_debug_canvas() -> void:
	if _canvas != null:
		return
	_canvas = CanvasLayer.new()
	_canvas.layer = 100
	add_child(_canvas)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(_root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.10, 0.12, 0.16, 1.0)
	_root.add_child(bg)

	_card = PanelContainer.new()
	_card.position = Vector2(120, 120)
	_card.size = Vector2(1100, 460)
	_root.add_child(_card)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.14, 0.17, 0.23, 1.0)
	panel_style.border_color = Color(0.45, 0.82, 1.0, 1.0)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	_card.add_theme_stylebox_override("panel", panel_style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.position = Vector2(28, 28)
	content.size = Vector2(1040, 400)
	_card.add_child(content)

	_title_label = Label.new()
	_title_label.text = "Exploration Gameplay Flow v1"
	_title_label.add_theme_font_size_override("font_size", 34)
	content.add_child(_title_label)

	_step_label = Label.new()
	_step_label.text = "Step -"
	_step_label.add_theme_font_size_override("font_size", 26)
	content.add_child(_step_label)

	_detail_label = Label.new()
	_detail_label.text = "-"
	_detail_label.add_theme_font_size_override("font_size", 22)
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_detail_label)

	_badge_label = Label.new()
	_badge_label.text = "PENDING"
	_badge_label.add_theme_font_size_override("font_size", 24)
	content.add_child(_badge_label)


func _update_debug_canvas(step_title: String, detail: String, badge: String) -> void:
	if _step_label == null or _detail_label == null or _badge_label == null:
		return
	_step_label.text = step_title
	_detail_label.text = detail
	_badge_label.text = "Status: %s" % badge


func _render_settle() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _mark(message: String) -> void:
	print("%s %s" % [MARKER_PREFIX, message])


func _fail(message: String) -> void:
	push_error("%s FAIL: %s" % [MARKER_PREFIX, message])
	get_tree().quit(1)


func _ensure_parent_dir(path: String) -> void:
	var dir_path := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)


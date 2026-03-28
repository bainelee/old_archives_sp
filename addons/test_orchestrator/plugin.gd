@tool
extends EditorPlugin

const CLI_PATH := "res://tools/game-test-runner/core/cli.py"
const SUITE_PATH := "res://tools/game-test-runner/core/regression_suite.py"
const FLOW_PATH := "res://tools/game-test-runner/core/flow_runner.py"
const DEFAULT_GAMEPLAY_FLOW_FILE := "res://flows/build_clean_wait_linked_acceptance.json"
const RUNS_DIR_REL := "res://artifacts/test-runs"
const FlowTimelineUtils := preload("res://addons/test_orchestrator/flow_timeline_utils.gd")
const PluginHistoryController := preload("res://addons/test_orchestrator/plugin_history_controller.gd")
const PluginLiveFlowController := preload("res://addons/test_orchestrator/plugin_live_flow_controller.gd")
const PluginUiBuilder := preload("res://addons/test_orchestrator/plugin_ui_builder.gd")
const SETTINGS_GODOT_BIN := "test_orchestrator/godot_bin"
const SETTINGS_DRY_RUN := "test_orchestrator/dry_run"
const SETTINGS_LAST_SUITE_ROOT := "test_orchestrator/last_suite_root"
const LIVE_FLOW_POLL_SEC := 0.8

var _dock: VBoxContainer
var _status_label: Label
var _artifact_label: Label
var _godot_bin_input: LineEdit
var _dry_run_checkbox: CheckBox
var _file_dialog: FileDialog
var _history_list: ItemList
var _history_entries: Array = []
var _editor_settings: EditorSettings
var _last_suite_root := ""
var _suite_label: Label
var _failure_summary_label: Label
var _flow_steps_list: ItemList
var _flow_step_detail_label: Label
var _flow_step_evidence_label: Label
var _flow_step_preview: TextureRect
var _flow_step_preview_label: Label
var _flow_step_entries: Array = []
var _live_poll_timer: Timer
var _live_flow_pid := -1
var _live_flow_active := false
var _live_flow_started_unix := 0.0
var _live_flow_run_id := ""
var _live_flow_run_abs := ""
var _live_flow_expected_steps: Array = []


func _enter_tree() -> void:
	_editor_settings = get_editor_interface().get_editor_settings()
	_dock = VBoxContainer.new()
	_dock.name = "Test Orchestrator"

	var title := Label.new()
	title.text = "Game Test Runner"
	_dock.add_child(title)

	var path_row := HBoxContainer.new()
	var path_label := Label.new()
	path_label.text = "Godot Bin:"
	path_row.add_child(path_label)

	_godot_bin_input = LineEdit.new()
	_godot_bin_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_godot_bin_input.placeholder_text = "Optional: C:/.../Godot_v4.6.1-stable_win64.exe"
	path_row.add_child(_godot_bin_input)

	var browse_button := Button.new()
	browse_button.text = "Browse"
	browse_button.pressed.connect(_on_browse_pressed)
	path_row.add_child(browse_button)
	_dock.add_child(path_row)

	_dry_run_checkbox = CheckBox.new()
	_dry_run_checkbox.text = "Dry Run"
	_dry_run_checkbox.button_pressed = true
	_dry_run_checkbox.toggled.connect(_on_dry_run_toggled)
	_dock.add_child(_dry_run_checkbox)

	var run_button := Button.new()
	run_button.text = "Run Exploration Smoke"
	run_button.pressed.connect(_on_run_exploration_smoke_pressed)
	_dock.add_child(run_button)

	var suite_button := Button.new()
	suite_button.text = "Run Quick Regression Suite"
	suite_button.pressed.connect(_on_run_quick_regression_suite_pressed)
	_dock.add_child(suite_button)

	var gameplay_flow_button := Button.new()
	gameplay_flow_button.text = "Run Gameplay Debug Flow"
	gameplay_flow_button.pressed.connect(_on_run_gameplay_debug_flow_pressed)
	_dock.add_child(gameplay_flow_button)

	var open_suite_button := Button.new()
	open_suite_button.text = "Open suite_report.json"
	open_suite_button.pressed.connect(_open_last_suite_report_json)
	_dock.add_child(open_suite_button)

	_suite_label = Label.new()
	_suite_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_suite_label.text = "Suite: -"
	_dock.add_child(_suite_label)

	var visual_row := HBoxContainer.new()
	var record_baseline_button := Button.new()
	record_baseline_button.text = "Record Visual Baseline"
	record_baseline_button.pressed.connect(_on_record_visual_baseline_pressed)
	visual_row.add_child(record_baseline_button)

	var run_visual_check_button := Button.new()
	run_visual_check_button.text = "Run Visual Check"
	run_visual_check_button.pressed.connect(_on_run_visual_check_pressed)
	visual_row.add_child(run_visual_check_button)
	_dock.add_child(visual_row)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.text = "Status: idle"
	_dock.add_child(_status_label)

	var copy_status_button := Button.new()
	copy_status_button.text = "Copy Status"
	copy_status_button.pressed.connect(_copy_status_text)
	_dock.add_child(copy_status_button)

	_artifact_label = Label.new()
	_artifact_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_artifact_label.text = "Artifacts: -"
	_dock.add_child(_artifact_label)

	var copy_artifact_button := Button.new()
	copy_artifact_button.text = "Copy Artifacts Path"
	copy_artifact_button.pressed.connect(_copy_artifact_text)
	_dock.add_child(copy_artifact_button)

	var sep := HSeparator.new()
	_dock.add_child(sep)

	var history_title := Label.new()
	history_title.text = "Recent Runs"
	_dock.add_child(history_title)

	_history_list = ItemList.new()
	_history_list.custom_minimum_size = Vector2(0, 140)
	_history_list.select_mode = ItemList.SELECT_SINGLE
	_history_list.item_selected.connect(_on_history_item_selected)
	_dock.add_child(_history_list)

	var history_actions := HBoxContainer.new()
	var refresh_button := Button.new()
	refresh_button.text = "Refresh"
	refresh_button.pressed.connect(_refresh_history)
	history_actions.add_child(refresh_button)

	var open_dir_button := Button.new()
	open_dir_button.text = "Open Folder"
	open_dir_button.pressed.connect(_open_selected_run_folder)
	history_actions.add_child(open_dir_button)

	var open_report_button := Button.new()
	open_report_button.text = "Open report.json"
	open_report_button.pressed.connect(_open_selected_report_json)
	history_actions.add_child(open_report_button)

	var open_flow_report_button := Button.new()
	open_flow_report_button.text = "Open flow_report.json"
	open_flow_report_button.pressed.connect(_open_selected_flow_report_json)
	history_actions.add_child(open_flow_report_button)

	var open_failure_summary_button := Button.new()
	open_failure_summary_button.text = "Open failure_summary.json"
	open_failure_summary_button.pressed.connect(_open_selected_failure_summary_json)
	history_actions.add_child(open_failure_summary_button)

	var open_step_timeline_button := Button.new()
	open_step_timeline_button.text = "Open step_timeline.json"
	open_step_timeline_button.pressed.connect(_open_selected_step_timeline_json)
	history_actions.add_child(open_step_timeline_button)

	var open_diff_button := Button.new()
	open_diff_button.text = "Open diff.png"
	open_diff_button.pressed.connect(_open_selected_diff_png)
	history_actions.add_child(open_diff_button)

	var open_diff_annotated_button := Button.new()
	open_diff_annotated_button.text = "Open diff_annotated.png"
	open_diff_annotated_button.pressed.connect(_open_selected_diff_annotated_png)
	history_actions.add_child(open_diff_annotated_button)
	_dock.add_child(history_actions)

	_failure_summary_label = Label.new()
	_failure_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_failure_summary_label.text = "Latest failure: -"
	_dock.add_child(_failure_summary_label)

	var flow_steps_title := Label.new()
	flow_steps_title.text = "Flow Steps (Timeline)"
	_dock.add_child(flow_steps_title)

	_flow_steps_list = ItemList.new()
	_flow_steps_list.custom_minimum_size = Vector2(0, 150)
	_flow_steps_list.select_mode = ItemList.SELECT_SINGLE
	_flow_steps_list.item_selected.connect(_on_flow_step_selected)
	_dock.add_child(_flow_steps_list)

	var flow_steps_actions := HBoxContainer.new()
	var open_step_evidence_button := Button.new()
	open_step_evidence_button.text = "Open Step Evidence"
	open_step_evidence_button.pressed.connect(_open_selected_step_evidence)
	flow_steps_actions.add_child(open_step_evidence_button)
	_dock.add_child(flow_steps_actions)

	_flow_step_detail_label = Label.new()
	_flow_step_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flow_step_detail_label.text = "Step detail: -"
	_dock.add_child(_flow_step_detail_label)

	_flow_step_evidence_label = Label.new()
	_flow_step_evidence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flow_step_evidence_label.text = "Step evidence: -"
	_dock.add_child(_flow_step_evidence_label)

	_flow_step_preview_label = Label.new()
	_flow_step_preview_label.text = "Step screenshot preview:"
	_dock.add_child(_flow_step_preview_label)

	_flow_step_preview = TextureRect.new()
	_flow_step_preview.custom_minimum_size = Vector2(0, 160)
	_flow_step_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_flow_step_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_dock.add_child(_flow_step_preview)

	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.title = "Select Godot Executable"
	_file_dialog.filters = PackedStringArray(["*.exe ; Executable"])
	_file_dialog.file_selected.connect(_on_godot_bin_selected)
	_dock.add_child(_file_dialog)

	_live_poll_timer = Timer.new()
	_live_poll_timer.one_shot = false
	_live_poll_timer.wait_time = LIVE_FLOW_POLL_SEC
	_live_poll_timer.timeout.connect(_on_live_poll_timeout)
	_dock.add_child(_live_poll_timer)

	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	_load_saved_preferences()
	_refresh_history()


func _exit_tree() -> void:
	if _live_poll_timer != null:
		_live_poll_timer.stop()
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null


func _on_browse_pressed() -> void:
	if _file_dialog != null:
		_file_dialog.popup_centered_ratio(0.7)


func _on_godot_bin_selected(path: String) -> void:
	if _godot_bin_input != null:
		_godot_bin_input.text = path
	_save_preferences()


func _on_dry_run_toggled(_pressed: bool) -> void:
	_save_preferences()


func _on_run_exploration_smoke_pressed() -> void:
	_run_scenario("exploration", "exploration_smoke", [])


func _on_record_visual_baseline_pressed() -> void:
	if _dry_run_checkbox != null and _dry_run_checkbox.button_pressed:
		_set_status("Status: fail - Visual baseline requires Dry Run off")
		return
	_run_scenario("visual", "visual_regression_probe", ["--record-baseline"])


func _on_run_visual_check_pressed() -> void:
	if _dry_run_checkbox != null and _dry_run_checkbox.button_pressed:
		_set_status("Status: fail - Visual check requires Dry Run off")
		return
	_run_scenario("visual", "visual_regression_probe", [])


func _on_run_quick_regression_suite_pressed() -> void:
	if _dry_run_checkbox != null and _dry_run_checkbox.button_pressed:
		_set_status("Status: fail - Quick suite requires Dry Run off")
		return
	var suite_abs := ProjectSettings.globalize_path(SUITE_PATH)
	if not FileAccess.file_exists(suite_abs):
		_set_status("Status: fail - missing regression_suite.py")
		return
	var project_root := ProjectSettings.globalize_path("res://")
	var godot_bin := ""
	if _godot_bin_input != null:
		godot_bin = _godot_bin_input.text.strip_edges()
	if godot_bin.is_empty():
		_set_status("Status: fail - Godot Bin required for quick suite")
		return
	var resolved_godot_bin := _resolve_godot_bin(godot_bin)
	if resolved_godot_bin.is_empty():
		_set_status("Status: fail - invalid Godot Bin for quick suite")
		return
	if _godot_bin_input != null and _godot_bin_input.text != resolved_godot_bin:
		_godot_bin_input.text = resolved_godot_bin
	_save_preferences()

	var output: Array = []
	var args := PackedStringArray(
		[
			suite_abs,
			"--project-root", project_root,
			"--godot-bin", resolved_godot_bin,
			"--timeout-sec", "120"
		]
	)
	_set_status("Status: running quick suite...")
	_set_artifact("Artifacts: -")
	var exit_code := OS.execute("python", args, output, true, false)
	var payload := _extract_json_payload(output)
	if payload.is_empty():
		_set_status("Status: fail - quick suite no JSON output, py_exit=%d" % exit_code)
		return
	var suite_id := str(payload.get("suite_id", ""))
	var suite_status := str(payload.get("status", "unknown"))
	var suite_root := project_root.path_join("artifacts").path_join("test-suites").path_join(suite_id)
	_last_suite_root = suite_root
	_save_preferences()
	_set_suite_label("Suite: %s (%s)" % [suite_id, suite_status])
	_set_status("Status: suite %s, id=%s, py_exit=%d" % [suite_status, suite_id, exit_code])
	_set_artifact("Artifacts: %s" % suite_root)
	_refresh_history()


func _on_run_gameplay_debug_flow_pressed() -> void:
	if _live_flow_active:
		_set_status("Status: gameplay flow already running")
		return
	if _dry_run_checkbox != null and _dry_run_checkbox.button_pressed:
		_set_status("Status: fail - Gameplay debug flow requires Dry Run off")
		return
	var flow_abs := ProjectSettings.globalize_path(FLOW_PATH)
	if not FileAccess.file_exists(flow_abs):
		_set_status("Status: fail - missing flow_runner.py")
		return
	var gameplay_flow_file_abs := ProjectSettings.globalize_path(DEFAULT_GAMEPLAY_FLOW_FILE)
	if not FileAccess.file_exists(gameplay_flow_file_abs):
		_set_status("Status: fail - missing gameplay flow json")
		return
	var project_root := ProjectSettings.globalize_path("res://")
	var godot_bin := ""
	if _godot_bin_input != null:
		godot_bin = _godot_bin_input.text.strip_edges()
	if godot_bin.is_empty():
		_set_status("Status: fail - Godot Bin required for gameplay flow")
		return
	var resolved_godot_bin := _resolve_godot_bin(godot_bin)
	if resolved_godot_bin.is_empty():
		_set_status("Status: fail - invalid Godot Bin for gameplay flow")
		return
	if _godot_bin_input != null and _godot_bin_input.text != resolved_godot_bin:
		_godot_bin_input.text = resolved_godot_bin
	_save_preferences()

	var args := PackedStringArray(
		[
			flow_abs,
			"--flow-file", gameplay_flow_file_abs,
			"--project-root", project_root,
			"--godot-bin", resolved_godot_bin,
			"--timeout-sec", "120"
		]
	)
	_set_status("Status: running gameplay flow...")
	_set_artifact("Artifacts: -")
	var pid := OS.create_process("python", args, false)
	if pid <= 0:
		_set_status("Status: fail - unable to start gameplay flow process")
		return
	_live_flow_pid = pid
	_live_flow_active = true
	_live_flow_started_unix = Time.get_unix_time_from_system()
	_live_flow_run_id = ""
	_live_flow_run_abs = ""
	_live_flow_expected_steps = FlowTimelineUtils.load_expected_flow_steps(gameplay_flow_file_abs)
	_show_live_expected_bootstrap()
	if _live_poll_timer != null:
		_live_poll_timer.start()
	_set_status("Status: running gameplay flow (live), pid=%d" % pid)


func _on_live_poll_timeout() -> void:
	if not _live_flow_active:
		if _live_poll_timer != null:
			_live_poll_timer.stop()
		return
	_detect_live_flow_run()
	_refresh_live_flow_view()
	if _live_flow_pid > 0 and OS.is_process_running(_live_flow_pid):
		return
	var exit_code := 0
	if _live_flow_pid > 0:
		exit_code = OS.get_process_exit_code(_live_flow_pid)
	_live_flow_active = false
	_live_flow_pid = -1
	if _live_poll_timer != null:
		_live_poll_timer.stop()
	if not _live_flow_run_id.is_empty():
		_refresh_history(_live_flow_run_id)
		var final_status := _read_run_status(_live_flow_run_abs)
		_set_status(
			"Status: flow %s, flow_id=%s, run_id=%s, py_exit=%d"
			% [final_status, "build_clean_wait_linked_acceptance", _live_flow_run_id, exit_code]
		)
		_set_artifact("Artifacts: %s" % _live_flow_run_abs)
	else:
		_refresh_history()
		_set_status("Status: gameplay flow finished, py_exit=%d" % exit_code)


func _detect_live_flow_run() -> void:
	if not _live_flow_run_abs.is_empty() and DirAccess.dir_exists_absolute(_live_flow_run_abs):
		return
	var runs_abs := ProjectSettings.globalize_path(RUNS_DIR_REL)
	var match := PluginLiveFlowController.detect_live_run(runs_abs, _live_flow_started_unix)
	if match.is_empty():
		return
	_live_flow_run_id = str(match.get("run_id", ""))
	_live_flow_run_abs = str(match.get("run_abs", ""))
	if _live_flow_run_id.is_empty() or _live_flow_run_abs.is_empty():
		return
	_set_artifact("Artifacts: %s" % _live_flow_run_abs)


func _refresh_live_flow_view() -> void:
	if _live_flow_run_abs.is_empty():
		return
	_update_failure_summary_from_run_abs(_live_flow_run_abs)
	_update_flow_steps_from_run_abs(_live_flow_run_abs)
	if not _live_flow_run_id.is_empty():
		_set_status("Status: running gameplay flow, run_id=%s" % _live_flow_run_id)


func _run_scenario(system: String, scenario: String, extra_user_args: Array) -> void:
	var cli_abs := ProjectSettings.globalize_path(CLI_PATH)
	if not FileAccess.file_exists(cli_abs):
		_set_status("Status: fail - missing cli.py")
		return

	var project_root := ProjectSettings.globalize_path("res://")
	var output: Array = []
	var args := PackedStringArray(
		[
			cli_abs,
			"--system", system,
			"--project-root", project_root,
			"--scenario", scenario
		]
	)
	if _dry_run_checkbox != null and _dry_run_checkbox.button_pressed:
		args.append("--dry-run")
	var godot_bin := ""
	if _godot_bin_input != null:
		godot_bin = _godot_bin_input.text.strip_edges()
	_save_preferences()
	if not godot_bin.is_empty():
		var resolved_godot_bin := _resolve_godot_bin(godot_bin)
		if resolved_godot_bin.is_empty():
			if DirAccess.dir_exists_absolute(godot_bin.replace("/", "\\")):
				_set_status("Status: fail - Godot Bin folder has no Godot*.exe")
			else:
				_set_status("Status: fail - Godot Bin not found")
			return
		if _godot_bin_input != null and _godot_bin_input.text != resolved_godot_bin:
			_godot_bin_input.text = resolved_godot_bin
			_save_preferences()
		args.append("--godot-bin")
		args.append(resolved_godot_bin)

	for user_arg in extra_user_args:
		args.append("--extra-arg=%s" % str(user_arg))

	_set_status("Status: running...")
	_set_artifact("Artifacts: -")
	var exit_code := OS.execute("python", args, output, true, false)

	var payload := _extract_json_payload(output)
	if payload.is_empty():
		var last_line := _last_non_empty_line(output)
		if last_line.is_empty():
			_set_status("Status: fail - python exit code %d, no JSON output" % exit_code)
		else:
			_set_status("Status: fail - py_exit=%d, %s" % [exit_code, last_line])
		return

	var run_id := str(payload.get("run_id", ""))
	var status := str(payload.get("status", "unknown"))
	var artifact_root := str(payload.get("artifact_root", ""))
	_set_status("Status: %s, run_id=%s, py_exit=%d" % [status, run_id, exit_code])
	_set_artifact("Artifacts: %s" % artifact_root)
	_refresh_history(run_id)


func _extract_json_payload(output: Array) -> Dictionary:
	for i in range(output.size() - 1, -1, -1):
		var line := str(output[i]).strip_edges()
		if line.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			return parsed
	return {}


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func _set_artifact(text: String) -> void:
	if _artifact_label != null:
		_artifact_label.text = text


func _set_suite_label(text: String) -> void:
	if _suite_label != null:
		_suite_label.text = text


func _set_failure_summary(text: String) -> void:
	if _failure_summary_label != null:
		_failure_summary_label.text = text


func _resolve_godot_bin(path: String) -> String:
	var normalized := path.replace("/", "\\").strip_edges()
	if normalized.is_empty():
		return ""
	if FileAccess.file_exists(normalized):
		return normalized
	if not DirAccess.dir_exists_absolute(normalized):
		return ""
	var dir := DirAccess.open(normalized)
	if dir == null:
		return ""
	var candidates: Array[String] = []
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if dir.current_is_dir():
			continue
		var lower_name := name.to_lower()
		if lower_name.ends_with(".exe") and lower_name.contains("godot"):
			candidates.append(normalized.path_join(name))
	dir.list_dir_end()
	if candidates.is_empty():
		return ""
	return _pick_preferred_godot_exe(candidates)


func _pick_preferred_godot_exe(candidates: Array[String]) -> String:
	# 优先图形版（非 console）Godot.exe，避免误选 console 可执行文件。
	var non_console: Array[String] = []
	var console_only: Array[String] = []
	for path in candidates:
		var lower_path := path.to_lower()
		if lower_path.contains("_console.exe"):
			console_only.append(path)
		else:
			non_console.append(path)
	if not non_console.is_empty():
		non_console.sort()
		return non_console[0]
	console_only.sort()
	return console_only[0]


func _last_non_empty_line(output: Array) -> String:
	for i in range(output.size() - 1, -1, -1):
		var line := str(output[i]).strip_edges()
		if not line.is_empty():
			return line
	return ""


func _load_saved_preferences() -> void:
	if _editor_settings == null:
		return
	if _editor_settings.has_setting(SETTINGS_GODOT_BIN) and _godot_bin_input != null:
		_godot_bin_input.text = str(_editor_settings.get_setting(SETTINGS_GODOT_BIN))
	if _editor_settings.has_setting(SETTINGS_DRY_RUN) and _dry_run_checkbox != null:
		_dry_run_checkbox.button_pressed = bool(_editor_settings.get_setting(SETTINGS_DRY_RUN))
	if _editor_settings.has_setting(SETTINGS_LAST_SUITE_ROOT):
		_last_suite_root = str(_editor_settings.get_setting(SETTINGS_LAST_SUITE_ROOT))
		if not _last_suite_root.is_empty():
			_set_suite_label("Suite: %s" % _last_suite_root)


func _save_preferences() -> void:
	if _editor_settings == null:
		return
	if _godot_bin_input != null:
		_editor_settings.set_setting(SETTINGS_GODOT_BIN, _godot_bin_input.text.strip_edges())
	if _dry_run_checkbox != null:
		_editor_settings.set_setting(SETTINGS_DRY_RUN, _dry_run_checkbox.button_pressed)
	_editor_settings.set_setting(SETTINGS_LAST_SUITE_ROOT, _last_suite_root)
	if _editor_settings.has_method("save"):
		_editor_settings.call("save")


func _refresh_history(preferred_run_id: String = "") -> void:
	if _history_list == null:
		return
	_history_list.clear()
	_history_entries.clear()

	var runs_abs := ProjectSettings.globalize_path(RUNS_DIR_REL)
	var dir := DirAccess.open(runs_abs)
	if dir == null:
		_history_list.add_item("(no runs directory)")
		_set_failure_summary("Latest failure: no runs directory")
		_clear_flow_steps("Flow steps: no runs directory")
		return

	var run_ids: Array = []
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue
		if dir.current_is_dir():
			run_ids.append(name)
	dir.list_dir_end()

	run_ids.sort()
	run_ids.reverse()
	if run_ids.is_empty():
		_history_list.add_item("(no runs yet)")
		_set_failure_summary("Latest failure: no runs yet")
		_clear_flow_steps("Flow steps: no runs yet")
		return

	var select_index := -1
	for idx in range(run_ids.size()):
		var run_id := str(run_ids[idx])
		var run_abs := runs_abs.path_join(run_id)
		var status := _read_run_status(run_abs)
		_history_entries.append({"run_id": run_id, "run_abs": run_abs})
		_history_list.add_item("%s | %s" % [run_id, status])
		if preferred_run_id != "" and preferred_run_id == run_id:
			select_index = idx

	if select_index < 0:
		select_index = 0
	_history_list.select(select_index)
	_update_failure_summary_for_selected()
	_update_flow_steps_for_selected()


func _on_history_item_selected(_index: int) -> void:
	_update_failure_summary_for_selected()
	_update_flow_steps_for_selected()


func _update_failure_summary_for_selected() -> void:
	var entry := _get_selected_run_entry()
	if entry.is_empty():
		_set_failure_summary("Latest failure: no run selected")
		return
	var run_abs := str(entry.get("run_abs", ""))
	if run_abs.is_empty():
		_set_failure_summary("Latest failure: selected run invalid")
		return
	_update_failure_summary_from_run_abs(run_abs)


func _update_failure_summary_from_run_abs(run_abs: String) -> void:
	_set_failure_summary(PluginHistoryController.build_failure_summary_text(run_abs))


func _clear_flow_steps(reason: String) -> void:
	_flow_step_entries.clear()
	if _flow_steps_list != null:
		_flow_steps_list.clear()
		_flow_steps_list.add_item("(no flow steps)")
	if _flow_step_detail_label != null:
		_flow_step_detail_label.text = "Step detail: %s" % reason
	if _flow_step_evidence_label != null:
		_flow_step_evidence_label.text = "Step evidence: -"
	if _flow_step_preview != null:
		_flow_step_preview.texture = null
	if _flow_step_preview_label != null:
		_flow_step_preview_label.text = "Step screenshot preview: -"


func _update_flow_steps_for_selected() -> void:
	var entry := _get_selected_run_entry()
	if entry.is_empty():
		_clear_flow_steps("no run selected")
		return
	var run_abs := str(entry.get("run_abs", ""))
	if run_abs.is_empty():
		_clear_flow_steps("selected run invalid")
		return
	_update_flow_steps_from_run_abs(run_abs)


func _update_flow_steps_from_run_abs(run_abs: String) -> void:
	_flow_step_entries = FlowTimelineUtils.load_flow_step_entries(run_abs)
	if _flow_steps_list == null:
		return
	_flow_steps_list.clear()
	if _flow_step_entries.is_empty():
		_flow_steps_list.add_item("(no flow steps)")
		if _flow_step_detail_label != null:
			_flow_step_detail_label.text = "Step detail: no step_timeline/driver_flow data"
		if _flow_step_evidence_label != null:
			_flow_step_evidence_label.text = "Step evidence: -"
		return
	var select_idx := 0
	var has_failed := false
	for i in range(_flow_step_entries.size()):
		var raw: Variant = _flow_step_entries[i]
		if not (raw is Dictionary):
			continue
		var item := raw as Dictionary
		var step_id := str(item.get("step_id", ""))
		var status := str(item.get("status", "unknown"))
		var icon := "•"
		if status == "passed":
			icon = "OK"
		elif status == "failed":
			icon = "FAIL"
			has_failed = true
			select_idx = i
		elif status == "skipped":
			icon = "SKIP"
		elif status == "running":
			icon = "RUN"
		elif status == "pending":
			icon = "TODO"
		_flow_steps_list.add_item("%s %s | %s" % [icon, step_id, status])
	var live_for_run := (
		_live_flow_active
		and not _live_flow_run_abs.is_empty()
		and run_abs == _live_flow_run_abs
		and _live_flow_pid > 0
		and OS.is_process_running(_live_flow_pid)
	)
	if live_for_run and not has_failed:
		var seen: Dictionary = {}
		for step_raw in _flow_step_entries:
			if step_raw is Dictionary:
				var sid := str((step_raw as Dictionary).get("step_id", ""))
				if not sid.is_empty():
					seen[sid] = true
		var predicted_next := ""
		for step_id in _live_flow_expected_steps:
			var sid := str(step_id)
			if sid.is_empty():
				continue
			if not seen.has(sid):
				predicted_next = sid
				break
		if predicted_next.is_empty():
			predicted_next = "current_step"
		_flow_step_entries.append(
			{
				"step_id": predicted_next,
				"action": "running",
				"description": "Predicted next step from flow file while process is still running.",
				"status": "running",
				"expected": "next step result persisted to logs/driver_flow.json",
				"actual": "process still running",
				"evidence_files": ["logs/driver_flow.json"],
			}
		)
		_flow_steps_list.add_item("RUN %s | running" % predicted_next)
		select_idx = _flow_step_entries.size() - 1
	_flow_steps_list.select(select_idx)
	if _flow_steps_list.has_method("ensure_current_is_visible"):
		_flow_steps_list.call("ensure_current_is_visible")
	_update_selected_flow_step_detail()


func _on_flow_step_selected(_index: int) -> void:
	_update_selected_flow_step_detail()


func _update_selected_flow_step_detail() -> void:
	var entry := _get_selected_run_entry()
	var run_abs := ""
	if not entry.is_empty():
		run_abs = str(entry.get("run_abs", ""))
	if run_abs.is_empty() and not _live_flow_run_abs.is_empty():
		run_abs = _live_flow_run_abs
	if _flow_steps_list == null:
		return
	var selected := _flow_steps_list.get_selected_items()
	if selected.is_empty():
		if _flow_step_detail_label != null:
			_flow_step_detail_label.text = "Step detail: no step selected"
		if _flow_step_evidence_label != null:
			_flow_step_evidence_label.text = "Step evidence: -"
		return
	var idx := int(selected[0])
	if idx < 0 or idx >= _flow_step_entries.size():
		return
	var raw: Variant = _flow_step_entries[idx]
	if not (raw is Dictionary):
		return
	var step := raw as Dictionary
	if _flow_step_detail_label != null:
		_flow_step_detail_label.text = PluginUiBuilder.build_step_detail_text(step)
	var evidence_files: Array = []
	var raw_evidence: Variant = step.get("evidence_files", [])
	if raw_evidence is Array:
		evidence_files = raw_evidence as Array
	var evidence_text := "-"
	if not evidence_files.is_empty():
		evidence_text = str(evidence_files[0])
	if _flow_step_evidence_label != null:
		_flow_step_evidence_label.text = "Step evidence: %s" % evidence_text
	if not run_abs.is_empty():
		_update_flow_step_preview(step, run_abs)


func _open_selected_step_evidence() -> void:
	var entry := _get_selected_run_entry()
	if entry.is_empty():
		_set_status("Status: no run selected")
		return
	var run_abs := str(entry.get("run_abs", ""))
	if run_abs.is_empty():
		_set_status("Status: selected run invalid")
		return
	if _flow_steps_list == null:
		_set_status("Status: step list unavailable")
		return
	var selected := _flow_steps_list.get_selected_items()
	if selected.is_empty():
		_set_status("Status: no step selected")
		return
	var idx := int(selected[0])
	if idx < 0 or idx >= _flow_step_entries.size():
		_set_status("Status: selected step invalid")
		return
	var raw: Variant = _flow_step_entries[idx]
	if not (raw is Dictionary):
		_set_status("Status: selected step invalid")
		return
	var step := raw as Dictionary
	var raw_evidence: Variant = step.get("evidence_files", [])
	if not (raw_evidence is Array):
		_set_status("Status: step has no evidence")
		return
	var evidence_files := raw_evidence as Array
	if evidence_files.is_empty():
		_set_status("Status: step has no evidence")
		return
	var rel := str(evidence_files[0])
	var abs := run_abs.path_join(rel)
	if not FileAccess.file_exists(abs) and not DirAccess.dir_exists_absolute(abs):
		_set_status("Status: step evidence missing")
		return
	OS.shell_open(abs)


func _update_flow_step_preview(step: Dictionary, run_abs: String) -> void:
	if _flow_step_preview == null:
		return
	_flow_step_preview.texture = null
	if _flow_step_preview_label != null:
		_flow_step_preview_label.text = "Step screenshot preview: -"
	var raw_evidence: Variant = step.get("evidence_files", [])
	if not (raw_evidence is Array):
		return
	var evidence_files := raw_evidence as Array
	for item in evidence_files:
		var rel := str(item)
		if not rel.to_lower().ends_with(".png"):
			continue
		var abs := run_abs.path_join(rel)
		if not FileAccess.file_exists(abs):
			continue
		var img := Image.new()
		var err := img.load(abs)
		if err != OK:
			continue
		var tex := ImageTexture.create_from_image(img)
		_flow_step_preview.texture = tex
		if _flow_step_preview_label != null:
			_flow_step_preview_label.text = "Step screenshot preview: %s" % rel
		return


func _show_live_expected_bootstrap() -> void:
	if _flow_steps_list == null:
		return
	if _live_flow_expected_steps.is_empty():
		_clear_flow_steps("flow started; waiting for first driver step")
		return
	_flow_step_entries.clear()
	_flow_steps_list.clear()
	for i in range(_live_flow_expected_steps.size()):
		var step_id := str(_live_flow_expected_steps[i])
		var status := "pending"
		var icon := "TODO"
		if i == 0:
			status = "running"
			icon = "RUN"
		_flow_step_entries.append(
			{
				"step_id": step_id,
				"action": "planned",
				"description": "Planned step from flow definition.",
				"status": status,
				"expected": "step result persisted to logs/driver_flow.json",
				"actual": "waiting for execution",
				"evidence_files": ["logs/driver_flow.json"],
			}
		)
		_flow_steps_list.add_item("%s %s | %s" % [icon, step_id, status])
	_flow_steps_list.select(0)
	if _flow_steps_list.has_method("ensure_current_is_visible"):
		_flow_steps_list.call("ensure_current_is_visible")
	_update_selected_flow_step_detail()


func _read_run_status(run_abs: String) -> String:
	return PluginHistoryController.read_run_status(run_abs)


func _get_selected_run_entry() -> Dictionary:
	if _history_list == null:
		return {}
	var selected := _history_list.get_selected_items()
	if selected.is_empty():
		return {}
	var idx := int(selected[0])
	if idx < 0 or idx >= _history_entries.size():
		return {}
	var entry: Variant = _history_entries[idx]
	if entry is Dictionary:
		return entry as Dictionary
	return {}


func _open_selected_run_folder() -> void:
	var entry := _get_selected_run_entry()
	if entry.is_empty():
		_set_status("Status: no run selected")
		return
	var run_abs := str(entry.get("run_abs", ""))
	if run_abs.is_empty() or not DirAccess.dir_exists_absolute(run_abs):
		_set_status("Status: selected run folder missing")
		return
	OS.shell_open(run_abs)


func _open_selected_report_json() -> void:
	var entry := _get_selected_run_entry()
	if entry.is_empty():
		_set_status("Status: no run selected")
		return
	var run_abs := str(entry.get("run_abs", ""))
	if run_abs.is_empty():
		_set_status("Status: selected run invalid")
		return
	var report_json := run_abs.path_join("report.json")
	if not FileAccess.file_exists(report_json):
		_set_status("Status: report.json missing")
		return
	OS.shell_open(report_json)


func _open_selected_flow_report_json() -> void:
	var entry := _get_selected_run_entry()
	if entry.is_empty():
		_set_status("Status: no run selected")
		return
	var run_abs := str(entry.get("run_abs", ""))
	if run_abs.is_empty():
		_set_status("Status: selected run invalid")
		return
	var flow_report_json := run_abs.path_join("flow_report.json")
	if not FileAccess.file_exists(flow_report_json):
		_set_status("Status: flow_report.json missing")
		return
	OS.shell_open(flow_report_json)


func _open_selected_failure_summary_json() -> void:
	var entry := _get_selected_run_entry()
	if entry.is_empty():
		_set_status("Status: no run selected")
		return
	var run_abs := str(entry.get("run_abs", ""))
	if run_abs.is_empty():
		_set_status("Status: selected run invalid")
		return
	var summary_json := run_abs.path_join("failure_summary.json")
	if not FileAccess.file_exists(summary_json):
		_set_status("Status: failure_summary.json missing")
		return
	OS.shell_open(summary_json)


func _open_selected_step_timeline_json() -> void:
	var entry := _get_selected_run_entry()
	if entry.is_empty():
		_set_status("Status: no run selected")
		return
	var run_abs := str(entry.get("run_abs", ""))
	if run_abs.is_empty():
		_set_status("Status: selected run invalid")
		return
	var timeline_json := run_abs.path_join("step_timeline.json")
	if not FileAccess.file_exists(timeline_json):
		_set_status("Status: step_timeline.json missing")
		return
	OS.shell_open(timeline_json)


func _open_selected_diff_png() -> void:
	var entry := _get_selected_run_entry()
	if entry.is_empty():
		_set_status("Status: no run selected")
		return
	var run_abs := str(entry.get("run_abs", ""))
	if run_abs.is_empty():
		_set_status("Status: selected run invalid")
		return
	var diff_png := run_abs.path_join("screenshots").path_join("visual_ui_button_diff.png")
	if not FileAccess.file_exists(diff_png):
		_set_status("Status: diff image missing (run visual check first)")
		return
	OS.shell_open(diff_png)


func _open_selected_diff_annotated_png() -> void:
	var entry := _get_selected_run_entry()
	if entry.is_empty():
		_set_status("Status: no run selected")
		return
	var run_abs := str(entry.get("run_abs", ""))
	if run_abs.is_empty():
		_set_status("Status: selected run invalid")
		return
	var diff_png := run_abs.path_join("screenshots").path_join("visual_ui_button_diff_annotated.png")
	if not FileAccess.file_exists(diff_png):
		_set_status("Status: annotated diff missing (run visual check first)")
		return
	OS.shell_open(diff_png)


func _copy_status_text() -> void:
	if _status_label == null:
		return
	DisplayServer.clipboard_set(_status_label.text)
	_set_status("Status copied to clipboard")


func _copy_artifact_text() -> void:
	if _artifact_label == null:
		return
	var raw := _artifact_label.text
	var prefix := "Artifacts: "
	var value := raw
	if raw.begins_with(prefix):
		value = raw.substr(prefix.length())
	DisplayServer.clipboard_set(value)
	_set_status("Artifacts path copied to clipboard")


func _open_last_suite_report_json() -> void:
	if _last_suite_root.is_empty():
		_set_status("Status: no suite report yet")
		return
	var report_json := _last_suite_root.path_join("suite_report.json")
	if not FileAccess.file_exists(report_json):
		_set_status("Status: suite_report.json missing")
		return
	OS.shell_open(report_json)

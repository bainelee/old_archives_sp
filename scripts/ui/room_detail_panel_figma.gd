@tool
extends CanvasLayer

const ZoneTypeScript = preload("res://scripts/core/zone_type.gd")
const BuiltRoomHelper = preload("res://scripts/game/game_main_built_room.gd")
const ShelterHelper = preload("res://scripts/game/game_main_shelter.gd")
const _GameValuesRef = preload("res://scripts/core/game_values_ref.gd")
const ICON_COGNITION = preload("res://assets/icons/icon_cognition.png")
const ICON_COMPUTATION = preload("res://assets/icons/icon_computing_power_white.png")
const ICON_WILL = preload("res://assets/icons/icon_willpower.png")
const ICON_PERMISSION = preload("res://assets/icons/icon_permission.png")
const ICON_INFO = preload("res://assets/icons/icon_infomation.png")
const ICON_QUESTION = preload("res://assets/icons/icon_questions.png")
const ICON_BOOK = preload("res://assets/icons/icon_book.png")
const ICON_RESEARCHER = preload("res://assets/icons/icon_researcher.png")

const MAX_SKILL_BUTTONS: int = 4
const SKILL_BUTTON_WIDTH: float = 48.0
const SKILL_BUTTON_GAP: float = 8.0
const SKILL_BUTTON_RIGHT: float = 548.0
const SKILL_BUTTON_TOP: float = 52.0
const TOPBAR_TEXT_LEFT: float = 32.0
const TOPBAR_TEXT_GAP: float = 6.0
const TOPBAR_TEXT_RIGHT_LIMIT: float = 522.0

## 庇护条在 PanelRoot 下的全局坐标（直接子节点）
const _SHELTER_FILL_LEFT := 20.0
const _SHELTER_FILL_RIGHT := 50.0
const _SHELTER_FILL_BOTTOM := 782.0
const _SHELTER_FILL_MAX_H := 654.0
const _SHELTER_HANDLE_HALF_H := 5.0

@onready var _title_name: Label = $PanelRoot/group_room_detials_title/text_room_title_big
@onready var _title_type: Label = $PanelRoot/group_room_detials_title/text_room_type
@onready var _top_name: Label = $PanelRoot/group_room_details_top_bar/text_roomname_details_top_bar
@onready var _top_type: Label = $PanelRoot/group_room_details_top_bar/text_roomtype_details_top_bar
@onready var _desc_label: RichTextLabel = $PanelRoot/group_room_desc/scroll_room_desc/text_room_desc
@onready var _shelter_value: Label = $PanelRoot/text_shelter_value
@onready var _shelter_back: TextureRect = $PanelRoot/room_shelter_progress_back
@onready var _shelter_fill: ColorRect = $PanelRoot/room_shelter_progress_inside
@onready var _shelter_handle: TextureRect = $PanelRoot/room_shelter_handle
@onready var _skill_buttons: Array[TextureButton] = [
	$PanelRoot/group_room_detials_title/group_room_skill_buttons/SkillButton0,
	$PanelRoot/group_room_detials_title/group_room_skill_buttons/SkillButton1,
	$PanelRoot/group_room_detials_title/group_room_skill_buttons/SkillButton2,
	$PanelRoot/group_room_detials_title/group_room_skill_buttons/SkillButton3,
]
@onready var _remodel_slots: Array[TextureRect] = [
	$PanelRoot/select_slot_room_remodel_0,
	$PanelRoot/select_slot_room_remodel_1,
	$PanelRoot/select_slot_room_remodel_2,
]

@onready var _group_fixed: Node = $PanelRoot/group_room_fixed_overhead
@onready var _group_reserve: Node = $PanelRoot/group_room_resource_reserve
@onready var _group_dynamic: Node = $PanelRoot/group_room_dynamic_overhead
@onready var _group_output: Node = $PanelRoot/group_room_total_output
@onready var _btn_destroy: RoomDetailsActionButton = $PanelRoot/group_room_details_bottombar_destroy
@onready var _btn_shutdown: RoomDetailsActionButton = $PanelRoot/group_room_details_bottombar_close
@onready var _panel_root: Control = $PanelRoot

var _current_room: ArchivesRoomInfo = null
var _last_dynamic_hash: int = -1
var _active_skills: Array[Dictionary] = []
var _is_dragging_shelter: bool = false
var _drag_room_id: String = ""
var _drag_preview_energy: int = 0
## 松手提交后先保持目标显示，直到 tick 分配追上，避免“先回弹再前进”闪烁
var _pending_manual_visual_room_id: String = ""
var _pending_manual_visual_energy: int = -1



func _enter_tree() -> void:
	if _panel_root:
		_panel_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	call_deferred("_apply_skill_button_layout", 2)


func _ready() -> void:
	## TimePanel 暂停会 tree.paused；详情为决策 UI，须 ALWAYS 与 UIMain 一致可交互
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_mark_test_ids()
	_apply_skill_button_layout(2)
	_layout_topbar_texts()
	var close_btn: BaseButton = $PanelRoot/group_room_details_top_bar/button_room_details_top_bar as BaseButton
	if close_btn:
		close_btn.pressed.connect(hide_panel)
	for i in _skill_buttons.size():
		var btn: BaseButton = _skill_buttons[i] as BaseButton
		if btn:
			var idx: int = i
			btn.pressed.connect(func() -> void:
				_on_skill_button_pressed(idx)
			)
	if _btn_destroy:
		_btn_destroy.pressed.connect(_on_destroy_pressed)
	if _btn_shutdown:
		_btn_shutdown.pressed.connect(_on_shutdown_pressed)
	_setup_shelter_drag_input()


func _mark_test_ids() -> void:
	if _panel_root:
		_panel_root.set_meta("test_id", "room_detail_panel")
	if _btn_destroy:
		_btn_destroy.set_meta("test_id", "room_detail_btn_destroy")
	if _btn_shutdown:
		_btn_shutdown.set_meta("test_id", "room_detail_btn_shutdown")


func _process(_delta: float) -> void:
	if not visible or _current_room == null:
		return
	var dynamic_hash: int = _compute_dynamic_hash(_current_room)
	if dynamic_hash == _last_dynamic_hash:
		return
	_last_dynamic_hash = dynamic_hash
	_refresh_dynamic_data()
	_update_shelter_visual()


func show_room(room: ArchivesRoomInfo) -> void:
	if room == null:
		hide_panel()
		return
	_current_room = room
	_title_name.text = room.get_display_name()
	_title_type.text = ArchivesRoomInfo.get_room_type_name(room.room_type)
	_top_name.text = _title_name.text
	_top_type.text = _title_type.text
	_layout_topbar_texts()
	_desc_label.text = room.get_display_desc()
	_apply_remodel_slots(_get_remodel_slot_count(room))
	_apply_skill_buttons(room)
	_refresh_action_buttons(room)
	_refresh_dynamic_data()
	_last_dynamic_hash = _compute_dynamic_hash(room)
	## 先设置可见，再更新视觉
	visible = true
	_update_shelter_visual("show_room_after_visible")
	## show_room 常在 _input 中早于 GameMain._process 的 process_shelter_tick，首帧 _room_shelter_energy 仍空 → 条/数会错。
	## call_deferred 在本帧 _process 之后执行，与 tick 写入的分配一致。
	call_deferred("_update_shelter_visual_deferred")


func hide_panel() -> void:
	_current_room = null
	_last_dynamic_hash = -1
	_active_skills.clear()
	_is_dragging_shelter = false
	_drag_room_id = ""
	_drag_preview_energy = 0
	_pending_manual_visual_room_id = ""
	_pending_manual_visual_energy = -1
	visible = false


func _refresh_dynamic_data() -> void:
	if _current_room == null:
		return
	_refresh_action_buttons(_current_room)
	_apply_skill_buttons(_current_room)
	_fill_fixed_group(_current_room)
	_fill_reserve_group(_current_room)
	_fill_dynamic_group(_current_room)
	_fill_output_group(_current_room)


func _fill_fixed_group(room: ArchivesRoomInfo) -> void:
	_group_fixed.call("set_group_title", tr("LABEL_FIXED_CONSUMPTION"))
	var entries: Array = []
	if room.zone_type == 0:
		entries.append({"name": tr("LABEL_ZONE"), "value": tr("LABEL_NO_ZONE_BUILT"), "icon": ICON_QUESTION})
		_group_fixed.call("set_entries", _pad_entries(entries))
		return
	var researcher_count: int = room.get_construction_researcher_count(room.zone_type)
	entries.append({"name": tr("LABEL_RESEARCHER"), "value": str(researcher_count), "icon": ICON_RESEARCHER})
	entries.append({
		"name": tr("LABEL_WILLPOWER"),
		"value": "%d%s" % [BuiltRoomHelper.FIXED_WILL_COST_PER_DAY, tr("LABEL_DAILY_SUFFIX")],
		"icon": ICON_WILL
	})
	_group_fixed.call("set_entries", _pad_entries(entries))


func _fill_reserve_group(room: ArchivesRoomInfo) -> void:
	_group_reserve.call("set_group_title", tr("LABEL_RESOURCE_RESERVE"))
	var entries: Array = []
	for r in room.resources:
		if not (r is Dictionary):
			continue
		var rt: int = int(r.get("resource_type", ArchivesRoomInfo.ResourceType.NONE))
		var amt: int = int(r.get("resource_amount", 0))
		entries.append({
			"name": ArchivesRoomInfo.get_resource_type_name(rt),
			"value": str(amt),
			"icon": _icon_for_resource_type(rt),
		})
		if entries.size() >= 4:
			break
	if entries.is_empty():
		entries.append({"name": tr("RESERVE_NONE"), "value": "", "icon": ICON_QUESTION})
	_group_reserve.call("set_entries", _pad_entries(entries))


func _fill_dynamic_group(room: ArchivesRoomInfo) -> void:
	_group_dynamic.call("set_group_title", tr("LABEL_DYNAMIC_CONSUMPTION"))
	var entries: Array = []
	if room.zone_type == ZoneTypeScript.Type.CREATION:
		var ui: Node = get_node_or_null("../UIMain")
		var is_paused: bool = ui != null and BuiltRoomHelper.is_creation_zone_paused(room, ui)
		entries.append({"name": tr("LABEL_STATUS"), "value": tr("LABEL_STATUS_PAUSED") if is_paused else tr("FACTOR_STATUS_NORMAL"), "icon": ICON_QUESTION})
		var gv: Node = _GameValuesRef.get_singleton()
		if gv:
			var units: int = BuiltRoomHelper.get_room_units(room)
			var will_hour: int = units * int(gv.get_creation_consume_per_unit_per_hour(room.room_type))
			entries.append({"name": tr("LABEL_HOURLY_CONSUME"), "value": tr("LABEL_WILL_H") % will_hour, "icon": ICON_WILL})
	elif room.zone_type == ZoneTypeScript.Type.RESEARCH:
		entries.append({"name": tr("LABEL_STATUS"), "value": tr("FACTOR_STATUS_NORMAL"), "icon": ICON_QUESTION})
	_group_dynamic.call("set_entries", _pad_entries(entries))


func _fill_output_group(room: ArchivesRoomInfo) -> void:
	_group_output.call("set_group_title", tr("TOTAL_OUTPUT"))
	var entries: Array = []
	var gv: Node = _GameValuesRef.get_singleton()
	if gv:
		var units: int = BuiltRoomHelper.get_room_units(room)
		if room.zone_type == ZoneTypeScript.Type.RESEARCH:
			var output_unit: int = int(gv.get_research_output_per_unit_per_hour(room.room_type))
			var res_name: String = str(gv.get_research_output_resource(room.room_type))
			entries.append({
				"name": ArchivesRoomInfo.get_resource_type_name(_resource_name_to_type(res_name)),
				"value": "+%d/h" % (units * output_unit),
				"icon": _icon_for_resource_type(_resource_name_to_type(res_name)),
			})
		elif room.zone_type == ZoneTypeScript.Type.CREATION:
			var output_per_unit: int = int(gv.get_creation_produce_per_unit_per_hour(room.room_type))
			match room.room_type:
				ArchivesRoomInfo.RoomType.SERVER_ROOM:
					entries.append({"name": tr("RESOURCE_PERMISSION"), "value": "+%d/h" % (units * output_per_unit), "icon": ICON_PERMISSION})
				ArchivesRoomInfo.RoomType.REASONING:
					entries.append({"name": tr("RESOURCE_INFO"), "value": "+%d/h" % (units * output_per_unit), "icon": ICON_INFO})
	_group_output.call("set_entries", _pad_entries(entries))


func _pad_entries(entries: Array) -> Array:
	var out: Array = []
	for e in entries:
		if e is Dictionary:
			out.append(e)
		if out.size() >= 4:
			return out
	return out


func _apply_skill_button_layout(count: int) -> void:
	if _skill_buttons.is_empty():
		return
	var safe_count: int = clampi(count, 0, MAX_SKILL_BUTTONS)
	for i in _skill_buttons.size():
		var btn: TextureButton = _skill_buttons[i] as TextureButton
		if btn == null:
			continue
		btn.visible = i < safe_count
		if not btn.visible:
			continue
		var slot_from_right: int = safe_count - 1 - i
		btn.position = Vector2(
			SKILL_BUTTON_RIGHT - (SKILL_BUTTON_WIDTH + SKILL_BUTTON_GAP) * float(slot_from_right) - SKILL_BUTTON_WIDTH,
			SKILL_BUTTON_TOP
		)


func _apply_remodel_slots(slot_count: int) -> void:
	var count: int = clampi(slot_count, 1, 3)
	for i in _remodel_slots.size():
		_remodel_slots[i].visible = i < count


func _get_remodel_slot_count(room: ArchivesRoomInfo) -> int:
	return clampi(room.remodel_slot_count, 1, 3)


func _update_shelter_visual(_caller: String = "unknown") -> void:
	
	if not _shelter_fill:
		return
	
	var rid: String = ""
	if _current_room:
		rid = _current_room.id if _current_room.id else _current_room.json_room_id
	var gm: Node2D = get_parent() as Node2D
	
	var level: int = 0
	var per_room_max: int = 5
	var gv: Node = _GameValuesRef.get_singleton()
	if gv and gv.has_method("get_shelter_energy_per_room_max"):
		per_room_max = maxi(1, int(gv.get_shelter_energy_per_room_max()))
	var allocated_for_bar: int = 0
	var baseline: int = 0
	var tick_alloc: int = -1
	if not rid.is_empty() and gm:
		level = ShelterHelper.get_room_shelter_level(gm, rid)
		baseline = ShelterHelper.get_shelter_baseline_erosion()
		tick_alloc = ShelterHelper.get_room_allocated_shelter_energy(gm, rid)
		## 条表示「本房获得的庇护能量」：由等级与全局基线反推，与数字自洽
		allocated_for_bar = clampi(level - baseline, 0, per_room_max)
	if rid == _pending_manual_visual_room_id and _pending_manual_visual_energy >= 0:
		allocated_for_bar = clampi(_pending_manual_visual_energy, 0, per_room_max)
		level = baseline + allocated_for_bar
		## tick 已追上目标后，清理临时视觉锁定
		if tick_alloc == _pending_manual_visual_energy:
			_pending_manual_visual_room_id = ""
			_pending_manual_visual_energy = -1
	if _is_dragging_shelter and rid == _drag_room_id:
		allocated_for_bar = clampi(_drag_preview_energy, 0, per_room_max)
		level = baseline + allocated_for_bar
	
	
	
	_shelter_value.text = str(level)
	var ratio: float = clampf(float(allocated_for_bar) / float(per_room_max), 0.0, 1.0)
	var fill_h: float = _SHELTER_FILL_MAX_H * ratio
	var fill_top: float = _SHELTER_FILL_BOTTOM - fill_h
	var fill_w: float = _SHELTER_FILL_RIGHT - _SHELTER_FILL_LEFT
	
	if _shelter_fill:
		_shelter_fill.position = Vector2(_SHELTER_FILL_LEFT, fill_top)
		_shelter_fill.size = Vector2(fill_w, maxf(fill_h, 0.5))
	
		_shelter_fill.queue_redraw()
	if _shelter_handle:
		_shelter_handle.position = Vector2(_SHELTER_FILL_LEFT, fill_top - _SHELTER_HANDLE_HALF_H)
		_shelter_handle.size = Vector2(fill_w, _SHELTER_HANDLE_HALF_H * 2.0)
		_shelter_handle.scale = Vector2.ONE
		_shelter_handle.queue_redraw()
	
	## 直接检查尺寸
	_write_size_to_file()


func _setup_shelter_drag_input() -> void:
	if _shelter_handle:
		_shelter_handle.mouse_filter = Control.MOUSE_FILTER_STOP
		if not _shelter_handle.gui_input.is_connected(_on_shelter_drag_gui_input):
			_shelter_handle.gui_input.connect(_on_shelter_drag_gui_input)
	if _shelter_back:
		_shelter_back.mouse_filter = Control.MOUSE_FILTER_STOP
		if not _shelter_back.gui_input.is_connected(_on_shelter_drag_gui_input):
			_shelter_back.gui_input.connect(_on_shelter_drag_gui_input)


func _on_shelter_drag_gui_input(event: InputEvent) -> void:
	if not visible or _current_room == null:
		return
	if not (event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	var rid: String = _current_room.id if _current_room.id else _current_room.json_room_id
	if rid.is_empty():
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_is_dragging_shelter = true
			_drag_room_id = rid
			_update_drag_preview_from_mouse()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT and (not mb.pressed) and _is_dragging_shelter:
			_commit_shelter_drag()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _is_dragging_shelter:
		_update_drag_preview_from_mouse()
		get_viewport().set_input_as_handled()


func _update_drag_preview_from_mouse() -> void:
	if _current_room == null:
		return
	var rid: String = _current_room.id if _current_room.id else _current_room.json_room_id
	if rid.is_empty():
		return
	var gm: Node2D = get_parent() as Node2D
	if gm == null or not gm.has_method("get_room_manual_shelter_max_assignable"):
		return
	var local_mouse: Vector2 = _panel_root.get_local_mouse_position()
	var ratio: float = clampf((_SHELTER_FILL_BOTTOM - local_mouse.y) / _SHELTER_FILL_MAX_H, 0.0, 1.0)
	var gv: Node = _GameValuesRef.get_singleton()
	var per_room_max: int = 5
	if gv and gv.has_method("get_shelter_energy_per_room_max"):
		per_room_max = maxi(1, int(gv.get_shelter_energy_per_room_max()))
	var wanted: int = int(round(ratio * float(per_room_max)))
	var max_assignable: int = int(gm.get_room_manual_shelter_max_assignable(rid))
	_drag_preview_energy = clampi(wanted, 0, max_assignable)
	_update_shelter_visual("drag_preview")


func _commit_shelter_drag() -> void:
	if _current_room == null:
		_is_dragging_shelter = false
		return
	var rid: String = _current_room.id if _current_room.id else _current_room.json_room_id
	var gm: Node2D = get_parent() as Node2D
	if gm and gm.has_method("set_room_manual_shelter_target") and rid == _drag_room_id:
		var result: Dictionary = gm.set_room_manual_shelter_target(rid, _drag_preview_energy)
		_drag_preview_energy = int(result.get("applied", _drag_preview_energy))
		_pending_manual_visual_room_id = rid
		_pending_manual_visual_energy = _drag_preview_energy
	_is_dragging_shelter = false
	_drag_room_id = ""
	_refresh_dynamic_data()
	_update_shelter_visual("drag_commit")




## 用于 call_deferred 的包装函数
func _update_shelter_visual_deferred() -> void:
	_update_shelter_visual("deferred")

func _write_size_to_file() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var dfp: Node = tree.root.get_node_or_null("DebugFramePrint")
	if dfp == null or not dfp.has_method("line"):
		return
	dfp.call("line", "shelter_check", "valid=%s" % is_instance_valid(_shelter_fill))
	if not is_instance_valid(_shelter_fill):
		return
	var gscale: Vector2 = _shelter_fill.get_global_transform().get_scale()
	dfp.call(
		"line",
		"shelter_data",
		"pos=%s size=%s gscale=%s eff_h=%s" % [_shelter_fill.position, _shelter_fill.size, gscale, _shelter_fill.size.y * gscale.y]
	)




func _compute_dynamic_hash(room: ArchivesRoomInfo) -> int:
	if room == null:
		return -1
	var h: int = 17
	h = h * 31 + room.zone_type
	h = h * 31 + room.clean_status
	h = h * 31 + room.resources.hash()
	h = h * 31 + _get_room_shelter_hash_parts()
	var ui: Node = get_node_or_null("../UIMain")
	if ui:
		h = h * 31 + int(ui.get("will_amount") if ui.get("will_amount") != null else 0)
	var gm: Node2D = get_parent() as Node2D
	if gm and gm.has_method("is_room_forced_shutdown"):
		h = h * 31 + (1 if gm.is_room_forced_shutdown(room) else 0)
	return h


static func _resource_name_to_type(res_name: String) -> int:
	match res_name:
		"cognition": return ArchivesRoomInfo.ResourceType.COGNITION
		"computation": return ArchivesRoomInfo.ResourceType.COMPUTATION
		"willpower": return ArchivesRoomInfo.ResourceType.WILL
		"permission": return ArchivesRoomInfo.ResourceType.PERMISSION
		"info": return ArchivesRoomInfo.ResourceType.INFO
		_: return ArchivesRoomInfo.ResourceType.NONE


func _layout_topbar_texts() -> void:
	if _top_name == null or _top_type == null:
		return
	_top_name.offset_left = TOPBAR_TEXT_LEFT
	_top_name.offset_top = 4.0
	_top_name.offset_bottom = 20.0
	_top_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	_top_name.clip_text = true

	var name_width: float = _measure_label_text_width(_top_name)
	var name_right: float = minf(TOPBAR_TEXT_LEFT + name_width, TOPBAR_TEXT_RIGHT_LIMIT)
	_top_name.offset_right = name_right

	var type_left: float = minf(name_right + TOPBAR_TEXT_GAP, TOPBAR_TEXT_RIGHT_LIMIT)
	var name_bottom: float = _top_name.offset_bottom
	_top_type.offset_left = type_left
	_top_type.offset_bottom = name_bottom
	_top_type.offset_top = name_bottom - 10.0
	_top_type.offset_right = TOPBAR_TEXT_RIGHT_LIMIT
	_top_type.autowrap_mode = TextServer.AUTOWRAP_OFF
	_top_type.clip_text = true


func _measure_label_text_width(label: Label) -> float:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	if font:
		return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return float(label.text.length()) * float(font_size) * 0.6


## 动态 hash：庇护等级与分配量可能独立变化（例如侵蚀变化），需同时纳入
func _get_room_shelter_hash_parts() -> int:
	if _current_room == null:
		return 0
	var rid: String = _current_room.id if _current_room.id else _current_room.json_room_id
	if rid.is_empty():
		return 0
	var gm: Node2D = get_parent() as Node2D
	if not gm:
		return 0
	var level: int = ShelterHelper.get_room_shelter_level(gm, rid)
	var baseline: int = ShelterHelper.get_shelter_baseline_erosion()
	return level * 10007 + baseline


func _icon_for_resource_type(rt: int) -> Texture2D:
	match rt:
		ArchivesRoomInfo.ResourceType.COGNITION:
			return ICON_COGNITION
		ArchivesRoomInfo.ResourceType.COMPUTATION:
			return ICON_COMPUTATION
		ArchivesRoomInfo.ResourceType.WILL:
			return ICON_WILL
		ArchivesRoomInfo.ResourceType.PERMISSION:
			return ICON_PERMISSION
		ArchivesRoomInfo.ResourceType.INFO:
			return ICON_INFO
		_:
			return ICON_QUESTION


func _refresh_action_buttons(room: ArchivesRoomInfo) -> void:
	if room == null:
		return
	var can_operate: bool = room.zone_type != 0
	if _btn_destroy:
		_btn_destroy.disabled = not can_operate
	var gm: Node2D = get_parent() as Node2D
	var is_shutdown: bool = gm != null and gm.has_method("is_room_forced_shutdown") and gm.is_room_forced_shutdown(room)
	if _btn_shutdown:
		_btn_shutdown.disabled = not can_operate
		_btn_shutdown.label_text = "恢复" if is_shutdown else "关停"


func _on_destroy_pressed() -> void:
	if _current_room == null:
		return
	var gm: Node2D = get_parent() as Node2D
	if gm and gm.has_method("request_demolish_room"):
		gm.request_demolish_room(_current_room)
		_refresh_action_buttons(_current_room)


func _on_shutdown_pressed() -> void:
	if _current_room == null:
		return
	var gm: Node2D = get_parent() as Node2D
	if gm and gm.has_method("toggle_room_forced_shutdown"):
		gm.toggle_room_forced_shutdown(_current_room)
		_refresh_action_buttons(_current_room)


func _apply_skill_buttons(room: ArchivesRoomInfo) -> void:
	_active_skills = _build_room_skills(room)
	_apply_skill_button_layout(_active_skills.size())
	for i in _skill_buttons.size():
		var btn: TextureButton = _skill_buttons[i] as TextureButton
		if btn == null:
			continue
		if i >= _active_skills.size():
			btn.disabled = true
			btn.tooltip_text = ""
			continue
		var skill: Dictionary = _active_skills[i]
		btn.disabled = not bool(skill.get("enabled", true))
		btn.tooltip_text = str(skill.get("label", ""))


func _build_room_skills(room: ArchivesRoomInfo) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if room == null or room.zone_type == 0:
		return out
	out.append({"id": "focus", "label": "聚焦房间", "enabled": true})
	if room.zone_type == ZoneTypeScript.Type.CREATION:
		var gm: Node2D = get_parent() as Node2D
		var is_shutdown: bool = gm != null and gm.has_method("is_room_forced_shutdown") and gm.is_room_forced_shutdown(room)
		out.append({"id": "toggle_shutdown", "label": "恢复运作" if is_shutdown else "关停房间", "enabled": true})
	return out


func _on_skill_button_pressed(index: int) -> void:
	if _current_room == null or index < 0 or index >= _active_skills.size():
		return
	var skill: Dictionary = _active_skills[index]
	var skill_id: String = str(skill.get("id", ""))
	var gm: Node2D = get_parent() as Node2D
	match skill_id:
		"focus":
			if gm:
				var rooms: Array = gm.get_game_rooms()
				for i in rooms.size():
					if rooms[i] == _current_room:
						gm.call("_focus_camera_on_room", i)
						break
		"toggle_shutdown":
			if gm and gm.has_method("toggle_room_forced_shutdown"):
				gm.toggle_room_forced_shutdown(_current_room)
				_refresh_action_buttons(_current_room)
				_apply_skill_buttons(_current_room)

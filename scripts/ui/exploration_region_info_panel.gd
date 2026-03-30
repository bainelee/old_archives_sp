extends PanelContainer
## 探索地图 — 右侧「地区信息」面板：名称、状态、耗时、调查员、配置文案区（brief_*）、开始探索、已探索地区的调查点列表与事件。

signal explore_requested(region_id: String)
signal region_info_close_requested()

const _Codec := preload("res://scripts/game/exploration/exploration_state_codec.gd")
const _Rules := preload("res://scripts/game/exploration/exploration_rules.gd")
const _EventPanelScene := preload("res://scenes/ui/exploration_investigation_event_panel.tscn")
## 地区说明：`exploration_config.json` → regions_placeholder 条目中可选；展示在「可能获得」与「开始探索」之间。
const _KEY_BRIEF_BEFORE_EXPLORE_ZH := "brief_before_explore_zh"
const _KEY_BRIEF_AFTER_EXPLORE_ZH := "brief_after_explore_zh"
const _BRIEF_MIN_LINES := 5

@onready var _title: Label = get_node_or_null("Margin/VBox/TitleRow/TitleLabel") as Label
@onready var _btn_close: Button = get_node_or_null("Margin/VBox/TitleRow/BtnClose") as Button
@onready var _status: Label = get_node_or_null("Margin/VBox/StatusLabel") as Label
@onready var _duration: Label = get_node_or_null("Margin/VBox/DurationLabel") as Label
@onready var _invest: Label = get_node_or_null("Margin/VBox/InvestLabel") as Label
@onready var _reward: Label = get_node_or_null("Margin/VBox/RewardLabel") as Label
@onready var _brief_rt: RichTextLabel = get_node_or_null("Margin/VBox/RegionBriefRichText") as RichTextLabel
@onready var _btn_explore: Button = get_node_or_null("Margin/VBox/BtnExplore") as Button
@onready var _sites_label: Label = get_node_or_null("Margin/VBox/InvestigationSitesLabel") as Label
@onready var _sites_box: VBoxContainer = get_node_or_null("Margin/VBox/InvestigationSitesBox") as VBoxContainer

var _region_id: String = ""
var _exploration_service: Variant = null
var _game_main: Node2D = null
var _event_panel: Control = null
var _event_signals_connected: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vp: Viewport = get_viewport()
	if vp:
		vp.size_changed.connect(_on_viewport_size_changed)
	if _btn_close:
		_btn_close.pressed.connect(func() -> void:
			_hide_event_panel()
			region_info_close_requested.emit()
		)
	if _btn_explore:
		_btn_explore.pressed.connect(func() -> void:
			if not _region_id.is_empty():
				explore_requested.emit(_region_id)
		)


func bind_exploration_service(service: Variant) -> void:
	_exploration_service = service


func bind_game_main(game_main: Node2D) -> void:
	_game_main = game_main


func hide_panel() -> void:
	_hide_event_panel()
	_clear_region_brief()
	visible = false
	_region_id = ""


func _hide_event_panel() -> void:
	if _event_panel and is_instance_valid(_event_panel) and _event_panel.has_method("hide_panel"):
		_event_panel.call("hide_panel")


## 根据当前服务状态刷新右侧信息；若地区未解锁则不调用或在外部先判断。
func present_region(region_id: String) -> void:
	_region_id = region_id
	_hide_event_panel()
	if _exploration_service == null:
		return
	_exploration_service.call("ensure_first_open_initialized")
	var config: Dictionary = _exploration_service.call("get_config_readonly")
	var state: Dictionary = _exploration_service.call("get_runtime_state_readonly")
	var name_zh: String = _display_name_for(config, region_id)
	if _title:
		_title.text = name_zh
	var unlocked: Variant = state.get(_Codec.KEY_UNLOCKED_REGION_IDS, [])
	var explored: Variant = state.get(_Codec.KEY_EXPLORED_REGION_IDS, [])
	var exploring: Variant = state.get(_Codec.KEY_EXPLORING_BY_REGION, {})
	var is_unlocked: bool = unlocked is Array and (unlocked as Array).has(region_id)
	var is_explored: bool = explored is Array and (explored as Array).has(region_id)
	var is_exploring: bool = exploring is Dictionary and (exploring as Dictionary).has(region_id)
	var hours: float = _Rules.get_region_explore_game_hours(config, region_id)
	if hours <= 0.0:
		hours = float(config.get("default_explore_game_hours", 24.0))
	var need_inv: int = int(config.get("explore_investigators_per_region", 1))
	var pool: int = int(state.get(_Codec.KEY_DEBUG_INVESTIGATOR_POOL, 0))
	if _duration:
		_duration.text = "预计探索时间：%.0f 游戏小时" % hours
	if _invest:
		_invest.text = "需要调查员：%d（当前可用：%d）" % [need_inv, pool]
	if _reward:
		_reward.text = "可能获得：待配置"
	_apply_region_brief(is_unlocked, is_explored, config, region_id)
	if _status:
		if not is_unlocked:
			_status.text = "状态：未解锁"
		elif is_exploring:
			var left: float = 0.0
			if exploring is Dictionary:
				var ent: Variant = (exploring as Dictionary).get(region_id)
				if ent is Dictionary:
					left = float((ent as Dictionary).get("hours_remaining", 0.0))
			_status.text = "状态：探索中（剩余约 %.1f 游戏小时）" % maxf(left, 0.0)
		elif is_explored:
			_status.text = "状态：已探索"
		else:
			_status.text = "状态：已解锁，可开始探索"
	if _btn_explore:
		_btn_explore.disabled = (not is_unlocked) or is_explored or is_exploring or pool < need_inv
		if is_exploring:
			_btn_explore.text = "探索中…"
		elif is_explored:
			_btn_explore.text = "已完成"
		else:
			_btn_explore.text = "开始探索"
	_refresh_investigation_sites(is_explored)
	visible = true
	if _brief_rt != null and _brief_rt.visible:
		call_deferred("_run_brief_height_fit_chain")


func _run_brief_height_fit_chain() -> void:
	if not is_instance_valid(self) or _brief_rt == null or not _brief_rt.visible:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(self) or _brief_rt == null:
		return
	_fit_region_brief_height()


func _brief_line_height_px() -> float:
	if _brief_rt == null:
		return 20.0
	var fs: int = _brief_rt.get_theme_font_size("font_size")
	var f: Font = _brief_rt.get_theme_font("font")
	if f != null:
		return float(f.get_height(fs))
	return maxf(float(fs), 14.0) * 1.25


func _clear_region_brief() -> void:
	if _brief_rt == null:
		return
	_brief_rt.visible = false
	_brief_rt.text = ""
	_brief_rt.custom_minimum_size = Vector2.ZERO


func _apply_region_brief(
	is_unlocked: bool,
	is_explored: bool,
	config: Dictionary,
	region_id: String
) -> void:
	if _brief_rt == null:
		return
	if not is_unlocked:
		_clear_region_brief()
		return
	var entry: Dictionary = _catalog_entry_for(config, region_id)
	var body: String = _brief_text_for_entry(entry, is_explored)
	if body.is_empty():
		_clear_region_brief()
		return
	_brief_rt.visible = true
	_brief_rt.text = body
	_brief_rt.custom_minimum_size = Vector2.ZERO


func _on_viewport_size_changed() -> void:
	if _brief_rt != null and _brief_rt.visible and visible:
		call_deferred("_run_brief_height_fit_chain")


func _fit_region_brief_height() -> void:
	if _brief_rt == null or not _brief_rt.visible:
		return
	var line_h: float = _brief_line_height_px()
	var min_h: float = line_h * float(_BRIEF_MIN_LINES)
	var content_h: float = float(_brief_rt.get_content_height())
	_brief_rt.custom_minimum_size.y = maxf(min_h, content_h)


func _refresh_investigation_sites(is_explored: bool) -> void:
	if _sites_label == null or _sites_box == null:
		return
	if not is_explored or _exploration_service == null:
		_sites_label.visible = false
		_sites_box.visible = false
		_clear_sites_box()
		return
	_sites_label.visible = true
	_sites_box.visible = true
	_clear_sites_box()
	var sites: Variant = _exploration_service.call("get_investigation_sites_for_region", _region_id)
	if not (sites is Array):
		return
	for item in sites as Array:
		if not (item is Dictionary):
			continue
		var site: Dictionary = item as Dictionary
		var sid: String = str(site.get("id", ""))
		if sid.is_empty():
			continue
		var completed: bool = bool(_exploration_service.call("is_investigation_site_completed", sid))
		if completed:
			var lab := Label.new()
			lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lab.add_theme_font_size_override("font_size", 16)
			lab.text = "%s（已完成）" % str(site.get("title_zh", sid))
			_sites_box.add_child(lab)
		else:
			var btn := Button.new()
			btn.text = str(site.get("title_zh", sid))
			btn.focus_mode = Control.FOCUS_NONE
			btn.add_theme_font_size_override("font_size", 16)
			btn.custom_minimum_size = Vector2(0, 40)
			var site_copy: Dictionary = site.duplicate(true)
			btn.pressed.connect(func() -> void:
				_open_investigation_site(site_copy)
			)
			_sites_box.add_child(btn)


func _clear_sites_box() -> void:
	if _sites_box == null:
		return
	for c in _sites_box.get_children():
		_sites_box.remove_child(c)
		c.queue_free()


func _ensure_event_panel() -> void:
	if _event_panel != null and is_instance_valid(_event_panel):
		if not _event_signals_connected:
			_connect_event_panel_signals()
		return
	var node: Node = _EventPanelScene.instantiate()
	_event_panel = node as Control
	if _event_panel == null:
		return
	add_child(_event_panel)
	_event_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_event_panel.offset_left = 0.0
	_event_panel.offset_top = 0.0
	_event_panel.offset_right = 0.0
	_event_panel.offset_bottom = 0.0
	_event_panel.z_index = 10
	_connect_event_panel_signals()


func _connect_event_panel_signals() -> void:
	if _event_panel == null or _event_signals_connected:
		return
	if _event_panel.has_signal("option_selected"):
		_event_panel.option_selected.connect(_on_investigation_option_selected)
	if _event_panel.has_signal("defer_requested"):
		_event_panel.defer_requested.connect(_on_investigation_defer)
	_event_signals_connected = true


func _open_investigation_site(site: Dictionary) -> void:
	_ensure_event_panel()
	if _event_panel and _event_panel.has_method("present_site"):
		_event_panel.call("present_site", site)


func _on_investigation_option_selected(option_id: String) -> void:
	if _game_main == null or not is_instance_valid(_game_main):
		_hide_event_panel()
		return
	if not _game_main.has_method("apply_exploration_investigation_option"):
		_hide_event_panel()
		return
	var res: Variant = _game_main.call("apply_exploration_investigation_option", _event_panel.get_presented_site_id(), option_id)
	if res is Dictionary and bool((res as Dictionary).get("ok", false)):
		_hide_event_panel()
		present_region(_region_id)
	else:
		var reason: String = str((res as Dictionary).get("reason", "")) if res is Dictionary else ""
		if not reason.is_empty():
			push_warning("Exploration investigation option failed: %s" % reason)


func _on_investigation_defer() -> void:
	_hide_event_panel()


static func _catalog_entry_for(config: Dictionary, region_id: String) -> Dictionary:
	var catalog: Variant = config.get("regions_placeholder", [])
	if catalog is Array:
		for entry in catalog as Array:
			if entry is Dictionary and str((entry as Dictionary).get("id", "")) == region_id:
				return entry as Dictionary
	return {}


static func _brief_text_for_entry(entry: Dictionary, is_explored: bool) -> String:
	var key: String = (
		_KEY_BRIEF_AFTER_EXPLORE_ZH if is_explored else _KEY_BRIEF_BEFORE_EXPLORE_ZH
	)
	return str(entry.get(key, "")).strip_edges()


static func _display_name_for(config: Dictionary, region_id: String) -> String:
	var entry: Dictionary = _catalog_entry_for(config, region_id)
	if not entry.is_empty():
		return str(entry.get("display_name_zh", region_id))
	return region_id

extends CanvasLayer

const _Codec := preload("res://scripts/game/exploration/exploration_state_codec.gd")
const _RegionInfoScene := preload("res://scenes/ui/exploration_region_info_panel.tscn")

const _REGION_LAYOUT := {
	"old_archives": Vector2(0.45, 0.56),
	"white_cliff": Vector2(0.52, 0.42),
	"durkin_mine": Vector2(0.31, 0.42),
	"mandos_industrial": Vector2(0.52, 0.64),
	"bolero_port": Vector2(0.70, 0.56),
	"saint_river_afv": Vector2(0.50, 0.28),
	"andal_town": Vector2(0.60, 0.18),
	"korloh_sea": Vector2(0.50, 0.10),
	"bluewood_transit": Vector2(0.82, 0.38),
	"grey_town": Vector2(0.88, 0.10),
	"ural_mountain": Vector2(0.20, 0.54),
	"new_barguzin": Vector2(0.46, 0.76),
	"morku_industrial": Vector2(0.16, 0.72),
	"mason_port": Vector2(0.90, 0.74),
	"west_202_port": Vector2(0.30, 0.82),
	"korborko": Vector2(0.05, 0.72),
}

const _REGION_EDGES := [
	["old_archives", "white_cliff"],
	["old_archives", "durkin_mine"],
	["old_archives", "mandos_industrial"],
	["white_cliff", "durkin_mine"],
	["white_cliff", "saint_river_afv"],
	["white_cliff", "bolero_port"],
	["durkin_mine", "ural_mountain"],
	["mandos_industrial", "new_barguzin"],
	["mandos_industrial", "bolero_port"],
	["bolero_port", "bluewood_transit"],
	["bolero_port", "mason_port"],
	["saint_river_afv", "andal_town"],
	["saint_river_afv", "korloh_sea"],
	["andal_town", "grey_town"],
	["korloh_sea", "grey_town"],
	["bluewood_transit", "grey_town"],
	["ural_mountain", "morku_industrial"],
	["new_barguzin", "west_202_port"],
	["morku_industrial", "west_202_port"],
	["morku_industrial", "korborko"],
]

@onready var _map_area: Control = get_node_or_null("OverlayRoot/MapArea") as Control
@onready var _map_stack: Control = get_node_or_null("OverlayRoot/MapArea/MapStack") as Control
@onready var _map_pan_zoom_root: Control = get_node_or_null("OverlayRoot/MapArea/MapStack/MapPanZoomRoot") as Control
@onready var _map_texture: TextureRect = get_node_or_null("OverlayRoot/MapArea/MapStack/MapPanZoomRoot/MapTexture") as TextureRect
@onready var _map_canvas: Control = get_node_or_null("OverlayRoot/MapArea/MapStack/MapPanZoomRoot/MapCanvas") as Control
@onready var _line_root: Node2D = get_node_or_null("OverlayRoot/MapArea/MapStack/MapPanZoomRoot/MapCanvas/LineRoot") as Node2D
@onready var _top_chrome: Control = get_node_or_null("OverlayRoot/TopChrome") as Control
@onready var _selected_region_label: Label = get_node_or_null("OverlayRoot/TopChrome/Margin/HBox/SelectedRegionLabel") as Label
@onready var _detail_anchor: Control = get_node_or_null("OverlayRoot/DetailAnchor") as Control
@onready var _btn_close: Button = get_node_or_null("OverlayRoot/TopChrome/Margin/HBox/BtnClose") as Button

var _exploration_service: RefCounted = null
var _game_main: Node2D = null
var _region_buttons: Dictionary = {}
var _region_names: Dictionary = {}
var _region_info_panel: Control = null
var _placeholder_texture: Texture2D = null
var _selected_region_id: String = ""

## UIMain 为 CanvasLayer 10，探索为 9：顶栏/底栏会盖在探索 UI 上，需为地图与地区信息留出与 TopBar/BottomRightBar 等高的安全区。
const _EDGE_MARGIN := 12.0
const _TOP_CHROME_BAR_HEIGHT := 52.0
const _FALLBACK_UIMain_TOPBAR_H := 108.0
const _FALLBACK_UIMain_BOTTOMBAR_H := 56.0

## 地图区独立缩放/平移（与主场景 3D 镜头一致：滚轮系数 1.1）
const _MAP_ZOOM_MIN := 0.35
const _MAP_ZOOM_MAX := 3.5
const _MAP_ZOOM_STEP := 1.1
var _map_zoom: float = 1.0
var _map_pan: Vector2 = Vector2.ZERO
var _map_middle_dragging: bool = false
var _map_drag_mouse_start: Vector2 = Vector2.ZERO
var _map_pan_at_drag_start: Vector2 = Vector2.ZERO


func _ready() -> void:
	## 时间暂停时 tree.paused；探索叠层须 ALWAYS 以便关闭/选区/地图操作
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_process_input(true)
	if _btn_close:
		_btn_close.set_meta("test_id", "btn_exploration_close")
		_btn_close.pressed.connect(close_overlay)
	if _map_canvas:
		_map_canvas.resized.connect(_on_map_canvas_resized)
	if _map_stack:
		_map_stack.resized.connect(_on_map_stack_resized)
	_on_map_stack_resized()
	_ensure_placeholder_texture()
	_update_detail_anchor_mouse_filter()
	call_deferred("_sync_overlay_layout_to_uimain")
	var vp: Viewport = get_viewport()
	if vp and not vp.size_changed.is_connected(_on_viewport_size_changed_for_overlay_layout):
		vp.size_changed.connect(_on_viewport_size_changed_for_overlay_layout)


func _on_viewport_size_changed_for_overlay_layout() -> void:
	if visible:
		_sync_overlay_layout_to_uimain()


func _uimain_chrome_top_bottom() -> Vector2:
	var top_h: float = 0.0
	var bot_h: float = 0.0
	var gm: Node = get_parent()
	if gm:
		var ui_main: Node = gm.get_node_or_null("UIMain")
		if ui_main:
			var top_bar: Control = ui_main.get_node_or_null("TopBar") as Control
			if top_bar and top_bar.visible:
				top_h = float(top_bar.size.y)
			var bot_bar: Control = ui_main.get_node_or_null("BottomRightBar") as Control
			if bot_bar and bot_bar.visible:
				bot_h = float(bot_bar.size.y)
	if top_h < 1.0:
		top_h = _FALLBACK_UIMain_TOPBAR_H
	if bot_h < 1.0:
		bot_h = _FALLBACK_UIMain_BOTTOMBAR_H
	return Vector2(top_h, bot_h)


func _sync_overlay_layout_to_uimain() -> void:
	var chrome: Vector2 = _uimain_chrome_top_bottom()
	var top_r: float = chrome.x
	var bot_r: float = chrome.y
	var m: float = _EDGE_MARGIN
	if _map_area:
		_map_area.offset_left = m
		_map_area.offset_top = m + top_r
		_map_area.offset_right = -m
		_map_area.offset_bottom = -m - bot_r
	if _top_chrome:
		_top_chrome.offset_left = m
		_top_chrome.offset_top = m + top_r
		_top_chrome.offset_right = -m
		_top_chrome.offset_bottom = m + top_r + _TOP_CHROME_BAR_HEIGHT
	if _detail_anchor:
		_detail_anchor.offset_left = -320.0
		_detail_anchor.offset_right = 0.0
		_detail_anchor.offset_top = m + top_r
		_detail_anchor.offset_bottom = -m - bot_r
	_on_map_stack_resized()


func _map_chrome_blocks_point(pos: Vector2) -> bool:
	if _top_chrome and _top_chrome.visible and _top_chrome.get_global_rect().has_point(pos):
		return true
	if _detail_anchor and _detail_anchor.mouse_filter == Control.MOUSE_FILTER_STOP and _detail_anchor.get_global_rect().has_point(pos):
		return true
	return false


## Node 须 set_process_input(true)；_unhandled_input 默认不派发。中键拖动用 _input 在 GUI 之前处理。
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _map_stack == null or _map_pan_zoom_root == null:
		return
	var map_rect: Rect2 = _map_stack.get_global_rect()
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				if map_rect.has_point(mb.position) and not _map_chrome_blocks_point(mb.position):
					_map_middle_dragging = true
					_map_drag_mouse_start = mb.position
					_map_pan_at_drag_start = _map_pan
					get_viewport().set_input_as_handled()
			elif _map_middle_dragging:
				_map_middle_dragging = false
				get_viewport().set_input_as_handled()
			return
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			if not map_rect.has_point(mb.position) or _map_chrome_blocks_point(mb.position):
				return
			_apply_map_zoom(mb.button_index == MOUSE_BUTTON_WHEEL_UP, mb.position)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if _map_middle_dragging:
			_map_pan = _map_pan_at_drag_start + (mm.position - _map_drag_mouse_start)
			_sync_map_view_transform()
			get_viewport().set_input_as_handled()
			return
		## 中键按住时部分环境下首帧未置 _map_middle_dragging，用 button_mask 兜底
		if (mm.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0 and map_rect.has_point(mm.position) and not _map_chrome_blocks_point(mm.position):
			if not _map_middle_dragging:
				_map_middle_dragging = true
				_map_drag_mouse_start = mm.position
				_map_pan_at_drag_start = _map_pan
			_map_pan = _map_pan_at_drag_start + (mm.position - _map_drag_mouse_start)
			_sync_map_view_transform()
			get_viewport().set_input_as_handled()


func _on_map_stack_resized() -> void:
	if _map_stack and _map_pan_zoom_root:
		_map_pan_zoom_root.size = _map_stack.size
	_sync_map_view_transform()


func _reset_map_view() -> void:
	_map_zoom = 1.0
	_map_pan = Vector2.ZERO
	_map_middle_dragging = false
	_sync_map_view_transform()


func _sync_map_view_transform() -> void:
	if _map_pan_zoom_root == null:
		return
	_map_pan_zoom_root.scale = Vector2(_map_zoom, _map_zoom)
	_map_pan_zoom_root.position = _map_pan


func _apply_map_zoom(zoom_in: bool, mouse_pos_viewport: Vector2) -> void:
	var rect: Rect2 = _map_stack.get_global_rect()
	var local: Vector2 = mouse_pos_viewport - rect.position
	var old_z: float = _map_zoom
	if zoom_in:
		_map_zoom = minf(_map_zoom * _MAP_ZOOM_STEP, _MAP_ZOOM_MAX)
	else:
		_map_zoom = maxf(_map_zoom / _MAP_ZOOM_STEP, _MAP_ZOOM_MIN)
	if is_equal_approx(old_z, _map_zoom):
		return
	var focus: Vector2 = (local - _map_pan) / old_z
	_map_pan = local - focus * _map_zoom
	_sync_map_view_transform()


func set_context(exploration_service: RefCounted, game_main: Node2D = null) -> void:
	_exploration_service = exploration_service
	_game_main = game_main
	refresh_regions()


func toggle_overlay() -> void:
	if visible:
		close_overlay()
		return
	open_overlay()


func open_overlay() -> void:
	visible = true
	_selected_region_label.text = "当前地区: -"
	_selected_region_id = ""
	_hide_region_info_panel()
	_reset_map_view()
	refresh_regions()
	_update_detail_anchor_mouse_filter()
	call_deferred("_sync_overlay_layout_to_uimain")


func close_overlay() -> void:
	visible = false
	_hide_region_info_panel()
	_update_detail_anchor_mouse_filter()


func refresh_regions() -> void:
	if not _map_canvas:
		return
	if _exploration_service == null:
		return
	var config: Dictionary = _exploration_service.call("get_config_readonly")
	var state: Dictionary = _exploration_service.call("get_runtime_state_readonly")
	var unlocked: Dictionary = _to_set(state.get(_Codec.KEY_UNLOCKED_REGION_IDS, []))
	var explored: Dictionary = _to_set(state.get(_Codec.KEY_EXPLORED_REGION_IDS, []))
	var exploring_raw: Variant = state.get(_Codec.KEY_EXPLORING_BY_REGION, {})
	var exploring_ids: Dictionary = {}
	if exploring_raw is Dictionary:
		for ek in (exploring_raw as Dictionary).keys():
			exploring_ids[str(ek)] = true
	_region_names.clear()
	var catalog: Variant = config.get("regions_placeholder", [])
	if catalog is Array:
		for entry in catalog as Array:
			if not (entry is Dictionary):
				continue
			var d: Dictionary = entry as Dictionary
			var rid: String = str(d.get("id", ""))
			var name_zh: String = str(d.get("display_name_zh", rid))
			if rid.is_empty():
				continue
			_region_names[rid] = name_zh
			var btn: Button = _ensure_region_button(rid)
			_apply_button_state(btn, rid, name_zh, unlocked.has(rid), explored.has(rid), exploring_ids.has(rid))
	_rebuild_lines()
	if _region_info_panel and is_instance_valid(_region_info_panel) and _region_info_panel.visible:
		if not _selected_region_id.is_empty() and _region_info_panel.has_method("present_region"):
			_region_info_panel.call("present_region", _selected_region_id)


func _ensure_region_button(region_id: String) -> Button:
	var existing: Variant = _region_buttons.get(region_id, null)
	if existing is Button:
		return existing as Button
	var btn := Button.new()
	btn.name = "RegionButton_%s" % region_id
	btn.custom_minimum_size = Vector2(116, 32)
	btn.size = Vector2(116, 32)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.flat = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(func() -> void:
		_on_region_pressed(region_id)
	)
	_map_canvas.add_child(btn)
	_region_buttons[region_id] = btn
	return btn


func _apply_button_state(btn: Button, region_id: String, region_name: String, unlocked: bool, explored: bool, exploring: bool) -> void:
	var pos: Vector2 = _resolve_button_pos(region_id, btn.size)
	btn.position = pos
	if not unlocked:
		btn.text = "?"
		btn.disabled = true
		btn.modulate = Color(0.75, 0.75, 0.75, 1.0)
		return
	if exploring:
		btn.text = "%s …" % region_name
		btn.disabled = false
		btn.modulate = Color(0.95, 0.9, 0.65, 1.0)
	elif explored:
		btn.text = region_name
		btn.disabled = false
		btn.modulate = Color(0.75, 0.95, 0.8, 1.0)
	else:
		btn.text = region_name
		btn.disabled = false
		btn.modulate = Color(0.95, 0.95, 0.95, 1.0)


func _resolve_button_pos(region_id: String, btn_size: Vector2) -> Vector2:
	var canvas_size: Vector2 = _map_canvas.size
	var norm: Vector2 = _REGION_LAYOUT.get(region_id, Vector2(0.5, 0.5))
	return Vector2(norm.x * canvas_size.x, norm.y * canvas_size.y) - btn_size * 0.5


func _resolve_region_edges() -> Array:
	if _exploration_service != null:
		var cfg: Variant = _exploration_service.call("get_config_readonly")
		if cfg is Dictionary:
			var raw: Variant = (cfg as Dictionary).get("region_edges", [])
			if raw is Array and (raw as Array).size() > 0:
				return raw as Array
	var fallback: Array = []
	for e in _REGION_EDGES:
		fallback.append(e)
	return fallback


func _rebuild_lines() -> void:
	if _line_root == null:
		return
	for child in _line_root.get_children():
		_line_root.remove_child(child)
		child.queue_free()
	for edge in _resolve_region_edges():
		if not (edge is Array):
			continue
		var pair: Array = edge as Array
		if pair.size() < 2:
			continue
		var aid: String = str(pair[0])
		var bid: String = str(pair[1])
		var a_btn: Button = _region_buttons.get(aid) as Button
		var b_btn: Button = _region_buttons.get(bid) as Button
		if a_btn == null or b_btn == null:
			continue
		var line := Line2D.new()
		line.width = 2.0
		line.default_color = Color(0.1, 0.1, 0.1, 0.95)
		line.add_point(a_btn.position + a_btn.size * 0.5)
		line.add_point(b_btn.position + b_btn.size * 0.5)
		_line_root.add_child(line)
	for region_id in _region_buttons.keys():
		var btn: Button = _region_buttons[region_id] as Button
		if btn:
			_map_canvas.move_child(btn, _map_canvas.get_child_count() - 1)


func _on_region_pressed(region_id: String) -> void:
	_selected_region_id = region_id
	var region_name: String = str(_region_names.get(region_id, region_id))
	_selected_region_label.text = "当前地区: %s" % region_name
	var panel: Control = _ensure_region_info_panel()
	if panel == null:
		return
	if _exploration_service and panel.has_method("bind_exploration_service"):
		panel.call("bind_exploration_service", _exploration_service)
	if _game_main and panel.has_method("bind_game_main"):
		panel.call("bind_game_main", _game_main)
	if panel.has_method("present_region"):
		panel.call("present_region", region_id)
	_update_detail_anchor_mouse_filter()


func _on_region_explore_requested(rid: String) -> void:
	if _exploration_service == null:
		return
	var res: Variant = _exploration_service.call("explore_region", rid)
	if res is Dictionary and bool((res as Dictionary).get("ok", false)):
		refresh_regions()
		if _region_info_panel and is_instance_valid(_region_info_panel) and _region_info_panel.has_method("present_region"):
			_region_info_panel.call("present_region", rid)


func _ensure_region_info_panel() -> Control:
	if _region_info_panel != null and is_instance_valid(_region_info_panel):
		return _region_info_panel
	if _detail_anchor == null:
		return null
	var panel_node: Node = _RegionInfoScene.instantiate()
	var panel: Control = panel_node as Control
	if panel == null:
		return null
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	panel.visible = false
	_detail_anchor.add_child(panel)
	_region_info_panel = panel
	if panel.has_signal("explore_requested"):
		panel.explore_requested.connect(_on_region_explore_requested)
	if panel.has_signal("region_info_close_requested"):
		panel.region_info_close_requested.connect(_on_region_info_close_requested)
	return _region_info_panel


func _on_region_info_close_requested() -> void:
	_selected_region_label.text = "当前地区: -"
	_hide_region_info_panel()


func _update_detail_anchor_mouse_filter() -> void:
	if _detail_anchor == null:
		return
	var panel_visible: bool = (
		_region_info_panel != null
		and is_instance_valid(_region_info_panel)
		and _region_info_panel.visible
	)
	_detail_anchor.mouse_filter = (
		Control.MOUSE_FILTER_STOP if panel_visible else Control.MOUSE_FILTER_IGNORE
	)


func _hide_region_info_panel() -> void:
	_selected_region_id = ""
	if _region_info_panel == null:
		_update_detail_anchor_mouse_filter()
		return
	if not is_instance_valid(_region_info_panel):
		_region_info_panel = null
		_update_detail_anchor_mouse_filter()
		return
	if _region_info_panel.has_method("hide_panel"):
		_region_info_panel.call("hide_panel")
	else:
		_region_info_panel.visible = false
	_update_detail_anchor_mouse_filter()


func _ensure_placeholder_texture() -> void:
	if _map_texture == null:
		return
	if _placeholder_texture == null:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.96, 0.96, 0.96, 1.0))
		_placeholder_texture = ImageTexture.create_from_image(img)
	_map_texture.texture = _placeholder_texture


func _to_set(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if raw is Array:
		for item in raw as Array:
			out[str(item)] = true
	return out


func _on_map_canvas_resized() -> void:
	refresh_regions()

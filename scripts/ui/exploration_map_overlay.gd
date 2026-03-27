extends CanvasLayer

const _Codec := preload("res://scripts/game/exploration/exploration_state_codec.gd")
const _InvestigatorPanelScene := preload("res://scenes/ui/investigator_details_panel.tscn")

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

@onready var _map_texture: TextureRect = get_node_or_null("OverlayRoot/MapFrame/MapTexture") as TextureRect
@onready var _map_canvas: Control = get_node_or_null("OverlayRoot/MapFrame/MapCanvas") as Control
@onready var _line_root: Node2D = get_node_or_null("OverlayRoot/MapFrame/MapCanvas/LineRoot") as Node2D
@onready var _selected_region_label: Label = get_node_or_null("OverlayRoot/MapFrame/TopRow/SelectedRegionLabel") as Label
@onready var _detail_anchor: Control = get_node_or_null("OverlayRoot/MapFrame/DetailAnchor") as Control
@onready var _btn_close: Button = get_node_or_null("OverlayRoot/MapFrame/TopRow/BtnClose") as Button

var _exploration_service: RefCounted = null
var _region_buttons: Dictionary = {}
var _region_names: Dictionary = {}
var _detail_panel: Control = null
var _placeholder_texture: Texture2D = null


func _ready() -> void:
	visible = false
	if _btn_close:
		_btn_close.pressed.connect(close_overlay)
	if _map_canvas:
		_map_canvas.resized.connect(_on_map_canvas_resized)
	_ensure_placeholder_texture()


func set_context(exploration_service: RefCounted) -> void:
	_exploration_service = exploration_service
	refresh_regions()


func toggle_overlay() -> void:
	if visible:
		close_overlay()
		return
	open_overlay()


func open_overlay() -> void:
	visible = true
	_selected_region_label.text = "当前地区: -"
	refresh_regions()


func close_overlay() -> void:
	visible = false
	_hide_detail_panel()


func refresh_regions() -> void:
	if not _map_canvas:
		return
	if _exploration_service == null:
		return
	var config: Dictionary = _exploration_service.call("get_config_readonly")
	var state: Dictionary = _exploration_service.call("get_runtime_state_readonly")
	var unlocked: Dictionary = _to_set(state.get(_Codec.KEY_UNLOCKED_REGION_IDS, []))
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
			_apply_button_state(btn, rid, name_zh, unlocked.has(rid))
	_rebuild_lines()


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


func _apply_button_state(btn: Button, region_id: String, region_name: String, unlocked: bool) -> void:
	var pos: Vector2 = _resolve_button_pos(region_id, btn.size)
	btn.position = pos
	if unlocked:
		btn.text = region_name
		btn.disabled = false
		btn.modulate = Color(0.95, 0.95, 0.95, 1.0)
	else:
		btn.text = "?"
		btn.disabled = true
		btn.modulate = Color(0.75, 0.75, 0.75, 1.0)


func _resolve_button_pos(region_id: String, btn_size: Vector2) -> Vector2:
	var canvas_size: Vector2 = _map_canvas.size
	var norm: Vector2 = _REGION_LAYOUT.get(region_id, Vector2(0.5, 0.5))
	return Vector2(norm.x * canvas_size.x, norm.y * canvas_size.y) - btn_size * 0.5


func _rebuild_lines() -> void:
	if _line_root == null:
		return
	for child in _line_root.get_children():
		_line_root.remove_child(child)
		child.queue_free()
	for edge in _REGION_EDGES:
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
			# Button 没有 raise()；通过调子节点顺序确保按钮压在线条之上。
			_map_canvas.move_child(btn, _map_canvas.get_child_count() - 1)


func _on_region_pressed(region_id: String) -> void:
	var region_name: String = str(_region_names.get(region_id, region_id))
	_selected_region_label.text = "当前地区: %s" % region_name
	_show_detail_panel_for_region(region_name)


func _show_detail_panel_for_region(region_name: String) -> void:
	var panel: Control = _ensure_detail_panel()
	if panel == null or not panel.has_method("show_panel"):
		return
	var data: Dictionary = _build_region_panel_data(region_name)
	panel.show_panel(data)
	panel.visible = true


func _build_region_panel_data(region_name: String) -> Dictionary:
	var data: Dictionary = {}
	if Engine.has_singleton("DataProviders"):
		var dp: Object = Engine.get_singleton("DataProviders")
		if dp != null and dp.has_method("get_investigator_breakdown"):
			data = dp.call("get_investigator_breakdown")
	if data.is_empty():
		data = {
			"available": 0,
			"assigned": 0,
			"total": 0,
			"assigned_details": [],
			"recruited_details": [],
		}
	var assigned_details: Array = data.get("assigned_details", [])
	if not (assigned_details is Array):
		assigned_details = []
	if assigned_details.is_empty():
		assigned_details.append({
			"node_name": "探索-" + region_name,
			"count": 1,
		})
	data["assigned_details"] = assigned_details
	return data


func _ensure_detail_panel() -> Control:
	if _detail_panel != null:
		return _detail_panel
	if _detail_anchor == null:
		return null
	var panel_node: Node = _InvestigatorPanelScene.instantiate()
	var panel: Control = panel_node as Control
	if panel == null:
		return null
	panel.anchor_left = 1.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -340.0
	panel.offset_top = 46.0
	panel.offset_right = -20.0
	panel.offset_bottom = 630.0
	panel.visible = false
	_detail_anchor.add_child(panel)
	_detail_panel = panel
	return _detail_panel


func _hide_detail_panel() -> void:
	if _detail_panel == null:
		return
	if _detail_panel.has_method("hide_panel"):
		_detail_panel.call("hide_panel")
	else:
		_detail_panel.visible = false


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

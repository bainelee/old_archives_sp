extends Node2D
class_name MapEditor

## 地图编辑器 - 网格与底板编辑
## 网格: 80×60, 每格 20px（向上向下各扩 10 高度）

const GRID_WIDTH := 80
const GRID_HEIGHT := 60
const CELL_SIZE := 20

const TILE_COLORS := {
	FloorTileType.Type.EMPTY: Color(0.15, 0.15, 0.2),
	FloorTileType.Type.WALL: Color(0.4, 0.4, 0.45),
	FloorTileType.Type.ROOM_FLOOR: Color(0.55, 0.45, 0.35),
}

var _tiles: Array[Array] = []
var _edit_level: int = FloorTileType.EditLevel.FLOOR
var _select_mode: int = FloorTileType.SelectMode.SINGLE
@warning_ignore("unused_private_class_variable")
var _paint_tool: int = FloorTileType.PaintTool.ROOM_FLOOR  ## 由 MapEditorToolbarBuilder/Grid 通过 get/set 使用
var _rooms: Array = []
var _room_ids: Array[Array] = []  ## gx,gy -> room_index (-1 表示无)
var _selected_room_index: int = -1
var _next_room_id: int = 0
var _is_drawing := false
var _is_panning := false
var _pan_start := Vector2.ZERO
var _box_start: Vector2i = Vector2i(-1, -1)  ## 框选起始格
var _quick_room_size: Vector2i = Vector2i.ZERO  ## 快捷尺寸 (0,0)=手动框选，否则为固定宽高
var _quick_room_buttons: Array[Button] = []
var _floor_selection: Rect2i = Rect2i(-1, -1, -1, -1)  ## 选中的底板区域，position.x<0 表示无选择
var _floor_move_mode: bool = false  ## 底板层级：移动状态
var _floor_move_dragging: bool = false
var _floor_move_drag_start: Vector2i = Vector2i.ZERO
var _btn_floor_move: Button
var _camera: Camera2D
var _ui_panel: PanelContainer
var _ui_layer: CanvasLayer
var _box_size_label: Label
var _ruler_overlay: Control
var _grid_snap_check: CheckBox
var _grid_snap_enabled: bool = false
var _level_buttons: Array[Button] = []
var _select_buttons: Array[Button] = []
var _tool_buttons: Array[Button] = []
var _room_panel: PanelContainer
var _room_name_edit: LineEdit
@warning_ignore("unused_private_class_variable")
var _room_type_option: OptionButton  ## 由 MapEditorRoomUIBuilder 注入并读写
@warning_ignore("unused_private_class_variable")
var _room_clean_option: OptionButton  ## 同上
var _room_pre_clean_edit: LineEdit  ## 清理前文本
var _room_desc_edit: TextEdit  ## 房间描述（支持多行）
@warning_ignore("unused_private_class_variable")
var _room_resources_container: VBoxContainer  ## 资源列表；由 MapEditorRoomUIBuilder 注入并读写
@warning_ignore("unused_private_class_variable")
var _room_res_add_btn: Button  ## 同上
@warning_ignore("unused_private_class_variable")
var _room_base_image_edit: LineEdit  ## 底图路径，只读展示；由 MapEditorRoomUIBuilder 注入并读写
@warning_ignore("unused_private_class_variable")
var _room_base_image_btn: Button    ## 选择底图按钮；同上
var _room_base_image_dialog: FileDialog
var _btn_delete_room: Button
@warning_ignore("unused_private_class_variable")
var _btn_import_template: Button  ## 由 MapEditorRoomUIBuilder 注入并读写
var _import_template_panel: PanelContainer  ## 从 room_info.json 导入模板的弹窗
var _import_template_list: ItemList  ## 模板房间列表（编号+名称）
var _import_template_data: Array = []  ## 从 JSON 加载的模板房间列表
var _main_toolbar: HBoxContainer
@warning_ignore("unused_private_class_variable")
var _room_list_panel: PanelContainer  ## 由 MapEditorRoomUIBuilder 注入并读写
var _room_list_toggle_btn: Button
var _room_list_dropdown_visible: bool = true
var _room_list_scroll: ScrollContainer
@warning_ignore("unused_private_class_variable")
var _room_list_container: VBoxContainer  ## 由 MapEditorRoomUIBuilder 注入并读写
var _skip_room_name_callback: bool = false  ## 程序化设置 LineEdit 时跳过 text_changed，避免覆盖
@warning_ignore("unused_private_class_variable")
var _base_image_cache: Dictionary = {}  ## path -> Texture2D；由 MapEditorDrawHelper 通过 get 使用
var _current_map_slot: int = -1  ## 当前地图槽位 0-4，-1 表示未保存
var _map_name_edit: LineEdit
var _open_map_panel: PanelContainer
var _open_map_slot_buttons: Array[Button] = []
var _save_confirm_panel: PanelContainer  ## 保存确认弹窗：保存当前/保存为新/取消


func _ready() -> void:
	# 像素图不模糊：使用最近邻过滤
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	MapEditorMapIO.migrate_old_map_to_slot0()
	_setup_grid()
	_setup_camera()
	_setup_ui()


func _setup_grid() -> void:
	_tiles.clear()
	_room_ids.clear()
	for x in GRID_WIDTH:
		var col: Array[int] = []
		var rid_col: Array[int] = []
		for y in GRID_HEIGHT:
			col.append(FloorTileType.Type.EMPTY)
			rid_col.append(-1)
		_tiles.append(col)
		_room_ids.append(rid_col)


func _setup_camera() -> void:
	_camera = Camera2D.new()
	_camera.name = "Camera2D"
	add_child(_camera)
	_camera.make_current()
	_camera.position_smoothing_enabled = false  # 编辑器需要即时响应，无延迟缓动
	_camera.position = Vector2(GRID_WIDTH * CELL_SIZE / 2.0, GRID_HEIGHT * CELL_SIZE / 2.0)


func _setup_ui() -> void:
	# 先创建 CanvasLayer（UI 固定于屏幕，不随摄像机缩放）
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UILayer"
	_ui_layer.follow_viewport_enabled = false
	add_child(_ui_layer)
	
	# 标尺网格（先添加，位于底层）
	_ruler_overlay = Control.new()
	_ruler_overlay.set_script(load("res://scripts/editor/map_editor_ruler.gd") as GDScript)
	_ruler_overlay.name = "RulerOverlay"
	_ui_layer.add_child(_ruler_overlay)
	if _ruler_overlay.has_method("setup"):
		_ruler_overlay.setup(self, CELL_SIZE, GRID_WIDTH, GRID_HEIGHT)
	
	_ui_panel = PanelContainer.new()
	_ui_panel.name = "EditorPanel"
	_ui_layer.add_child(_ui_panel)
	
	var vbox: VBoxContainer = VBoxContainer.new()
	_ui_panel.add_child(vbox)
	
	# 编辑层级
	var level_bar: HBoxContainer = HBoxContainer.new()
	var lbl_level: Label = Label.new()
	lbl_level.text = tr("EDITOR_LEVEL")
	level_bar.add_child(lbl_level)
	_level_buttons.clear()
	var btn_floor: Button = MapEditorToolbarBuilder.make_level_button(self, tr("EDITOR_FLOOR"), FloorTileType.EditLevel.FLOOR)
	var btn_room: Button = MapEditorToolbarBuilder.make_level_button(self, tr("EDITOR_ROOM"), FloorTileType.EditLevel.ROOM)
	_level_buttons.append(btn_floor)
	_level_buttons.append(btn_room)
	level_bar.add_child(btn_floor)
	level_bar.add_child(btn_room)
	vbox.add_child(level_bar)
	
	# 工具栏
	_main_toolbar = HBoxContainer.new()
	_main_toolbar.name = "Toolbar"
	vbox.add_child(_main_toolbar)
	
	# 单选、框选、选择（互斥）
	_select_buttons.clear()
	var btn_single: Button = MapEditorToolbarBuilder.make_select_button(self, tr("EDITOR_SINGLE"), FloorTileType.SelectMode.SINGLE)
	var btn_box: Button = MapEditorToolbarBuilder.make_select_button(self, tr("EDITOR_BOX"), FloorTileType.SelectMode.BOX)
	var btn_floor_select: Button = MapEditorToolbarBuilder.make_select_button(self, tr("EDITOR_FLOOR_SELECT"), FloorTileType.SelectMode.FLOOR_SELECT)
	_select_buttons.append(btn_single)
	_select_buttons.append(btn_box)
	_select_buttons.append(btn_floor_select)
	_main_toolbar.add_child(btn_single)
	_btn_delete_room = Button.new()
	_btn_delete_room.text = tr("EDITOR_DELETE_ROOM")
	_btn_delete_room.pressed.connect(_on_delete_room_pressed)
	_btn_delete_room.visible = false
	_main_toolbar.add_child(_btn_delete_room)
	_main_toolbar.add_child(btn_box)
	_main_toolbar.add_child(btn_floor_select)
	_quick_room_buttons.clear()
	for sz in [Vector2i(5, 3), Vector2i(10, 3), Vector2i(5, 7)]:
		var qbtn: Button = MapEditorToolbarBuilder.make_quick_room_button(self, sz.x, sz.y, _quick_room_buttons)
		_quick_room_buttons.append(qbtn)
		_main_toolbar.add_child(qbtn)
	var toolbar_sep: Control = HSeparator.new()
	toolbar_sep.name = "ToolbarSeparator"
	_main_toolbar.add_child(toolbar_sep)
	
	# 底板层级：移动（选择模式下有选区时显示）
	_btn_floor_move = Button.new()
	_btn_floor_move.text = tr("EDITOR_MOVE")
	_btn_floor_move.toggle_mode = true
	_btn_floor_move.toggled.connect(_on_floor_move_toggled)
	_main_toolbar.add_child(_btn_floor_move)
	
	# 工具：空、墙壁、房间底板、橡皮擦（一级编辑时使用）
	_tool_buttons.clear()
	var btn_empty: Button = MapEditorToolbarBuilder.make_tool_button(self, tr("EDITOR_EMPTY"), FloorTileType.PaintTool.EMPTY)
	var btn_wall: Button = MapEditorToolbarBuilder.make_tool_button(self, tr("EDITOR_WALL"), FloorTileType.PaintTool.WALL)
	var btn_room_floor: Button = MapEditorToolbarBuilder.make_tool_button(self, tr("EDITOR_ROOM_FLOOR"), FloorTileType.PaintTool.ROOM_FLOOR)
	var btn_eraser: Button = MapEditorToolbarBuilder.make_tool_button(self, tr("EDITOR_ERASER"), FloorTileType.PaintTool.ERASER)
	_tool_buttons.append(btn_empty)
	_tool_buttons.append(btn_wall)
	_tool_buttons.append(btn_room_floor)
	_tool_buttons.append(btn_eraser)
	_main_toolbar.add_child(btn_empty)
	_main_toolbar.add_child(btn_wall)
	_main_toolbar.add_child(btn_room_floor)
	_main_toolbar.add_child(btn_eraser)
	
	# 房间编辑面板（二级编辑时显示）
	_room_panel = MapEditorRoomUIBuilder.build_room_edit_panel(self)
	_room_panel.visible = false
	vbox.add_child(_room_panel)
	_ui_layer.add_child(_room_base_image_dialog)
	
	# 地图名称
	var name_row: HBoxContainer = HBoxContainer.new()
	var lbl_name: Label = Label.new()
	lbl_name.text = tr("EDITOR_MAP_NAME")
	name_row.add_child(lbl_name)
	_map_name_edit = LineEdit.new()
	_map_name_edit.placeholder_text = tr("EDITOR_MAP_NAME_PLACEHOLDER")
	_map_name_edit.custom_minimum_size.x = 140
	name_row.add_child(_map_name_edit)
	vbox.add_child(name_row)
	
	# 网格对齐开关（已隐藏，自适应标尺已足够）
	_grid_snap_check = CheckBox.new()
	_grid_snap_check.name = "GridSnapCheck"
	_grid_snap_check.text = tr("EDITOR_GRID_SNAP")
	_grid_snap_check.toggled.connect(_on_grid_snap_toggled)
	_grid_snap_check.visible = false
	vbox.add_child(_grid_snap_check)
	
	# 保存、打开、进入游戏
	var save_open_row: HBoxContainer = HBoxContainer.new()
	var btn_save: Button = Button.new()
	btn_save.text = tr("EDITOR_SAVE_MAP")
	btn_save.pressed.connect(_on_save_pressed)
	save_open_row.add_child(btn_save)
	var btn_open: Button = Button.new()
	btn_open.text = tr("EDITOR_OPEN_MAP")
	btn_open.pressed.connect(_on_open_map_pressed)
	save_open_row.add_child(btn_open)
	var btn_play: Button = Button.new()
	btn_play.text = tr("EDITOR_PLAY")
	btn_play.pressed.connect(_on_enter_game_pressed)
	save_open_row.add_child(btn_play)
	vbox.add_child(save_open_row)
	
	_ui_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_ui_panel.set_offset(Side.SIDE_LEFT, 10)
	_ui_panel.set_offset(Side.SIDE_TOP, 10)
	
	# 房间列表（右上角，房间层级显示，可折叠下拉+滚轮滚动）
	MapEditorRoomUIBuilder.build_room_list_panel(self, _ui_layer)
	
	# 打开地图面板
	_open_map_panel = PanelContainer.new()
	_open_map_panel.name = "OpenMapPanel"
	_open_map_panel.visible = false
	var open_vbox: VBoxContainer = VBoxContainer.new()
	var open_title: Label = Label.new()
	open_title.text = tr("EDITOR_SELECT_MAP")
	open_vbox.add_child(open_title)
	_open_map_slot_buttons.clear()
	for i in MapEditorMapIO.MAP_SLOTS:
		var btn: Button = Button.new()
		btn.custom_minimum_size.x = 200
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var slot_idx: int = i
		btn.pressed.connect(func() -> void:
			_load_map_from_slot(slot_idx)
		)
		_open_map_slot_buttons.append(btn)
		open_vbox.add_child(btn)
	var btn_close_open: Button = Button.new()
	btn_close_open.text = tr("EDITOR_CLOSE")
	btn_close_open.pressed.connect(func() -> void:
		_open_map_panel.visible = false
	)
	open_vbox.add_child(btn_close_open)
	_open_map_panel.add_child(open_vbox)
	_open_map_panel.set_anchors_preset(Control.PRESET_CENTER)
	_open_map_panel.offset_left = -110
	_open_map_panel.offset_top = -120
	_open_map_panel.offset_right = 110
	_open_map_panel.offset_bottom = 180
	_ui_layer.add_child(_open_map_panel)
	
	# 导入模板弹窗
	MapEditorRoomUIBuilder.build_import_template_panel(self, _ui_layer)
	# 保存确认弹窗
	MapEditorRoomUIBuilder.build_save_confirm_panel(self, _ui_layer)
	
	# 框选尺寸提示（跟随鼠标右侧）
	_box_size_label = Label.new()
	_box_size_label.name = "BoxSizeLabel"
	_box_size_label.visible = false
	_box_size_label.add_theme_font_size_override("font_size", 14)
	_box_size_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_box_size_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_box_size_label.add_theme_constant_override("shadow_offset_x", 1)
	_box_size_label.add_theme_constant_override("shadow_offset_y", 1)
	_ui_layer.add_child(_box_size_label)
	
	_update_all_buttons()
	_update_room_panel_visibility()


func _on_import_template_pressed() -> void:
	if _selected_room_index < 0 or _selected_room_index >= _rooms.size():
		push_error(tr("ERROR_SELECT_ROOM"))
		return
	var rooms_arr: Variant = MapEditorRoomUIBuilder.load_room_templates()
	if rooms_arr == null:
		push_error(tr("ERROR_ROOM_JSON_OPEN"))
		return
	_import_template_data.clear()
	_import_template_list.clear()
	for r in (rooms_arr as Array):
		if r is Dictionary:
			_import_template_data.append(r)
			var rid: String = str(r.get("id", ""))
			var rname: String = str(r.get("room_name", ""))
			_import_template_list.add_item("%s  %s" % [rid, rname])
	_import_template_panel.visible = true
	_import_template_list.deselect_all()


func _on_import_template_item_selected(_index: int) -> void:
	pass  # 选择在确认时读取


func _on_import_template_confirm_pressed() -> void:
	var sel: PackedInt32Array = _import_template_list.get_selected_items()
	if sel.size() == 0:
		return
	var template_idx: int = sel[0]
	if template_idx < 0 or template_idx >= _import_template_data.size():
		return
	if _selected_room_index < 0 or _selected_room_index >= _rooms.size():
		return
	var t: Dictionary = _import_template_data[template_idx] as Dictionary
	var room: RoomInfo = _rooms[_selected_room_index]
	room.json_room_id = str(t.get("id", ""))
	room.room_name = str(t.get("room_name", ""))
	room.room_type = int(t.get("room_type_id", RoomInfo.RoomType.EMPTY_ROOM))
	room.clean_status = int(t.get("clean_status", RoomInfo.CleanStatus.UNCLEANED))
	room.pre_clean_text = RoomInfo.parse_text_field(t.get("pre_clean_text"), tr("DEFAULT_PRE_CLEAN"))
	room.base_image_path = str(t.get("base_image_path", ""))
	room.desc = RoomInfo.parse_text_field(t.get("desc"), "")
	room.resources.clear()
	for res in (t.get("resources", []) as Array):
		if res is Dictionary:
			room.resources.append({
				"resource_type": int(res.get("resource_type", RoomInfo.ResourceType.NONE)),
				"resource_amount": int(res.get("resource_amount", 0))
			})
	_import_template_panel.visible = false
	_refresh_room_panel()
	queue_redraw()
	print(tr("INFO_IMPORTED_TEMPLATE") % room.room_name)


func _on_room_name_changed(_new_text: String) -> void:
	if _skip_room_name_callback:
		return
	if _selected_room_index >= 0 and _selected_room_index < _rooms.size():
		_rooms[_selected_room_index].room_name = _room_name_edit.text
		_refresh_room_list()


func _on_room_type_selected(index: int) -> void:
	if _selected_room_index >= 0 and _selected_room_index < _rooms.size():
		_rooms[_selected_room_index].room_type = index


func _on_room_clean_selected(index: int) -> void:
	if _selected_room_index >= 0 and _selected_room_index < _rooms.size():
		_rooms[_selected_room_index].clean_status = index


func _on_room_pre_clean_changed(_new_text: String) -> void:
	if _selected_room_index >= 0 and _selected_room_index < _rooms.size():
		_rooms[_selected_room_index].pre_clean_text = _room_pre_clean_edit.text


func _on_room_desc_changed() -> void:
	if _selected_room_index >= 0 and _selected_room_index < _rooms.size():
		_rooms[_selected_room_index].desc = _room_desc_edit.text


func _on_room_res_add_pressed() -> void:
	if _selected_room_index < 0 or _selected_room_index >= _rooms.size():
		return
	var room: RoomInfo = _rooms[_selected_room_index]
	room.resources.append({"resource_type": RoomInfo.ResourceType.NONE, "resource_amount": 0})
	_refresh_room_resources_ui()


func _on_room_res_type_changed(res_idx: int, type_idx: int) -> void:
	if _selected_room_index < 0 or _selected_room_index >= _rooms.size():
		return
	var room: RoomInfo = _rooms[_selected_room_index]
	if res_idx >= 0 and res_idx < room.resources.size():
		if room.resources[res_idx] is Dictionary:
			room.resources[res_idx]["resource_type"] = type_idx


func _on_room_res_amount_changed(res_idx: int, value: float) -> void:
	if _selected_room_index < 0 or _selected_room_index >= _rooms.size():
		return
	var room: RoomInfo = _rooms[_selected_room_index]
	if res_idx >= 0 and res_idx < room.resources.size():
		if room.resources[res_idx] is Dictionary:
			room.resources[res_idx]["resource_amount"] = int(value)


func _on_room_res_remove_pressed(res_idx: int) -> void:
	if _selected_room_index < 0 or _selected_room_index >= _rooms.size():
		return
	var room: RoomInfo = _rooms[_selected_room_index]
	if res_idx >= 0 and res_idx < room.resources.size():
		room.resources.remove_at(res_idx)
		_refresh_room_resources_ui()


func _refresh_room_resources_ui() -> void:
	MapEditorRoomUIBuilder.refresh_room_resources_ui(self)


func _on_delete_room_pressed() -> void:
	if _selected_room_index < 0 or _selected_room_index >= _rooms.size():
		return
	_rooms.remove_at(_selected_room_index)
	_rebuild_room_ids()
	_selected_room_index = -1
	_refresh_room_panel()
	_refresh_room_list()
	queue_redraw()
	print(tr("INFO_ROOM_DELETED"))


func _on_base_image_pick_pressed() -> void:
	_room_base_image_dialog.popup_centered()


func _on_base_image_clear_pressed() -> void:
	if _selected_room_index >= 0 and _selected_room_index < _rooms.size():
		_rooms[_selected_room_index].base_image_path = ""
		_refresh_room_panel()
		queue_redraw()


func _on_base_image_selected(path: String) -> void:
	if _selected_room_index < 0 or _selected_room_index >= _rooms.size():
		return
	# ACCESS_RESOURCES 下返回的路径已是 res:// 形式
	if path.begins_with("res://"):
		_rooms[_selected_room_index].base_image_path = path
	else:
		_rooms[_selected_room_index].base_image_path = "res://" + path
	_refresh_room_panel()
	queue_redraw()


func _refresh_room_panel() -> void:
	MapEditorRoomUIBuilder.refresh_room_panel(self)


func _update_all_buttons() -> void:
	MapEditorToolbarBuilder.update_all_buttons(self)


func _on_room_list_toggle_pressed() -> void:
	_room_list_dropdown_visible = not _room_list_dropdown_visible
	_room_list_scroll.visible = _room_list_dropdown_visible
	_room_list_toggle_btn.text = tr("EDITOR_ROOM_LIST_DOWN") if _room_list_dropdown_visible else tr("EDITOR_ROOM_LIST_RIGHT")


func _refresh_room_list() -> void:
	MapEditorRoomUIBuilder.refresh_room_list(self)


func _focus_camera_on_room(room_index: int) -> void:
	MapEditorRoomUIBuilder.focus_camera_on_room(self, room_index)


func _update_room_panel_visibility() -> void:
	MapEditorRoomUIBuilder.update_room_panel_visibility(self)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = mb.pressed
			if _is_panning:
				_pan_start = get_viewport().get_mouse_position()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			if _camera:
				_camera.zoom *= 1.1
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _camera:
				_camera.zoom /= 1.1
			get_viewport().set_input_as_handled()


func _is_point_in_floor_selection(p: Vector2i) -> bool:
	return MapEditorGridHelper.is_point_in_floor_selection(self, p)


func _set_floor_selection(start: Vector2i, end: Vector2i) -> void:
	MapEditorGridHelper.set_floor_selection(self, start, end)


func _apply_floor_move(release_grid: Vector2i) -> void:
	MapEditorGridHelper.apply_floor_move(self, release_grid)


func _clear_floor_selection() -> void:
	MapEditorGridHelper.clear_floor_selection(self)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and _edit_level == FloorTileType.EditLevel.FLOOR:
			if _floor_selection.position.x >= 0:
				_clear_floor_selection()
				get_viewport().set_input_as_handled()
				return
		if mb.button_index == MOUSE_BUTTON_LEFT and not _is_panning:
			if _edit_level == FloorTileType.EditLevel.FLOOR and _floor_move_mode and _floor_selection.position.x >= 0 and _select_mode == FloorTileType.SelectMode.FLOOR_SELECT:
				var grid: Vector2i = _get_mouse_grid()
				if mb.pressed:
					if _is_point_in_floor_selection(grid):
						_floor_move_dragging = true
						_floor_move_drag_start = grid
						get_viewport().set_input_as_handled()
						return
				else:
					if _floor_move_dragging:
						MapEditorGridHelper.apply_floor_move(self, grid)
						_floor_move_dragging = false
						get_viewport().set_input_as_handled()
						return
			if _select_mode == FloorTileType.SelectMode.SINGLE:
				if mb.pressed:
					if _edit_level == FloorTileType.EditLevel.FLOOR:
						MapEditorGridHelper.apply_paint_at_mouse(self)
					else:
						MapEditorGridHelper.try_select_room_at_mouse(self)
			else:
				if mb.pressed:
					_box_start = _get_mouse_grid() if _quick_room_size == Vector2i.ZERO else Vector2i(-1, -1)
					_is_drawing = true
				else:
					if _select_mode == FloorTileType.SelectMode.BOX or _select_mode == FloorTileType.SelectMode.FLOOR_SELECT:
						if _quick_room_size != Vector2i.ZERO and _edit_level == FloorTileType.EditLevel.ROOM:
							var start: Vector2i = _get_mouse_grid()
							var end: Vector2i = start + _quick_room_size - Vector2i(1, 1)
							if MapEditorGridHelper.is_room_box_valid(self, start, end):
								MapEditorGridHelper.try_create_room(self, start, end)
							_refresh_room_list()
						elif _box_start.x >= 0:
							if _edit_level == FloorTileType.EditLevel.FLOOR:
								if _select_mode == FloorTileType.SelectMode.FLOOR_SELECT:
									MapEditorGridHelper.set_floor_selection(self, _box_start, _get_mouse_grid())
								else:
									MapEditorGridHelper.fill_box(self, _box_start, _get_mouse_grid())
							elif _edit_level == FloorTileType.EditLevel.ROOM:
								if MapEditorGridHelper.is_room_box_valid(self, _box_start, _get_mouse_grid()):
									MapEditorGridHelper.try_create_room(self, _box_start, _get_mouse_grid())
								_refresh_room_list()
					_box_start = Vector2i(-1, -1)
					_is_drawing = false
					queue_redraw()
	elif event is InputEventMouseMotion:
		if _is_panning and _camera:
			var delta: Vector2 = get_viewport().get_mouse_position() - _pan_start
			_pan_start = get_viewport().get_mouse_position()
			_camera.position -= delta / _camera.zoom
			if _grid_snap_enabled:
				_snap_camera_to_grid()
		elif _is_drawing and (_select_mode == FloorTileType.SelectMode.BOX or _select_mode == FloorTileType.SelectMode.FLOOR_SELECT):
			queue_redraw()  # 快捷尺寸或拖拽时预览跟随
		elif _floor_move_dragging:
			queue_redraw()  # 移动底板时预览跟随


func _process(_delta: float) -> void:
	if Input.is_key_pressed(KEY_ESCAPE):
		_is_drawing = false
		_box_start = Vector2i(-1, -1)
		if _floor_move_dragging:
			_floor_move_dragging = false
			queue_redraw()
	
	# 标尺重绘
	if _ruler_overlay:
		_ruler_overlay.queue_redraw()
	
	# 框选时更新尺寸提示
	if (_select_mode == FloorTileType.SelectMode.BOX or _select_mode == FloorTileType.SelectMode.FLOOR_SELECT) and _is_drawing:
		var w: int
		var h: int
		if _quick_room_size != Vector2i.ZERO:
			w = _quick_room_size.x
			h = _quick_room_size.y
		elif _box_start.x >= 0:
			var end: Vector2i = _get_mouse_grid()
			w = abs(end.x - _box_start.x) + 1
			h = abs(end.y - _box_start.y) + 1
		else:
			w = 0
			h = 0
		if w > 0 and h > 0:
			_box_size_label.text = "%d×%d" % [w, h]
			_box_size_label.visible = true
			var mouse_pos: Vector2 = get_viewport().get_mouse_position()
			_box_size_label.position = mouse_pos + Vector2(16, -8)
		else:
			_box_size_label.visible = false
	else:
		_box_size_label.visible = false


func _get_mouse_grid() -> Vector2i:
	var viewport: Viewport = get_viewport()
	var mouse_pos: Vector2 = viewport.get_mouse_position()
	var world: Vector2 = viewport.get_canvas_transform().affine_inverse() * mouse_pos
	var gx: int = int(world.x / CELL_SIZE)
	var gy: int = int(world.y / CELL_SIZE)
	return Vector2i(clampi(gx, 0, GRID_WIDTH - 1), clampi(gy, 0, GRID_HEIGHT - 1))


func _is_room_box_valid(start: Vector2i, end: Vector2i) -> bool:
	return MapEditorGridHelper.is_room_box_valid(self, start, end)


func _rebuild_room_ids() -> void:
	for x in GRID_WIDTH:
		for y in GRID_HEIGHT:
			_room_ids[x][y] = -1
	for i in _rooms.size():
		var room: RoomInfo = _rooms[i]
		for gx in range(room.rect.position.x, room.rect.position.x + room.rect.size.x):
			for gy in range(room.rect.position.y, room.rect.position.y + room.rect.size.y):
				if gx >= 0 and gx < GRID_WIDTH and gy >= 0 and gy < GRID_HEIGHT:
					_room_ids[gx][gy] = i


func _set_tile(gx: int, gy: int, type: int) -> void:
	if gx < 0 or gx >= GRID_WIDTH or gy < 0 or gy >= GRID_HEIGHT:
		return
	_tiles[gx][gy] = type
	if type != FloorTileType.Type.ROOM_FLOOR:
		_room_ids[gx][gy] = -1
	queue_redraw()


func _draw() -> void:
	MapEditorDrawHelper.draw_all(self, self)


func _on_floor_move_toggled(pressed: bool) -> void:
	_floor_move_mode = pressed
	if not pressed:
		_floor_move_dragging = false
	_update_all_buttons()
	queue_redraw()


func _on_grid_snap_toggled(pressed: bool) -> void:
	_grid_snap_enabled = pressed
	if pressed and _camera:
		_snap_camera_to_grid()


func _snap_camera_to_grid() -> void:
	if not _camera:
		return
	_camera.position.x = roundf(_camera.position.x / CELL_SIZE) * CELL_SIZE
	_camera.position.y = roundf(_camera.position.y / CELL_SIZE) * CELL_SIZE


func _refresh_open_map_panel() -> void:
	for i in MapEditorMapIO.MAP_SLOTS:
		var name_str: String = MapEditorMapIO.get_slot_map_name(i)
		var btn: Button = _open_map_slot_buttons[i]
		if name_str.is_empty():
			btn.text = tr("SLOT_EMPTY") % (i + 1)
		else:
			btn.text = tr("SLOT_WITH_NAME") % [i + 1, name_str]


func _on_save_pressed() -> void:
	_save_confirm_panel.visible = true


func _on_save_confirm_save_current() -> void:
	_save_confirm_panel.visible = false
	var slot: int = _current_map_slot
	if slot < 0:
		slot = 0
	_do_save_to_slot(slot)


func _on_save_confirm_save_new() -> void:
	var empty_slot: int = -1
	for i in MapEditorMapIO.MAP_SLOTS:
		if not FileAccess.file_exists(MapEditorMapIO.get_slot_path(i)):
			empty_slot = i
			break
	if empty_slot < 0:
		_save_confirm_panel.visible = false
		OS.alert(tr("ERROR_NO_SLOT_EMPTY"), tr("ERROR_SAVE_FAILED_TITLE"))
		return
	_save_confirm_panel.visible = false
	_do_save_to_slot(empty_slot)


func _do_save_to_slot(slot: int) -> void:
	_current_map_slot = slot
	var map_name: String = _map_name_edit.text.strip_edges()
	if map_name.is_empty():
		map_name = tr("DEFAULT_UNNAMED_MAP")
	var ok: bool = MapEditorMapIO.save_to_slot(slot, GRID_WIDTH, GRID_HEIGHT, CELL_SIZE, _tiles, _rooms, map_name, _next_room_id)
	if ok:
		MapEditorMapIO.sync_rooms_to_json(_rooms)


func _on_open_map_pressed() -> void:
	_refresh_open_map_panel()
	_open_map_panel.visible = true


func _on_enter_game_pressed() -> void:
	## 进入游戏主场景；游戏展示槽位 1 的地图，进入后地图编辑器无法唤出
	get_tree().change_scene_to_file("res://scenes/game/game_main.tscn")


func _load_map_from_slot(slot: int) -> void:
	var result: Variant = MapEditorMapIO.load_from_slot(slot)
	if result == null:
		print(tr("INFO_SLOT_EMPTY") % (slot + 1))
		return
	var path: String = MapEditorMapIO.get_slot_path(slot)
	if result is Dictionary:
		var d: Dictionary = result as Dictionary
		var map_name: String = str(d.get(MapEditorMapIO.SAVE_KEY_MAP_NAME, ""))
		_map_name_edit.text = map_name
		for x in GRID_WIDTH:
			for y in GRID_HEIGHT:
				_tiles[x][y] = FloorTileType.Type.EMPTY
				_room_ids[x][y] = -1
		var tiles_data: Array = d.get(MapEditorMapIO.SAVE_KEY_TILES, []) as Array
		for x in min(tiles_data.size(), GRID_WIDTH):
			var col: Variant = tiles_data[x]
			if col is Array:
				for y in min(col.size(), GRID_HEIGHT):
					_tiles[x][y] = int(col[y])
		_rooms.clear()
		var rooms_data: Array = d.get(MapEditorMapIO.SAVE_KEY_ROOMS, []) as Array
		for room_dict in rooms_data:
			if room_dict is Dictionary:
				_rooms.append(RoomInfo.from_dict(room_dict as Dictionary))
		_next_room_id = int(d.get("next_room_id", 0))
		_rebuild_room_ids()
		if _edit_level == FloorTileType.EditLevel.ROOM:
			_refresh_room_list()
		_selected_room_index = -1
		_current_map_slot = slot
		_open_map_panel.visible = false
		queue_redraw()
		print(tr("INFO_MAP_LOADED") % path)

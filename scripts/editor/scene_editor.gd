extends Node2D
class_name SceneEditor

## 场景编辑器 - 网格与底板编辑
## 网格: 80×40, 每格 20px

const GRID_WIDTH := 80
const GRID_HEIGHT := 40
const CELL_SIZE := 20

const TILE_COLORS := {
	FloorTileType.Type.EMPTY: Color(0.15, 0.15, 0.2),
	FloorTileType.Type.WALL: Color(0.4, 0.4, 0.45),
	FloorTileType.Type.ROOM_FLOOR: Color(0.55, 0.45, 0.35),
}

var _tiles: Array[Array] = []
var _edit_level: int = FloorTileType.EditLevel.FLOOR
var _select_mode: int = FloorTileType.SelectMode.SINGLE
var _paint_tool: int = FloorTileType.PaintTool.ROOM_FLOOR
var _rooms: Array = []
var _room_ids: Array[Array] = []  ## gx,gy -> room_index (-1 表示无)
var _selected_room_index: int = -1
var _next_room_id: int = 0
var _is_drawing := false
var _is_panning := false
var _pan_start := Vector2.ZERO
var _box_start: Vector2i = Vector2i(-1, -1)  ## 框选起始格
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
var _room_type_option: OptionButton
var _room_res_option: OptionButton
var _room_res_total_spin: SpinBox
var _main_toolbar: HBoxContainer
var _room_list_panel: PanelContainer
var _room_list_container: VBoxContainer
var _skip_room_name_callback: bool = false  ## 程序化设置 LineEdit 时跳过 text_changed，避免覆盖
var _save_path := "user://scene_archive.json"

const SAVE_KEY_GRID := "grid_width"
const SAVE_KEY_GRID_H := "grid_height"
const SAVE_KEY_CELL := "cell_size"
const SAVE_KEY_TILES := "tiles"
const SAVE_KEY_ROOMS := "rooms"


func _ready() -> void:
	_setup_grid()
	_setup_camera()
	_setup_ui()
	_load_scene()


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
	_ruler_overlay.set_script(load("res://scripts/editor/scene_editor_ruler.gd") as GDScript)
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
	lbl_level.text = "编辑层级："
	level_bar.add_child(lbl_level)
	_level_buttons.clear()
	var btn_floor: Button = _make_level_button("底板", FloorTileType.EditLevel.FLOOR)
	var btn_room: Button = _make_level_button("房间", FloorTileType.EditLevel.ROOM)
	_level_buttons.append(btn_floor)
	_level_buttons.append(btn_room)
	level_bar.add_child(btn_floor)
	level_bar.add_child(btn_room)
	vbox.add_child(level_bar)
	
	# 工具栏
	_main_toolbar = HBoxContainer.new()
	_main_toolbar.name = "Toolbar"
	vbox.add_child(_main_toolbar)
	
	# 单选、框选
	_select_buttons.clear()
	var btn_single: Button = _make_select_button("单选", FloorTileType.SelectMode.SINGLE)
	var btn_box: Button = _make_select_button("框选", FloorTileType.SelectMode.BOX)
	_select_buttons.append(btn_single)
	_select_buttons.append(btn_box)
	_main_toolbar.add_child(btn_single)
	_main_toolbar.add_child(btn_box)
	_main_toolbar.add_child(HSeparator.new())
	
	# 工具：空、墙壁、房间底板、橡皮擦（一级编辑时使用）
	_tool_buttons.clear()
	var btn_empty: Button = _make_tool_button("空", FloorTileType.PaintTool.EMPTY)
	var btn_wall: Button = _make_tool_button("墙壁", FloorTileType.PaintTool.WALL)
	var btn_room_floor: Button = _make_tool_button("房间底板", FloorTileType.PaintTool.ROOM_FLOOR)
	var btn_eraser: Button = _make_tool_button("橡皮擦", FloorTileType.PaintTool.ERASER)
	_tool_buttons.append(btn_empty)
	_tool_buttons.append(btn_wall)
	_tool_buttons.append(btn_room_floor)
	_tool_buttons.append(btn_eraser)
	_main_toolbar.add_child(btn_empty)
	_main_toolbar.add_child(btn_wall)
	_main_toolbar.add_child(btn_room_floor)
	_main_toolbar.add_child(btn_eraser)
	
	# 房间编辑面板（二级编辑时显示）
	_room_panel = _build_room_edit_panel()
	_room_panel.visible = false
	vbox.add_child(_room_panel)
	
	# 网格对齐开关
	_grid_snap_check = CheckBox.new()
	_grid_snap_check.name = "GridSnapCheck"
	_grid_snap_check.text = "网格对齐"
	_grid_snap_check.toggled.connect(_on_grid_snap_toggled)
	vbox.add_child(_grid_snap_check)
	
	# 保存按钮
	var btn_save: Button = Button.new()
	btn_save.text = "保存场景"
	btn_save.pressed.connect(_on_save_pressed)
	vbox.add_child(btn_save)
	
	_ui_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_ui_panel.set_offset(Side.SIDE_LEFT, 10)
	_ui_panel.set_offset(Side.SIDE_TOP, 10)
	
	# 房间列表（右上角，房间层级显示）
	_room_list_panel = PanelContainer.new()
	_room_list_panel.name = "RoomListPanel"
	_room_list_panel.visible = false
	var room_list_vbox: VBoxContainer = VBoxContainer.new()
	var room_list_title: Label = Label.new()
	room_list_title.text = "房间列表"
	room_list_vbox.add_child(room_list_title)
	_room_list_container = VBoxContainer.new()
	_room_list_container.name = "RoomListItems"
	room_list_vbox.add_child(_room_list_container)
	_room_list_panel.add_child(room_list_vbox)
	_room_list_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_room_list_panel.set_offset(Side.SIDE_RIGHT, -10)
	_room_list_panel.set_offset(Side.SIDE_TOP, 10)
	_room_list_panel.set_offset(Side.SIDE_LEFT, -160)
	_room_list_panel.set_offset(Side.SIDE_BOTTOM, 10)
	_ui_layer.add_child(_room_list_panel)
	
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


func _build_room_edit_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "RoomPanel"
	var vbox: VBoxContainer = VBoxContainer.new()
	panel.add_child(vbox)
	
	var lbl: Label = Label.new()
	lbl.text = "房间信息（选中房间后可编辑）"
	vbox.add_child(lbl)
	
	var name_row: HBoxContainer = HBoxContainer.new()
	var lbl_name: Label = Label.new()
	lbl_name.text = "名称："
	name_row.add_child(lbl_name)
	_room_name_edit = LineEdit.new()
	_room_name_edit.placeholder_text = "房间名称"
	_room_name_edit.custom_minimum_size.x = 160  # 容纳约 8 个中文字符
	_room_name_edit.text_changed.connect(_on_room_name_changed)
	name_row.add_child(_room_name_edit)
	vbox.add_child(name_row)
	
	var type_row: HBoxContainer = HBoxContainer.new()
	var lbl_type: Label = Label.new()
	lbl_type.text = "类型："
	type_row.add_child(lbl_type)
	_room_type_option = OptionButton.new()
	for i in range(9):
		_room_type_option.add_item(RoomInfo.get_room_type_name(i), i)
	_room_type_option.item_selected.connect(_on_room_type_selected)
	type_row.add_child(_room_type_option)
	vbox.add_child(type_row)
	
	var res_row: HBoxContainer = HBoxContainer.new()
	var lbl_res: Label = Label.new()
	lbl_res.text = "资源："
	res_row.add_child(lbl_res)
	_room_res_option = OptionButton.new()
	for i in range(7):
		_room_res_option.add_item(RoomInfo.get_resource_type_name(i), i)
	_room_res_option.item_selected.connect(_on_room_res_selected)
	res_row.add_child(_room_res_option)
	vbox.add_child(res_row)
	
	var total_row: HBoxContainer = HBoxContainer.new()
	var lbl_total: Label = Label.new()
	lbl_total.text = "总量："
	total_row.add_child(lbl_total)
	_room_res_total_spin = SpinBox.new()
	_room_res_total_spin.min_value = 0
	_room_res_total_spin.max_value = 999999
	_room_res_total_spin.value_changed.connect(_on_room_res_total_changed)
	total_row.add_child(_room_res_total_spin)
	vbox.add_child(total_row)
	
	return panel


func _on_room_name_changed(_new_text: String) -> void:
	if _skip_room_name_callback:
		return
	if _selected_room_index >= 0 and _selected_room_index < _rooms.size():
		_rooms[_selected_room_index].room_name = _room_name_edit.text
		_refresh_room_list()


func _on_room_type_selected(index: int) -> void:
	if _selected_room_index >= 0 and _selected_room_index < _rooms.size():
		_rooms[_selected_room_index].room_type = index


func _on_room_res_selected(index: int) -> void:
	if _selected_room_index >= 0 and _selected_room_index < _rooms.size():
		_rooms[_selected_room_index].resource_type = index


func _on_room_res_total_changed(_value: float) -> void:
	if _selected_room_index >= 0 and _selected_room_index < _rooms.size():
		_rooms[_selected_room_index].resource_total = int(_room_res_total_spin.value)


func _refresh_room_panel() -> void:
	if _selected_room_index < 0 or _selected_room_index >= _rooms.size():
		_skip_room_name_callback = true
		_room_name_edit.text = ""
		_skip_room_name_callback = false
		_room_name_edit.editable = false
		_room_type_option.disabled = true
		_room_res_option.disabled = true
		_room_res_total_spin.editable = false
		return
	var room: RoomInfo = _rooms[_selected_room_index]
	_room_name_edit.editable = true
	_room_type_option.disabled = false
	_room_res_option.disabled = false
	_room_res_total_spin.editable = true
	_skip_room_name_callback = true
	_room_name_edit.text = room.room_name
	_skip_room_name_callback = false
	_room_type_option.selected = room.room_type
	_room_res_option.selected = room.resource_type
	_room_res_total_spin.value = room.resource_total


func _make_level_button(text: String, level: int) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.button_pressed = (_edit_level == level)
	btn.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			_edit_level = level
			_update_all_buttons()
			_update_room_panel_visibility()
	)
	return btn


func _make_select_button(text: String, mode: int) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.button_pressed = (_select_mode == mode)
	btn.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			_select_mode = mode
			_update_all_buttons()
	)
	return btn


func _make_tool_button(text: String, tool_type: int) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.button_pressed = (_paint_tool == tool_type)
	btn.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			_paint_tool = tool_type
			_update_all_buttons()
	)
	return btn


func _update_all_buttons() -> void:
	var levels: Array[int] = [FloorTileType.EditLevel.FLOOR, FloorTileType.EditLevel.ROOM]
	for i in _level_buttons.size():
		_level_buttons[i].button_pressed = (_edit_level == levels[i])
	var select_modes: Array[int] = [FloorTileType.SelectMode.SINGLE, FloorTileType.SelectMode.BOX]
	var single_text: String = "选择房间" if _edit_level == FloorTileType.EditLevel.ROOM else "单选"
	var box_text: String = "框选房间" if _edit_level == FloorTileType.EditLevel.ROOM else "框选"
	for i in _select_buttons.size():
		_select_buttons[i].button_pressed = (_select_mode == select_modes[i])
		if i == 0:
			_select_buttons[i].text = single_text
		elif i == 1:
			_select_buttons[i].text = box_text
	var tools: Array[int] = [FloorTileType.PaintTool.EMPTY, FloorTileType.PaintTool.WALL, FloorTileType.PaintTool.ROOM_FLOOR, FloorTileType.PaintTool.ERASER]
	for i in _tool_buttons.size():
		_tool_buttons[i].button_pressed = (_paint_tool == tools[i])


func _refresh_room_list() -> void:
	for child in _room_list_container.get_children():
		child.queue_free()
	for i in _rooms.size():
		var room: RoomInfo = _rooms[i]
		var btn: Button = Button.new()
		var display_name: String = room.room_name if room.room_name else ("房间 %d" % (i + 1))
		btn.text = display_name
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var room_index: int = i
		btn.pressed.connect(func() -> void:
			_focus_camera_on_room(room_index)
		)
		_room_list_container.add_child(btn)


func _focus_camera_on_room(room_index: int) -> void:
	if room_index < 0 or room_index >= _rooms.size() or not _camera:
		return
	var room: RoomInfo = _rooms[room_index]
	var r: Rect2i = room.rect
	var center_x: float = (r.position.x + r.size.x / 2.0) * CELL_SIZE
	var center_y: float = (r.position.y + r.size.y / 2.0) * CELL_SIZE
	_camera.position = Vector2(center_x, center_y)
	_selected_room_index = room_index
	_refresh_room_panel()
	queue_redraw()


func _update_room_panel_visibility() -> void:
	_room_panel.visible = (_edit_level == FloorTileType.EditLevel.ROOM)
	_room_list_panel.visible = (_edit_level == FloorTileType.EditLevel.ROOM)
	if _edit_level == FloorTileType.EditLevel.ROOM:
		_refresh_room_list()
	# 一级编辑显示绘制工具，二级编辑隐藏
	var show_floor_tools: bool = (_edit_level == FloorTileType.EditLevel.FLOOR)
	for btn in _tool_buttons:
		btn.visible = show_floor_tools
	if _main_toolbar.get_child_count() > 2:
		_main_toolbar.get_child(2).visible = show_floor_tools  # HSeparator
	if _edit_level == FloorTileType.EditLevel.ROOM:
		_refresh_room_panel()


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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not _is_panning:
			if _select_mode == FloorTileType.SelectMode.SINGLE:
				if mb.pressed:
					if _edit_level == FloorTileType.EditLevel.FLOOR:
						_apply_paint_at_mouse()
					else:
						_try_select_room_at_mouse()
			else:
				if mb.pressed:
					_box_start = _get_mouse_grid()
					_is_drawing = true
				else:
					if _select_mode == FloorTileType.SelectMode.BOX and _box_start.x >= 0:
						if _edit_level == FloorTileType.EditLevel.FLOOR:
							_fill_box(_box_start, _get_mouse_grid())
						else:
							if _is_room_box_valid(_box_start, _get_mouse_grid()):
								_try_create_room(_box_start, _get_mouse_grid())
							_refresh_room_list()  # 框选结束后刷新房间列表，确保名称与数据一致
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
		elif _is_drawing and _select_mode == FloorTileType.SelectMode.BOX:
			queue_redraw()


func _process(_delta: float) -> void:
	if Input.is_key_pressed(KEY_ESCAPE):
		_is_drawing = false
		_box_start = Vector2i(-1, -1)
	
	# 标尺重绘
	if _ruler_overlay:
		_ruler_overlay.queue_redraw()
	
	# 框选时更新尺寸提示
	if _select_mode == FloorTileType.SelectMode.BOX and _is_drawing and _box_start.x >= 0:
		var end: Vector2i = _get_mouse_grid()
		var w: int = abs(end.x - _box_start.x) + 1
		var h: int = abs(end.y - _box_start.y) + 1
		_box_size_label.text = "%d×%d" % [w, h]
		_box_size_label.visible = true
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		_box_size_label.position = mouse_pos + Vector2(16, -8)
	else:
		_box_size_label.visible = false


func _get_mouse_grid() -> Vector2i:
	var viewport: Viewport = get_viewport()
	var mouse_pos: Vector2 = viewport.get_mouse_position()
	var world: Vector2 = viewport.get_canvas_transform().affine_inverse() * mouse_pos
	var gx: int = int(world.x / CELL_SIZE)
	var gy: int = int(world.y / CELL_SIZE)
	return Vector2i(clampi(gx, 0, GRID_WIDTH - 1), clampi(gy, 0, GRID_HEIGHT - 1))


func _get_tile_type_from_tool() -> int:
	match _paint_tool:
		FloorTileType.PaintTool.ERASER, FloorTileType.PaintTool.EMPTY:
			return FloorTileType.Type.EMPTY
		FloorTileType.PaintTool.WALL:
			return FloorTileType.Type.WALL
		FloorTileType.PaintTool.ROOM_FLOOR:
			return FloorTileType.Type.ROOM_FLOOR
		_:
			return FloorTileType.Type.EMPTY


func _apply_paint_at_mouse() -> void:
	var grid: Vector2i = _get_mouse_grid()
	if grid.x >= 0 and grid.x < GRID_WIDTH and grid.y >= 0 and grid.y < GRID_HEIGHT:
		_set_tile(grid.x, grid.y, _get_tile_type_from_tool())


func _try_select_room_at_mouse() -> void:
	var grid: Vector2i = _get_mouse_grid()
	if grid.x >= 0 and grid.x < GRID_WIDTH and grid.y >= 0 and grid.y < GRID_HEIGHT:
		var rid: int = _room_ids[grid.x][grid.y] as int
		if rid >= 0 and rid < _rooms.size():
			_selected_room_index = rid
			_refresh_room_panel()
			queue_redraw()


func _is_room_box_valid(start: Vector2i, end: Vector2i) -> bool:
	var x_min: int = mini(start.x, end.x)
	var x_max: int = maxi(start.x, end.x)
	var y_min: int = mini(start.y, end.y)
	var y_max: int = maxi(start.y, end.y)
	for gx in range(x_min, x_max + 1):
		for gy in range(y_min, y_max + 1):
			if gx < 0 or gx >= GRID_WIDTH or gy < 0 or gy >= GRID_HEIGHT:
				return false
			if _tiles[gx][gy] != FloorTileType.Type.ROOM_FLOOR:
				return false
			if _room_ids[gx][gy] >= 0:
				return false
	return true


func _try_create_room(start: Vector2i, end: Vector2i) -> void:
	var x_min: int = mini(start.x, end.x)
	var x_max: int = maxi(start.x, end.x)
	var y_min: int = mini(start.y, end.y)
	var y_max: int = maxi(start.y, end.y)
	# 校验：区域内全部为房间底板
	for gx in range(x_min, x_max + 1):
		for gy in range(y_min, y_max + 1):
			if gx < 0 or gx >= GRID_WIDTH or gy < 0 or gy >= GRID_HEIGHT:
				return
			if _tiles[gx][gy] != FloorTileType.Type.ROOM_FLOOR:
				print("无法创建房间：区域内有非房间底板")
				return
			if _room_ids[gx][gy] >= 0:
				print("无法创建房间：与已有房间重叠")
				return
	var w: int = x_max - x_min + 1
	var h: int = y_max - y_min + 1
	var room: RoomInfo = RoomInfo.new()
	room.id = "room_%d" % _next_room_id
	_next_room_id += 1
	room.room_name = "未命名房间"
	room.rect = Rect2i(x_min, y_min, w, h)
	room.room_type = RoomInfo.RoomType.EMPTY_ROOM
	room.resource_type = RoomInfo.ResourceType.NONE
	room.resource_total = 0
	_rooms.append(room)
	for gx in range(x_min, x_max + 1):
		for gy in range(y_min, y_max + 1):
			_room_ids[gx][gy] = _rooms.size() - 1
	_selected_room_index = _rooms.size() - 1
	_refresh_room_panel()
	_refresh_room_list()
	queue_redraw()
	print("已创建房间: ", room.room_name, " ", w, "×", h)


func _fill_box(start: Vector2i, end: Vector2i) -> void:
	var x_min: int = mini(start.x, end.x)
	var x_max: int = maxi(start.x, end.x)
	var y_min: int = mini(start.y, end.y)
	var y_max: int = maxi(start.y, end.y)
	var paint_type: int = _get_tile_type_from_tool()
	for gx in range(x_min, x_max + 1):
		for gy in range(y_min, y_max + 1):
			_set_tile(gx, gy, paint_type)


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
	for x in GRID_WIDTH:
		for y in GRID_HEIGHT:
			var tile_type: int = _tiles[x][y] as int
			var color: Color = TILE_COLORS.get(tile_type, TILE_COLORS[FloorTileType.Type.EMPTY]) as Color
			var rect: Rect2 = Rect2(x * CELL_SIZE, y * CELL_SIZE, CELL_SIZE, CELL_SIZE)
			draw_rect(rect, color)
			draw_rect(rect, Color(0.2, 0.2, 0.25), false)
	
	# 绘制网格线（较淡）
	for x in GRID_WIDTH + 1:
		draw_line(
			Vector2(x * CELL_SIZE, 0),
			Vector2(x * CELL_SIZE, GRID_HEIGHT * CELL_SIZE),
			Color(0.25, 0.25, 0.3, 0.5)
		)
	for y in GRID_HEIGHT + 1:
		draw_line(
			Vector2(0, y * CELL_SIZE),
			Vector2(GRID_WIDTH * CELL_SIZE, y * CELL_SIZE),
			Color(0.25, 0.25, 0.3, 0.5)
		)
	
	# 房间边框（二级编辑时显示）
	if _edit_level == FloorTileType.EditLevel.ROOM:
		for i in _rooms.size():
			var room: RoomInfo = _rooms[i]
			var r: Rect2i = room.rect
			var border_color: Color = Color(0.2, 0.6, 1, 0.8)
			if i == _selected_room_index:
				border_color = Color(1, 0.8, 0.2, 0.9)
			var px: float = r.position.x * CELL_SIZE
			var py: float = r.position.y * CELL_SIZE
			var pw: float = r.size.x * CELL_SIZE
			var ph: float = r.size.y * CELL_SIZE
			draw_rect(Rect2(px - 2, py - 2, pw + 4, ph + 4), border_color, false)
	
	# 框选预览
	if _select_mode == FloorTileType.SelectMode.BOX and _is_drawing and _box_start.x >= 0:
		var end: Vector2i = _get_mouse_grid()
		var x_min: int = mini(_box_start.x, end.x)
		var x_max: int = maxi(_box_start.x, end.x)
		var y_min: int = mini(_box_start.y, end.y)
		var y_max: int = maxi(_box_start.y, end.y)
		var preview_rect: Rect2 = Rect2(
			x_min * CELL_SIZE, y_min * CELL_SIZE,
			(x_max - x_min + 1) * CELL_SIZE, (y_max - y_min + 1) * CELL_SIZE
		)
		var is_valid: bool = true
		if _edit_level == FloorTileType.EditLevel.ROOM:
			is_valid = _is_room_box_valid(_box_start, end)
		if is_valid:
			draw_rect(preview_rect, Color(1, 1, 1, 0.2))
			draw_rect(preview_rect, Color(1, 1, 1, 0.5), false)
		else:
			draw_rect(preview_rect, Color(1, 0.2, 0.2, 0.3))
			draw_rect(preview_rect, Color(1, 0.3, 0.3, 0.9), false)


func _on_grid_snap_toggled(pressed: bool) -> void:
	_grid_snap_enabled = pressed
	if pressed and _camera:
		_snap_camera_to_grid()


func _snap_camera_to_grid() -> void:
	if not _camera:
		return
	_camera.position.x = roundf(_camera.position.x / CELL_SIZE) * CELL_SIZE
	_camera.position.y = roundf(_camera.position.y / CELL_SIZE) * CELL_SIZE


func _on_save_pressed() -> void:
	_save_scene()


func _save_scene() -> void:
	var data: Dictionary = {
		SAVE_KEY_GRID: GRID_WIDTH,
		SAVE_KEY_GRID_H: GRID_HEIGHT,
		SAVE_KEY_CELL: CELL_SIZE,
		SAVE_KEY_TILES: [],
		SAVE_KEY_ROOMS: [],
		"next_room_id": _next_room_id
	}
	for x in GRID_WIDTH:
		var col: Array = []
		for y in GRID_HEIGHT:
			col.append(_tiles[x][y])
		data[SAVE_KEY_TILES].append(col)
	for room in _rooms:
		data[SAVE_KEY_ROOMS].append(room.to_dict())
	
	var json: String = JSON.stringify(data)
	var file: FileAccess = FileAccess.open(_save_path, FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()
		print("场景已保存: ", _save_path)
	else:
		push_error("保存失败: ", _save_path)


func _load_scene() -> void:
	if not FileAccess.file_exists(_save_path):
		return
	var file: FileAccess = FileAccess.open(_save_path, FileAccess.READ)
	if not file:
		return
	var json: String = file.get_as_text()
	file.close()
	var result: Variant = JSON.parse_string(json)
	if result is Dictionary:
		var tiles_data: Array = (result as Dictionary).get(SAVE_KEY_TILES, []) as Array
		for x in min(tiles_data.size(), GRID_WIDTH):
			var col: Variant = tiles_data[x]
			if col is Array:
				for y in min(col.size(), GRID_HEIGHT):
					_tiles[x][y] = int(col[y])
		_rooms.clear()
		var rooms_data: Array = (result as Dictionary).get(SAVE_KEY_ROOMS, []) as Array
		for room_dict in rooms_data:
			if room_dict is Dictionary:
				_rooms.append(RoomInfo.from_dict(room_dict as Dictionary))
		_next_room_id = int((result as Dictionary).get("next_room_id", 0))
		_rebuild_room_ids()
		if _edit_level == FloorTileType.EditLevel.ROOM:
			_refresh_room_list()
		_selected_room_index = -1
		queue_redraw()
		print("场景已加载: ", _save_path)

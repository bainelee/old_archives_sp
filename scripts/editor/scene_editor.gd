extends Node2D
class_name SceneEditor

## 场景编辑器 - 网格与底板编辑
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
var _paint_tool: int = FloorTileType.PaintTool.ROOM_FLOOR
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
var _room_type_option: OptionButton
var _room_res_option: OptionButton
var _room_res_total_spin: SpinBox
var _room_base_image_edit: LineEdit  ## 底图路径，只读展示
var _room_base_image_btn: Button    ## 选择底图按钮
var _room_base_image_dialog: FileDialog
var _btn_delete_room: Button
var _main_toolbar: HBoxContainer
var _room_list_panel: PanelContainer
var _room_list_container: VBoxContainer
var _skip_room_name_callback: bool = false  ## 程序化设置 LineEdit 时跳过 text_changed，避免覆盖
var _base_image_cache: Dictionary = {}  ## path -> Texture2D，避免每帧重复加载
var _current_map_slot: int = -1  ## 当前地图槽位 0-4，-1 表示未保存
var _map_name_edit: LineEdit
var _open_map_panel: PanelContainer
var _open_map_slot_buttons: Array[Button] = []

const SAVE_KEY_GRID := "grid_width"
const SAVE_KEY_GRID_H := "grid_height"
const SAVE_KEY_CELL := "cell_size"
const SAVE_KEY_TILES := "tiles"
const SAVE_KEY_ROOMS := "rooms"
const SAVE_KEY_MAP_NAME := "map_name"
const MAP_SLOTS := 5
const MAPS_DIR := "user://maps/"


func _ready() -> void:
	# 像素图不模糊：使用最近邻过滤
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_migrate_old_map_to_slot0()
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
	
	# 单选、框选、选择（互斥）
	_select_buttons.clear()
	var btn_single: Button = _make_select_button("单选", FloorTileType.SelectMode.SINGLE)
	var btn_box: Button = _make_select_button("框选", FloorTileType.SelectMode.BOX)
	var btn_floor_select: Button = _make_select_button("选择", FloorTileType.SelectMode.FLOOR_SELECT)
	_select_buttons.append(btn_single)
	_select_buttons.append(btn_box)
	_select_buttons.append(btn_floor_select)
	_main_toolbar.add_child(btn_single)
	_main_toolbar.add_child(btn_box)
	_main_toolbar.add_child(btn_floor_select)
	_quick_room_buttons.clear()
	for sz in [Vector2i(5, 3), Vector2i(10, 3), Vector2i(5, 7)]:
		var qbtn: Button = _make_quick_room_button(sz.x, sz.y)
		_quick_room_buttons.append(qbtn)
		_main_toolbar.add_child(qbtn)
	var toolbar_sep: Control = HSeparator.new()
	toolbar_sep.name = "ToolbarSeparator"
	_main_toolbar.add_child(toolbar_sep)
	
	# 底板层级：移动（选择模式下有选区时显示）
	_btn_floor_move = Button.new()
	_btn_floor_move.text = "移动"
	_btn_floor_move.toggle_mode = true
	_btn_floor_move.toggled.connect(_on_floor_move_toggled)
	_main_toolbar.add_child(_btn_floor_move)
	
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
	_ui_layer.add_child(_room_base_image_dialog)
	
	# 地图名称
	var name_row: HBoxContainer = HBoxContainer.new()
	var lbl_name: Label = Label.new()
	lbl_name.text = "地图名："
	name_row.add_child(lbl_name)
	_map_name_edit = LineEdit.new()
	_map_name_edit.placeholder_text = "未命名地图"
	_map_name_edit.custom_minimum_size.x = 140
	name_row.add_child(_map_name_edit)
	vbox.add_child(name_row)
	
	# 网格对齐开关
	_grid_snap_check = CheckBox.new()
	_grid_snap_check.name = "GridSnapCheck"
	_grid_snap_check.text = "网格对齐"
	_grid_snap_check.toggled.connect(_on_grid_snap_toggled)
	vbox.add_child(_grid_snap_check)
	
	# 保存、打开
	var save_open_row: HBoxContainer = HBoxContainer.new()
	var btn_save: Button = Button.new()
	btn_save.text = "保存地图"
	btn_save.pressed.connect(_on_save_pressed)
	save_open_row.add_child(btn_save)
	var btn_open: Button = Button.new()
	btn_open.text = "打开地图"
	btn_open.pressed.connect(_on_open_map_pressed)
	save_open_row.add_child(btn_open)
	vbox.add_child(save_open_row)
	
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
	
	# 打开地图面板
	_open_map_panel = PanelContainer.new()
	_open_map_panel.name = "OpenMapPanel"
	_open_map_panel.visible = false
	var open_vbox: VBoxContainer = VBoxContainer.new()
	var open_title: Label = Label.new()
	open_title.text = "选择地图"
	open_vbox.add_child(open_title)
	_open_map_slot_buttons.clear()
	for i in MAP_SLOTS:
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
	btn_close_open.text = "关闭"
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
	
	# 底图
	var base_row: HBoxContainer = HBoxContainer.new()
	var lbl_base: Label = Label.new()
	lbl_base.text = "底图："
	base_row.add_child(lbl_base)
	_room_base_image_edit = LineEdit.new()
	_room_base_image_edit.placeholder_text = "无"
	_room_base_image_edit.editable = false
	_room_base_image_edit.custom_minimum_size.x = 120
	base_row.add_child(_room_base_image_edit)
	_room_base_image_btn = Button.new()
	_room_base_image_btn.text = "选择..."
	_room_base_image_btn.pressed.connect(_on_base_image_pick_pressed)
	base_row.add_child(_room_base_image_btn)
	var btn_clear_base: Button = Button.new()
	btn_clear_base.text = "清除"
	btn_clear_base.pressed.connect(_on_base_image_clear_pressed)
	base_row.add_child(btn_clear_base)
	vbox.add_child(base_row)
	
	var delete_row: HBoxContainer = HBoxContainer.new()
	_btn_delete_room = Button.new()
	_btn_delete_room.text = "删除房间"
	_btn_delete_room.pressed.connect(_on_delete_room_pressed)
	delete_row.add_child(_btn_delete_room)
	vbox.add_child(delete_row)
	
	# 底图文件选择对话框
	_room_base_image_dialog = FileDialog.new()
	_room_base_image_dialog.title = "选择底图"
	_room_base_image_dialog.access = FileDialog.ACCESS_RESOURCES
	_room_base_image_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_room_base_image_dialog.filters = ["*.png ; PNG 图像", "*.jpg, *.jpeg ; JPEG 图像", "*.webp ; WebP 图像"]
	_room_base_image_dialog.current_dir = "res://"
	_room_base_image_dialog.file_selected.connect(_on_base_image_selected)
	
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


func _on_delete_room_pressed() -> void:
	if _selected_room_index < 0 or _selected_room_index >= _rooms.size():
		return
	_rooms.remove_at(_selected_room_index)
	_rebuild_room_ids()
	_selected_room_index = -1
	_refresh_room_panel()
	_refresh_room_list()
	queue_redraw()
	print("已删除房间")


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
	if _selected_room_index < 0 or _selected_room_index >= _rooms.size():
		_skip_room_name_callback = true
		_room_name_edit.text = ""
		_skip_room_name_callback = false
		_room_name_edit.editable = false
		_room_type_option.disabled = true
		_room_res_option.disabled = true
		_room_res_total_spin.editable = false
		_room_base_image_btn.disabled = true
		_room_base_image_edit.text = ""
		_btn_delete_room.disabled = true
		return
	var room: RoomInfo = _rooms[_selected_room_index]
	_room_name_edit.editable = true
	_room_type_option.disabled = false
	_room_res_option.disabled = false
	_room_res_total_spin.editable = true
	_room_base_image_btn.disabled = false
	_btn_delete_room.disabled = false
	_skip_room_name_callback = true
	_room_name_edit.text = room.room_name
	_skip_room_name_callback = false
	_room_type_option.selected = room.room_type
	_room_res_option.selected = room.resource_type
	_room_res_total_spin.value = room.resource_total
	_room_base_image_edit.text = room.base_image_path.get_file() if room.base_image_path else ""


func _make_level_button(text: String, level: int) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.button_pressed = (_edit_level == level)
	btn.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			_edit_level = level
			if _edit_level == FloorTileType.EditLevel.FLOOR:
				_selected_room_index = -1
				_quick_room_size = Vector2i.ZERO
			else:
				_floor_selection = Rect2i(-1, -1, -1, -1)
				_floor_move_mode = false
				_floor_move_dragging = false
				if _select_mode == FloorTileType.SelectMode.FLOOR_SELECT:
					_select_mode = FloorTileType.SelectMode.SINGLE
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
			if mode != FloorTileType.SelectMode.FLOOR_SELECT:
				_floor_selection = Rect2i(-1, -1, -1, -1)
				_floor_move_mode = false
				_floor_move_dragging = false
			_update_all_buttons()
			_update_room_panel_visibility()
			queue_redraw()
	)
	return btn


func _make_quick_room_button(w: int, h: int) -> Button:
	var btn: Button = Button.new()
	btn.text = "%d×%d" % [w, h]
	btn.toggle_mode = true
	var size: Vector2i = Vector2i(w, h)
	btn.button_pressed = (_quick_room_size == size)
	btn.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			_quick_room_size = size
			for b in _quick_room_buttons:
				if b != btn:
					b.button_pressed = false
		else:
			# 仅当无其他按钮被选中时才清除，避免切换到第二按钮时误清除
			var other_pressed: bool = false
			for b in _quick_room_buttons:
				if b != btn and b.button_pressed:
					other_pressed = true
					break
			if not other_pressed:
				_quick_room_size = Vector2i.ZERO
		_update_all_buttons()
		queue_redraw()
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
	var select_modes: Array[int] = [FloorTileType.SelectMode.SINGLE, FloorTileType.SelectMode.BOX, FloorTileType.SelectMode.FLOOR_SELECT]
	var single_text: String = "选择房间" if _edit_level == FloorTileType.EditLevel.ROOM else "单选"
	var box_text: String = "框选房间" if _edit_level == FloorTileType.EditLevel.ROOM else "框选"
	for i in _select_buttons.size():
		_select_buttons[i].button_pressed = (i < select_modes.size() and _select_mode == select_modes[i])
		if i == 0:
			_select_buttons[i].text = single_text
		elif i == 1:
			_select_buttons[i].text = box_text
		elif i == 2:
			_select_buttons[i].visible = (_edit_level == FloorTileType.EditLevel.FLOOR)
	var qsizes: Array[Vector2i] = [Vector2i(5, 3), Vector2i(10, 3), Vector2i(5, 7)]
	for i in _quick_room_buttons.size():
		_quick_room_buttons[i].button_pressed = (i < qsizes.size() and _quick_room_size == qsizes[i])
		_quick_room_buttons[i].visible = (_edit_level == FloorTileType.EditLevel.ROOM and (_select_mode == FloorTileType.SelectMode.BOX))
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
	_btn_floor_move.visible = show_floor_tools and _select_mode == FloorTileType.SelectMode.FLOOR_SELECT and _floor_selection.position.x >= 0
	_btn_floor_move.button_pressed = _floor_move_mode
	var sep: Node = _main_toolbar.get_node_or_null("ToolbarSeparator")
	if sep:
		sep.visible = show_floor_tools
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


func _is_point_in_floor_selection(p: Vector2i) -> bool:
	if _floor_selection.position.x < 0:
		return false
	var r: Rect2i = _floor_selection
	return p.x >= r.position.x and p.x < r.position.x + r.size.x and p.y >= r.position.y and p.y < r.position.y + r.size.y


func _set_floor_selection(start: Vector2i, end: Vector2i) -> void:
	var x_min: int = mini(start.x, end.x)
	var x_max: int = maxi(start.x, end.x)
	var y_min: int = mini(start.y, end.y)
	var y_max: int = maxi(start.y, end.y)
	_floor_selection = Rect2i(x_min, y_min, x_max - x_min + 1, y_max - y_min + 1)
	_update_room_panel_visibility()
	queue_redraw()


func _apply_floor_move(release_grid: Vector2i) -> void:
	var r: Rect2i = _floor_selection
	if r.position.x < 0:
		return
	var offset: Vector2i = release_grid - _floor_move_drag_start
	var new_x: int = r.position.x + offset.x
	var new_y: int = r.position.y + offset.y
	if new_x == r.position.x and new_y == r.position.y:
		return  # 未移动
	# 检查新位置是否在网格内
	if new_x < 0 or new_y < 0 or new_x + r.size.x > GRID_WIDTH or new_y + r.size.y > GRID_HEIGHT:
		return
	# 复制到临时缓冲
	var temp: Array = []
	for gx in range(r.position.x, r.position.x + r.size.x):
		var col: Array = []
		for gy in range(r.position.y, r.position.y + r.size.y):
			col.append(_tiles[gx][gy])
		temp.append(col)
	# 清空原区域
	for gx in range(r.position.x, r.position.x + r.size.x):
		for gy in range(r.position.y, r.position.y + r.size.y):
			_tiles[gx][gy] = FloorTileType.Type.EMPTY
			_room_ids[gx][gy] = -1
	# 粘贴到新位置
	for i in r.size.x:
		for j in r.size.y:
			var gx: int = new_x + i
			var gy: int = new_y + j
			_tiles[gx][gy] = temp[i][j]
			_room_ids[gx][gy] = -1
	# 更新选择区域为新位置
	_floor_selection = Rect2i(new_x, new_y, r.size.x, r.size.y)
	queue_redraw()


func _clear_floor_selection() -> void:
	_floor_selection = Rect2i(-1, -1, -1, -1)
	_floor_move_mode = false
	_floor_move_dragging = false
	_update_room_panel_visibility()
	queue_redraw()


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
						_apply_floor_move(grid)
						_floor_move_dragging = false
						get_viewport().set_input_as_handled()
						return
			if _select_mode == FloorTileType.SelectMode.SINGLE:
				if mb.pressed:
					if _edit_level == FloorTileType.EditLevel.FLOOR:
						_apply_paint_at_mouse()
					else:
						_try_select_room_at_mouse()
			else:
				if mb.pressed:
					_box_start = _get_mouse_grid() if _quick_room_size == Vector2i.ZERO else Vector2i(-1, -1)
					_is_drawing = true
				else:
					if _select_mode == FloorTileType.SelectMode.BOX or _select_mode == FloorTileType.SelectMode.FLOOR_SELECT:
						if _quick_room_size != Vector2i.ZERO and _edit_level == FloorTileType.EditLevel.ROOM:
							# 快捷尺寸：以松开时鼠标位置为左上角（仅房间层级）
							var start: Vector2i = _get_mouse_grid()
							var end: Vector2i = start + _quick_room_size - Vector2i(1, 1)
							if _is_room_box_valid(start, end):
								_try_create_room(start, end)
							_refresh_room_list()
						elif _box_start.x >= 0:
							if _edit_level == FloorTileType.EditLevel.FLOOR:
								if _select_mode == FloorTileType.SelectMode.FLOOR_SELECT:
									_set_floor_selection(_box_start, _get_mouse_grid())
								else:
									_fill_box(_box_start, _get_mouse_grid())
							elif _edit_level == FloorTileType.EditLevel.ROOM:
								if _is_room_box_valid(_box_start, _get_mouse_grid()):
									_try_create_room(_box_start, _get_mouse_grid())
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
		else:
			_selected_room_index = -1
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


func _draw_single_base_image(tex: Texture2D, room_rect: Rect2i) -> void:
	var tw: float = tex.get_width()
	var th: float = tex.get_height()
	if tw <= 0 or th <= 0:
		return
	var px: float = room_rect.position.x * CELL_SIZE
	var py: float = room_rect.position.y * CELL_SIZE
	var room_px: Rect2 = Rect2(px, py, room_rect.size.x * CELL_SIZE, room_rect.size.y * CELL_SIZE)
	var img_rect: Rect2 = Rect2(px, py, tw, th)
	var clip: Rect2 = room_px.intersection(img_rect)
	if not clip.has_area():
		return
	var src_rect: Rect2 = Rect2(
		clip.position.x - img_rect.position.x,
		clip.position.y - img_rect.position.y,
		clip.size.x, clip.size.y
	)
	draw_texture_rect_region(tex, clip, src_rect)


func _get_base_image_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _base_image_cache.has(path):
		return _base_image_cache[path] as Texture2D
	var tex: Texture2D = load(path) as Texture2D
	if tex:
		_base_image_cache[path] = tex
	return tex


func _set_tile(gx: int, gy: int, type: int) -> void:
	if gx < 0 or gx >= GRID_WIDTH or gy < 0 or gy >= GRID_HEIGHT:
		return
	_tiles[gx][gy] = type
	if type != FloorTileType.Type.ROOM_FLOOR:
		_room_ids[gx][gy] = -1
	queue_redraw()


func _draw() -> void:
	var hide_source: bool = _floor_move_dragging and _floor_selection.position.x >= 0
	for x in GRID_WIDTH:
		for y in GRID_HEIGHT:
			if hide_source and _is_point_in_floor_selection(Vector2i(x, y)):
				var rect: Rect2 = Rect2(x * CELL_SIZE, y * CELL_SIZE, CELL_SIZE, CELL_SIZE)
				draw_rect(rect, TILE_COLORS[FloorTileType.Type.EMPTY])
				draw_rect(rect, Color(0.2, 0.2, 0.25), false)
				continue
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
	
	# 房间底图（进入场景即可见，仅显示一张、左上角对齐，超出房间不显示）
	for room in _rooms:
		if room.base_image_path.is_empty():
			continue
		var tex: Texture2D = _get_base_image_texture(room.base_image_path)
		if tex == null:
			continue
		_draw_single_base_image(tex, room.rect)
	
	# 房间边框（进入场景即可见，选中时高亮为黄色）
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
	if (_select_mode == FloorTileType.SelectMode.BOX or _select_mode == FloorTileType.SelectMode.FLOOR_SELECT) and _is_drawing:
		var start: Vector2i
		var end: Vector2i
		if _quick_room_size != Vector2i.ZERO:
			start = _get_mouse_grid()
			end = start + _quick_room_size - Vector2i(1, 1)
		elif _box_start.x >= 0:
			start = _box_start
			end = _get_mouse_grid()
		else:
			pass
		if _quick_room_size != Vector2i.ZERO or _box_start.x >= 0:
			var x_min: int = mini(start.x, end.x)
			var x_max: int = maxi(start.x, end.x)
			var y_min: int = mini(start.y, end.y)
			var y_max: int = maxi(start.y, end.y)
			if x_max >= x_min and y_max >= y_min:
				var preview_rect: Rect2 = Rect2(
					x_min * CELL_SIZE, y_min * CELL_SIZE,
					(x_max - x_min + 1) * CELL_SIZE, (y_max - y_min + 1) * CELL_SIZE
				)
				var is_valid: bool = true
				if _edit_level == FloorTileType.EditLevel.ROOM:
					is_valid = _is_room_box_valid(start, end)
				if is_valid:
					draw_rect(preview_rect, Color(1, 1, 1, 0.2))
					draw_rect(preview_rect, Color(1, 1, 1, 0.5), false)
				else:
					draw_rect(preview_rect, Color(1, 0.2, 0.2, 0.3))
					draw_rect(preview_rect, Color(1, 0.3, 0.3, 0.9), false)
	
	# 底板选择区域高亮与移动预览
	if _edit_level == FloorTileType.EditLevel.FLOOR and _floor_selection.position.x >= 0:
		var sel: Rect2i = _floor_selection
		var px: float = sel.position.x * CELL_SIZE
		var py: float = sel.position.y * CELL_SIZE
		var pw: float = sel.size.x * CELL_SIZE
		var ph: float = sel.size.y * CELL_SIZE
		var draw_rect_pos: Rect2 = Rect2(px, py, pw, ph)
		if _floor_move_dragging:
			var offset: Vector2i = _get_mouse_grid() - _floor_move_drag_start
			var dst_x: int = sel.position.x + offset.x
			var dst_y: int = sel.position.y + offset.y
			draw_rect_pos = Rect2(dst_x * CELL_SIZE, dst_y * CELL_SIZE, pw, ph)
			# 实时绘制被移动的底板内容
			for i in sel.size.x:
				for j in sel.size.y:
					var src_gx: int = sel.position.x + i
					var src_gy: int = sel.position.y + j
					if src_gx >= 0 and src_gx < GRID_WIDTH and src_gy >= 0 and src_gy < GRID_HEIGHT:
						var tile_type: int = _tiles[src_gx][src_gy] as int
						var color: Color = TILE_COLORS.get(tile_type, TILE_COLORS[FloorTileType.Type.EMPTY]) as Color
						var cell_rect: Rect2 = Rect2((dst_x + i) * CELL_SIZE, (dst_y + j) * CELL_SIZE, CELL_SIZE, CELL_SIZE)
						draw_rect(cell_rect, color)
						draw_rect(cell_rect, Color(0.2, 0.2, 0.25), false)
		draw_rect(Rect2(draw_rect_pos.position.x - 2, draw_rect_pos.position.y - 2, draw_rect_pos.size.x + 4, draw_rect_pos.size.y + 4), Color(0.2, 1, 0.4, 0.9), false)


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


func _get_slot_path(slot: int) -> String:
	return MAPS_DIR + "slot_%d.json" % slot


## 一次性迁移：若存在旧的 scene_archive.json 且槽位 0 为空，则迁移到 slot_0.json
func _migrate_old_map_to_slot0() -> void:
	var old_path: String = "user://scene_archive.json"
	var slot0_path: String = _get_slot_path(0)
	if not FileAccess.file_exists(old_path):
		return
	if FileAccess.file_exists(slot0_path):
		return
	var file: FileAccess = FileAccess.open(old_path, FileAccess.READ)
	if not file:
		return
	var json_str: String = file.get_as_text()
	file.close()
	var data: Variant = JSON.parse_string(json_str)
	if not (data is Dictionary):
		return
	(data as Dictionary)[SAVE_KEY_MAP_NAME] = "原场景"
	_ensure_maps_dir()
	var out: FileAccess = FileAccess.open(slot0_path, FileAccess.WRITE)
	if out:
		out.store_string(JSON.stringify(data))
		out.close()
		print("已从 scene_archive.json 迁移到槽位 1")


func _ensure_maps_dir() -> void:
	if not DirAccess.dir_exists_absolute(MAPS_DIR):
		DirAccess.make_dir_recursive_absolute(MAPS_DIR)


func _get_slot_map_name(slot: int) -> String:
	var path: String = _get_slot_path(slot)
	if not FileAccess.file_exists(path):
		return ""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return ""
	var json: String = file.get_as_text()
	file.close()
	var result: Variant = JSON.parse_string(json)
	if result is Dictionary:
		return str((result as Dictionary).get(SAVE_KEY_MAP_NAME, ""))
	return ""


func _refresh_open_map_panel() -> void:
	for i in MAP_SLOTS:
		var name_str: String = _get_slot_map_name(i)
		var btn: Button = _open_map_slot_buttons[i]
		if name_str.is_empty():
			btn.text = "槽位 %d: (空)" % (i + 1)
		else:
			btn.text = "槽位 %d: %s" % [i + 1, name_str]


func _on_save_pressed() -> void:
	_save_scene()


func _save_scene() -> void:
	var slot: int = _current_map_slot
	if slot < 0:
		slot = 0
	_current_map_slot = slot
	var map_name: String = _map_name_edit.text.strip_edges()
	if map_name.is_empty():
		map_name = "未命名地图"
	_ensure_maps_dir()
	var data: Dictionary = {
		SAVE_KEY_GRID: GRID_WIDTH,
		SAVE_KEY_GRID_H: GRID_HEIGHT,
		SAVE_KEY_CELL: CELL_SIZE,
		SAVE_KEY_TILES: [],
		SAVE_KEY_ROOMS: [],
		SAVE_KEY_MAP_NAME: map_name,
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
	var path: String = _get_slot_path(slot)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()
		print("地图已保存: ", path, " (", map_name, ")")
	else:
		push_error("保存失败: ", path)


func _on_open_map_pressed() -> void:
	_refresh_open_map_panel()
	_open_map_panel.visible = true


func _load_map_from_slot(slot: int) -> void:
	var path: String = _get_slot_path(slot)
	if not FileAccess.file_exists(path):
		print("槽位 ", slot + 1, " 为空")
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("无法打开: ", path)
		return
	var json: String = file.get_as_text()
	file.close()
	var result: Variant = JSON.parse_string(json)
	if result is Dictionary:
		var d: Dictionary = result as Dictionary
		var map_name: String = str(d.get(SAVE_KEY_MAP_NAME, ""))
		_map_name_edit.text = map_name
		for x in GRID_WIDTH:
			for y in GRID_HEIGHT:
				_tiles[x][y] = FloorTileType.Type.EMPTY
				_room_ids[x][y] = -1
		var tiles_data: Array = d.get(SAVE_KEY_TILES, []) as Array
		for x in min(tiles_data.size(), GRID_WIDTH):
			var col: Variant = tiles_data[x]
			if col is Array:
				for y in min(col.size(), GRID_HEIGHT):
					_tiles[x][y] = int(col[y])
		_rooms.clear()
		var rooms_data: Array = d.get(SAVE_KEY_ROOMS, []) as Array
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
		print("已加载地图: ", path)

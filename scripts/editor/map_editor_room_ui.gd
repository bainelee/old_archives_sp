class_name MapEditorRoomUIBuilder
extends RefCounted

## 地图编辑器房间相关 UI 构建 - 房间编辑面板、导入模板弹窗、保存确认弹窗、房间列表
## 将 UI 构建逻辑与主类解耦，通过 editor 参数连接信号与注入控件引用

const ROOM_INFO_JSON_PATH := "datas/room_info.json"


static func build_room_edit_panel(editor: Node) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "RoomPanel"
	var vbox: VBoxContainer = VBoxContainer.new()
	panel.add_child(vbox)

	var lbl: Label = Label.new()
	lbl.text = "房间信息（选中房间后可编辑）"
	vbox.add_child(lbl)

	var import_row: HBoxContainer = HBoxContainer.new()
	var btn_import_template: Button = Button.new()
	btn_import_template.text = "从模板导入"
	btn_import_template.pressed.connect(editor._on_import_template_pressed)
	import_row.add_child(btn_import_template)
	vbox.add_child(import_row)

	var name_row: HBoxContainer = HBoxContainer.new()
	var lbl_name: Label = Label.new()
	lbl_name.text = "名称："
	name_row.add_child(lbl_name)
	var room_name_edit: LineEdit = LineEdit.new()
	room_name_edit.placeholder_text = "房间名称"
	room_name_edit.custom_minimum_size.x = 160
	room_name_edit.text_changed.connect(editor._on_room_name_changed)
	name_row.add_child(room_name_edit)
	vbox.add_child(name_row)

	var type_row: HBoxContainer = HBoxContainer.new()
	var lbl_type: Label = Label.new()
	lbl_type.text = "类型："
	type_row.add_child(lbl_type)
	var room_type_option: OptionButton = OptionButton.new()
	for i in range(10):
		room_type_option.add_item(RoomInfo.get_room_type_name(i), i)
	room_type_option.item_selected.connect(editor._on_room_type_selected)
	type_row.add_child(room_type_option)
	vbox.add_child(type_row)

	var clean_row: HBoxContainer = HBoxContainer.new()
	var lbl_clean: Label = Label.new()
	lbl_clean.text = "清理状态："
	clean_row.add_child(lbl_clean)
	var room_clean_option: OptionButton = OptionButton.new()
	for i in range(2):
		room_clean_option.add_item(RoomInfo.get_clean_status_name(i), i)
	room_clean_option.item_selected.connect(editor._on_room_clean_selected)
	clean_row.add_child(room_clean_option)
	vbox.add_child(clean_row)

	var pre_clean_row: HBoxContainer = HBoxContainer.new()
	var lbl_pre_clean: Label = Label.new()
	lbl_pre_clean.text = "清理前文本："
	pre_clean_row.add_child(lbl_pre_clean)
	var room_pre_clean_edit: LineEdit = LineEdit.new()
	room_pre_clean_edit.placeholder_text = "默认清理前文本"
	room_pre_clean_edit.custom_minimum_size.x = 160
	room_pre_clean_edit.text_changed.connect(editor._on_room_pre_clean_changed)
	pre_clean_row.add_child(room_pre_clean_edit)
	vbox.add_child(pre_clean_row)

	var desc_row: HBoxContainer = HBoxContainer.new()
	var lbl_desc: Label = Label.new()
	lbl_desc.text = "描述："
	desc_row.add_child(lbl_desc)
	var room_desc_edit: TextEdit = TextEdit.new()
	room_desc_edit.placeholder_text = "房间背景描述"
	room_desc_edit.custom_minimum_size = Vector2(200, 100)
	room_desc_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	room_desc_edit.text_changed.connect(editor._on_room_desc_changed)
	desc_row.add_child(room_desc_edit)
	vbox.add_child(desc_row)

	var res_label_row: HBoxContainer = HBoxContainer.new()
	var lbl_res: Label = Label.new()
	lbl_res.text = "资源："
	res_label_row.add_child(lbl_res)
	var room_res_add_btn: Button = Button.new()
	room_res_add_btn.text = "添加"
	room_res_add_btn.pressed.connect(editor._on_room_res_add_pressed)
	res_label_row.add_child(room_res_add_btn)
	vbox.add_child(res_label_row)
	var room_resources_container: VBoxContainer = VBoxContainer.new()
	vbox.add_child(room_resources_container)

	var base_row: HBoxContainer = HBoxContainer.new()
	var lbl_base: Label = Label.new()
	lbl_base.text = "底图："
	base_row.add_child(lbl_base)
	var room_base_image_edit: LineEdit = LineEdit.new()
	room_base_image_edit.placeholder_text = "无"
	room_base_image_edit.editable = false
	room_base_image_edit.custom_minimum_size.x = 120
	base_row.add_child(room_base_image_edit)
	var room_base_image_btn: Button = Button.new()
	room_base_image_btn.text = "选择..."
	room_base_image_btn.pressed.connect(editor._on_base_image_pick_pressed)
	base_row.add_child(room_base_image_btn)
	var btn_clear_base: Button = Button.new()
	btn_clear_base.text = "清除"
	btn_clear_base.pressed.connect(editor._on_base_image_clear_pressed)
	base_row.add_child(btn_clear_base)
	vbox.add_child(base_row)

	var room_base_image_dialog: FileDialog = FileDialog.new()
	room_base_image_dialog.title = "选择底图"
	room_base_image_dialog.access = FileDialog.ACCESS_RESOURCES
	room_base_image_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	room_base_image_dialog.filters = ["*.png ; PNG 图像", "*.jpg, *.jpeg ; JPEG 图像", "*.webp ; WebP 图像"]
	room_base_image_dialog.current_dir = "res://"
	room_base_image_dialog.file_selected.connect(editor._on_base_image_selected)

	editor.set("_btn_import_template", btn_import_template)
	editor.set("_room_name_edit", room_name_edit)
	editor.set("_room_type_option", room_type_option)
	editor.set("_room_clean_option", room_clean_option)
	editor.set("_room_pre_clean_edit", room_pre_clean_edit)
	editor.set("_room_desc_edit", room_desc_edit)
	editor.set("_room_res_add_btn", room_res_add_btn)
	editor.set("_room_resources_container", room_resources_container)
	editor.set("_room_base_image_edit", room_base_image_edit)
	editor.set("_room_base_image_btn", room_base_image_btn)
	editor.set("_room_base_image_dialog", room_base_image_dialog)
	return panel


static func build_import_template_panel(editor: Node, ui_layer: CanvasLayer) -> void:
	var import_template_panel: PanelContainer = PanelContainer.new()
	import_template_panel.name = "ImportTemplatePanel"
	import_template_panel.visible = false
	var vbox: VBoxContainer = VBoxContainer.new()
	var lbl: Label = Label.new()
	lbl.text = "选择要导入的房间模板（编号 + 名称）"
	vbox.add_child(lbl)
	var import_template_list: ItemList = ItemList.new()
	import_template_list.custom_minimum_size = Vector2(220, 280)
	import_template_list.item_selected.connect(editor._on_import_template_item_selected)
	vbox.add_child(import_template_list)
	var btn_row: HBoxContainer = HBoxContainer.new()
	var btn_import: Button = Button.new()
	btn_import.text = "导入"
	btn_import.pressed.connect(editor._on_import_template_confirm_pressed)
	btn_row.add_child(btn_import)
	var btn_cancel: Button = Button.new()
	btn_cancel.text = "取消"
	btn_cancel.pressed.connect(func() -> void: import_template_panel.visible = false)
	btn_row.add_child(btn_cancel)
	vbox.add_child(btn_row)
	import_template_panel.add_child(vbox)
	import_template_panel.set_anchors_preset(Control.PRESET_CENTER)
	import_template_panel.offset_left = -120
	import_template_panel.offset_top = -160
	import_template_panel.offset_right = 120
	import_template_panel.offset_bottom = 160
	ui_layer.add_child(import_template_panel)
	editor.set("_import_template_panel", import_template_panel)
	editor.set("_import_template_list", import_template_list)


static func build_save_confirm_panel(editor: Node, ui_layer: CanvasLayer) -> void:
	var save_confirm_panel: PanelContainer = PanelContainer.new()
	save_confirm_panel.name = "SaveConfirmPanel"
	save_confirm_panel.visible = false
	var vbox: VBoxContainer = VBoxContainer.new()
	var lbl: Label = Label.new()
	lbl.text = "保存地图"
	vbox.add_child(lbl)
	var btn_save_current: Button = Button.new()
	btn_save_current.text = "保存当前地图"
	btn_save_current.pressed.connect(editor._on_save_confirm_save_current)
	vbox.add_child(btn_save_current)
	var btn_save_new: Button = Button.new()
	btn_save_new.text = "保存为新地图"
	btn_save_new.pressed.connect(editor._on_save_confirm_save_new)
	vbox.add_child(btn_save_new)
	var btn_cancel: Button = Button.new()
	btn_cancel.text = "取消"
	btn_cancel.pressed.connect(func() -> void: save_confirm_panel.visible = false)
	vbox.add_child(btn_cancel)
	save_confirm_panel.add_child(vbox)
	save_confirm_panel.set_anchors_preset(Control.PRESET_CENTER)
	save_confirm_panel.offset_left = -80
	save_confirm_panel.offset_top = -90
	save_confirm_panel.offset_right = 80
	save_confirm_panel.offset_bottom = 90
	ui_layer.add_child(save_confirm_panel)
	editor.set("_save_confirm_panel", save_confirm_panel)


static func build_room_list_panel(editor: Node, ui_layer: CanvasLayer) -> void:
	var room_list_panel: PanelContainer = PanelContainer.new()
	room_list_panel.name = "RoomListPanel"
	room_list_panel.visible = false
	var room_list_vbox: VBoxContainer = VBoxContainer.new()
	var room_list_toggle_btn: Button = Button.new()
	room_list_toggle_btn.text = "房间列表 ▼"
	room_list_toggle_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	room_list_toggle_btn.pressed.connect(editor._on_room_list_toggle_pressed)
	room_list_vbox.add_child(room_list_toggle_btn)
	var room_list_scroll: ScrollContainer = ScrollContainer.new()
	room_list_scroll.custom_minimum_size = Vector2(140, 120)
	var room_list_container: VBoxContainer = VBoxContainer.new()
	room_list_container.name = "RoomListItems"
	room_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_list_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	room_list_scroll.add_child(room_list_container)
	room_list_vbox.add_child(room_list_scroll)
	room_list_panel.add_child(room_list_vbox)
	room_list_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	room_list_panel.set_offset(Side.SIDE_RIGHT, -10)
	room_list_panel.set_offset(Side.SIDE_TOP, 10)
	room_list_panel.set_offset(Side.SIDE_LEFT, -170)
	room_list_panel.set_offset(Side.SIDE_BOTTOM, 10)
	ui_layer.add_child(room_list_panel)
	editor.set("_room_list_panel", room_list_panel)
	editor.set("_room_list_toggle_btn", room_list_toggle_btn)
	editor.set("_room_list_scroll", room_list_scroll)
	editor.set("_room_list_container", room_list_container)


static func refresh_room_panel(editor: Node) -> void:
	var selected_idx: int = editor.get("_selected_room_index")
	var rooms: Array = editor.get("_rooms")
	var room_name_edit: LineEdit = editor.get("_room_name_edit")
	var room_type_option: OptionButton = editor.get("_room_type_option")
	var room_clean_option: OptionButton = editor.get("_room_clean_option")
	var room_pre_clean_edit: LineEdit = editor.get("_room_pre_clean_edit")
	var room_desc_edit: TextEdit = editor.get("_room_desc_edit")
	var room_res_add_btn: Button = editor.get("_room_res_add_btn")
	var btn_import_template: Button = editor.get("_btn_import_template")
	var room_base_image_btn: Button = editor.get("_room_base_image_btn")
	var room_base_image_edit: LineEdit = editor.get("_room_base_image_edit")
	var btn_delete_room: Button = editor.get("_btn_delete_room")
	if selected_idx < 0 or selected_idx >= rooms.size():
		editor.set("_skip_room_name_callback", true)
		room_name_edit.text = ""
		editor.set("_skip_room_name_callback", false)
		room_name_edit.editable = false
		room_type_option.disabled = true
		room_clean_option.disabled = true
		room_pre_clean_edit.editable = false
		room_pre_clean_edit.text = ""
		room_desc_edit.editable = false
		room_desc_edit.text = ""
		room_res_add_btn.disabled = true
		btn_import_template.disabled = true
		room_base_image_btn.disabled = true
		room_base_image_edit.text = ""
		btn_delete_room.visible = false
		editor.call("_refresh_room_resources_ui")
		return
	var room: RoomInfo = rooms[selected_idx]
	room_name_edit.editable = true
	room_type_option.disabled = false
	room_clean_option.disabled = false
	room_pre_clean_edit.editable = true
	room_desc_edit.editable = true
	room_res_add_btn.disabled = false
	btn_import_template.disabled = false
	room_base_image_btn.disabled = false
	btn_delete_room.visible = true
	editor.set("_skip_room_name_callback", true)
	room_name_edit.text = room.room_name
	editor.set("_skip_room_name_callback", false)
	room_type_option.selected = room.room_type
	room_clean_option.selected = room.clean_status
	room_pre_clean_edit.text = room.pre_clean_text
	room_desc_edit.text = room.desc
	editor.call("_refresh_room_resources_ui")
	room_base_image_edit.text = room.base_image_path.get_file() if room.base_image_path else ""


static func refresh_room_list(editor: Node) -> void:
	var room_list_container: VBoxContainer = editor.get("_room_list_container")
	var rooms: Array = editor.get("_rooms")
	for child in room_list_container.get_children():
		child.queue_free()
	for i in rooms.size():
		var room: RoomInfo = rooms[i]
		var btn: Button = Button.new()
		var display_name: String = room.room_name if room.room_name else ("房间 %d" % (i + 1))
		btn.text = display_name
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var room_index: int = i
		btn.pressed.connect(func() -> void:
			editor.call("_focus_camera_on_room", room_index)
		)
		room_list_container.add_child(btn)


static func focus_camera_on_room(editor: Node, room_index: int) -> void:
	var rooms: Array = editor.get("_rooms")
	var camera: Camera2D = editor.get("_camera")
	var cell_size: int = editor.get("CELL_SIZE")
	if room_index < 0 or room_index >= rooms.size() or not camera:
		return
	var room: RoomInfo = rooms[room_index]
	var r: Rect2i = room.rect
	var center_x: float = (r.position.x + r.size.x / 2.0) * cell_size
	var center_y: float = (r.position.y + r.size.y / 2.0) * cell_size
	camera.position = Vector2(center_x, center_y)
	editor.set("_selected_room_index", room_index)
	refresh_room_panel(editor)
	editor.queue_redraw()


static func update_room_panel_visibility(editor: Node) -> void:
	var edit_level: int = editor.get("_edit_level")
	var selected_idx: int = editor.get("_selected_room_index")
	var room_list_dropdown_visible: bool = editor.get("_room_list_dropdown_visible")
	var room_panel: PanelContainer = editor.get("_room_panel")
	var room_list_panel: PanelContainer = editor.get("_room_list_panel")
	var room_list_scroll: ScrollContainer = editor.get("_room_list_scroll")
	var room_list_toggle_btn: Button = editor.get("_room_list_toggle_btn")
	var btn_delete_room: Button = editor.get("_btn_delete_room")
	var tool_buttons: Array = editor.get("_tool_buttons")
	var main_toolbar: HBoxContainer = editor.get("_main_toolbar")
	var btn_floor_move: Button = editor.get("_btn_floor_move")
	var select_mode: int = editor.get("_select_mode")
	var floor_selection: Rect2i = editor.get("_floor_selection")
	var floor_move_mode: bool = editor.get("_floor_move_mode")

	room_panel.visible = (edit_level == FloorTileType.EditLevel.ROOM)
	room_list_panel.visible = (edit_level == FloorTileType.EditLevel.ROOM)
	btn_delete_room.visible = (edit_level == FloorTileType.EditLevel.ROOM and selected_idx >= 0)
	if edit_level == FloorTileType.EditLevel.ROOM:
		room_list_scroll.visible = room_list_dropdown_visible
		room_list_toggle_btn.text = "房间列表 ▼" if room_list_dropdown_visible else "房间列表 ▶"
		refresh_room_list(editor)
	var show_floor_tools: bool = (edit_level == FloorTileType.EditLevel.FLOOR)
	for btn in tool_buttons:
		btn.visible = show_floor_tools
	btn_floor_move.visible = show_floor_tools and select_mode == FloorTileType.SelectMode.FLOOR_SELECT and floor_selection.position.x >= 0
	btn_floor_move.button_pressed = floor_move_mode
	var sep: Node = main_toolbar.get_node_or_null("ToolbarSeparator")
	if sep:
		sep.visible = show_floor_tools
	if edit_level == FloorTileType.EditLevel.ROOM:
		refresh_room_panel(editor)


static func refresh_room_resources_ui(editor: Node) -> void:
	var room_resources_container: VBoxContainer = editor.get("_room_resources_container")
	var selected_idx: int = editor.get("_selected_room_index")
	var rooms: Array = editor.get("_rooms")
	for c in room_resources_container.get_children():
		c.queue_free()
	if selected_idx < 0 or selected_idx >= rooms.size():
		return
	var room: RoomInfo = rooms[selected_idx]
	for i in room.resources.size():
		var r: Variant = room.resources[i]
		if not (r is Dictionary):
			continue
		var row: HBoxContainer = HBoxContainer.new()
		var opt: OptionButton = OptionButton.new()
		for j in range(7):
			opt.add_item(RoomInfo.get_resource_type_name(j), j)
		opt.selected = int(r.get("resource_type", RoomInfo.ResourceType.NONE))
		var res_idx: int = i
		opt.item_selected.connect(func(sel: int) -> void: editor.call("_on_room_res_type_changed", res_idx, sel))
		row.add_child(opt)
		var spin: SpinBox = SpinBox.new()
		spin.min_value = 0
		spin.max_value = 999999
		spin.value = int(r.get("resource_amount", 0))
		spin.value_changed.connect(func(v: float) -> void: editor.call("_on_room_res_amount_changed", res_idx, v))
		row.add_child(spin)
		var btn_rm: Button = Button.new()
		btn_rm.text = "删除"
		btn_rm.pressed.connect(func() -> void: editor.call("_on_room_res_remove_pressed", res_idx))
		row.add_child(btn_rm)
		room_resources_container.add_child(row)


static func load_room_templates() -> Variant:
	var project_path: String = ProjectSettings.globalize_path("res://")
	var json_path: String = project_path.path_join(ROOM_INFO_JSON_PATH)
	var file: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if not file:
		return null
	var json_str: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(json_str)
	if not (parsed is Dictionary):
		return null
	return (parsed as Dictionary).get("rooms", [])

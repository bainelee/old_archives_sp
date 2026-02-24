class_name SceneEditorToolbarBuilder
extends RefCounted

## 场景编辑器工具栏与按钮构建 - 编辑层级、选择模式、绘制工具、房间快捷尺寸
## 将按钮创建与 _update_all_buttons 与主类解耦

static func make_level_button(editor: Node, text: String, level: int) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.button_pressed = (editor.get("_edit_level") == level)
	btn.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			editor.set("_edit_level", level)
			if level == FloorTileType.EditLevel.FLOOR:
				editor.set("_selected_room_index", -1)
				editor.set("_quick_room_size", Vector2i.ZERO)
			else:
				editor.set("_floor_selection", Rect2i(-1, -1, -1, -1))
				editor.set("_floor_move_mode", false)
				editor.set("_floor_move_dragging", false)
				if editor.get("_select_mode") == FloorTileType.SelectMode.FLOOR_SELECT:
					editor.set("_select_mode", FloorTileType.SelectMode.SINGLE)
			editor.call("_update_all_buttons")
			editor.call("_update_room_panel_visibility")
	)
	return btn


static func make_select_button(editor: Node, text: String, mode: int) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.button_pressed = (editor.get("_select_mode") == mode)
	btn.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			editor.set("_select_mode", mode)
			if mode != FloorTileType.SelectMode.FLOOR_SELECT:
				editor.set("_floor_selection", Rect2i(-1, -1, -1, -1))
				editor.set("_floor_move_mode", false)
				editor.set("_floor_move_dragging", false)
			editor.call("_update_all_buttons")
			editor.call("_update_room_panel_visibility")
			editor.queue_redraw()
	)
	return btn


static func make_quick_room_button(editor: Node, w: int, h: int, quick_room_buttons: Array) -> Button:
	var btn: Button = Button.new()
	btn.text = "%d×%d" % [w, h]
	btn.toggle_mode = true
	var size: Vector2i = Vector2i(w, h)
	btn.button_pressed = (editor.get("_quick_room_size") == size)
	btn.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			editor.set("_quick_room_size", size)
			for b in quick_room_buttons:
				if b != btn:
					b.button_pressed = false
		else:
			var other_pressed: bool = false
			for b in quick_room_buttons:
				if b != btn and b.button_pressed:
					other_pressed = true
					break
			if not other_pressed:
				editor.set("_quick_room_size", Vector2i.ZERO)
		editor.call("_update_all_buttons")
		editor.queue_redraw()
	)
	return btn


static func make_tool_button(editor: Node, text: String, tool_type: int) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.button_pressed = (editor.get("_paint_tool") == tool_type)
	btn.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			editor.set("_paint_tool", tool_type)
			editor.call("_update_all_buttons")
	)
	return btn


static func update_all_buttons(editor: Node) -> void:
	var level_buttons: Array = editor.get("_level_buttons")
	var select_buttons: Array = editor.get("_select_buttons")
	var quick_room_buttons: Array = editor.get("_quick_room_buttons")
	var tool_buttons: Array = editor.get("_tool_buttons")
	var edit_level: int = editor.get("_edit_level")
	var select_mode: int = editor.get("_select_mode")
	var quick_room_size: Vector2i = editor.get("_quick_room_size")
	var paint_tool: int = editor.get("_paint_tool")

	var levels: Array[int] = [FloorTileType.EditLevel.FLOOR, FloorTileType.EditLevel.ROOM]
	for i in level_buttons.size():
		level_buttons[i].button_pressed = (edit_level == levels[i])
	var select_modes: Array[int] = [FloorTileType.SelectMode.SINGLE, FloorTileType.SelectMode.BOX, FloorTileType.SelectMode.FLOOR_SELECT]
	var single_text: String = "选择房间" if edit_level == FloorTileType.EditLevel.ROOM else "单选"
	var box_text: String = "框选房间" if edit_level == FloorTileType.EditLevel.ROOM else "框选"
	for i in select_buttons.size():
		select_buttons[i].button_pressed = (i < select_modes.size() and select_mode == select_modes[i])
		if i == 0:
			select_buttons[i].text = single_text
		elif i == 1:
			select_buttons[i].text = box_text
		elif i == 2:
			select_buttons[i].visible = (edit_level == FloorTileType.EditLevel.FLOOR)
	var qsizes: Array[Vector2i] = [Vector2i(5, 3), Vector2i(10, 3), Vector2i(5, 7)]
	for i in quick_room_buttons.size():
		quick_room_buttons[i].button_pressed = (i < qsizes.size() and quick_room_size == qsizes[i])
		quick_room_buttons[i].visible = (edit_level == FloorTileType.EditLevel.ROOM and (select_mode == FloorTileType.SelectMode.BOX))
	var tools: Array[int] = [FloorTileType.PaintTool.EMPTY, FloorTileType.PaintTool.WALL, FloorTileType.PaintTool.ROOM_FLOOR, FloorTileType.PaintTool.ERASER]
	for i in tool_buttons.size():
		tool_buttons[i].button_pressed = (paint_tool == tools[i])

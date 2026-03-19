class_name SlotPanelHelper
extends RefCounted


static func connect_slot_rows(slot_buttons: Array[Button], delete_buttons: Array[Button], on_select: Callable, on_delete: Callable) -> void:
	for i in slot_buttons.size():
		var slot_index: int = i
		slot_buttons[i].pressed.connect(func() -> void: on_select.call(slot_index))
		delete_buttons[i].pressed.connect(func() -> void: on_delete.call(slot_index))


static func refresh_slot_rows(slot_buttons: Array[Button], delete_buttons: Array[Button], mode: String) -> void:
	## mode: "new_game" / "save" / "load"
	for i in slot_buttons.size():
		var meta: Variant = SaveManager.get_slot_metadata(i)
		if meta == null:
			slot_buttons[i].text = TranslationServer.translate("SLOT_EMPTY") % [i + 1]
			delete_buttons[i].disabled = true
			if mode == "new_game":
				slot_buttons[i].tooltip_text = TranslationServer.translate("SLOT_TOOLTIP_NEW")
			elif mode == "save":
				slot_buttons[i].tooltip_text = TranslationServer.translate("SLOT_TOOLTIP_SAVE")
			else:
				slot_buttons[i].tooltip_text = TranslationServer.translate("SLOT_TOOLTIP_LOAD_EMPTY")
		else:
			var name_str: String = (meta as Dictionary).get("map_name", TranslationServer.translate("DEFAULT_UNTITLED"))
			slot_buttons[i].text = TranslationServer.translate("SLOT_WITH_NAME") % [i + 1, name_str]
			delete_buttons[i].disabled = false
			if mode == "new_game":
				slot_buttons[i].tooltip_text = TranslationServer.translate("SLOT_TOOLTIP_OVERWRITE")
			elif mode == "save":
				slot_buttons[i].tooltip_text = TranslationServer.translate("SLOT_TOOLTIP_SAVE")
			else:
				slot_buttons[i].tooltip_text = TranslationServer.translate("SLOT_TOOLTIP_LOAD")
		slot_buttons[i].disabled = (mode == "load" and meta == null)

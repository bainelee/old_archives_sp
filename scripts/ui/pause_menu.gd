extends CanvasLayer
## 游戏内暂停菜单 - 按 ESC 唤出
## 选项：返回游戏、保存游戏、载入游戏、设置、退出游戏

const START_MENU_SCENE := "res://scenes/ui/start_menu.tscn"
const GAME_MAIN_SCENE := "res://scenes/game/game_main.tscn"

@onready var _panel: Control = $Panel
@onready var _btn_resume: Button = $Panel/Center/MenuPanel/VBox/BtnResume
@onready var _btn_save: Button = $Panel/Center/MenuPanel/VBox/BtnSave
@onready var _btn_load: Button = $Panel/Center/MenuPanel/VBox/BtnLoad
@onready var _btn_settings: Button = $Panel/Center/MenuPanel/VBox/BtnSettings
@onready var _btn_quit: Button = $Panel/Center/MenuPanel/VBox/BtnQuit
@onready var _slot_panel: Control = $SlotPanel
@onready var _slot_buttons: Array[Button] = [
	$SlotPanel/Center/Panel/VBox/Slot0Row/Slot0,
	$SlotPanel/Center/Panel/VBox/Slot1Row/Slot1,
	$SlotPanel/Center/Panel/VBox/Slot2Row/Slot2,
	$SlotPanel/Center/Panel/VBox/Slot3Row/Slot3,
	$SlotPanel/Center/Panel/VBox/Slot4Row/Slot4,
]
@onready var _delete_buttons: Array[Button] = [
	$SlotPanel/Center/Panel/VBox/Slot0Row/BtnDelete0,
	$SlotPanel/Center/Panel/VBox/Slot1Row/BtnDelete1,
	$SlotPanel/Center/Panel/VBox/Slot2Row/BtnDelete2,
	$SlotPanel/Center/Panel/VBox/Slot3Row/BtnDelete3,
	$SlotPanel/Center/Panel/VBox/Slot4Row/BtnDelete4,
]
@onready var _btn_slot_cancel: Button = $SlotPanel/Center/Panel/VBox/BtnSlotCancel
@onready var _delete_confirm: ConfirmationDialog = $SlotPanel/DeleteConfirmDialog

enum Mode { MAIN, SAVE, LOAD }
var _mode: Mode = Mode.MAIN
var _pending_delete_slot: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_panel.visible = true
	_slot_panel.visible = false
	_setup_buttons()


func _setup_buttons() -> void:
	_btn_resume.pressed.connect(_on_resume)
	_btn_save.pressed.connect(_on_save)
	_btn_load.pressed.connect(_on_load)
	_btn_settings.pressed.connect(_on_settings)
	_btn_quit.pressed.connect(_on_quit)
	_btn_slot_cancel.pressed.connect(_on_slot_cancel)
	_delete_confirm.confirmed.connect(_on_delete_confirmed)
	for i in _slot_buttons.size():
		var slot_index := i
		_slot_buttons[i].pressed.connect(func() -> void: _on_slot_selected(slot_index))
		_delete_buttons[i].pressed.connect(func() -> void: _on_delete_clicked(slot_index))


func show_menu() -> void:
	visible = true
	_mode = Mode.MAIN
	_panel.visible = true
	_slot_panel.visible = false
	get_tree().paused = true


func hide_menu() -> void:
	visible = false
	get_tree().paused = false


func _on_resume() -> void:
	hide_menu()


func _on_save() -> void:
	_mode = Mode.SAVE
	_show_slot_panel("选择保存槽位")


func _on_load() -> void:
	_mode = Mode.LOAD
	_show_slot_panel("选择载入槽位")


func _show_slot_panel(title: String) -> void:
	_panel.visible = false
	_slot_panel.visible = true
	var title_label: Label = _slot_panel.get_node_or_null("Center/Panel/VBox/Label")
	if title_label:
		title_label.text = title
	_refresh_slot_buttons()


func _refresh_slot_buttons() -> void:
	for i in _slot_buttons.size():
		var meta: Variant = SaveManager.get_slot_metadata(i)
		if meta == null:
			_slot_buttons[i].text = "槽位 %d - 空" % [i + 1]
			_delete_buttons[i].disabled = true
		else:
			var name_str: String = (meta as Dictionary).get("map_name", "未命名")
			_slot_buttons[i].text = "槽位 %d - %s" % [i + 1, name_str]
			_delete_buttons[i].disabled = false
		_slot_buttons[i].disabled = (_mode == Mode.LOAD and meta == null)


func _on_delete_clicked(slot: int) -> void:
	_pending_delete_slot = slot
	_delete_confirm.popup_centered()


func _on_delete_confirmed() -> void:
	if _pending_delete_slot < 0:
		return
	if SaveManager.delete_slot(_pending_delete_slot):
		_refresh_slot_buttons()
	_pending_delete_slot = -1


func _on_slot_cancel() -> void:
	_panel.visible = true
	_slot_panel.visible = false


func _on_slot_selected(slot: int) -> void:
	if _mode == Mode.SAVE:
		_do_save(slot)
	elif _mode == Mode.LOAD:
		_do_load(slot)
	_panel.visible = true
	_slot_panel.visible = false


func _do_save(slot: int) -> void:
	var game_main: Node = get_parent()
	if not game_main.has_method("collect_game_state"):
		push_error("PauseMenu: GameMain 无 collect_game_state 方法")
		return
	var game_state: Dictionary = game_main.collect_game_state()
	if SaveManager.save_to_slot(slot, game_state):
		SaveManager.pending_load_slot = slot
		# 可选：Toast 提示，暂用 print
		print("已保存至槽位 %d" % [slot + 1])
	else:
		push_error("保存失败")


func _do_load(slot: int) -> void:
	SaveManager.pending_load_slot = slot
	hide_menu()
	get_tree().change_scene_to_file(GAME_MAIN_SCENE)


func _on_settings() -> void:
	print("设置（待实现）")


func _on_quit() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(START_MENU_SCENE)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			if _slot_panel.visible:
				_on_slot_cancel()
			else:
				hide_menu()
		else:
			show_menu()
		get_viewport().set_input_as_handled()

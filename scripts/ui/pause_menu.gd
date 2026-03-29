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
var _was_flowing_before_menu: bool = true  ## show_menu 前的时间流逝状态，hide_menu 时恢复


func _game_main_node() -> Node:
	## PauseMenu 挂在 InteractiveUiRoot 下，存档/退出需指向 GameMain
	var p: Node = get_parent()
	if p and String(p.name) == "InteractiveUiRoot":
		return p.get_parent()
	return p


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
	SlotPanelHelper.connect_slot_rows(_slot_buttons, _delete_buttons, Callable(self, "_on_slot_selected"), Callable(self, "_on_delete_clicked"))


func show_menu() -> void:
	_was_flowing_before_menu = GameTime.is_flowing if GameTime else true
	if GameTime:
		GameTime.is_flowing = false
	visible = true
	_mode = Mode.MAIN
	_panel.visible = true
	_slot_panel.visible = false
	get_tree().paused = true


func hide_menu() -> void:
	visible = false
	if GameTime:
		GameTime.is_flowing = _was_flowing_before_menu
	## 关闭菜单时根据时间是否在流逝决定 tree.paused，避免时间暂停时恢复游戏逻辑
	get_tree().paused = not (GameTime and GameTime.is_flowing)


func _on_resume() -> void:
	hide_menu()


func _on_save() -> void:
	_mode = Mode.SAVE
	_show_slot_panel(tr("SLOT_SELECT_SAVE"))


func _on_load() -> void:
	_mode = Mode.LOAD
	_show_slot_panel(tr("SLOT_SELECT_LOAD"))


func _show_slot_panel(title: String) -> void:
	_panel.visible = false
	_slot_panel.visible = true
	var title_label: Label = _slot_panel.get_node_or_null("Center/Panel/VBox/Label")
	if title_label:
		title_label.text = title
	_refresh_slot_buttons()


func _refresh_slot_buttons() -> void:
	var mode_key: String = "save" if _mode == Mode.SAVE else "load"
	SlotPanelHelper.refresh_slot_rows(_slot_buttons, _delete_buttons, mode_key)


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
	var game_main: Node = _game_main_node()
	if not game_main.has_method("collect_game_state"):
		push_error(tr("ERROR_PAUSE_NO_COLLECT"))
		return
	var game_state: Dictionary = game_main.collect_game_state()
	if SaveManager.save_to_slot(slot, game_state):
		SaveManager.pending_load_slot = slot
		# 可选：Toast 提示，暂用 print
		print("已保存至槽位 %d" % [slot + 1])
	else:
		push_error(tr("ERROR_SAVE_FAILED"))


func _do_load(slot: int) -> void:
	SaveManager.pending_load_slot = slot
	hide_menu()
	get_tree().change_scene_to_file(GAME_MAIN_SCENE)


func _on_settings() -> void:
	print("设置（待实现）")


func _on_quit() -> void:
	get_tree().paused = false
	## 退出前自动保存到当前槽位，确保进度不丢失
	var game_main: Node = _game_main_node()
	if game_main and game_main.has_method("collect_game_state") and game_main.get("_current_slot") != null:
		var slot: int = int(game_main.get("_current_slot"))
		var game_state: Dictionary = game_main.collect_game_state()
		SaveManager.save_to_slot(slot, game_state)
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

extends Control

## 游戏开始界面 - 主菜单
## 显示游戏名称、新游戏、继续游戏、设定、退出游戏
## 无存档时「继续游戏」禁用；新游戏需选择槽位并创建存档

const GAME_MAIN_SCENE := "res://scenes/game/game_main.tscn"

@onready var _btn_new_game: Button = $Center/VBox/BtnNewGame
@onready var _btn_continue: Button = $Center/VBox/BtnContinue
@onready var _btn_settings: Button = $Center/VBox/BtnSettings
@onready var _btn_quit: Button = $Center/VBox/BtnQuit
@onready var _slot_panel: Control = $SlotSelectPanel
@onready var _slot_buttons: Array[Button] = [
	$SlotSelectPanel/Center/Panel/VBox/Slot0Row/Slot0,
	$SlotSelectPanel/Center/Panel/VBox/Slot1Row/Slot1,
	$SlotSelectPanel/Center/Panel/VBox/Slot2Row/Slot2,
	$SlotSelectPanel/Center/Panel/VBox/Slot3Row/Slot3,
	$SlotSelectPanel/Center/Panel/VBox/Slot4Row/Slot4,
]
@onready var _delete_buttons: Array[Button] = [
	$SlotSelectPanel/Center/Panel/VBox/Slot0Row/BtnDelete0,
	$SlotSelectPanel/Center/Panel/VBox/Slot1Row/BtnDelete1,
	$SlotSelectPanel/Center/Panel/VBox/Slot2Row/BtnDelete2,
	$SlotSelectPanel/Center/Panel/VBox/Slot3Row/BtnDelete3,
	$SlotSelectPanel/Center/Panel/VBox/Slot4Row/BtnDelete4,
]
@onready var _btn_cancel: Button = $SlotSelectPanel/Center/Panel/VBox/BtnCancel
@onready var _delete_confirm: ConfirmationDialog = $SlotSelectPanel/DeleteConfirmDialog

var _pending_delete_slot: int = -1


func _ready() -> void:
	_setup_buttons()
	_setup_slot_panel()
	_update_continue_availability()


func _setup_buttons() -> void:
	_btn_new_game.pressed.connect(_on_new_game)
	_btn_continue.pressed.connect(_on_continue)
	_btn_settings.pressed.connect(_on_settings)
	_btn_quit.pressed.connect(_on_quit)


func _setup_slot_panel() -> void:
	for i in _slot_buttons.size():
		var slot_index := i
		_slot_buttons[i].pressed.connect(func() -> void: _on_slot_selected(slot_index))
		_delete_buttons[i].pressed.connect(func() -> void: _on_delete_clicked(slot_index))
	_btn_cancel.pressed.connect(_on_slot_cancel)
	_delete_confirm.confirmed.connect(_on_delete_confirmed)


func _update_continue_availability() -> void:
	## 若无存档则禁用「继续游戏」
	var has_save := SaveManager.get_first_occupied_slot() >= 0
	_btn_continue.disabled = not has_save
	if not has_save:
		_btn_continue.tooltip_text = "暂无存档"
	else:
		_btn_continue.tooltip_text = ""


func _on_new_game() -> void:
	_refresh_slot_panel()
	_slot_panel.visible = true


func _on_slot_cancel() -> void:
	_slot_panel.visible = false


func _on_slot_selected(slot: int) -> void:
	var game_state: Dictionary = SaveManager.create_new_game_state("新游戏")
	if not SaveManager.save_to_slot(slot, game_state):
		push_error("新游戏存档创建失败")
		return
	SaveManager.pending_load_slot = slot
	get_tree().change_scene_to_file(GAME_MAIN_SCENE)


func _refresh_slot_panel() -> void:
	## 刷新槽位按钮显示
	for i in _slot_buttons.size():
		var meta: Variant = SaveManager.get_slot_metadata(i)
		if meta == null:
			_slot_buttons[i].text = "槽位 %d - 空" % [i + 1]
			_slot_buttons[i].tooltip_text = "新建存档"
			_delete_buttons[i].disabled = true
		else:
			var name_str: String = (meta as Dictionary).get("map_name", "未命名")
			_slot_buttons[i].text = "槽位 %d - %s" % [i + 1, name_str]
			_slot_buttons[i].tooltip_text = "覆盖已有存档"
			_delete_buttons[i].disabled = false
	_update_continue_availability()


func _on_delete_clicked(slot: int) -> void:
	_pending_delete_slot = slot
	_delete_confirm.popup_centered()


func _on_delete_confirmed() -> void:
	if _pending_delete_slot < 0:
		return
	if SaveManager.delete_slot(_pending_delete_slot):
		_refresh_slot_panel()
	_pending_delete_slot = -1


func _on_continue() -> void:
	var slot: int = SaveManager.get_first_occupied_slot()
	if slot < 0:
		return
	SaveManager.pending_load_slot = slot
	get_tree().change_scene_to_file(GAME_MAIN_SCENE)


func _on_settings() -> void:
	## 设定界面待实现
	print("设定（待实现）")


func _on_quit() -> void:
	get_tree().quit()

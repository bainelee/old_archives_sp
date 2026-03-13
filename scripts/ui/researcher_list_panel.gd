extends PanelContainer
## 研究员列表面板：列表 + 详情，点击行聚焦镜头并切到详情；入口按钮在 ui_main 中

var _game_main: Node = null
var _showing_detail: bool = false
var _detail_researcher_id: int = -1

@onready var _list_container: Control = $Margin/VBox/ListContainer
@onready var _detail_container: Control = $Margin/VBox/DetailContainer
@onready var _item_list: ItemList = $Margin/VBox/ListContainer/ItemList
@onready var _btn_back: Button = $Margin/VBox/DetailContainer/BackRow/BtnBack
@onready var _label_id: Label = $Margin/VBox/DetailContainer/DetailScroll/VBox/IdRow/Value
@onready var _label_name: Label = $Margin/VBox/DetailContainer/DetailScroll/VBox/NameRow/Value
@onready var _label_state: Label = $Margin/VBox/DetailContainer/DetailScroll/VBox/StateRow/Value
@onready var _label_work_area: Label = $Margin/VBox/DetailContainer/DetailScroll/VBox/WorkAreaRow/Value
@onready var _label_living_area: Label = $Margin/VBox/DetailContainer/DetailScroll/VBox/LivingAreaRow/Value
@onready var _label_erosion_prob: Label = $Margin/VBox/DetailContainer/DetailScroll/VBox/ErosionProbRow/Value
@onready var _label_recovery_prob: Label = $Margin/VBox/DetailContainer/DetailScroll/VBox/RecoveryProbRow/Value
@onready var _label_cognition_per_hour: Label = $Margin/VBox/DetailContainer/DetailScroll/VBox/CognitionPerHourRow/Value
@onready var _label_info_output: Label = $Margin/VBox/DetailContainer/DetailScroll/VBox/InfoOutputRow/Value


func _ready() -> void:
	_game_main = _get_game_main()
	_item_list.item_clicked.connect(_on_list_item_clicked)
	_btn_back.pressed.connect(_on_back_pressed)
	if GameTime:
		GameTime.time_updated.connect(_on_time_updated)
	_refresh_list()


func _exit_tree() -> void:
	if GameTime and GameTime.time_updated.is_connected(_on_time_updated):
		GameTime.time_updated.disconnect(_on_time_updated)
	_list_container.visible = true
	_detail_container.visible = false
	hide()


func _on_time_updated() -> void:
	## 详情可见时随游戏时间同步刷新状态与信息
	if visible and _showing_detail and _detail_researcher_id >= 0:
		_refresh_detail_labels()


func _get_game_main() -> Node:
	var root: Node = get_tree().current_scene
	if root:
		return root
	return get_tree().root.get_child(get_tree().root.get_child_count() - 1)


## 入口按钮点击：若在详情则退回列表，若在列表则关闭面板，否则打开面板并显示列表
func toggle_from_entry() -> void:
	if _showing_detail:
		_show_list()
		return
	if visible:
		hide()
		return
	_show_list()
	show()


func _refresh_list() -> void:
	_item_list.clear()
	if not _game_main or not PersonnelErosionCore:
		return
	var researchers: Array = PersonnelErosionCore.get_researchers()
	researchers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.get("id", 0) < b.get("id", 0))
	for r in researchers:
		var rid: int = int(r.get("id", 0))
		var name_str: String = "研究员 %d" % rid
		_item_list.add_item("%d %s" % [rid, name_str], null)
		_item_list.set_item_metadata(_item_list.item_count - 1, rid)


func _show_list() -> void:
	_showing_detail = false
	_detail_researcher_id = -1
	_refresh_list()
	_list_container.visible = true
	_detail_container.visible = false


func _show_detail(researcher_id: int) -> void:
	_showing_detail = true
	_detail_researcher_id = researcher_id
	if _game_main and _game_main.has_method("focus_camera_on_researcher"):
		_game_main.focus_camera_on_researcher(researcher_id)
	_refresh_detail_labels()
	_list_container.visible = false
	_detail_container.visible = true


func _refresh_detail_labels() -> void:
	if not _game_main or not _game_main.has_method("get_researcher_detail") or _detail_researcher_id < 0:
		return
	var d: Dictionary = _game_main.get_researcher_detail(_detail_researcher_id)
	_label_id.text = str(d.get("id", ""))
	_label_name.text = str(d.get("name", ""))
	_label_state.text = str(d.get("current_state", ""))
	_label_work_area.text = str(d.get("work_area", ""))
	_label_living_area.text = str(d.get("living_area", ""))
	_label_erosion_prob.text = "%d%%" % int(d.get("erosion_prob", 0))
	_label_recovery_prob.text = "%d%%" % int(d.get("recovery_prob", 0))
	_label_cognition_per_hour.text = str(d.get("cognition_per_hour", 0))
	_label_info_output.text = str(d.get("info_output", "—"))


func _on_list_item_clicked(index: int, _at_position: Vector2, _mouse_button: int) -> void:
	var rid: Variant = _item_list.get_item_metadata(index)
	if rid != null:
		_show_detail(int(rid))


func _on_back_pressed() -> void:
	_show_list()

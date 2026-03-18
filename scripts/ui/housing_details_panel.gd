@tool
extends PanelContainer
## 住房详细信息面板
## 结构：无状态文、储存标题「住房信息总览」、住房总览条（需求/已提供）；可分配/住房缺口/住房产出+细则/住房总数；Figma 76:65
## 住房缺口时显示警告；编辑器可见逻辑禁止放在 _ready；见 .cursor/rules/ui-no-ready.mdc

@export_group("布局配置")
@export var content_margin_horizontal: int = 20:
	set(v):
		content_margin_horizontal = maxi(0, v)
		_apply_content_margin()

@export var separation: int = 4:
	set(v):
		separation = maxi(0, v)
		_apply_separation()

var _content_margin: MarginContainer
var _content_vbox: VBoxContainer
var _details_vbox: VBoxContainer

func _enter_tree() -> void:
	_details_vbox = get_node_or_null("DetailsVboxContainer") as VBoxContainer
	_content_margin = get_node_or_null("DetailsVboxContainer/ContentMargin") as MarginContainer
	_content_vbox = get_node_or_null("DetailsVboxContainer/ContentMargin/ContentVbox") as VBoxContainer
	_apply_content_margin()
	_apply_separation()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _get_content_margin() -> MarginContainer:
	return _content_margin if _content_margin else get_node_or_null("DetailsVboxContainer/ContentMargin") as MarginContainer


func _get_details_vbox() -> VBoxContainer:
	return _details_vbox if _details_vbox else get_node_or_null("DetailsVboxContainer") as VBoxContainer


func _get_content_vbox() -> VBoxContainer:
	return _content_vbox if _content_vbox else get_node_or_null("DetailsVboxContainer/ContentMargin/ContentVbox") as VBoxContainer


func _apply_content_margin() -> void:
	var m: MarginContainer = _get_content_margin()
	if m:
		m.add_theme_constant_override("margin_left", content_margin_horizontal)
		m.add_theme_constant_override("margin_right", content_margin_horizontal)


func _apply_separation() -> void:
	var dv: VBoxContainer = _get_details_vbox()
	var cv: VBoxContainer = _get_content_vbox()
	if dv:
		dv.add_theme_constant_override("separation", separation)
	if cv:
		cv.add_theme_constant_override("separation", separation)


## 运行期：显示住房详细信息
func show_for_housing(_data: Dictionary) -> void:
	visible = true


func hide_panel() -> void:
	visible = false

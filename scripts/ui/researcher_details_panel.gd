@tool
extends PanelContainer
## 研究员详细信息面板
## 结构：无状态文、储存标题「研究员总览」、三段进度条（闲置/在职/被侵蚀）；闲置/被侵蚀/在职+区域细则/研究员总数；见 [ui-detail-panel-design.md](docs/predesign/ui-detail-panel-design.md)
## 研究员总览不显示警告文本；Figma 70:964
## 编辑器可见逻辑禁止放在 _ready；见 .cursor/rules/ui-no-ready.mdc / ui-editor-live.mdc

@export_group("布局配置")
@export var content_margin_horizontal: int = 20:
	set(v):
		content_margin_horizontal = maxi(0, v)
		_apply_content_margin()

@export var separation: int = 4:
	set(v):
		separation = maxi(0, v)
		_apply_separation()

@export_group("编辑器")
@export var editor_preview: bool = true:
	set(v):
		editor_preview = v
		_update_editor_preview()

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


func _update_editor_preview() -> void:
	if not Engine.is_editor_hint():
		return
	_apply_content_margin()
	_apply_separation()


## 运行期：显示研究员详细信息；data 可含 idle, eroded, on_duty, total, region_breakdown 等
func show_for_researcher(_data: Dictionary) -> void:
	visible = true


func hide_panel() -> void:
	visible = false

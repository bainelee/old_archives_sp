@tool
extends PanelContainer
## 计算因子详细信息面板
## 计算因子消耗组为「核心消耗」、仅 title 层无子条目；见 [ui-detail-panel-design.md](docs/predesign/ui-detail-panel-design.md)
## 复用 [ui-detail-panel-summary.md](docs/predesign/ui-detail-panel-summary.md) 的组件与资产；Figma 67:751
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

@export var storage_progress_wrapper_path: NodePath = NodePath("DetailsVboxContainer/ContentMargin/ContentVbox/DetailStorageInfo/ProgressBarWrapper")

var _content_margin: MarginContainer
var _content_vbox: VBoxContainer
var _details_vbox: VBoxContainer

func _enter_tree() -> void:
	_details_vbox = get_node_or_null("DetailsVboxContainer") as VBoxContainer
	_content_margin = get_node_or_null("DetailsVboxContainer/ContentMargin") as MarginContainer
	_content_vbox = get_node_or_null("DetailsVboxContainer/ContentMargin/ContentVbox") as VBoxContainer
	_apply_content_margin()
	_apply_separation()
	if not Engine.is_editor_hint():
		call_deferred("_sync_storage_progress_label")


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


func _format_storage_num(n: float) -> String:
	var i := int(n)
	var s := str(abs(i))
	var out := ""
	for j in range(s.length()):
		if j > 0 and (s.length() - j) % 3 == 0:
			out += ","
		out += s[j]
	return "-" + out if i < 0 else out


func _sync_storage_progress_label() -> void:
	if Engine.is_editor_hint():
		return
	if not storage_progress_wrapper_path:
		return
	var wrapper := get_node_or_null(storage_progress_wrapper_path) as Control
	if not wrapper:
		return
	var bar: Node = wrapper.get_node_or_null("StorageProgressBar")
	var label: Label = wrapper.get_node_or_null("ProgressBarLabel") as Label
	if not bar or not label:
		return
	if not "current_value" in bar or not "max_value" in bar:
		return
	var cur: float = bar.get("current_value")
	var mx: float = bar.get("max_value")
	label.text = _format_storage_num(cur) + " / " + _format_storage_num(mx)


func _update_editor_preview() -> void:
	if not Engine.is_editor_hint():
		return
	_apply_content_margin()
	_apply_separation()


## 运行期：显示计算因子详细信息（含预期总消耗、固有消耗、核心消耗、产出、资源富余）
func show_for_factor(_factor_key: String, _data: Dictionary) -> void:
	visible = true


func hide_panel() -> void:
	visible = false

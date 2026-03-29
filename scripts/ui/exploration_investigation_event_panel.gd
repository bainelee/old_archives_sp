extends PanelContainer
## 调查点事件：标题、四行正文、动态选项、「稍后处理」。

signal option_selected(option_id: String)
signal defer_requested()

const _ThemeRes = preload("res://assets/ui/detail_panel_theme.tres")

@onready var _title: Label = get_node_or_null("Margin/VBox/TitleLabel") as Label
@onready var _body: Label = get_node_or_null("Margin/VBox/BodyLabel") as Label
@onready var _options_box: VBoxContainer = get_node_or_null("Margin/VBox/OptionsBox") as VBoxContainer
@onready var _btn_defer: Button = get_node_or_null("Margin/VBox/BtnDefer") as Button

var _site_id: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	if theme == null:
		theme = _ThemeRes
	if _btn_defer:
		_btn_defer.pressed.connect(func() -> void:
			hide_panel()
			defer_requested.emit()
		)


func hide_panel() -> void:
	visible = false
	_site_id = ""


func present_site(site: Dictionary) -> void:
	_site_id = str(site.get("id", ""))
	if _title:
		_title.text = str(site.get("title_zh", _site_id))
	if _body:
		_body.text = str(site.get("body_zh", ""))
	_clear_options()
	var opts: Variant = site.get("options", [])
	if _options_box and opts is Array:
		for item in opts as Array:
			if not (item is Dictionary):
				continue
			var o: Dictionary = item as Dictionary
			var oid: String = str(o.get("id", ""))
			var label: String = str(o.get("label_zh", oid))
			var hint: String = str(o.get("hint_zh", ""))
			var btn := Button.new()
			btn.text = label
			btn.focus_mode = Control.FOCUS_NONE
			btn.tooltip_text = hint
			btn.custom_minimum_size = Vector2(0, 32)
			var captured: String = oid
			btn.pressed.connect(func() -> void:
				option_selected.emit(captured)
			)
			_options_box.add_child(btn)
	visible = true


func get_presented_site_id() -> String:
	return _site_id


func _clear_options() -> void:
	if _options_box == null:
		return
	for c in _options_box.get_children():
		_options_box.remove_child(c)
		c.queue_free()

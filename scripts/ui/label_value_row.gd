class_name LabelValueRow
extends HBoxContainer
## 可复用的标签+数值行
## 用于 room_detail_panel 等动态生成的键值对列表

func _init() -> void:
	add_theme_constant_override("separation", 12)


## 创建并配置一行，label_text 会追加 LABEL_SUFFIX
static func create_row(label_text: String, value: String, value_color: Color) -> HBoxContainer:
	var row: HBoxContainer = LabelValueRow.new()
	var lbl: Label = Label.new()
	lbl.text = label_text + TranslationServer.translate("LABEL_SUFFIX")
	lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	lbl.add_theme_font_size_override("font_size", 13)
	var val: Label = Label.new()
	val.text = value
	val.add_theme_color_override("font_color", value_color)
	val.add_theme_font_size_override("font_size", 13)
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	row.add_child(val)
	return row

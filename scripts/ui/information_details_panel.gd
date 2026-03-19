@tool
class_name InformationDetailsPanel
extends DetailPanelBase
## 信息详细信息面板
## 结构：无储存条；信息产出+细则、额外影响+细则、信息储量；Figma 70:1154
## 编辑器可见逻辑禁止放在 _ready；见 .cursor/rules/ui-no-ready.mdc

var _title_label: Label

func _enter_tree() -> void:
	super._enter_tree()
	_title_label = get_node_or_null("DetailsVboxContainer/HeaderVbox/DetailsTitle/TitleLayout/TextTitleName") as Label
	_update_title()


func _ready() -> void:
	super._ready()


## 显示信息详细信息
func show_panel(data: Dictionary) -> void:
	super.show_panel(data)
	_refresh_display(data)


## 刷新当前显示的数据
func refresh_data() -> void:
	super.refresh_data()
	if _data_provider:
		var new_data: Dictionary = _data_provider.get_information_breakdown()
		_refresh_display(new_data)


func _refresh_display(data: Dictionary) -> void:
	var content := _get_content_vbox()
	if not content:
		return

	## 清空现有内容
	clear_container(content)

	## 获取数据
	var current: int = data.get("current", 0)
	var output: Array = data.get("output", [])
	var extra_effects: Array = data.get("extra_effects", [])

	## 信息产出和细则
	var total_output := 0
	for entry in output:
		total_output += entry.get("amount", 0)

	_add_section_title(content, tr("INFORMATION_OUTPUT"))
	_add_info_row(content, tr("TOTAL_OUTPUT"), "+" + str(total_output) + "/" + tr("DAY"))

	if output.size() > 0:
		for detail in output:
			var source: String = detail.get("source", tr("UNKNOWN"))
			var amount: int = detail.get("amount", 0)
			_add_detail_row(content, source, "+" + str(amount))

	## 额外影响和细则
	var total_extra := 0
	for entry in extra_effects:
		total_extra += entry.get("amount", 0)

	if extra_effects.size() > 0 or total_extra != 0:
		_add_split_line(content)
		_add_section_title(content, tr("EXTRA_EFFECTS"))
	if total_extra != 0:
		var total_sign := "+" if total_extra > 0 else ""
		_add_info_row(content, tr("TOTAL_EXTRA"), total_sign + str(total_extra))
	for effect in extra_effects:
		var source: String = effect.get("source", tr("UNKNOWN"))
		var amount: int = effect.get("amount", 0)
		var desc: String = effect.get("description", "")
		var display_text := source
		if desc:
			display_text += " (" + desc + ")"
		var effect_sign := "+" if amount > 0 else ""
		_add_detail_row(content, display_text, effect_sign + str(amount))

	## 信息储量
	_add_split_line(content)
	_add_info_row(content, tr("INFORMATION_STORAGE"), format_number(current))
	
	## 确保面板高度自适应内容
	call_deferred("_force_layout_refresh")


## 强制刷新面板布局（延迟一帧确保内容更新完成）
func _force_layout_refresh() -> void:
	## 重置面板最小高度，让其根据内容自适应
	custom_minimum_size.y = 0
	custom_minimum_size.x = 320
	## 强制重新计算大小
	reset_size()
	## 重新排序
	queue_sort()
	var content := _get_content_vbox()
	if content:
		content.reset_size()
		content.queue_sort()


## 修复预置行的布局（确保Label不占满空间，数值右对齐）
func _fix_predefined_rows_layout() -> void:
	## 场景文件已正确设置size_flags，此函数只设置horizontal_alignment
	var content := _get_content_vbox()
	if not content:
		return
	
	## 修复所有预置行的布局（只设置对齐，不覆盖size_flags）
	var row_names := []
	for row_name in row_names:
		var row := content.get_node_or_null(row_name) as HBoxContainer
		if not row:
			continue
		
		for child in row.get_children():
			if child is Label:
				if child.name == "Value":
					child.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				else:
					child.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


## 添加分隔线
func _add_split_line(container: VBoxContainer) -> void:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(280, 2)
	line.color = Color(0.3, 0.35, 0.4, 0.5)
	container.add_child(line)


## 添加章节标题
func _add_section_title(container: VBoxContainer, title: String) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_color_override("font_color", Color(0.063, 0.063, 0.063))
	container.add_child(label)


## 添加信息行
func _add_info_row(container: VBoxContainer, label: String, value: String, value_color: Color = Color(0.063, 0.063, 0.063)) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(hbox)

	var label_node := Label.new()
	label_node.text = label
	label_node.add_theme_color_override("font_color", Color(0.063, 0.063, 0.063))
	label_node.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hbox.add_child(label_node)

	## 弹性空间，将标签和数值推到两边
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var value_node := Label.new()
	value_node.text = value
	value_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_node.add_theme_color_override("font_color", value_color)
	value_node.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hbox.add_child(value_node)


## 添加细则行
func _add_detail_row(container: VBoxContainer, source: String, value: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(hbox)

	var source_label := Label.new()
	source_label.text = "  " + source
	source_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	hbox.add_child(source_label)

	## 弹性空间，将来源和数值推到两边
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var value_label := Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	hbox.add_child(value_label)


## 更新标题（支持本地化）
func _update_title() -> void:
	if not _title_label:
		return
	var title_text := tr("LABEL_INFO")
	if title_text == "LABEL_INFO" or title_text.is_empty():
		title_text = "信息"
	_title_label.text = title_text

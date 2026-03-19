@tool
class_name TruthDetailsPanel
extends DetailPanelBase
## 真相详细信息面板
## 结构：已获得真相+细则（名称列表）、已解读真相+细则（名称列表）；Figma 72:1337
## 编辑器可见逻辑禁止放在 _ready；见 .cursor/rules/ui-no-ready.mdc

var _title_label: Label

func _enter_tree() -> void:
	super._enter_tree()
	_title_label = get_node_or_null("DetailsVboxContainer/HeaderVbox/DetailsTitle/TitleLayout/TextTitleName") as Label
	_update_title()


func _ready() -> void:
	super._ready()


## 显示真相详细信息
func show_panel(data: Dictionary) -> void:
	super.show_panel(data)
	_refresh_display(data)


## 刷新当前显示的数据
func refresh_data() -> void:
	super.refresh_data()
	if _data_provider:
		var new_data: Dictionary = _data_provider.get_truth_breakdown()
		_refresh_display(new_data)


func _refresh_display(data: Dictionary) -> void:
	var content := _get_content_vbox()
	if not content:
		return

	## 清空现有内容
	clear_container(content)

	## 获取数据
	var acquired: Array = data.get("acquired", [])
	var interpreted: Array = data.get("interpreted", [])

	## 已获得真相数量
	_add_section_title(content, tr("TRUTH_ACQUIRED"))
	_add_info_row(content, tr("ACQUIRED_COUNT"), str(acquired.size()))

	## 已获得真相细则：真相名称列表
	if acquired.size() > 0:
		for truth in acquired:
			var truth_name: String = truth.get("name", tr("UNKNOWN_TRUTH"))
			_add_truth_item(content, truth_name, false)
	else:
		_add_detail_text(content, tr("NO_TRUTH_ACQUIRED"))

	## 已解读真相数量
	_add_split_line(content)
	_add_section_title(content, tr("TRUTH_INTERPRETED"))
	_add_info_row(content, tr("INTERPRETED_COUNT"), str(interpreted.size()))

	## 已解读真相细则：真相名称列表
	if interpreted.size() > 0:
		for truth in interpreted:
			var truth_name: String = truth.get("name", tr("UNKNOWN_TRUTH"))
			_add_truth_item(content, truth_name, true)
	else:
		_add_detail_text(content, tr("NO_TRUTH_INTERPRETED"))
	
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


## 添加真相条目（带图标指示是否已解读）
func _add_truth_item(container: VBoxContainer, truth_name: String, is_interpreted: bool) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(hbox)

	## 状态指示器（小图标）
	var indicator := ColorRect.new()
	indicator.custom_minimum_size = Vector2(8, 8)
	indicator.color = Color(0.2, 0.6, 0.3) if is_interpreted else Color(0.4, 0.4, 0.4)
	hbox.add_child(indicator)

	## 间距
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(4, 0)
	hbox.add_child(spacer)

	## 真相名称
	var name_label := Label.new()
	name_label.text = truth_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", Color(0.063, 0.063, 0.063))
	hbox.add_child(name_label)


## 添加详情文本（用于空状态）
func _add_detail_text(container: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = "  " + text
	label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	container.add_child(label)


## 更新标题（支持本地化）
func _update_title() -> void:
	if not _title_label:
		return
	var title_text := tr("LABEL_TRUTH")
	if title_text == "LABEL_TRUTH" or title_text.is_empty():
		title_text = "真相"
	_title_label.text = title_text

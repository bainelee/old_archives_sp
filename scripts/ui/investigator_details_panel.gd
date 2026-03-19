@tool
class_name InvestigatorDetailsPanel
extends DetailPanelBase
## 调查员详细信息面板
## 结构：无储存条；可分配调查员、已分配调查员+探索节点细则、已招募调查员+事务所/事件细则；Figma 72:1259
## 编辑器可见逻辑禁止放在 _ready；见 .cursor/rules/ui-no-ready.mdc

var _title_label: Label

func _enter_tree() -> void:
	super._enter_tree()
	_title_label = get_node_or_null("DetailsVboxContainer/HeaderVbox/DetailsTitle/TitleLayout/TextTitleName") as Label
	_update_title()


func _ready() -> void:
	super._ready()


## 显示调查员详细信息
func show_panel(data: Dictionary) -> void:
	super.show_panel(data)
	_refresh_display(data)


## 刷新当前显示的数据
func refresh_data() -> void:
	super.refresh_data()
	if _data_provider:
		var new_data: Dictionary = _data_provider.get_investigator_breakdown()
		_refresh_display(new_data)


func _refresh_display(data: Dictionary) -> void:
	var content := _get_content_vbox()
	if not content:
		return

	## 清空现有内容
	clear_container(content)

	## 获取数据
	var total: int = data.get("total", 0)
	var assigned: int = data.get("assigned", 0)
	var available: int = data.get("available", 0)
	var assigned_details: Array = data.get("assigned_details", [])
	var recruited_details: Array = data.get("recruited_details", [])

	## 如果可分配未提供，计算它
	if available == 0 and total > 0:
		available = maxi(0, total - assigned)

	## 可分配调查员章节（标题+数量同行）
	_add_section_title_row(content, tr("INVESTIGATOR_AVAILABLE"), str(available))

	## 已分配调查员章节（标题+数量同行）
	_add_split_line(content)
	_add_section_title_row(content, tr("INVESTIGATOR_ASSIGNED"), str(assigned))

	## 已分配细则：探索节点名称+数量（带灰色背景）
	if assigned_details.size() > 0:
		for detail in assigned_details:
			var node_name: String = detail.get("node_name", tr("UNKNOWN_NODE"))
			var count: int = detail.get("count", 0)
			_add_detail_row_with_bg(content, node_name, str(count))
	elif assigned > 0:
		## 有分配但没有细则时显示占位文本
		_add_detail_row_with_bg(content, tr("EXPLORATION_NODES"), "...")

	## 已招募调查员章节（标题+数量同行）
	_add_split_line(content)
	_add_section_title_row(content, tr("INVESTIGATOR_RECRUITED"), str(total))

	## 已招募细则：事务所区招募+事件/探索节点招募（带灰色背景）
	if recruited_details.size() > 0:
		for detail in recruited_details:
			var source: String = detail.get("source", tr("UNKNOWN_SOURCE"))
			var count: int = detail.get("count", 0)
			_add_detail_row_with_bg(content, source, str(count))
	else:
		## 默认显示两种来源占位
		_add_detail_row_with_bg(content, tr("OFFICE_RECRUITMENT"), "0")
		_add_detail_row_with_bg(content, tr("EVENT_RECRUITMENT"), "0")
	
	## 底部空白条目间隔
	_add_bottom_spacer(content)
	
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


## 添加章节标题行（标题和数值在同一行）
func _add_section_title_row(container: VBoxContainer, title: String, value: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(hbox)
	
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_color_override("font_color", Color(0.063, 0.063, 0.063))
	title_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hbox.add_child(title_label)
	
	## 弹性空间
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)
	
	var value_label := Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", Color(0.063, 0.063, 0.063))
	value_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hbox.add_child(value_label)


## 添加带灰色背景的细则行
func _add_detail_row_with_bg(container: VBoxContainer, source: String, value: String) -> void:
	## 创建一个容器来放置背景和行内容
	var row_container := Control.new()
	row_container.custom_minimum_size = Vector2(280, 24)
	row_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(row_container)
	
	## 添加灰色背景（先添加，确保在最底层）
	var bg := ColorRect.new()
	bg.color = Color(0.5, 0.5, 0.5, 0.3)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	row_container.add_child(bg)
	
	## 创建行内容的HBoxContainer
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 8
	hbox.offset_right = -8
	row_container.add_child(hbox)

	var source_label := Label.new()
	source_label.text = source
	source_label.add_theme_color_override("font_color", Color(0.063, 0.063, 0.063))
	source_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	source_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(source_label)

	## 弹性空间，将来源和数值推到两边
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var value_label := Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", Color(0.063, 0.063, 0.063))
	value_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(value_label)


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
	source_label.add_theme_color_override("font_color", Color(0.063, 0.063, 0.063))
	source_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hbox.add_child(source_label)

	## 弹性空间，将来源和数值推到两边
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var value_label := Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", Color(0.063, 0.063, 0.063))
	value_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hbox.add_child(value_label)


## 添加底部空白间隔
func _add_bottom_spacer(container: VBoxContainer) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	container.add_child(spacer)


## 更新标题（支持本地化，英文大写）
func _update_title() -> void:
	if not _title_label:
		return
	var title_text := tr("LABEL_INVESTIGATOR")
	## 英文时使用全大写标题
	if title_text == "INVESTIGATOR":
		_title_label.text = "INVESTIGATOR"
	elif title_text == "LABEL_INVESTIGATOR" or title_text.is_empty():
		_title_label.text = "调查员"
	else:
		_title_label.text = title_text

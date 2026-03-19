@tool
class_name HousingDetailsPanel
extends DetailPanelBase
## 住房详细信息面板
## 结构：无状态文、储存标题「住房信息总览」、住房总览条（需求/已提供）；可分配/已提供/住房缺口/住房产出+细则/住房总数；Figma 76:65
## 住房缺口时显示警告；编辑器可见逻辑禁止放在 _ready；见 .cursor/rules/ui-no-ready.mdc

var _title_label: Label
var _overview_bar: DetailHousingOverviewBar

func _enter_tree() -> void:
	super._enter_tree()
	_title_label = get_node_or_null("DetailsVboxContainer/HeaderVbox/DetailsTitle/TitleLayout/TextTitleName") as Label
	_overview_bar = get_node_or_null("DetailsVboxContainer/ContentMargin/ContentVbox/DetailStorageInfo/ProgressBarWrapper/HousingOverviewBar") as DetailHousingOverviewBar
	_update_title()


func _ready() -> void:
	super._ready()


## 显示住房详细信息
func show_panel(data: Dictionary) -> void:
	super.show_panel(data)
	_refresh_display(data)


## 刷新当前显示的数据
func refresh_data() -> void:
	super.refresh_data()
	if _data_provider:
		var new_data: Dictionary = _data_provider.get_housing_breakdown()
		_refresh_display(new_data)


func _refresh_display(data: Dictionary) -> void:
	var content := _get_content_vbox()
	if not content:
		return

	## 获取数据
	var demand: int = data.get("demand", 0)
	var supplied: int = data.get("supplied", 0)
	var deficit: int = data.get("deficit", 0)
	var output_details: Array = data.get("output_details", [])

	## 计算可分配住房（有缺口时为0，否则为富余量）
	var available := maxi(0, supplied - demand) if supplied > demand else 0
	var assigned := mini(supplied, demand)  ## 已分配 = 已提供但不超过需求

	## 更新场景中已有的节点数据
	_update_storage_info(demand, supplied)
	_update_info_rows(available, assigned, deficit, supplied)
	_update_output_entries(output_details)

	## 修复预置行的布局（确保Label不占满空间，数值右对齐）
	call_deferred("_fix_predefined_rows_layout")
	
	## 确保面板高度自适应内容
	call_deferred("_force_layout_refresh")


## 强制刷新面板布局（延迟一帧确保内容更新完成）
func _force_layout_refresh() -> void:
	var content := _get_content_vbox()
	if not content:
		return
	
	## 重置面板最小高度，让其根据内容自适应
	custom_minimum_size.y = 0
	custom_minimum_size.x = 320
	
	## 强制重新计算大小
	reset_size()
	content.reset_size()
	
	## 重新排序
	queue_sort()
	content.queue_sort()


## 修复预置行的布局（确保Label不占满空间，数值右对齐）
func _fix_predefined_rows_layout() -> void:
	## 首先确保 ContentVbox 填满 ContentMargin 的可用空间
	var content_margin := _get_content_margin()
	var content := _get_content_vbox()
	
	if content_margin and content:
		## ContentVbox 应该填满 ContentMargin 减去边距后的宽度
		## ContentMargin 宽度 = 316，边距 = 左右各 20，所以可用宽度 = 276
		content.custom_minimum_size.x = 276
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if not content:
		return
	
	## 修复所有预置行的布局 - 正确的布局策略：
	## Label: SHRINK_BEGIN (0) - 只占用自身文本宽度
	## Spacer: EXPAND_FILL (3) - 占据所有剩余空间
	## Value: SHRINK_END (8) - 只占用自身文本宽度，但通过alignment右对齐
	var row_names := ["AvailableRow", "DeficitRow", "TotalRow"]
	for row_name in row_names:
		var row := content.get_node_or_null(row_name) as HBoxContainer
		if not row:
			continue
		
		## 强制行填满 ContentVbox 宽度
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size.x = 276  ## ContentVbox 可用宽度
		
		## 遍历行的子节点
		for child in row.get_children():
			if child is Label:
				if child.name == "Value":
					## Value: SHRINK_END + 右对齐，不占满空间
					child.size_flags_horizontal = Control.SIZE_SHRINK_END
					child.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				else:
					## Label: SHRINK_BEGIN + 左对齐，不占满空间
					child.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
					child.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
					
			elif child is Control and child.name == "Spacer":
				## Spacer应该占据所有剩余空间
				child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				child.size_flags_stretch_ratio = 1.0
	
	## 强制重新布局和排序
	for row_name in row_names:
		var row := content.get_node_or_null(row_name) as HBoxContainer
		if row:
			row.queue_sort()
	queue_sort()


## 添加储存标题
func _add_storage_title(container: VBoxContainer, title: String) -> void:
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.063, 0.063, 0.063))
	container.add_child(label)


## 添加住房总览进度条
func _add_overview_bar(container: VBoxContainer, demand: int, supplied: int) -> void:
	## 创建进度条容器
	var bar_container := MarginContainer.new()
	bar_container.custom_minimum_size = Vector2(280, 20)
	container.add_child(bar_container)

	## 如果场景中有预制的 OverviewBar 节点，使用它
	if _overview_bar:
		_overview_bar.demand_total = demand
		_overview_bar.supplied_total = supplied
		return

	## 否则创建简单的文本显示作为回退
	var label := Label.new()
	label.text = "%d/%d" % [demand, supplied]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar_container.add_child(label)


## 添加分隔线
func _add_split_line(container: VBoxContainer) -> void:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(280, 2)
	line.color = Color(0.3, 0.35, 0.4, 0.5)
	container.add_child(line)


## 添加信息行
func _add_info_row(container: VBoxContainer, label_text: String, value: String, value_color: Color = Color(0.063, 0.063, 0.063)) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(hbox)

	var label_node := Label.new()
	label_node.text = label_text
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


## 添加章节标题
func _add_section_title(container: VBoxContainer, title: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(hbox)
	
	var label := Label.new()
	label.text = title
	label.add_theme_color_override("font_color", Color(0.063, 0.063, 0.063))
	hbox.add_child(label)


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
	value_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	value_label.add_theme_color_override("font_color", Color(0.063, 0.063, 0.063))
	hbox.add_child(value_label)


## 更新标题（支持本地化）
func _update_title() -> void:
	if not _title_label:
		return
	## 获取翻译文本，如果翻译系统未加载则使用默认值
	var title_text := tr("LABEL_HOUSING")
	if title_text == "LABEL_HOUSING" or title_text.is_empty():
		## 翻译失败，使用硬编码中文或英文
		title_text = "住房"
	_title_label.text = title_text


## 更新储存信息区域（进度条）
func _update_storage_info(demand: int, supplied: int) -> void:
	if _overview_bar:
		_overview_bar.demand_total = demand
		_overview_bar.supplied_total = supplied


## 更新信息行（可分配、已分配、缺口、总数）
func _update_info_rows(available: int, assigned: int, deficit: int, total: int) -> void:
	var content := _get_content_vbox()
	if not content:
		return
	
	## 更新 AvailableRow
	var available_row := content.get_node_or_null("AvailableRow") as HBoxContainer
	if available_row:
		var available_value := available_row.get_node_or_null("Value") as Label
		if available_value:
			available_value.text = str(available)
	
	## 查找并更新 AssignedRow（如果有）
	var assigned_row := content.get_node_or_null("AssignedRow") as HBoxContainer
	if assigned_row:
		var assigned_value := assigned_row.get_node_or_null("Value") as Label
		if assigned_value:
			assigned_value.text = str(assigned)
	
	## 更新 DeficitRow
	var deficit_row := content.get_node_or_null("DeficitRow") as HBoxContainer
	if deficit_row:
		var deficit_value := deficit_row.get_node_or_null("Value") as Label
		if deficit_value:
			deficit_value.text = str(deficit)
			## 根据缺口值设置颜色
			if deficit > 0:
				deficit_value.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
			else:
				deficit_value.add_theme_color_override("font_color", Color(0.063, 0.063, 0.063))
		## 控制缺口行可见性
		deficit_row.visible = deficit > 0
	
	## 更新 TotalRow
	var total_row := content.get_node_or_null("TotalRow") as HBoxContainer
	if total_row:
		var total_value := total_row.get_node_or_null("Value") as Label
		if total_value:
			total_value.text = str(total)


## 更新产出条目
func _update_output_entries(output_details: Array) -> void:
	var content := _get_content_vbox()
	if not content:
		return
	
	var output_wrap := content.get_node_or_null("OutputWrap") as MarginContainer
	if not output_wrap:
		return
	
	## 控制产出区域可见性
	output_wrap.visible = output_details.size() > 0
	if output_details.size() == 0:
		return
	
	## 更新产出总值
	var output := output_wrap.get_node_or_null("Output") as VBoxContainer
	if output:
		var output_title := output.get_node_or_null("OutputTitle/Value") as Label
		if output_title:
			var total_output := 0
			for detail in output_details:
				total_output += detail.get("amount", 0)
			output_title.text = str(total_output)
	
	## 更新产出条目（Entry1, Entry2等）
	var output_entries := output.get_node_or_null("OutputEntries") as VBoxContainer
	if output_entries:
		var entries := output_entries.get_children()
		for i in range(entries.size()):
			var entry := entries[i] as PanelContainer
			if not entry:
				continue
			
			## 如果有多于预设的条目，显示并更新
			if i < output_details.size():
				entry.visible = true
				var detail: Dictionary = output_details[i]
				var hbox := entry.get_node_or_null("HBox") as HBoxContainer
				if hbox:
					var label := hbox.get_node_or_null("Label") as Label
					var value := hbox.get_node_or_null("Value") as Label
					if label:
						label.text = detail.get("source", tr("UNKNOWN"))
					if value:
						value.text = "+" + str(detail.get("amount", 0))
			else:
				## 超出数据范围的预设条目隐藏
				entry.visible = false

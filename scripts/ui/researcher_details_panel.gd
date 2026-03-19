@tool
class_name ResearcherDetailsPanel
extends DetailPanelBase
## 研究员详细信息面板
## 结构：无状态文、储存标题「研究员总览」、三段进度条（闲置/在职/被侵蚀）；闲置/被侵蚀/在职+区域细则/研究员总数
## 研究员总览不显示警告文本；Figma 70:964
## 编辑器可见逻辑禁止放在 _ready；见 .cursor/rules/ui-no-ready.mdc / ui-editor-live.mdc

## 节点引用缓存
var _title_label: Label
var _overview_bar: DetailResearcherOverviewBar
var _idle_value_label: Label
var _eroded_value_label: Label
var _on_duty_value_label: Label
var _total_value_label: Label
var _region_entries_container: VBoxContainer

## 当前显示的数据
var _current_idle: int = 0
var _current_eroded: int = 0
var _current_on_duty: int = 0
var _current_total: int = 0

func _enter_tree() -> void:
	super._enter_tree()
	_cache_panel_nodes()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	super._ready()


## 缓存面板特有节点
func _cache_panel_nodes() -> void:
	_title_label = get_node_or_null("DetailsVboxContainer/HeaderVbox/DetailsTitle/TitleLayout/TextTitleName") as Label
	_overview_bar = get_node_or_null("DetailsVboxContainer/ContentMargin/ContentVbox/DetailStorageInfo/ProgressBarWrapper/ResearcherOverviewBar") as DetailResearcherOverviewBar
	_idle_value_label = get_node_or_null("DetailsVboxContainer/ContentMargin/ContentVbox/IdleRow/Value") as Label
	_eroded_value_label = get_node_or_null("DetailsVboxContainer/ContentMargin/ContentVbox/ErodedRow/Value") as Label
	_on_duty_value_label = get_node_or_null("DetailsVboxContainer/ContentMargin/ContentVbox/OnDutyWrap/OnDuty/OnDutyTitle/Value") as Label
	_total_value_label = get_node_or_null("DetailsVboxContainer/ContentMargin/ContentVbox/TotalRow/Value") as Label
	_region_entries_container = get_node_or_null("DetailsVboxContainer/ContentMargin/ContentVbox/OnDutyWrap/OnDuty/RegionEntries") as VBoxContainer
	## 更新标题（支持本地化）
	_update_title()


## 显示研究员详细信息面板
## data: 来自 DataProviders.get_researcher_breakdown() 的字典
## 包含: idle, on_duty, eroded, total, region_breakdown
func show_panel(data: Dictionary) -> void:
	_current_idle = data.get("idle", 0)
	_current_eroded = data.get("eroded", 0)
	_current_on_duty = data.get("on_duty", 0)
	_current_total = data.get("total", 0)

	## 更新进度条
	if _overview_bar:
		_overview_bar.idle_count = _current_idle
		_overview_bar.total_count = _current_total
		_overview_bar.eroded_count = _current_eroded

	## 更新数值标签
	if _idle_value_label:
		_idle_value_label.text = format_number(_current_idle)
	if _eroded_value_label:
		_eroded_value_label.text = format_number(_current_eroded)
	if _on_duty_value_label:
		_on_duty_value_label.text = format_number(_current_on_duty)
	if _total_value_label:
		_total_value_label.text = format_number(_current_total)

	## 更新区域分布细则
	_update_region_entries(data.get("region_breakdown", []))

	## 先调用基类显示面板（设置 visible = true）
	## 必须在布局修复前调用，否则布局计算不正确
	super.show_panel(data)
	
	## 修复预置行的布局（确保Label不占满空间，数值右对齐）
	## 必须在面板可见后执行，这样布局计算才有正确的尺寸
	_fix_predefined_rows_layout()
	
	## 确保面板高度自适应内容
	_force_layout_refresh()


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
	var row_names := ["IdleRow", "ErodedRow", "OnDutyWrap/OnDuty/OnDutyTitle", "TotalRow"]
	for row_name in row_names:
		var row := content.get_node_or_null(row_name) as HBoxContainer
		if not row:
			continue
		
		## 强制行填满 ContentVbox 宽度
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size.x = 276  # ContentVbox 可用宽度
		
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


## 更新区域分布条目
func _update_region_entries(region_breakdown: Array) -> void:
	if not _region_entries_container:
		return

	## 清空现有条目
	clear_container(_region_entries_container)

	## 如果没有区域数据，添加一个示例条目
	if region_breakdown.is_empty():
		## 编辑器预览模式或空数据时显示示例
		if Engine.is_editor_hint() or _current_on_duty > 0:
			_add_region_entry(tr("ZONE_RESEARCH"), _current_on_duty / 2)
			_add_region_entry(tr("ZONE_CREATION"), _current_on_duty / 3)
			_add_region_entry(tr("ZONE_LIVING"), _current_on_duty - (_current_on_duty / 2) - (_current_on_duty / 3))
		return

	## 根据实际数据创建条目
	for entry in region_breakdown:
		var region_name: String = entry.get("region_name", tr("UNKNOWN_REGION"))
		var count: int = entry.get("count", 0)
		_add_region_entry(region_name, count)


## 添加单个区域条目
func _add_region_entry(region_name: String, count: int) -> void:
	if not _region_entries_container:
		return

	## 创建条目容器
	var entry_panel := PanelContainer.new()
	entry_panel.custom_minimum_size = Vector2(0, 24)
	## layout_mode 默认即可，无需设置

	## 创建行布局
	var hbox := HBoxContainer.new()
	## layout_mode 默认即可，无需设置
	hbox.add_theme_constant_override("separation", 8)

	## 区域名称标签
	var name_label := Label.new()
	## layout_mode 默认即可，无需设置
	name_label.add_theme_color_override("font_color", Color(0.063, 0.063, 0.063))
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.text = region_name
	name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	## 弹性空间
	var spacer := Control.new()
	## layout_mode 默认即可，无需设置
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	## 数值标签
	var value_label := Label.new()
	## layout_mode 默认即可，无需设置
	value_label.add_theme_color_override("font_color", Color(0.063, 0.063, 0.063))
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.text = format_number(count)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	## 组装
	hbox.add_child(name_label)
	hbox.add_child(spacer)
	hbox.add_child(value_label)
	entry_panel.add_child(hbox)
	_region_entries_container.add_child(entry_panel)


## 刷新当前显示的数据
func refresh_data() -> void:
	if not visible or _current_data.is_empty():
		return

	## 如果有数据提供者，重新获取数据
	if _data_provider and _data_provider.has_method("get_researcher_breakdown"):
		var new_data: Dictionary = _data_provider.get_researcher_breakdown()
		## 检查数据是否变化
		if new_data.hash() != _current_data.hash():
			show_panel(new_data)
	else:
		## 无数据提供者时，使用缓存数据刷新显示
		show_panel(_current_data)


## 更新标题（支持本地化）
func _update_title() -> void:
	if not _title_label:
		return
	var title_text := tr("LABEL_RESEARCHER")
	if title_text == "LABEL_RESEARCHER" or title_text.is_empty():
		title_text = "研究员"
	_title_label.text = title_text

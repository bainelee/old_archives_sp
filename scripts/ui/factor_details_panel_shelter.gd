@tool
class_name FactorDetailsPanelShelter
extends FactorDetailPanelBase
## 庇护能量详细信息面板
## 结构区别于因子：无状态文、储存标题为「庇护能量出力上限」、特殊三段进度条（已分配/缺口）
## 含已分配、固有分配组（细则）、建设分配、产出、区域庇护状态；见 [ui-detail-panel-design.md]
## 复用 [ui-detail-panel-summary.md] 的组件与资产；Figma 67:855
## 编辑器可见逻辑禁止放在 _ready；见 .cursor/rules/ui-no-ready.mdc / ui-editor-live.mdc

## 节点引用缓存
var _shelter_progress_bar: DetailShelterProgressBar
var _allocated_value_label: Label
var _inherent_title_value_label: Label
var _inherent_entries_container: VBoxContainer
var _construction_value_label: Label
var _output_title_value_label: Label
var _output_entries_container: VBoxContainer

## 区域庇护状态值标签
var _status_labels: Dictionary = {}

## 当前显示的数据
var _current_assigned: float = 0.0
var _current_deficit: float = 0.0
var _current_capacity: float = 0.0

func _enter_tree() -> void:
	super._enter_tree()
	_cache_panel_nodes()
	_update_title()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	super._ready()


## 缓存面板特有节点
func _cache_panel_nodes() -> void:
	## 进度条（使用新的庇护能量专用三段进度条）
	_shelter_progress_bar = get_node_or_null("DetailsVboxContainer/ContentMargin/ContentVbox/DetailStorageInfo/ProgressBarWrapper/ShelterProgressBar") as DetailShelterProgressBar

	## 已分配行
	_allocated_value_label = get_node_or_null("DetailsVboxContainer/ContentMargin/ContentVbox/AllocatedRow/Value") as Label

	## 固有分配组
	_inherent_title_value_label = get_node_or_null("DetailsVboxContainer/ContentMargin/ContentVbox/InherentAllocWrap/InherentAlloc/InherentAllocTitle/Value") as Label
	_inherent_entries_container = get_node_or_null("DetailsVboxContainer/ContentMargin/ContentVbox/InherentAllocWrap/InherentAlloc/InherentEntries") as VBoxContainer

	## 建设分配
	_construction_value_label = get_node_or_null("DetailsVboxContainer/ContentMargin/ContentVbox/ConstructionAllocWrap/ConstructionAllocTitle/Value") as Label

	## 产出组
	_output_title_value_label = get_node_or_null("DetailsVboxContainer/ContentMargin/ContentVbox/OutputWrap/Output/OutputTitle/Value") as Label
	_output_entries_container = get_node_or_null("DetailsVboxContainer/ContentMargin/ContentVbox/OutputWrap/Output/OutputEntries") as VBoxContainer

	## 区域庇护状态
	_status_labels["perfect"] = get_node_or_null("DetailsVboxContainer/ContentMargin/ContentVbox/RegionShelterWrap/RegionShelterStatus/StatusEntries/RowPerfect/HBox/Value") as Label
	_status_labels["adequate"] = get_node_or_null("DetailsVboxContainer/ContentMargin/ContentVbox/RegionShelterWrap/RegionShelterStatus/StatusEntries/RowProper/HBox/Value") as Label
	_status_labels["weak"] = get_node_or_null("DetailsVboxContainer/ContentMargin/ContentVbox/RegionShelterWrap/RegionShelterStatus/StatusEntries/RowWeak/HBox/Value") as Label
	_status_labels["exposed"] = get_node_or_null("DetailsVboxContainer/ContentMargin/ContentVbox/RegionShelterWrap/RegionShelterStatus/StatusEntries/RowExposed/HBox/Value") as Label
	_status_labels["critical"] = get_node_or_null("DetailsVboxContainer/ContentMargin/ContentVbox/RegionShelterWrap/RegionShelterStatus/StatusEntries/RowCritical/HBox/Value") as Label
	_status_labels["shutdown"] = get_node_or_null("DetailsVboxContainer/ContentMargin/ContentVbox/RegionShelterWrap/RegionShelterStatus/StatusEntries/RowClosed/HBox/Value") as Label


## 显示庇护能量详细信息面板
## data: 来自 DataProviders.get_shelter_breakdown() 的字典
## 包含: capacity, assigned, deficit, innate, construction, output, region_status
func show_panel(data: Dictionary) -> void:
	## 先调用基类设置可见性，确保子节点准备好
	super.show_panel(data)
	
	_current_capacity = data.get("capacity", 1.0)
	_current_assigned = data.get("assigned", 0.0)
	_current_deficit = data.get("deficit", 0.0)

	var innate: float = data.get("innate", 0.0)
	var construction: float = data.get("construction", 0.0)
	var output: float = data.get("output", 0.0)

	## 更新进度条（延迟一帧确保节点布局完成）
	call_deferred("_update_shelter_progress_bar_deferred", _current_assigned, _current_deficit, _current_capacity)

	## 更新已分配数值
	if _allocated_value_label:
		_allocated_value_label.text = format_resource_amount(_current_assigned)

	## 更新固有分配
	if _inherent_title_value_label:
		_inherent_title_value_label.text = format_resource_amount(innate) + tr("LABEL_DAILY_SUFFIX")

	## 更新建设分配
	if _construction_value_label:
		_construction_value_label.text = format_resource_amount(construction) + tr("LABEL_DAILY_SUFFIX")

	## 更新产出
	if _output_title_value_label:
		_output_title_value_label.text = format_resource_amount(output) + tr("LABEL_DAILY_SUFFIX")

	## 更新区域庇护状态
	var region_status: Dictionary = data.get("region_status", {})
	_update_region_status(region_status)

	## 更新动态条目
	_update_inherent_entries(data.get("innate_details", []), innate)
	_update_output_entries(data.get("output_details", []), output)
	
	## 修复预置行的布局（确保Label不占满空间，数值右对齐）
	call_deferred("_fix_predefined_rows_layout")
	
	## 确保面板高度自适应内容
	call_deferred("_force_layout_refresh")


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
	
	## 注意：庇护能量面板的行结构与其他因子不同，需要正确路径
	var row_paths := [
		"AllocatedRow",
		"InherentAllocWrap/InherentAlloc/InherentAllocTitle",
		"ConstructionAllocWrap/ConstructionAllocTitle",
		"OutputWrap/Output/OutputTitle"
	]
	
	for row_path in row_paths:
		var row := content.get_node_or_null(row_path) as HBoxContainer
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
	for row_path in row_paths:
		var row := content.get_node_or_null(row_path) as HBoxContainer
		if row:
			row.queue_sort()
	queue_sort()


## 延迟更新庇护能量进度条（确保面板布局完成后更新）
func _update_shelter_progress_bar_deferred(assigned: float, deficit: float, capacity: float) -> void:
	if _shelter_progress_bar:
		_shelter_progress_bar.assigned = assigned
		_shelter_progress_bar.deficit = deficit
		_shelter_progress_bar.capacity = capacity


## 更新区域庇护状态显示
func _update_region_status(region_status: Dictionary) -> void:
	var status_keys := ["perfect", "adequate", "weak", "exposed", "critical", "shutdown"]
	for key in status_keys:
		var label: Label = _status_labels.get(key, null)
		if label:
			var count: int = region_status.get(key, 0)
			label.text = str(count)


## 更新固有分配条目
func _update_inherent_entries(innate_details: Array, total_innate: float) -> void:
	if not _inherent_entries_container:
		return

	## 清空现有条目
	clear_container(_inherent_entries_container)

	## 如果有数据则创建条目
	if not innate_details.is_empty():
		for entry in innate_details:
			var entry_name: String = entry.get("name", tr("UNKNOWN"))
			var amount: float = entry.get("amount", 0.0)
			_add_detail_entry(_inherent_entries_container, entry_name, amount, tr("LABEL_DAILY_SUFFIX"))
	elif Engine.is_editor_hint():
		## 编辑器预览模式显示示例
		if total_innate > 0:
			_add_detail_entry(_inherent_entries_container, tr("SHELTER_EXAMPLE_INNATE"), total_innate, "/天")


## 更新产出条目
func _update_output_entries(output_details: Array, total_output: float) -> void:
	if not _output_entries_container:
		return

	## 清空现有条目
	clear_container(_output_entries_container)

	## 如果有数据则创建条目
	if not output_details.is_empty():
		for entry in output_details:
			var source: String = entry.get("source", tr("UNKNOWN"))
			var amount: float = entry.get("amount", 0.0)
			_add_detail_entry(_output_entries_container, source, amount, tr("LABEL_DAILY_SUFFIX"))
	elif Engine.is_editor_hint():
		## 编辑器预览模式显示示例
		if total_output > 0:
			_add_detail_entry(_output_entries_container, tr("ARCHIVES_CORE"), total_output, tr("LABEL_DAILY_SUFFIX"))


## 添加明细条目
func _add_detail_entry(container: VBoxContainer, label_text: String, value: float, suffix: String = "") -> void:
	if not container:
		return

	## 创建条目容器
	var entry_panel := PanelContainer.new()
	entry_panel.custom_minimum_size = Vector2(0, 24)
	## layout_mode 默认即可，无需设置

	## 创建行布局
	var hbox := HBoxContainer.new()
	## layout_mode 默认即可，无需设置
	hbox.add_theme_constant_override("separation", 8)

	## 名称标签
	var name_label := Label.new()
	## layout_mode 默认即可，无需设置
	name_label.add_theme_color_override("font_color", Color(0.063, 0.063, 0.063))
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.text = label_text
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
	value_label.text = format_resource_amount(value) + suffix
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	## 组装
	hbox.add_child(name_label)
	hbox.add_child(spacer)
	hbox.add_child(value_label)
	entry_panel.add_child(hbox)
	container.add_child(entry_panel)


## 刷新当前显示的数据
func refresh_data() -> void:
	if not visible or _current_data.is_empty():
		return

	## 如果有数据提供者，重新获取数据
	if _data_provider and _data_provider.has_method("get_shelter_breakdown"):
		var new_data: Dictionary = _data_provider.get_shelter_breakdown()
		## 检查数据是否变化
		if new_data.hash() != _current_data.hash():
			show_panel(new_data)
	else:
		## 无数据提供者时，使用缓存数据刷新显示
		show_panel(_current_data)


## 更新标题（支持本地化）
func _update_title() -> void:
	var title_label := get_node_or_null("DetailsVboxContainer/HeaderVbox/DetailsTitle/TitleLayout/TextTitleName") as Label
	if not title_label:
		return
	var title_text := tr("LABEL_SHELTER")
	if title_text == "LABEL_SHELTER" or title_text.is_empty():
		title_text = "庇护能量"
	title_label.text = title_text

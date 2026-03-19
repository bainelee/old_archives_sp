@tool
extends "res://scripts/ui/factor_detail_panel_base.gd"
## 意志因子详细信息面板
## 继承自 DetailPanelBase，复用基类的布局配置与工具方法
## 与认知因子详情面板结构一致，解耦为独立场景与脚本
## 复用 [ui-detail-panel-summary.md](docs/predesign/ui-detail-panel-summary.md) 的组件与资产
## 宽度固定 320px，高度随内容条目数量动态变化
## 支持编辑器中配置与观测：修改 @export 属性即可在 Inspector 中即时看到效果
## 编辑器可见逻辑禁止放在 _ready；见 .cursor/rules/ui-no-ready.mdc / ui-editor-live.mdc

## 因子类型标识
const FACTOR_KEY := "willpower"

## 节点路径配置（可在 Inspector 中调整）
@export_group("节点路径")
@export var title_name_label_path: NodePath = NodePath("DetailsVboxContainer/HeaderVbox/DetailsTitle/TitleLayout/TextTitleName")
@export var title_state_label_path: NodePath = NodePath("DetailsVboxContainer/HeaderVbox/DetailsTitle/TitleLayout/TextTitleState")
@export var storage_progress_wrapper_path: NodePath = NodePath("DetailsVboxContainer/ContentMargin/ContentVbox/DetailStorageInfo/ProgressBarWrapper")
@export var warning_text_label_path: NodePath = NodePath("DetailsVboxContainer/ContentMargin/ContentVbox/DetailStorageInfo/StorageWarning/WarningText")
@export var total_burn_value_path: NodePath = NodePath("DetailsVboxContainer/ContentMargin/ContentVbox/TotalExpectedBurn/Value")
@export var fixed_title_value_path: NodePath = NodePath("DetailsVboxContainer/ContentMargin/ContentVbox/FixedOverheadWrap/FixedOverhead/FixedOverheadTitle/Value")
@export var archives_title_value_path: NodePath = NodePath("DetailsVboxContainer/ContentMargin/ContentVbox/ArchivesOverheadWrap/ArchivesOverhead/ArchivesOverheadTitle/Value")
@export var output_title_value_path: NodePath = NodePath("DetailsVboxContainer/ContentMargin/ContentVbox/OutputWrap/Output/OutputTitle/Value")
@export var surplus_shortage_label_path: NodePath = NodePath("DetailsVboxContainer/ContentMargin/ContentVbox/ResourceShortage/Label")
@export var surplus_shortage_value_path: NodePath = NodePath("DetailsVboxContainer/ContentMargin/ContentVbox/ResourceShortage/Value")
@export var storage_row_value_path: NodePath = NodePath("DetailsVboxContainer/ContentMargin/ContentVbox/ResourceStorageRow/HBox/Value")
@export var storage_title_label_path: NodePath = NodePath("DetailsVboxContainer/ContentMargin/ContentVbox/DetailStorageInfo/TextStorageTitle")

## 条目容器路径
@export var fixed_entries_container_path: NodePath = NodePath("DetailsVboxContainer/ContentMargin/ContentVbox/FixedOverheadWrap/FixedOverhead/FixedOverheadEntries")
@export var archives_entries_container_path: NodePath = NodePath("DetailsVboxContainer/ContentMargin/ContentVbox/ArchivesOverheadWrap/ArchivesOverhead/ArchivesEntries")
@export var output_entries_container_path: NodePath = NodePath("DetailsVboxContainer/ContentMargin/ContentVbox/OutputWrap/Output/OutputEntries")

## 对象池引用
var _entries_pool: DetailEntriesPool = null


func _enter_tree() -> void:
	super._enter_tree()
	_update_title()
	_update_storage_title()
	if not Engine.is_editor_hint():
		call_deferred("_sync_storage_progress_label")


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	## 初始化对象池
	_entries_pool = DetailEntriesPool.new()


func _exit_tree() -> void:
	if _entries_pool:
		_clear_all_entries()
		_entries_pool.clear_all_pools()
		_entries_pool = null


## ============================================================================
## 数据展示接口（重写基类方法）
## ============================================================================

## 显示面板并绑定数据
func show_panel(data: Dictionary) -> void:
	## 先调用基类设置可见性，确保子节点准备好
	super.show_panel(data)
	
	## 统一数据流：优先使用外部传入 data，空时再兜底从 DataProviders 拉取
	var factor_data: Dictionary = data if not data.is_empty() else DataProviders.get_factor_breakdown(FACTOR_KEY)
	
	## 更新标题栏状态文本
	_update_title_state(factor_data.get("status", ""))
	
	## 更新储存进度条（延迟一帧确保节点布局完成）
	call_deferred("_update_storage_progress_deferred", factor_data.get("current", 0), factor_data.get("cap", 0))
	
	## 更新警告文本
	_update_warning_text(factor_data.get("warning_text", ""))
	
	## 更新预期总消耗
	_update_total_burn(factor_data.get("total_consumption", 0))
	
	## 使用对象池动态生成条目
	_clear_all_entries()
	
	## 固有消耗条目
	var fixed_entries: Array = factor_data.get("fixed_consumption", [])
	_update_fixed_overhead(fixed_entries)
	
	## 档案馆消耗条目（意志因子标准处理）
	var archives_entries: Array = factor_data.get("archives_consumption", [])
	_update_archives_overhead(archives_entries)
	
	## 产出条目
	var output_entries: Array = factor_data.get("output", [])
	_update_output(output_entries)
	
	## 更新资源富余/缺少
	_update_surplus_shortage(factor_data.get("daily_net", 0))
	
	## 修复预置行的布局（确保Label不占满空间，数值右对齐）
	call_deferred("_fix_predefined_rows_layout")
	
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
	_apply_standard_row_layout(["TotalExpectedBurn", "ResourceSurplus", "ResourceStorageRow"])


## ============================================================================
## 内部更新方法
## ============================================================================

func _update_title_state(status_text: String) -> void:
	var label := get_node_or_null(title_state_label_path) as Label
	if label:
		## 如果状态文本包含 FACTOR_STATUS_ 前缀（翻译失败时），提取状态名
		var display_text := status_text
		if status_text.begins_with("FACTOR_STATUS_"):
			display_text = status_text.substr("FACTOR_STATUS_".length())
		label.text = display_text.to_upper()
		## 确保标签不会扩展宽度
		label.size_flags_horizontal = Control.SIZE_SHRINK_END


func _update_storage_progress(current: int, max_value: int) -> void:
	if not storage_progress_wrapper_path:
		return
	var wrapper := get_node_or_null(storage_progress_wrapper_path) as Control
	if not wrapper:
		return
	var bar: Node = wrapper.get_node_or_null("StorageProgressBar")
	var label: Label = wrapper.get_node_or_null("ProgressBarLabel") as Label
	if bar and "current_value" in bar and "max_value" in bar:
		bar.set("current_value", current)
		bar.set("max_value", max_value)
	if label:
		label.text = format_resource_amount(current) + " / " + format_resource_amount(max_value)


func _sync_storage_progress_label() -> void:
	## 运行期同步进度条标签（已在_update_storage_progress中处理）
	pass


## 延迟更新储存进度条（确保面板布局完成后更新）
func _update_storage_progress_deferred(current: int, max_value: int) -> void:
	_update_storage_progress(current, max_value)


func _update_warning_text(warning: String) -> void:
	var label := get_node_or_null(warning_text_label_path) as Label
	if label:
		label.text = warning
		## 控制警告区域可见性 - 通过父节点
		var warning_container := label.get_parent() as Control
		if warning_container:
			warning_container.visible = not warning.is_empty()


func _update_total_burn(total: int) -> void:
	var label := get_node_or_null(total_burn_value_path) as Label
	if label:
		label.text = str(total)


func _update_fixed_overhead(entries: Array) -> void:
	## 计算固有消耗总计
	var total := 0
	for entry in entries:
		total += entry.get("amount", 0)
	
	## 更新标题数值
	var title_label := get_node_or_null(fixed_title_value_path) as Label
	if title_label:
		title_label.text = str(total) + "/天"
	
	## 获取容器
	var container := get_node_or_null(fixed_entries_container_path) as VBoxContainer
	if not container or not _entries_pool:
		return
	
	## 动态生成条目
	for entry in entries:
		var row := _entries_pool.acquire_row()
		row.custom_minimum_size = Vector2(0, 24)
		
		## 创建内部布局
		var hbox := _entries_pool.acquire_hbox()
		hbox.add_theme_constant_override("separation", 8)
		
		## 名称标签
		var name_label := _entries_pool.acquire_label()
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", Color(0.063, 0.063, 0.063, 1))
		name_label.text = entry.get("name", tr("UNKNOWN"))
		name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		
		## 间隔
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		## 数值标签
		var value_label := _entries_pool.acquire_label()
		value_label.add_theme_font_size_override("font_size", 14)
		value_label.add_theme_color_override("font_color", Color(0.063, 0.063, 0.063, 1))
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.text = str(entry.get("amount", 0)) + "/天"
		value_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		
		hbox.add_child(name_label)
		hbox.add_child(spacer)
		hbox.add_child(value_label)
		row.add_child(hbox)
		container.add_child(row)


func _update_archives_overhead(entries: Array) -> void:
	## 计算档案馆消耗总计
	var total := 0
	for entry in entries:
		total += entry.get("amount", 0)
	
	## 更新标题数值
	var title_label := get_node_or_null(archives_title_value_path) as Label
	if title_label:
		title_label.text = str(total) + "/天"
	
	## 获取容器
	var container := get_node_or_null(archives_entries_container_path) as VBoxContainer
	if not container or not _entries_pool:
		return
	
	## 动态生成档案馆消耗条目（意志因子标准处理，每个房间一个条目）
	for entry in entries:
		var row := _entries_pool.acquire_row()
		row.custom_minimum_size = Vector2(0, 24)
		
		var hbox := _entries_pool.acquire_hbox()
		hbox.add_theme_constant_override("separation", 8)
		
		var name_label := _entries_pool.acquire_label()
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", Color(0.063, 0.063, 0.063, 1))
		var room_name: String = entry.get("name", tr("UNKNOWN"))
		var room_type: int = entry.get("room_type", -1)
		var type_name := tr("ROOM_TYPE_" + str(room_type)) if room_type >= 0 else tr("ARCHIVES")
		name_label.text = type_name + "-" + room_name
		name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var value_label := _entries_pool.acquire_label()
		value_label.add_theme_font_size_override("font_size", 14)
		value_label.add_theme_color_override("font_color", Color(0.063, 0.063, 0.063, 1))
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.text = str(entry.get("amount", 0)) + "/天"
		value_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		
		hbox.add_child(name_label)
		hbox.add_child(spacer)
		hbox.add_child(value_label)
		row.add_child(hbox)
		container.add_child(row)


func _update_output(entries: Array) -> void:
	## 计算产出总计
	var total := 0
	for entry in entries:
		total += entry.get("amount", 0)
	
	## 更新标题数值
	var title_label := get_node_or_null(output_title_value_path) as Label
	if title_label:
		title_label.text = str(total) + "/天"
	
	## 获取容器
	var container := get_node_or_null(output_entries_container_path) as VBoxContainer
	if not container or not _entries_pool:
		return
	
	## 动态生成产出条目
	for entry in entries:
		var row := _entries_pool.acquire_row()
		row.custom_minimum_size = Vector2(0, 24)
		
		var hbox := _entries_pool.acquire_hbox()
		hbox.add_theme_constant_override("separation", 8)
		
		var name_label := _entries_pool.acquire_label()
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", Color(0.063, 0.063, 0.063, 1))
		var source_name: String = entry.get("source", tr("UNKNOWN"))
		var source_type: String = entry.get("source_type", "archives")
		name_label.text = tr("SOURCE_TYPE_" + source_type.to_upper()) + "-" + source_name
		name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var value_label := _entries_pool.acquire_label()
		value_label.add_theme_font_size_override("font_size", 14)
		value_label.add_theme_color_override("font_color", Color(0.063, 0.063, 0.063, 1))
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.text = str(entry.get("amount", 0)) + "/天"
		value_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		
		hbox.add_child(name_label)
		hbox.add_child(spacer)
		hbox.add_child(value_label)
		row.add_child(hbox)
		container.add_child(row)


func _update_surplus_shortage(daily_net: int) -> void:
	var label := get_node_or_null(surplus_shortage_label_path) as Label
	var value_label := get_node_or_null(surplus_shortage_value_path) as Label
	var storage_value := get_node_or_null(storage_row_value_path) as Label
	
	if daily_net >= 0:
		## 资源富余
		if label:
			label.text = tr("FACTOR_RESOURCE_SURPLUS")
		if value_label:
			value_label.text = "+" + str(daily_net) + "/天"
		if storage_value:
			storage_value.text = "+" + str(daily_net) + "/天"
	else:
		## 资源缺少
		if label:
			label.text = tr("FACTOR_RESOURCE_SHORTAGE")
		if value_label:
			value_label.text = str(daily_net) + "/天"
		if storage_value:
			storage_value.text = str(daily_net) + "/天"


func _clear_all_entries() -> void:
	## 清空所有动态条目容器
	if _entries_pool:
		var fixed_container := get_node_or_null(fixed_entries_container_path) as VBoxContainer
		if fixed_container:
			_entries_pool.release_container_contents(fixed_container)
		
		var archives_container := get_node_or_null(archives_entries_container_path) as VBoxContainer
		if archives_container:
			_entries_pool.release_container_contents(archives_container)
		
		var output_container := get_node_or_null(output_entries_container_path) as VBoxContainer
		if output_container:
			_entries_pool.release_container_contents(output_container)


## ============================================================================
## 刷新接口
## ============================================================================

func refresh_data() -> void:
	if not visible or _current_data.is_empty():
		return
	## 重新获取数据并刷新显示
	show_panel(_current_data)


## ============================================================================
## 兼容旧接口
## ============================================================================

## 运行期：显示指定因子的详细信息（兼容旧接口）
func show_for_factor(_factor_key: String, _data: Dictionary) -> void:
	show_panel(_data)


## 更新标题（支持本地化）
func _update_title() -> void:
	var title_label := get_node_or_null(title_name_label_path) as Label
	if not title_label:
		return
	var title_text := tr("LABEL_WILLPOWER")
	if title_text == "LABEL_WILLPOWER" or title_text.is_empty():
		title_text = "意志因子"
	title_label.text = title_text


## 更新储存服务器标题（支持本地化）
func _update_storage_title() -> void:
	var storage_title_label := get_node_or_null(storage_title_label_path) as Label
	if not storage_title_label:
		return
	var title_text := tr("DETAIL_STORAGE_TITLE_WILLPOWER")
	if title_text == "DETAIL_STORAGE_TITLE_WILLPOWER" or title_text.is_empty():
		title_text = "意志因子储存服务器"
	storage_title_label.text = title_text

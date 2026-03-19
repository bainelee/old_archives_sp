@tool
class_name DetailPanelBase
extends PanelContainer
## 详情面板基类
## 统一封装布局配置、节点引用获取、数字格式化等公共逻辑
## 所有详细信息面板（因子、研究员、住房等）继承此类

const PADDING := 12.0

## 内容区域水平边距（相对 316 宽，左右各此值）
@export_group("布局配置")
@export var content_margin_horizontal: int = 20:
	set(v):
		content_margin_horizontal = maxi(0, v)
		_apply_content_margin()

## 区块间垂直间距
@export var separation: int = 4:
	set(v):
		separation = maxi(0, v)
		_apply_separation()

@export_group("编辑器")
## 编辑器预览：是否在编辑器中显示示例内容
@export var editor_preview: bool = true:
	set(v):
		editor_preview = v
		_update_editor_preview()

## 缓存的节点引用
var _content_margin: MarginContainer
var _content_vbox: VBoxContainer
var _details_vbox: VBoxContainer

## 当前显示的数据缓存（用于刷新对比）
var _current_data: Dictionary = {}
var _data_provider: Node = null

func _enter_tree() -> void:
	_cache_nodes()
	_apply_content_margin()
	_apply_separation()
	## 固定面板宽度为 320px，防止内容拉伸
	custom_minimum_size.x = 320
	size.x = 320  # 强制固定宽度，不被内容撑开
	
	## 确保内容容器在水平方向上填满面板
	## 这是关键：如果父容器不扩展，子元素也无法正确扩展
	if _details_vbox:
		_details_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _content_margin:
		_content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _content_vbox:
		_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 缓存节点引用，避免重复查找
func _cache_nodes() -> void:
	_details_vbox = get_node_or_null("DetailsVboxContainer") as VBoxContainer
	_content_margin = get_node_or_null("DetailsVboxContainer/ContentMargin") as MarginContainer
	_content_vbox = get_node_or_null("DetailsVboxContainer/ContentMargin/ContentVbox") as VBoxContainer


## 获取内容边距容器（带缓存回退）
func _get_content_margin() -> MarginContainer:
	if not _content_margin:
		_cache_nodes()
	return _content_margin


## 获取详情 VBox（带缓存回退）
func _get_details_vbox() -> VBoxContainer:
	if not _details_vbox:
		_cache_nodes()
	return _details_vbox


## 获取内容 VBox（带缓存回退）
func _get_content_vbox() -> VBoxContainer:
	if not _content_vbox:
		_cache_nodes()
	return _content_vbox


## 应用内容边距
func _apply_content_margin() -> void:
	var m := _get_content_margin()
	if m:
		m.add_theme_constant_override("margin_left", content_margin_horizontal)
		m.add_theme_constant_override("margin_right", content_margin_horizontal)


## 应用垂直间距
func _apply_separation() -> void:
	var dv := _get_details_vbox()
	var cv := _get_content_vbox()
	if dv:
		dv.add_theme_constant_override("separation", separation)
	if cv:
		cv.add_theme_constant_override("separation", separation)


## 格式化数字为千分位字符串（如 45000 -> "45,000"）
func format_number(n: float) -> String:
	var i := int(n)
	var s := str(abs(i))
	var out := ""
	for j in range(s.length()):
		if j > 0 and (s.length() - j) % 3 == 0:
			out += ","
		out += s[j]
	return "-" + out if i < 0 else out


## 格式化资源数量（大数字简化，如 1000000 -> "1,000,000"）
func format_resource_amount(n: float) -> String:
	return format_number(n)


## 编辑器预览更新
func _update_editor_preview() -> void:
	if not Engine.is_editor_hint():
		return
	_apply_content_margin()
	_apply_separation()


## 显示面板（子类必须重写此方法实现具体数据展示）
## data: 包含面板所需的所有数据
func show_panel(data: Dictionary) -> void:
	_current_data = data.duplicate(true)
	visible = true
	_update_position_if_needed()


## 隐藏面板
func hide_panel() -> void:
	visible = false
	_current_data.clear()


## 刷新当前显示的数据（子类重写以实现增量更新）
func refresh_data() -> void:
	if not visible or _current_data.is_empty():
		return
	# 子类重写此方法实现刷新逻辑
	pass


## 设置数据提供者（用于刷新时获取最新数据）
func set_data_provider(provider: Node) -> void:
	_data_provider = provider


## 更新面板位置（继承自 DetailHoverPanelBase 的逻辑）
## 面板水平居中于鼠标，垂直位置由 _get_position_y 决定
func update_position(mouse_pos: Vector2, viewport_size: Vector2) -> void:
	var panel_size := size
	## 水平居中：面板中心对准鼠标X坐标
	var center_x := mouse_pos.x - panel_size.x / 2.0
	## 确保不超出视口左右边界
	center_x = clampf(center_x, 0, viewport_size.x - panel_size.x)
	var y := _get_position_y(mouse_pos, panel_size, viewport_size)
	position = Vector2(center_x, y)


## 子类可重写以自定义垂直位置
## 默认：面板顶部对齐 TopBar 底部（动态获取 TopBar 高度）
## 根据鼠标悬停位置判断：TopBar0元素悬停→偏移TopBar0高度；TopBar1元素悬停→偏移TopBar0+TopBar1高度
func _get_position_y(mouse_pos: Vector2, panel_size: Vector2, viewport_size: Vector2) -> float:
	## 动态获取 TopBar0 和 TopBar1 的实际高度
	var topbar_heights: Array = _get_topbar_heights()
	var topbar0_height: float = topbar_heights[0]
	var topbar1_height: float = topbar_heights[1]
	
	## 根据鼠标 Y 位置判断悬停在哪个区域
	var y_offset: float
	if mouse_pos.y <= topbar0_height:
		## 悬停在 TopBar0 区域，只偏移 TopBar0 高度
		y_offset = topbar0_height
	else:
		## 悬停在 TopBar1 区域，偏移 TopBar0 + TopBar1 高度
		y_offset = topbar0_height + topbar1_height
	
	## 面板顶部 = 计算的偏移位置，确保不超出视口
	return clampf(y_offset, 0, viewport_size.y - panel_size.y)


## 动态获取 TopBar0 和 TopBar1 的实际高度
## 返回 [TopBar0高度, TopBar1高度]
func _get_topbar_heights() -> Array:
	var topbar0_height := 60.0  ## 默认高度
	var topbar1_height := 48.0  ## 默认高度
	
	## 尝试通过 UIMain -> TopBar -> TopbarFigma 获取实际高度
	var ui_main := get_parent()
	if ui_main:
		var topbar := ui_main.get_node_or_null("TopBar") as Control
		if topbar:
			var topbar_figma := topbar.get_node_or_null("TopbarFigma") as Control
			if topbar_figma:
				## 获取 Topbar0 和 Topbar1 节点
				var topbar0 := topbar_figma.get_node_or_null("Topbar0") as Control
				var topbar1 := topbar_figma.get_node_or_null("Topbar1") as Control
				if topbar0:
					topbar0_height = topbar0.size.y
				if topbar1:
					topbar1_height = topbar1.size.y
	
	return [topbar0_height, topbar1_height]


## 更新位置（供子类调用）
func _update_position_if_needed() -> void:
	if not visible:
		return
	var viewport := get_viewport()
	if viewport:
		update_position(viewport.get_mouse_position(), viewport.get_visible_rect().size)


## 清空容器中的所有子节点（用于动态条目刷新前清空）
func clear_container(container: Container) -> void:
	if not container:
		return
	## 复制子节点列表，避免遍历时修改原列表
	var children := container.get_children().duplicate()
	for child in children:
		if is_instance_valid(child) and child.get_parent() == container:
			container.remove_child(child)
			child.queue_free()

@tool
class_name DetailShelterProgressBar
extends MarginContainer
## 庇护能量专用三段进度条
## 结构：已分配(橙色，左到右) / 缺口(红色，右到左，可覆盖已分配) / 底色
## 特殊规则：缺口超过上限时，红色最多占 90%，保留 10% 显示已分配
## 设计：[ui-detail-panel-design.md] 庇护能量进度条；Figma 67:855
## 编辑器可见：比例在 setter / _enter_tree / _notification 中更新

const MARGIN := 2.0  ## 上下左右各 2px，内部 16px 高
const ASSIGNED_COLOR := Color(0.886, 0.616, 0.176, 1.0)  ## 橙色 #e29d2d
const DEFICIT_COLOR := Color(0.831, 0.118, 0.118, 1.0)  ## 红色 #d41e1e
const BACK_COLOR := Color(0.349, 0.349, 0.349, 1.0)  ## 灰色背景
const MAX_DEFICIT_RATIO := 0.9  ## 缺口最多占 90%

@export_group("数值")
@export var assigned: float = 1000.0:
	set(v):
		assigned = maxf(0.0, v)
		_update_segments()

@export var deficit: float = 200.0:
	set(v):
		deficit = maxf(0.0, v)
		_update_segments()

@export var capacity: float = 1200.0:
	set(v):
		capacity = maxf(0.001, v)
		_update_segments()

var _hbox: HBoxContainer
var _assigned_segment: ColorRect
var _back_segment: ColorRect
var _deficit_segment: ColorRect
var _center_label: Label


func _enter_tree() -> void:
	_cache_nodes()
	_update_segments()


func _ready() -> void:
	if _hbox == null:
		_cache_nodes()
	_update_segments()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_segments()


## 缓存节点引用
func _cache_nodes() -> void:
	_hbox = get_node_or_null("Content/SegmentsWrap/SegmentsHBox") as HBoxContainer
	_center_label = get_node_or_null("Content/CenterLabel") as Label
	if _hbox:
		_assigned_segment = _hbox.get_node_or_null("SegmentAssigned") as ColorRect
		_back_segment = _hbox.get_node_or_null("SegmentBack") as ColorRect
		_deficit_segment = _hbox.get_node_or_null("SegmentDeficit") as ColorRect


## 更新三段比例和中央文案
func _update_segments() -> void:
	if not _hbox:
		_cache_nodes()
	if not _hbox:
		return

	if not _assigned_segment or not _back_segment or not _deficit_segment:
		return

	## 计算各段比例
	## 实际显示逻辑：
	## - 总可用宽度按 capacity 分配
	## - 已分配段 = assigned / capacity
	## - 缺口段 = deficit / capacity，但从右向左显示
	## - 如果缺口超过上限，红色最多占 MAX_DEFICIT_RATIO(90%)，保留 10% 给已分配

	var total_capacity := capacity
	var assigned_ratio := clampf(assigned / total_capacity, 0.0, 1.0)
	var deficit_ratio := clampf(deficit / total_capacity, 0.0, 1.0)

	## 处理超额缺口情况
	if deficit_ratio > MAX_DEFICIT_RATIO:
		## 红色最多占 90%，剩余必须保留给已分配
		deficit_ratio = MAX_DEFICIT_RATIO
		if assigned_ratio < 0.1:
			## 强制已分配至少占 10%
			assigned_ratio = 0.1

	## 底色比例 = 剩余空间
	var back_ratio := maxf(0.0, 1.0 - assigned_ratio - deficit_ratio)

	## 应用比例
	_assigned_segment.size_flags_stretch_ratio = float(assigned_ratio * 100.0)
	_back_segment.size_flags_stretch_ratio = float(back_ratio * 100.0)
	_deficit_segment.size_flags_stretch_ratio = float(deficit_ratio * 100.0)

	## 更新中央文案：已分配 / 上限
	if _center_label:
		var assigned_str := _format_number(int(assigned))
		var cap_str := _format_number(int(capacity))
		_center_label.text = assigned_str + " / " + cap_str


## 格式化数字为千分位字符串
func _format_number(n: int) -> String:
	var s := str(abs(n))
	var out := ""
	for j in range(s.length()):
		if j > 0 and (s.length() - j) % 3 == 0:
			out += ","
		out += s[j]
	return "-" + out if n < 0 else out

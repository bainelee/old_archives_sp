@tool
class_name DetailHousingOverviewBar
extends MarginContainer

## 住房总览进度条：三段 可分配(橙)/已提供(灰)/缺口(红)，中央文案 需求总数/已提供总数
## 设计：[ui-detail-panel-design.md] 住房信息总览进度条；Figma 76:65
## 编辑器可见：比例与文案在 setter / _enter_tree 中更新，不在 _ready 写

@export var demand_total: int = 36:
	set(v):
		demand_total = maxi(0, v)
		_update_segments()

@export var supplied_total: int = 32:
	set(v):
		supplied_total = maxi(0, v)
		_update_segments()

var _hbox: HBoxContainer
var _label: Label

func _enter_tree() -> void:
	_hbox = get_node_or_null("Content/SegmentsWrap/SegmentsHBox") as HBoxContainer
	_label = get_node_or_null("Content/CenterLabel") as Label
	_update_segments()


func _ready() -> void:
	if _hbox == null:
		_hbox = get_node_or_null("Content/SegmentsWrap/SegmentsHBox") as HBoxContainer
	if _label == null:
		_label = get_node_or_null("Content/CenterLabel") as Label
	_update_segments()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_segments()


func _update_segments() -> void:
	if not _hbox:
		_hbox = get_node_or_null("Content/SegmentsWrap/SegmentsHBox") as HBoxContainer
	if not _label:
		_label = get_node_or_null("Content/CenterLabel") as Label
	if not _hbox or not _label:
		return
	var demand := maxi(1, demand_total)
	var supplied := clampi(supplied_total, 0, demand)
	var deficit := demand - supplied
	var surplus := maxi(0, supplied_total - demand_total)
	_label.text = "%d/%d" % [demand_total, supplied_total]
	var seg_surplus: Control = _hbox.get_node_or_null("SegmentIdle")
	var seg_supplied: Control = _hbox.get_node_or_null("SegmentOnDuty")
	var seg_deficit: Control = _hbox.get_node_or_null("SegmentEroded")
	if seg_surplus:
		seg_surplus.size_flags_stretch_ratio = float(surplus)
	if seg_supplied:
		seg_supplied.size_flags_stretch_ratio = float(supplied)
	if seg_deficit:
		seg_deficit.size_flags_stretch_ratio = float(deficit)

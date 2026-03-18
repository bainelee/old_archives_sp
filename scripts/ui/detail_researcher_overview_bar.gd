@tool
class_name DetailResearcherOverviewBar
extends MarginContainer

## 研究员总览进度条：三段（闲置-橙 / 在职-灰 / 被侵蚀-红），中央文案 闲置数/总数/被侵蚀数
## 设计：[ui-detail-panel-design.md] 研究员总览的进度条 闲置/总数/被侵蚀；Figma 70:964
## 编辑器可见：比例与文案在 setter / _enter_tree 中更新，不在 _ready 写

@export var idle_count: int = 8:
	set(v):
		idle_count = maxi(0, v)
		_update_segments()

@export var total_count: int = 32:
	set(v):
		total_count = maxi(0, v)
		_update_segments()

@export var eroded_count: int = 4:
	set(v):
		eroded_count = maxi(0, v)
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
	var total := maxi(1, total_count)
	var idle := clampi(idle_count, 0, total)
	var eroded := clampi(eroded_count, 0, total)
	var on_duty := clampi(total - idle - eroded, 0, total)
	_label.text = "%d/%d/%d" % [idle, total, eroded]
	var seg_idle: Control = _hbox.get_node_or_null("SegmentIdle")
	var seg_on_duty: Control = _hbox.get_node_or_null("SegmentOnDuty")
	var seg_eroded: Control = _hbox.get_node_or_null("SegmentEroded")
	if seg_idle:
		seg_idle.size_flags_stretch_ratio = float(idle)
	if seg_on_duty:
		seg_on_duty.size_flags_stretch_ratio = float(on_duty)
	if seg_eroded:
		seg_eroded.size_flags_stretch_ratio = float(eroded)

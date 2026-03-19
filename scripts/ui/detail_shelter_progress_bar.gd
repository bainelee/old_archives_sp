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
	# region agent log - node caching debug
	var _agent_log = JSON.stringify({"sessionId":"ada89e","runId":"debug","hypothesisId":"text_overlay","location":"detail_shelter_progress_bar.gd:55","message":"_cache_nodes called","data":{},"timestamp":Time.get_ticks_msec()})
	var _agent_file = FileAccess.open("res://debug-ada89e.log", FileAccess.READ_WRITE)
	if _agent_file:
		_agent_file.seek_end()
		_agent_file.store_line(_agent_log)
		_agent_file.close()
	# endregion
	
	_hbox = get_node_or_null("Content/SegmentsWrap/SegmentsHBox") as HBoxContainer
	_center_label = get_node_or_null("Content/CenterLabel") as Label
	
	# region agent log - label found check
	var label_info = {}
	if _center_label:
		label_info = {"name":_center_label.name,"text":_center_label.text,"visible":_center_label.visible}
	else:
		label_info = {"found":false}
	_agent_log = JSON.stringify({"sessionId":"ada89e","runId":"debug","hypothesisId":"text_overlay","location":"detail_shelter_progress_bar.gd:65","message":"center_label check","data":label_info,"timestamp":Time.get_ticks_msec()})
	_agent_file = FileAccess.open("res://debug-ada89e.log", FileAccess.READ_WRITE)
	if _agent_file:
		_agent_file.seek_end()
		_agent_file.store_line(_agent_log)
		_agent_file.close()
	# endregion
	
	if _hbox:
		_assigned_segment = _hbox.get_node_or_null("SegmentAssigned") as ColorRect
		_back_segment = _hbox.get_node_or_null("SegmentBack") as ColorRect
		_deficit_segment = _hbox.get_node_or_null("SegmentDeficit") as ColorRect


## 更新三段比例和中央文案
func _update_segments() -> void:
	# region agent log - shelter progress bar text debug
	var _agent_log = JSON.stringify({"sessionId":"ada89e","runId":"debug","hypothesisId":"text_overlay","location":"detail_shelter_progress_bar.gd:66","message":"_update_segments called","data":{"assigned":assigned,"deficit":deficit,"capacity":capacity},"timestamp":Time.get_ticks_msec()})
	var _agent_file = FileAccess.open("res://debug-ada89e.log", FileAccess.WRITE)
	if _agent_file:
		_agent_file.store_line(_agent_log)
		_agent_file.close()
	# endregion
	
	if not _hbox:
		_cache_nodes()
	if not _hbox:
		# region agent log
		_agent_log = JSON.stringify({"sessionId":"ada89e","runId":"debug","hypothesisId":"text_overlay","location":"detail_shelter_progress_bar.gd:70","message":"_hbox not found","data":{},"timestamp":Time.get_ticks_msec()})
		_agent_file = FileAccess.open("res://debug-ada89e.log", FileAccess.READ_WRITE)
		if _agent_file:
			_agent_file.seek_end()
			_agent_file.store_line(_agent_log)
			_agent_file.close()
		# endregion
		return

	if not _assigned_segment or not _back_segment or not _deficit_segment:
		# region agent log
		_agent_log = JSON.stringify({"sessionId":"ada89e","runId":"debug","hypothesisId":"text_overlay","location":"detail_shelter_progress_bar.gd:75","message":"segments not found","data":{},"timestamp":Time.get_ticks_msec()})
		_agent_file = FileAccess.open("res://debug-ada89e.log", FileAccess.READ_WRITE)
		if _agent_file:
			_agent_file.seek_end()
			_agent_file.store_line(_agent_log)
			_agent_file.close()
		# endregion
		return

	## 计算各段比例
	var total_capacity := capacity
	var assigned_ratio := clampf(assigned / total_capacity, 0.0, 1.0)
	var deficit_ratio := clampf(deficit / total_capacity, 0.0, 1.0)

	## 处理超额缺口情况
	if deficit_ratio > MAX_DEFICIT_RATIO:
		deficit_ratio = MAX_DEFICIT_RATIO
		if assigned_ratio < 0.1:
			assigned_ratio = 0.1

	## 底色比例 = 剩余空间
	var back_ratio := maxf(0.0, 1.0 - assigned_ratio - deficit_ratio)

	## 应用比例
	_assigned_segment.size_flags_stretch_ratio = float(assigned_ratio * 100.0)
	_back_segment.size_flags_stretch_ratio = float(back_ratio * 100.0)
	_deficit_segment.size_flags_stretch_ratio = float(deficit_ratio * 100.0)

	## 更新中央文案：已分配 / 上限 / 缺口（三段式显示）
	if _center_label:
		var old_text = _center_label.text
		_center_label.text = ""
		var assigned_str := _format_number(int(assigned))
		var cap_str := _format_number(int(capacity))
		var deficit_str := _format_number(int(deficit))
		var new_text = assigned_str + " / " + cap_str + " / " + deficit_str
		_center_label.text = new_text
		# region agent log
		_agent_log = JSON.stringify({"sessionId":"ada89e","runId":"debug","hypothesisId":"text_overlay","location":"detail_shelter_progress_bar.gd:118","message":"label text updated","data":{"old_text":old_text,"new_text":new_text,"label_name":_center_label.name,"label_visible":_center_label.visible},"timestamp":Time.get_ticks_msec()})
		_agent_file = FileAccess.open("res://debug-ada89e.log", FileAccess.READ_WRITE)
		if _agent_file:
			_agent_file.seek_end()
			_agent_file.store_line(_agent_log)
			_agent_file.close()
		# endregion
	else:
		# region agent log
		_agent_log = JSON.stringify({"sessionId":"ada89e","runId":"debug","hypothesisId":"text_overlay","location":"detail_shelter_progress_bar.gd:129","message":"_center_label is null","data":{},"timestamp":Time.get_ticks_msec()})
		_agent_file = FileAccess.open("res://debug-ada89e.log", FileAccess.READ_WRITE)
		if _agent_file:
			_agent_file.seek_end()
			_agent_file.store_line(_agent_log)
			_agent_file.close()
		# endregion


## 格式化数字为千分位字符串
func _format_number(n: int) -> String:
	var s := str(abs(n))
	var out := ""
	for j in range(s.length()):
		if j > 0 and (s.length() - j) % 3 == 0:
			out += ","
		out += s[j]
	return "-" + out if n < 0 else out

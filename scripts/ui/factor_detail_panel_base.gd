@tool
class_name FactorDetailPanelBase
extends DetailPanelBase

## 因子详情面板公共基类：
## - 统一内容区宽度修正
## - 统一预置行「左标签 + Spacer + 右数值」布局策略
## - 统一强制重排逻辑

func _force_layout_refresh() -> void:
	custom_minimum_size.y = 0
	custom_minimum_size.x = 320
	reset_size()
	queue_sort()
	var content := _get_content_vbox()
	if content:
		content.reset_size()
		content.queue_sort()


func _apply_standard_row_layout(row_names: Array[String]) -> void:
	var content_margin := _get_content_margin()
	var content := _get_content_vbox()
	if content_margin and content:
		content.custom_minimum_size.x = 276
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not content:
		return
	for row_name in row_names:
		var row := content.get_node_or_null(row_name) as HBoxContainer
		if not row:
			continue
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size.x = 276
		for child in row.get_children():
			if child is Label:
				if child.name == "Value":
					child.size_flags_horizontal = Control.SIZE_SHRINK_END
					child.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				else:
					child.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
					child.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			elif child is Control and child.name == "Spacer":
				child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				child.size_flags_stretch_ratio = 1.0
	for row_name in row_names:
		var row := content.get_node_or_null(row_name) as HBoxContainer
		if row:
			row.queue_sort()
	queue_sort()

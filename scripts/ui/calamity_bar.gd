extends Control
## 灾厄值竖向进度条 - 显示在界面最下方中间
## 进度条从下往上涨，数据源 PersonnelErosionCore

## 进度条尺寸（宽 x 高，正方形）
const BAR_SIZE := 130

@onready var _spacer: Control = $Track/VBox/Spacer
@onready var _fill: Control = $Track/VBox/Fill
@onready var _label_value: Label = $LabelVBox/Value


func _ready() -> void:
	custom_minimum_size = Vector2(BAR_SIZE, BAR_SIZE)
	_update_fill_ratio(0.0)
	if PersonnelErosionCore:
		PersonnelErosionCore.calamity_updated.connect(_on_calamity_updated)
		_on_calamity_updated(PersonnelErosionCore.get_calamity_value())


func _on_calamity_updated(value: float) -> void:
	var max_val: float = float(PersonnelErosionCore.get_calamity_max()) if PersonnelErosionCore else 30000.0
	var ratio: float = clampf(value / max_val, 0.0, 1.0) if max_val > 0 else 0.0
	_update_fill_ratio(ratio)
	if _label_value:
		_label_value.text = str(int(value))


func _update_fill_ratio(ratio: float) -> void:
	if not _spacer or not _fill:
		return
	# Spacer 在上方占 (1-ratio)，Fill 在下方占 ratio，实现从下往上涨
	_spacer.size_flags_stretch_ratio = 1.0 - ratio
	_fill.size_flags_stretch_ratio = ratio

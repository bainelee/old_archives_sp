@tool
class_name CorrosionNumber
extends Control

## 侵蚀数字显示控件：三位数，个位补零（如 4 → 004）
## 使用 assets/ui/corrosion_number/ 中的数字图片（0-9、加减号）
## API：只需调用 set_corrosion_value(value) 即可自动刷新显示

const DIGIT_PATH := "res://assets/ui/corrosion_number/corrosion_number_%d.png"

@export_range(-999, 999) var preview_value: int = 0:
	set(v):
		preview_value = clampi(v, -999, 999)
		if Engine.is_editor_hint():
			call_deferred("_apply_preview")

var _background: TextureRect
var _plus_sign: TextureRect
var _minus_sign: TextureRect
var _digits: Array[TextureRect] = []


func _ready() -> void:
	_background = get_node_or_null("Background") as TextureRect
	_plus_sign = get_node_or_null("PlusSign") as TextureRect
	_minus_sign = get_node_or_null("MinusSign") as TextureRect
	for i in 3:
		var d: TextureRect = get_node_or_null("Digit%d" % i) as TextureRect
		if d:
			_digits.append(d)
	if Engine.is_editor_hint():
		_apply_preview()
	else:
		set_corrosion_value(0)


func _apply_preview() -> void:
	set_corrosion_value(preview_value)


## 设置侵蚀数字，自动刷新显示（三位数补零，如 4→004）
func set_corrosion_value(value: int) -> void:
	value = clampi(value, -999, 999)
	var abs_val: int = absi(value)
	var digits_str: String = "%03d" % abs_val
	# 正负号
	if _plus_sign:
		_plus_sign.visible = value >= 0
	if _minus_sign:
		_minus_sign.visible = value < 0
	# 三位数字图片
	for i in min(_digits.size(), 3):
		var d: int = int(digits_str[i])
		var tex: Texture2D = load(DIGIT_PATH % d) as Texture2D
		if tex:
			_digits[i].texture = tex
			_digits[i].visible = true
		else:
			_digits[i].visible = false

extends CanvasLayer
## 开发用作弊面板：调整全局庇护数值
## 控制 ErosionCore.shelter_bonus，影响 current_erosion = raw_mystery_erosion + shelter_bonus

@onready var _btn_plus: Button = $Panel/Margin/VBox/BtnPlus
@onready var _label_value: Label = $Panel/Margin/VBox/ValueLabel
@onready var _btn_minus: Button = $Panel/Margin/VBox/BtnMinus

var _cheat_value: int = 0


func _ready() -> void:
	layer = 20  # 高于主 UI，确保可见
	_btn_plus.pressed.connect(_on_plus)
	_btn_minus.pressed.connect(_on_minus)
	_update_display()


func _on_plus() -> void:
	_cheat_value += 1
	_apply()


func _on_minus() -> void:
	_cheat_value -= 1
	_apply()


func _apply() -> void:
	if ErosionCore:
		ErosionCore.shelter_bonus = _cheat_value
	_update_display()


func _update_display() -> void:
	if _label_value:
		_label_value.text = str(_cheat_value)

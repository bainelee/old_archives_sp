@tool
extends Button

## 通用按钮控件，基于 Figma 九宫格切图
## 支持任意偶数×偶数尺寸变化，StyleBoxTexture 自动缩放
## Win95 像素风格：texture_filter=NEAREST 保证像素清晰
## 尺寸在 Inspector 中通过 button_width / button_height 配置，修改后立即生效（含编辑器）

var _btn_w: int = 216
var _btn_h: int = 108

@export var button_width: int = 216:
	get: return _btn_w
	set(v):
		_btn_w = v
		_apply_size()

@export var button_height: int = 108:
	get: return _btn_h
	set(v):
		_btn_h = v
		_apply_size()


func _apply_size() -> void:
	custom_minimum_size = Vector2(_btn_w, _btn_h)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_size()

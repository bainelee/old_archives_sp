@tool
class_name ForecastHandleData
extends Resource

## 侵蚀 handle 配置：在编辑器中配置每个 handle 的显示
## 由 ForecastWarning 根据此数据创建 handle 与 warning sign

enum Level {
	BLUE,    ## 0
	GREEN,   ## 1
	ORANGE,  ## 2
	PURPLE,  ## 3
	RED,     ## 4
}

var _days: int = 0
var _level: int = 0
var _sign: bool = false

@export_range(0, 84) var days_from_now: int:
	get: return _days
	set(v):
		_days = clampi(v, 0, 84)
		emit_changed()

@export_range(0, 4) var erosion_level: int:
	get: return _level
	set(v):
		_level = clampi(v, 0, 4)
		emit_changed()

@export var warning_sign: bool:
	get: return _sign
	set(v):
		_sign = v
		emit_changed()


func _init() -> void:
	resource_name = "ForecastHandle"

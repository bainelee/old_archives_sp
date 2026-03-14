extends "res://scripts/ui/detail_hover_panel_base.gd"
## 因子悬停面板 - 显示：库存、总消耗、可供使用天数、消耗细则、产出细则

@onready var _label_stock: Label = $Margin/VBox/Stock
@onready var _label_consume_total: Label = $Margin/VBox/ConsumeTotal
@onready var _label_consume_details: Label = $Margin/VBox/ConsumeDetails
@onready var _label_produce_details: Label = $Margin/VBox/ProduceDetails


## data: { stock, cap, daily_consume, consume_details, daily_produce, produce_details }
## consume_details / produce_details: Array of { zone_name, room_name, per_day }
func show_for_factor(factor_name: String, data: Dictionary) -> void:
	## 库存格式 "X / Y"：斜杠为显示用字符（非除法运算）
	var stock: int = floori(data.get("stock", 0))
	var cap: int = floori(data.get("cap", 999999))
	var daily_consume: int = floori(data.get("daily_consume", 0))
	var consume_details: Array = data.get("consume_details", [])
	var produce_details: Array = data.get("produce_details", [])

	_label_stock.text = tr("HOVER_FACTOR_STOCK") % [factor_name, _fmt(stock), _fmt(cap)]

	var days_str: String = ""
	if daily_consume > 0:
		days_str = tr("HOVER_FACTOR_DAYS") % [_fmt(daily_consume), _days_if_positive(stock, daily_consume)]
	else:
		days_str = tr("HOVER_FACTOR_DAYS_NO_CONSUME") % "∞"
	_label_consume_total.text = days_str

	var consume_lines: PackedStringArray = []
	for entry in consume_details:
		if entry is Dictionary:
			var zn: String = str(entry.get("zone_name", ""))
			var rn: String = str(entry.get("room_name", ""))
			var pd: int = floori(entry.get("per_day", 0))
			consume_lines.append("%s-%s %s" % [zn, rn, _fmt(pd)] + "/天")
	_label_consume_details.text = tr("HOVER_FACTOR_CONSUME_HEADER") + "\n" + "\n".join(consume_lines) if consume_lines.size() > 0 else tr("HOVER_FACTOR_CONSUME_HEADER") + "\n" + tr("HOVER_FACTOR_NONE")

	var produce_lines: PackedStringArray = []
	for entry in produce_details:
		if entry is Dictionary:
			var zn: String = str(entry.get("zone_name", ""))
			var rn: String = str(entry.get("room_name", ""))
			var pd: int = floori(entry.get("per_day", 0))
			produce_lines.append("%s-%s %s" % [zn, rn, _fmt(pd)] + "/天")
	_label_produce_details.text = tr("HOVER_FACTOR_PRODUCE_HEADER") + "\n" + "\n".join(produce_lines) if produce_lines.size() > 0 else tr("HOVER_FACTOR_PRODUCE_HEADER") + "\n" + tr("HOVER_FACTOR_NONE")

	visible = true


const TOPBAR_HEIGHT := 108.0  ## TopBar 高度，面板 y 贴顶

func _get_position_y(_mouse_pos: Vector2, panel_size: Vector2, viewport_size: Vector2) -> float:
	return clampf(TOPBAR_HEIGHT, TOPBAR_HEIGHT, viewport_size.y - panel_size.y)


func _fmt(n: int) -> String:
	if n >= 10000:
		return "%d,%03d" % [floori(n / 1000.0), n % 1000]
	return str(n)


func _days_if_positive(stock: int, daily_consume: int) -> String:
	if daily_consume <= 0:
		return "∞"
	var d: int = floori(stock / float(daily_consume))
	return str(d) if d >= 0 else "0"

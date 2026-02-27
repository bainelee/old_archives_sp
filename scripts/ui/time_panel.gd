extends HBoxContainer
## 可复用的时间流逝 UI 面板
## 包含：时间流逝指示器、播放/暂停、1x/2x/6x/96x 倍速、时间显示

const ICON_PLAY := "▶"
const ICON_PAUSE := "⏸"

@onready var _indicator: Control = $TimeIndicator
@onready var _btn_play_pause: Button = $PlayPauseButton
@onready var _btn_1x: Button = $Speed1xButton
@onready var _btn_2x: Button = $Speed2xButton
@onready var _btn_6x: Button = $Speed6xButton
@onready var _btn_96x: Button = $Speed96xButton
@onready var _label_time: Label = $TimeLabel

var _indicator_rotation: float = 0.0
var _hovering_play_pause: bool = false


func _ready() -> void:
	GameTime.flowing_changed.connect(_on_flowing_changed)
	GameTime.speed_changed.connect(_on_speed_changed)
	GameTime.time_updated.connect(_on_time_updated)
	_update_play_pause_icon()
	_update_speed_buttons()
	_update_time_label()
	_btn_play_pause.pressed.connect(_on_play_pause_pressed)
	_btn_play_pause.mouse_entered.connect(_on_play_pause_mouse_entered)
	_btn_play_pause.mouse_exited.connect(_on_play_pause_mouse_exited)
	_btn_1x.tooltip_text = tr("TOOLTIP_NORMAL_SPEED")
	_btn_1x.pressed.connect(_on_1x_pressed)
	_btn_2x.pressed.connect(_on_2x_pressed)
	_btn_6x.pressed.connect(_on_6x_pressed)
	_btn_96x.pressed.connect(_on_96x_pressed)


func _process(delta: float) -> void:
	if GameTime.is_flowing:
		_indicator_rotation += 120.0 * delta  # 度/秒
		if _indicator_rotation >= 360.0:
			_indicator_rotation -= 360.0
	_indicator.rotation = deg_to_rad(_indicator_rotation)
	_indicator.queue_redraw()


func _on_flowing_changed(_flowing: bool) -> void:
	_update_play_pause_icon()


func _on_speed_changed(_speed: float) -> void:
	_update_speed_buttons()


func _on_time_updated() -> void:
	_update_time_label()


func _on_play_pause_pressed() -> void:
	GameTime.toggle_flow()


func _on_play_pause_mouse_entered() -> void:
	_hovering_play_pause = true
	_update_play_pause_icon()


func _on_play_pause_mouse_exited() -> void:
	_hovering_play_pause = false
	_update_play_pause_icon()


func _on_1x_pressed() -> void:
	GameTime.set_speed_1x()
	_btn_2x.button_pressed = false
	_btn_6x.button_pressed = false
	_btn_96x.button_pressed = false


func _on_2x_pressed() -> void:
	if _btn_2x.button_pressed:
		GameTime.set_speed_2x()
		_btn_6x.button_pressed = false
		_btn_96x.button_pressed = false
	else:
		GameTime.set_speed_1x()


func _on_6x_pressed() -> void:
	if _btn_6x.button_pressed:
		GameTime.set_speed_6x()
		_btn_2x.button_pressed = false
		_btn_96x.button_pressed = false
	else:
		GameTime.set_speed_1x()
		_btn_2x.button_pressed = false


func _on_96x_pressed() -> void:
	if _btn_96x.button_pressed:
		GameTime.set_speed_96x()
		_btn_2x.button_pressed = false
		_btn_6x.button_pressed = false
	else:
		GameTime.set_speed_1x()
		_btn_2x.button_pressed = false
		_btn_6x.button_pressed = false


## 时间流逝时默认显示播放图标，暂停时默认显示暂停图标；悬浮时显示「将要切换到的」图标
func _update_play_pause_icon() -> void:
	var is_flowing: bool = GameTime.is_flowing
	if _hovering_play_pause:
		# 悬浮时显示相反图标（点击后将切换到的状态）
		_btn_play_pause.text = ICON_PAUSE if is_flowing else ICON_PLAY
		_btn_play_pause.tooltip_text = tr("TOOLTIP_CLICK_PAUSE") if is_flowing else tr("TOOLTIP_CLICK_RESUME")
	else:
		# 默认：流逝时显示播放，暂停时显示暂停
		_btn_play_pause.text = ICON_PLAY if is_flowing else ICON_PAUSE
		_btn_play_pause.tooltip_text = tr("TOOLTIP_PAUSE") if is_flowing else tr("TOOLTIP_RESUME")


func _update_speed_buttons() -> void:
	var speed: float = GameTime.speed_multiplier
	_btn_2x.button_pressed = (speed >= 1.99 and speed < 5.99)
	_btn_6x.button_pressed = (speed >= 5.99 and speed < 95.99)
	_btn_96x.button_pressed = (speed >= 95.99)


func _update_time_label() -> void:
	_label_time.text = GameTime.format_time_short()

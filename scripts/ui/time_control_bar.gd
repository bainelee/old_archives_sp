class_name TimeControlBar
extends Control

## 时间控制条：背景 + 四个互斥时间按钮（暂停/1x/2x/6x）+ 时/天/周显示
## 与 GameTime 同步：flowing_changed、speed_changed、time_updated
## 外部暂停（ESC 菜单、清理模式等）时暂停按钮保持按下；恢复时回归之前的倍速按钮

enum SpeedIndex { PAUSE, SPEED_1X, SPEED_2X, SPEED_6X }

var _btn_pause: TextureButton
var _btn_1x: TextureButton
var _btn_2x: TextureButton
var _btn_6x: TextureButton
var _label_hour: Label
var _label_day: Label
var _label_week: Label

## 暂停前记录的倍速索引，恢复时用于显示对应按钮
var _speed_before_pause: int = SpeedIndex.SPEED_1X
var _last_displayed_hour: int = -1


func _ready() -> void:
	_btn_pause = get_node_or_null("Background/BtnPause") as TextureButton
	_btn_1x = get_node_or_null("Background/Btn1x") as TextureButton
	_btn_2x = get_node_or_null("Background/Btn2x") as TextureButton
	_btn_6x = get_node_or_null("Background/Btn6x") as TextureButton
	var time_labels: Control = get_node_or_null("Background/TimeLabels") as Control
	if time_labels:
		_label_hour = time_labels.get_node_or_null("Hour") as Label
		_label_day = time_labels.get_node_or_null("Day") as Label
		_label_week = time_labels.get_node_or_null("Week") as Label
	_connect_game_time()
	_connect_buttons()
	_update_buttons_state()
	_update_time_labels()


func _exit_tree() -> void:
	_disconnect_game_time()


func _connect_game_time() -> void:
	if not GameTime:
		return
	if not GameTime.flowing_changed.is_connected(_on_flowing_changed):
		GameTime.flowing_changed.connect(_on_flowing_changed)
	if not GameTime.speed_changed.is_connected(_on_speed_changed):
		GameTime.speed_changed.connect(_on_speed_changed)
	if not GameTime.time_updated.is_connected(_on_time_updated):
		GameTime.time_updated.connect(_on_time_updated)


func _disconnect_game_time() -> void:
	if not GameTime:
		return
	if GameTime.flowing_changed.is_connected(_on_flowing_changed):
		GameTime.flowing_changed.disconnect(_on_flowing_changed)
	if GameTime.speed_changed.is_connected(_on_speed_changed):
		GameTime.speed_changed.disconnect(_on_speed_changed)
	if GameTime.time_updated.is_connected(_on_time_updated):
		GameTime.time_updated.disconnect(_on_time_updated)


func _connect_buttons() -> void:
	if _btn_pause:
		_btn_pause.pressed.connect(_on_pause_pressed)
	if _btn_1x:
		_btn_1x.pressed.connect(_on_1x_pressed)
	if _btn_2x:
		_btn_2x.pressed.connect(_on_2x_pressed)
	if _btn_6x:
		_btn_6x.pressed.connect(_on_6x_pressed)


func _on_flowing_changed(flowing: bool) -> void:
	if not flowing and GameTime:
		## 外部触发暂停时，记录当前倍速供恢复时显示
		var s: float = GameTime.speed_multiplier
		if s >= 5.99:
			_speed_before_pause = SpeedIndex.SPEED_6X
		elif s >= 1.99:
			_speed_before_pause = SpeedIndex.SPEED_2X
		else:
			_speed_before_pause = SpeedIndex.SPEED_1X
	_update_buttons_state()


func _on_speed_changed(_speed: float) -> void:
	_update_buttons_state()


func _on_time_updated() -> void:
	if not GameTime:
		return
	var hour_floor: int = int(floor(GameTime.get_total_hours()))
	if _last_displayed_hour < 0 or hour_floor != _last_displayed_hour:
		_last_displayed_hour = hour_floor
		_update_time_labels()


func _on_pause_pressed() -> void:
	if not GameTime:
		return
	_record_speed_before_if_flowing()
	GameTime.toggle_flow()
	_sync_tree_paused()


func _on_1x_pressed() -> void:
	if not GameTime:
		return
	_record_speed_before_if_flowing()
	GameTime.is_flowing = true
	GameTime.set_speed_1x()
	_set_single_pressed(SpeedIndex.SPEED_1X)
	_sync_tree_paused()


func _on_2x_pressed() -> void:
	if not GameTime:
		return
	_record_speed_before_if_flowing()
	GameTime.is_flowing = true
	GameTime.set_speed_2x()
	_set_single_pressed(SpeedIndex.SPEED_2X)
	_sync_tree_paused()


func _on_6x_pressed() -> void:
	if not GameTime:
		return
	_record_speed_before_if_flowing()
	GameTime.is_flowing = true
	GameTime.set_speed_6x()
	_set_single_pressed(SpeedIndex.SPEED_6X)
	_sync_tree_paused()


## 暂停前记录当前倍速，供恢复时显示
func _record_speed_before_if_flowing() -> void:
	if not GameTime or not GameTime.is_flowing:
		return
	var s: float = GameTime.speed_multiplier
	if s >= 5.99:
		_speed_before_pause = SpeedIndex.SPEED_6X
	elif s >= 1.99:
		_speed_before_pause = SpeedIndex.SPEED_2X
	else:
		_speed_before_pause = SpeedIndex.SPEED_1X


func _set_single_pressed(idx: int) -> void:
	if _btn_pause:
		_btn_pause.button_pressed = (idx == SpeedIndex.PAUSE)
	if _btn_1x:
		_btn_1x.button_pressed = (idx == SpeedIndex.SPEED_1X)
	if _btn_2x:
		_btn_2x.button_pressed = (idx == SpeedIndex.SPEED_2X)
	if _btn_6x:
		_btn_6x.button_pressed = (idx == SpeedIndex.SPEED_6X)


func _update_buttons_state() -> void:
	if not GameTime:
		return
	if not GameTime.is_flowing:
		_record_speed_before_if_flowing()
		_set_single_pressed(SpeedIndex.PAUSE)
	else:
		var s: float = GameTime.speed_multiplier
		if s >= 5.99:
			_set_single_pressed(SpeedIndex.SPEED_6X)
		elif s >= 1.99:
			_set_single_pressed(SpeedIndex.SPEED_2X)
		else:
			_set_single_pressed(SpeedIndex.SPEED_1X)


func _sync_tree_paused() -> void:
	## 仅本控件触发暂停时设置 tree.paused；清理/建设等由各自模块处理
	if GameTime and is_inside_tree():
		get_tree().paused = not GameTime.is_flowing


func _update_time_labels() -> void:
	if not GameTime:
		return
	if _label_hour:
		_label_hour.text = "HOUR:%d" % GameTime.get_hour()
	if _label_day:
		_label_day.text = "DAY:%d" % GameTime.get_day()
	if _label_week:
		_label_week.text = "WEEK:%d" % GameTime.get_week()


## 设置时间显示（供外部注入，如无 GameTime 时）
func set_time_display(hour: int, day: int, week: int) -> void:
	if _label_hour:
		_label_hour.text = "HOUR:%d" % hour
	if _label_day:
		_label_day.text = "DAY:%d" % day
	if _label_week:
		_label_week.text = "WEEK:%d" % week

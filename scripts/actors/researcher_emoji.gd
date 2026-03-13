extends Sprite3D
## Phase 5: 研究员头顶表情。由 Researcher3D.set_emoji_state(flags) 驱动。
## 显示/隐藏 0.15s 缓动；0.8s/2s 事件表情；4s 周期随机表情。

## 调试：暂停时研究员 emoji/移动 问题，输出 [ResearcherPause] 日志
const RESEARCHER_PAUSE_DEBUG := false

const BASE_SCALE: float = 0.8
const TWEEN_SHOW_DURATION: float = 0.15
const TWEEN_HIDE_DURATION: float = 0.15
const DURATION_SHORT: float = 0.8
const DURATION_LONG: float = 2.0
const PERIODIC_INTERVAL: float = 4.0
const PERIODIC_JITTER: float = 1.2  ## 每人 ±1.2 秒随机偏移，避免所有人同步

const ICON_IDS: Array[String] = [
	"idle", "walking", "happy", "good", "clean", "build", "work",
	"confuse", "talk", "erosion", "erosion_danger", "no_house", "heal", "stairs"
]

var _textures: Dictionary = {}
var _show_tween: Tween = null
var _hide_tween: Tween = null
var _short_timer: Timer = null
var _long_timer: Timer = null
var _periodic_timer: Timer = null
var _last_phase: int = -1
var _last_got_housing: bool = false
var _last_recovered_erosion: bool = false
var _last_was_idle: bool = false
var _last_is_walking: bool = false
var _continuous_walking: bool = false
var _is_showing: bool = false
var _current_flags: Dictionary = {}


func _ready() -> void:
	_load_textures()
	scale = Vector3.ZERO
	visible = false
	_stop_tweens()
	_ensure_timers()
	if GameTime and not GameTime.flowing_changed.is_connected(_on_flowing_changed):
		GameTime.flowing_changed.connect(_on_flowing_changed)
	_update_timers_for_flowing()


func _exit_tree() -> void:
	## 不在 _exit_tree 中 disconnect：父 researcher_3d reparent 时本节点随之 _exit_tree，disconnect 会导致连接丢失。
	## 节点 freed 时引擎会清理连接。
	pass


## 供 Researcher3D.force_sync_flowing_state 调用，强制同步 Timer/Tween 暂停状态
func sync_timers_for_flowing() -> void:
	_update_timers_for_flowing()


func _on_flowing_changed(_is_flowing: bool) -> void:
	if RESEARCHER_PAUSE_DEBUG:
		var pid: int = _get_parent_researcher_id()
		var flowing: bool = GameTime != null and GameTime.is_flowing
		var short_p: bool = _short_timer.paused if _short_timer else false
		var long_p: bool = _long_timer.paused if _long_timer else false
		var periodic_p: bool = _periodic_timer.paused if _periodic_timer else false
		var my_path: String = str(get_path()) if is_inside_tree() else "not_in_tree"
		var parent_path: String = str(get_parent().get_path()) if get_parent() else ""
		print("[ResearcherPause] emoji_flowing parent_id=%d path=%s parent=%s is_flowing=%s short=%s long=%s periodic=%s" % [
			pid, my_path, parent_path, flowing, short_p, long_p, periodic_p])
	_update_timers_for_flowing()


## 游戏时间暂停时暂停本节点 Timers/Tweens，恢复时取消暂停
func _update_timers_for_flowing() -> void:
	var paused: bool = GameTime != null and not GameTime.is_flowing
	if _short_timer:
		_short_timer.paused = paused
	if _long_timer:
		_long_timer.paused = paused
	if _periodic_timer:
		_periodic_timer.paused = paused
	if _show_tween and _show_tween.is_valid():
		if paused:
			_show_tween.pause()
		else:
			## 仅对未完成的 Tween 调用 play()，避免 "Can't play finished Tween" 报错
			if _show_tween.get_total_elapsed_time() < TWEEN_SHOW_DURATION - 0.001:
				_show_tween.play()
	if _hide_tween and _hide_tween.is_valid():
		if paused:
			_hide_tween.pause()
		else:
			if _hide_tween.get_total_elapsed_time() < TWEEN_HIDE_DURATION - 0.001:
				_hide_tween.play()


func _load_textures() -> void:
	for icon_id in ICON_IDS:
		var path: String = "res://assets/icons/emoji/icon_emoji_%s.png" % icon_id
		var tex: Texture2D = load(path) as Texture2D
		if tex:
			_textures[icon_id] = tex
		else:
			_textures[icon_id] = null


func _ensure_timers() -> void:
	if _short_timer == null:
		_short_timer = Timer.new()
		_short_timer.one_shot = true
		_short_timer.timeout.connect(_on_short_timer_timeout)
		add_child(_short_timer)
	if _long_timer == null:
		_long_timer = Timer.new()
		_long_timer.one_shot = true
		_long_timer.timeout.connect(_on_long_timer_timeout)
		add_child(_long_timer)
	if _periodic_timer == null:
		_periodic_timer = Timer.new()
		_periodic_timer.one_shot = false
		_periodic_timer.timeout.connect(_on_periodic_timer_timeout)
		add_child(_periodic_timer)


func _stop_tweens() -> void:
	if _show_tween and _show_tween.is_valid():
		_show_tween.kill()
	_show_tween = null
	if _hide_tween and _hide_tween.is_valid():
		_hide_tween.kill()
	_hide_tween = null


## 由 Researcher3D 或生命周期调用。flags: is_walking, phase (Researcher3D.Phase),
## no_house, eroded, healing, got_housing, recovered_erosion
func set_emoji_state(flags: Dictionary) -> void:
	## 仅在暂停时记录（正常情况下 ResearcherLifecycle 不调用），避免 time_updated 每帧刷屏
	if RESEARCHER_PAUSE_DEBUG and GameTime and not GameTime.is_flowing:
		var pid: int = _get_parent_researcher_id()
		var dbg_phase: int = int(flags.get("phase", -1))
		print("[ResearcherPause] set_emoji id=%d phase=%d is_flowing=false ANOMALY" % [pid, dbg_phase])
	_current_flags = flags
	var is_walking: bool = bool(flags.get("is_walking", false))
	var phase: int = int(flags.get("phase", Researcher3D.Phase.WANDER))
	var _no_house: bool = bool(flags.get("no_house", false))
	var _eroded: bool = bool(flags.get("eroded", false))
	var _healing: bool = bool(flags.get("healing", false))
	var got_housing: bool = bool(flags.get("got_housing", false))
	var recovered_erosion: bool = bool(flags.get("recovered_erosion", false))

	## 睡觉时不显示 emoji。仅首次进入 SLEEP 时触发隐藏，避免 time_updated 每帧调用 _hide_with_tween 导致 tween 不断被杀而重启、emoji 缓慢缩小数小时
	if phase == Researcher3D.Phase.SLEEP:
		_stop_timers()
		_stop_periodic()
		var just_entered_sleep: bool = (phase != _last_phase)
		_last_phase = phase
		if just_entered_sleep and (_is_showing or visible):
			_hide_with_tween()
		return

	if is_walking:
		_last_is_walking = true
		if not _continuous_walking:
			## 仅首次进入行走时显示，避免每帧重置 scale 导致 emoji 变成小点
			_continuous_walking = true
			_stop_timers()
			_show_icon("walking", -1.0)
		return

	# 刚从行走切回：先隐藏，由 _on_hide_tween_finished 启动 4s 周期
	if _continuous_walking:
		_continuous_walking = false
		_hide_with_tween()
		return

	_last_is_walking = false

	# 2s 事件：刚进入 cleanup / construction / work
	if phase == Researcher3D.Phase.CLEANUP and phase != _last_phase:
		_show_icon("clean", DURATION_LONG)
		_last_phase = phase
		return
	if phase == Researcher3D.Phase.CONSTRUCTION and phase != _last_phase:
		_show_icon("build", DURATION_LONG)
		_last_phase = phase
		return
	if phase == Researcher3D.Phase.WORK and phase != _last_phase:
		_show_icon("work", DURATION_LONG)
		_last_phase = phase
		return

	_last_phase = phase

	# 0.8s 事件：刚获得住房 / 刚治愈侵蚀
	if got_housing and not _last_got_housing:
		_show_icon("happy", DURATION_SHORT)
		_last_got_housing = true
		return
	_last_got_housing = got_housing

	if recovered_erosion and not _last_recovered_erosion:
		_show_icon("good", DURATION_SHORT)
		_last_recovered_erosion = true
		return
	_last_recovered_erosion = recovered_erosion

	# 闲逛且未在 2s/0.8s 展示中：进入 idle 时先展示 0.8s idle，再交给 4s 周期（睡觉已在上面 return，此处仅 WANDER）
	var is_idle: bool = (phase == Researcher3D.Phase.WANDER)
	if is_idle and not _last_was_idle and not _is_in_timed_show():
		_show_icon("idle", DURATION_SHORT)
		_last_was_idle = true
		return
	_last_was_idle = is_idle

	# 非 cleanup/construction/sleep 且未在展示时，启动 4s 周期
	if not is_walking and phase != Researcher3D.Phase.CLEANUP and phase != Researcher3D.Phase.CONSTRUCTION and phase != Researcher3D.Phase.SLEEP:
		if not _is_showing and not _short_timer.time_left > 0 and not _long_timer.time_left > 0:
			_start_periodic_if_needed()


func _is_in_timed_show() -> bool:
	return _short_timer.time_left > 0 or _long_timer.time_left > 0


## 供 Researcher3D 等外部调用，显示指定 emoji 指定时长（如楼梯传送前的 stairs）
func show_icon_for(icon_id: String, duration_sec: float) -> void:
	_show_icon(icon_id, duration_sec)


func _show_icon(icon_id: String, duration_sec: float) -> void:
	var tex: Texture2D = _textures.get(icon_id) as Texture2D
	if not tex:
		tex = _textures.get("idle") as Texture2D
	if tex:
		texture = tex
	if duration_sec <= 0:
		_stop_timers()
	_show_with_tween()
	if duration_sec > 0:
		if duration_sec >= DURATION_LONG - 0.01:
			_long_timer.start(duration_sec)
		else:
			_short_timer.start(duration_sec)
		_stop_periodic()
	else:
		_stop_periodic()


func _show_with_tween() -> void:
	_stop_tweens()
	visible = true
	scale = Vector3.ZERO
	_is_showing = true
	_show_tween = create_tween()
	_show_tween.set_ease(Tween.EASE_OUT)
	_show_tween.set_trans(Tween.TRANS_QUAD)
	_show_tween.tween_property(self, "scale", Vector3(BASE_SCALE, BASE_SCALE, BASE_SCALE), TWEEN_SHOW_DURATION)


func _hide_with_tween() -> void:
	_stop_tweens()
	if not visible:
		return
	_hide_tween = create_tween()
	_hide_tween.set_ease(Tween.EASE_IN)
	_hide_tween.set_trans(Tween.TRANS_QUAD)
	_hide_tween.tween_property(self, "scale", Vector3.ZERO, TWEEN_HIDE_DURATION)
	_hide_tween.finished.connect(_on_hide_tween_finished)


func _on_hide_tween_finished() -> void:
	_is_showing = false
	visible = false
	scale = Vector3.ZERO
	if _hide_tween and _hide_tween.is_valid():
		_hide_tween.finished.disconnect(_on_hide_tween_finished)
	# 非行走、非 cleanup/construction/sleep 时启动 4s 周期
	var phase: int = int(_current_flags.get("phase", Researcher3D.Phase.WANDER))
	if not _continuous_walking and phase != Researcher3D.Phase.CLEANUP and phase != Researcher3D.Phase.CONSTRUCTION and phase != Researcher3D.Phase.SLEEP:
		_start_periodic_if_needed()


func _stop_timers() -> void:
	if _short_timer:
		_short_timer.stop()
	if _long_timer:
		_long_timer.stop()


func _stop_periodic() -> void:
	if _periodic_timer:
		_periodic_timer.stop()


func _get_parent_researcher_id() -> int:
	var anchor: Node = get_parent()
	if not anchor:
		return -1
	var r3d: Node = anchor.get_parent()
	if r3d and "researcher_id" in r3d:
		return int(r3d.researcher_id)
	return -1


func _start_periodic_if_needed() -> void:
	if _periodic_timer.is_stopped() and not _continuous_walking:
		_periodic_timer.wait_time = PERIODIC_INTERVAL + randf_range(-PERIODIC_JITTER, PERIODIC_JITTER)
		_periodic_timer.start()


func _on_short_timer_timeout() -> void:
	if RESEARCHER_PAUSE_DEBUG:
		var pid: int = _get_parent_researcher_id()
		var flowing: bool = GameTime != null and GameTime.is_flowing
		var dbg_phase: int = int(_current_flags.get("phase", -1))
		print("[ResearcherPause] emoji_timeout type=short id=%d is_flowing=%s phase=%d ABORT=%d" % [pid, flowing, dbg_phase, 0 if flowing else 1])
	if GameTime and not GameTime.is_flowing:
		return
	_hide_with_tween()
	_start_periodic_if_needed()


func _on_long_timer_timeout() -> void:
	if RESEARCHER_PAUSE_DEBUG:
		var pid: int = _get_parent_researcher_id()
		var flowing: bool = GameTime != null and GameTime.is_flowing
		var dbg_phase: int = int(_current_flags.get("phase", -1))
		print("[ResearcherPause] emoji_timeout type=long id=%d is_flowing=%s phase=%d ABORT=%d" % [pid, flowing, dbg_phase, 0 if flowing else 1])
	if GameTime and not GameTime.is_flowing:
		return
	_hide_with_tween()
	_start_periodic_if_needed()


func _on_periodic_timer_timeout() -> void:
	if RESEARCHER_PAUSE_DEBUG:
		var pid: int = _get_parent_researcher_id()
		var flowing: bool = GameTime != null and GameTime.is_flowing
		var dbg_phase: int = int(_current_flags.get("phase", -1))
		print("[ResearcherPause] emoji_timeout type=periodic id=%d is_flowing=%s phase=%d ABORT=%d" % [pid, flowing, dbg_phase, 0 if flowing else 1])
	if GameTime and not GameTime.is_flowing:
		return
	if _is_showing or _continuous_walking:
		return
	var phase: int = int(_current_flags.get("phase", Researcher3D.Phase.WANDER))
	if phase == Researcher3D.Phase.CLEANUP or phase == Researcher3D.Phase.CONSTRUCTION or phase == Researcher3D.Phase.SLEEP:
		return
	var no_house: bool = bool(_current_flags.get("no_house", false))
	var eroded: bool = bool(_current_flags.get("eroded", false))
	var unsheltered: bool = bool(_current_flags.get("unsheltered", false))
	var healing: bool = bool(_current_flags.get("healing", false))

	# 构建特殊 list（仅包含研究员实际满足的条件）
	var special_pool: Array[String] = []
	if no_house:
		special_pool.append("no_house")
	if eroded:
		special_pool.append("erosion")
	if unsheltered:
		special_pool.append("erosion_danger")
	if healing:
		special_pool.append("heal")

	# 若有任一特殊条件，则使用特殊 list 替换 base list
	var pool: Array[String] = []
	if not special_pool.is_empty():
		pool = special_pool
	elif phase == Researcher3D.Phase.WORK:
		pool = ["idle", "confuse", "work"]
	else:
		pool = ["idle", "confuse", "talk", "good"]
	if pool.is_empty():
		pool = ["idle"]
	var pick: String = pool[randi() % pool.size()]
	_show_icon(pick, DURATION_SHORT)

class_name Researcher3D
extends Node3D

## 可复用研究员 3D 角色：纸片风格，无骨骼无动画。
## 在房间地面上进行周期性、随机、短暂移动，会转身，尽量避免与其他研究员重叠。
## 地面约束：position.y 固定为 floor_y，所有移动仅在 XZ 平面进行。
## 纸片模型特殊设计：仅朝左或朝右（rotation.y 为 0 或 PI），无斜向偏转。若以后使用真实角色模型则重新设计。

const OVERLAP_MIN_DISTANCE: float = 0.6
const MOVE_INTERVAL_MIN: float = 3.0
const MOVE_INTERVAL_MAX: float = 8.0
## 最大移动速度（米/秒），防止短距离瞬移
const MAX_MOVE_SPEED: float = 2.0
## 单次移动最短时长（秒），避免极短距离抖动
const MOVE_DURATION_MIN: float = 0.3
## 单次移动最长时长（秒），避免过长等待
const MOVE_DURATION_MAX: float = 3.0
const SAMPLE_ATTEMPTS: int = 10

var _floor_y: float = 0.5
var _x_min: float = -4.5
var _x_max: float = 4.5
var _z_min: float = -2.0
var _z_max: float = 2.0

var _idle_timer: Timer = null
var _move_tween: Tween = null
var _is_idle_active: bool = false
var _is_moving: bool = false
var _move_start_pos: Vector3 = Vector3.ZERO  ## 本次移动的起始位置，用于检测「正在靠近」
var _move_start_time: float = 0.0  ## 本次移动开始时间，用于摇摆相位
var _wobble_amplitude: float = 0.02  ## 摇摆幅度（弧度），随机
var _wobble_freq: float = 1.5  ## 摇摆频率（Hz），类似步伐

## 与 PersonnelErosionCore 研究员一一对应，用于生活周期、UI、聚焦等；-1 表示未绑定
var researcher_id: int = -1

## 生命周期阶段常量（与 apply_phase 一致）
enum Phase {
	WORK = 0,
	WANDER = 1,
	SLEEP = 2,
	CLEANUP = 3,
	CONSTRUCTION = 4,
}


func get_is_moving() -> bool:
	return _is_moving


## Phase 5: 将表情状态转发给头顶 EmojiHead 子节点。flags 见 researcher_emoji.gd set_emoji_state。
func set_emoji_state(flags: Dictionary) -> void:
	var emoji: Node = get_node_or_null("EmojiAnchor/EmojiHead")
	if emoji and emoji.has_method("set_emoji_state"):
		emoji.set_emoji_state(flags)

## game_main 引用，由 game_main 在 _setup_researchers 中设置；未设置时退化为 get_tree().current_scene
var _game_main: Node = null
## 当前所在房间 id，用于避免每帧重复传送（清理/建设/工作等阶段）
var _current_room_id: String = ""


func _ready() -> void:
	add_to_group("researcher")
	if GameTime:
		if not GameTime.flowing_changed.is_connected(_on_game_time_flowing_changed):
			GameTime.flowing_changed.connect(_on_game_time_flowing_changed)
		## 初始化时按当前状态设置，避免暂停时仍在移动
		_update_process_mode_for_flowing()


func _exit_tree() -> void:
	if GameTime and GameTime.flowing_changed.is_connected(_on_game_time_flowing_changed):
		GameTime.flowing_changed.disconnect(_on_game_time_flowing_changed)
	stop_idle()


func _on_game_time_flowing_changed(_is_flowing: bool) -> void:
	_update_process_mode_for_flowing()


## 游戏时间暂停时禁用本节点处理（Timer/Tween/_process 均暂停），恢复时启用
func _update_process_mode_for_flowing() -> void:
	if GameTime and not GameTime.is_flowing:
		process_mode = Node.PROCESS_MODE_DISABLED
	else:
		process_mode = Node.PROCESS_MODE_INHERIT


func _process(_delta: float) -> void:
	## 强制 EmojiAnchor 在世界空间始终保持竖直，避免移动/转向时 emoji 横转
	var anchor: Node3D = get_node_or_null("EmojiAnchor") as Node3D
	if anchor:
		anchor.global_rotation = Vector3.ZERO
	if _is_moving:
		if _check_blocked_by_others():
			_stop_move_early()
		else:
			## Z 轴轻微摇摆仅作用于 ModelContainer，避免 EmojiAnchor 随动导致 emoji 横转
			var elapsed: float = Time.get_ticks_msec() / 1000.0 - _move_start_time
			var model: Node3D = get_node_or_null("ModelContainer") as Node3D
			if model:
				model.rotation.z = _wobble_amplitude * sin(TAU * _wobble_freq * elapsed)


func _check_blocked_by_others() -> bool:
	## 仅在「正在靠近」他人时判定阻挡；若起始已在重叠区则允许移动（便于逃离拥挤）
	var researchers: Array = get_tree().get_nodes_in_group("researcher")
	var my_xz: Vector3 = Vector3(position.x, 0, position.z)
	var start_xz: Vector3 = Vector3(_move_start_pos.x, 0, _move_start_pos.z)
	for node in researchers:
		if node == self:
			continue
		var other: Node3D = node as Node3D
		if not other:
			continue
		var other_xz: Vector3 = Vector3(other.position.x, 0, other.position.z)
		var dist_now: float = my_xz.distance_to(other_xz)
		if dist_now >= OVERLAP_MIN_DISTANCE:
			continue
		## 当前已过近，仅当「起始时较远、正在靠近」时才阻挡
		var dist_at_start: float = start_xz.distance_to(other_xz)
		if dist_at_start < OVERLAP_MIN_DISTANCE:
			continue
		## 起始时超过阈值，现在进入重叠区 → 阻挡
		return true
	return false


func _stop_move_early() -> void:
	_is_moving = false
	var model: Node3D = get_node_or_null("ModelContainer") as Node3D
	if model:
		model.rotation.z = 0.0
	if _move_tween and _move_tween.is_valid():
		_move_tween.finished.disconnect(_on_move_tween_finished)
		_move_tween.kill()
	_move_tween = null
	_schedule_next_move()


func set_researcher_id(id: int) -> void:
	researcher_id = id


func set_game_main(gm: Node) -> void:
	_game_main = gm


func _get_game_main() -> Node:
	if _game_main:
		return _game_main
	return get_tree().current_scene


## 传送到指定房间：从 game_main 取房间节点与 RoomInfo3D.room_volume，按与 _setup_researchers 相同公式计算边界，
## 在边界内随机一点（房间本地坐标）， reparent 到该房间的 ResearchersContainer 并设置本地 position，再 set_room_bounds。
func teleport_to_room_id(room_id: String) -> void:
	var gm: Node = _get_game_main()
	if not gm:
		return
	var archives: Node3D = gm.get_node_or_null("ArchivesBase0") as Node3D
	if not archives:
		return
	var room_node: Node3D = gm.call("_find_room_node_in_archives", archives, room_id) as Node3D
	if not room_node:
		return
	var room_info_3d: RoomInfo3D = room_node.get_node_or_null("RoomInfo") as RoomInfo3D
	if not room_info_3d:
		return
	var vol: Vector3 = room_info_3d.room_volume
	const GRID_CELL: float = 0.5
	var hx: float = vol.x * GRID_CELL * 0.5
	var hz: float = vol.z * GRID_CELL * 0.5
	var inset: float = GRID_CELL
	var x_min: float = -hx + inset
	var x_max: float = hx - inset
	var z_min: float = -hz + inset
	var z_max: float = hz - inset
	const FLOOR_Y: float = 0.5
	var local_pos: Vector3 = Vector3(randf_range(x_min, x_max), FLOOR_Y, randf_range(z_min, z_max))
	var container: Node = room_node.get_node_or_null("ResearchersContainer")
	if not container:
		container = Node3D.new()
		container.name = "ResearchersContainer"
		room_node.add_child(container)
	var old_parent: Node = get_parent()
	if old_parent != container:
		old_parent.remove_child(self)
		container.add_child(self)
	position = local_pos
	set_room_bounds(x_min, x_max, z_min, z_max, FLOOR_Y)


## 应用生命周期阶段：仅当目标房间与当前不同时才传送，避免每帧重复传送导致瞬移；再根据 phase 控制 idle（SLEEP 停止，其余开始）。
func apply_phase(phase: int, target_room_id: String, _options: Dictionary = {}) -> void:
	if target_room_id.is_empty() == false and target_room_id != _current_room_id:
		teleport_to_room_id(target_room_id)
		_current_room_id = target_room_id
	elif target_room_id.is_empty():
		_current_room_id = ""
	if phase == Phase.SLEEP:
		stop_idle()
	else:
		start_idle()


## 设置房间内可移动边界（房间本地坐标，XZ 范围，Y 由 floor_y 固定）
func set_room_bounds(x_min: float, x_max: float, z_min: float, z_max: float, floor_y: float = 0.5) -> void:
	_x_min = minf(x_min, x_max)
	_x_max = maxf(x_min, x_max)
	_z_min = minf(z_min, z_max)
	_z_max = maxf(z_min, z_max)
	_floor_y = floor_y


## 开始待机移动
func start_idle() -> void:
	if _is_idle_active:
		return
	_is_idle_active = true
	if _idle_timer == null:
		_idle_timer = Timer.new()
		_idle_timer.one_shot = true
		_idle_timer.timeout.connect(_on_idle_timer_timeout)
		add_child(_idle_timer)
	_schedule_next_move()


## 停止待机移动
func stop_idle() -> void:
	_is_idle_active = false
	_is_moving = false
	if _idle_timer:
		_idle_timer.stop()
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
		_move_tween = null


func _schedule_next_move() -> void:
	if not _is_idle_active or not _idle_timer:
		return
	_idle_timer.wait_time = randf_range(MOVE_INTERVAL_MIN, MOVE_INTERVAL_MAX)
	_idle_timer.start()


func _on_idle_timer_timeout() -> void:
	if not _is_idle_active:
		return
	_try_move_to_random_target()


func _try_move_to_random_target() -> void:
	var target: Vector3 = _pick_valid_target()
	if target == Vector3.INF:
		_schedule_next_move()
		return
	var dist_xz: float = Vector3(position.x, 0, position.z).distance_to(Vector3(target.x, 0, target.z))
	var duration: float = clampf(dist_xz / MAX_MOVE_SPEED, MOVE_DURATION_MIN, MOVE_DURATION_MAX)
	_move_to(target, duration)


func _pick_valid_target() -> Vector3:
	for _i in SAMPLE_ATTEMPTS:
		var x: float = randf_range(_x_min, _x_max)
		var z: float = randf_range(_z_min, _z_max)
		var candidate: Vector3 = Vector3(x, _floor_y, z)
		if _is_target_valid(candidate):
			return candidate
	return Vector3.INF


func _is_target_valid(target: Vector3) -> bool:
	var researchers: Array = get_tree().get_nodes_in_group("researcher")
	for node in researchers:
		if node == self:
			continue
		var other: Node3D = node as Node3D
		if not other:
			continue
		var dist: float = Vector3(target.x, 0, target.z).distance_to(Vector3(other.position.x, 0, other.position.z))
		if dist < OVERLAP_MIN_DISTANCE:
			return false
	return true


func _move_to(target: Vector3, duration: float) -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_is_moving = true
	_move_start_pos = position
	_move_start_time = Time.get_ticks_msec() / 1000.0
	_wobble_amplitude = deg_to_rad(randf_range(1.0, 3.0))
	_wobble_freq = randf_range(1.0, 2.5)
	_move_tween = create_tween()
	_move_tween.set_ease(Tween.EASE_IN_OUT)
	_move_tween.set_trans(Tween.TRANS_QUAD)
	var start_pos: Vector3 = position
	var end_pos: Vector3 = Vector3(target.x, _floor_y, target.z)
	_move_tween.tween_property(self, "position", end_pos, duration)
	_move_tween.finished.connect(_on_move_tween_finished)
	_update_facing(start_pos, end_pos)


func _on_move_tween_finished() -> void:
	_is_moving = false
	var model: Node3D = get_node_or_null("ModelContainer") as Node3D
	if model:
		model.rotation.z = 0.0
	if _move_tween and _move_tween.is_valid():
		_move_tween.finished.disconnect(_on_move_tween_finished)
	_move_tween = null
	_schedule_next_move()


## 纸片模型：仅朝左或朝右，根据 X 方向决定，斜向移动时不偏转
func _update_facing(from: Vector3, to: Vector3) -> void:
	var dx: float = to.x - from.x
	if absf(dx) < 0.001:
		return
	rotation.y = 0.0 if dx >= 0 else PI

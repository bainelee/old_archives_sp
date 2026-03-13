class_name ResearcherLifecycle
extends Node

## Phase 3: 研究员生命周期协调器
## 按游戏时间驱动每位 Researcher3D：工作时间 8–16、闲逛 16–20、回家 20–22、睡觉 22–6、前往工作 6–8。
## 尊重无工作/无住房：无工作仅闲逛；无住房则原地睡觉；分配工作则立即传送到工作房间。

const HOUR_WORK_START: int = 8
const HOUR_WORK_END: int = 16
const HOUR_WANDER_END: int = 20
const HOUR_SLEEP_START: int = 22
const HOUR_SLEEP_END: int = 6
const HOUR_MOVE_TO_WORK_END: int = 8

## 内部阶段（用于逻辑分支，再映射到 Researcher3D.Phase）
enum LifePhase {
	WORK,
	WANDER_ARCHIVES,
	RETURN_HOME,
	WAIT_AT_HOME,
	SLEEP,
	SLEEP_IN_PLACE,
	MOVE_TO_WORK,
	WANDER_NO_WORK,
	CLEANUP,
	CONSTRUCTION,
}

var _game_main: Node2D = null
## Phase 5: 上一帧是否有住房/是否被侵蚀，用于 got_housing、recovered_erosion 检测
var _last_had_housing: Dictionary = {}
var _last_was_eroded: Dictionary = {}


func _ready() -> void:
	if GameTime:
		GameTime.time_updated.connect(_on_time_updated)
	_on_time_updated()


func _exit_tree() -> void:
	if GameTime and GameTime.time_updated.is_connected(_on_time_updated):
		GameTime.time_updated.disconnect(_on_time_updated)


func set_game_main(gm: Node2D) -> void:
	_game_main = gm


func _get_game_main() -> Node2D:
	return _game_main


func _on_time_updated() -> void:
	## 防御性守卫：暂停时不应推进研究员生命周期，防止 time_updated 从其他路径误触发时仍执行
	if not GameTime or not GameTime.is_flowing:
		return
	var gm: Node2D = _get_game_main()
	if not gm:
		return
	_update_all_researchers(gm)


func _update_all_researchers(game_main: Node2D) -> void:
	var personnel_count: int = 0
	if PersonnelErosionCore:
		var personnel: Dictionary = PersonnelErosionCore.get_personnel()
		personnel_count = int(personnel.get("researcher", 0))
	if personnel_count <= 0:
		return

	var researchers: Array = PersonnelErosionCore.get_researchers() if PersonnelErosionCore else []
	var hour: int = GameTime.get_hour() if GameTime else 0
	var _wanderable_room_ids: Array[String] = _build_wanderable_room_list(game_main)

	for id in personnel_count:
		var researcher_dict: Dictionary = researchers[id] if id < researchers.size() else {}
		var enriched: Dictionary = GameMainShelterHelper.enrich_researcher_with_rooms(game_main, researcher_dict)
		var work_room_id: String = str(enriched.get("work_room_id", ""))
		var housing_room_id: String = str(enriched.get("housing_room_id", ""))
		var has_work: bool = not work_room_id.is_empty()
		var has_housing: bool = not housing_room_id.is_empty()

		var phase: LifePhase = LifePhase.WANDER_NO_WORK
		var target_room_id: String = ""

		# 1) 是否在清理中
		var cleanup_rooms: Dictionary = game_main.get("_cleanup_rooms_in_progress")
		for room_idx in cleanup_rooms:
			var data: Dictionary = cleanup_rooms[room_idx]
			var ids: Array = data.get("researcher_ids", [])
			if id in ids:
				var rooms: Array = game_main.get("_rooms")
				if room_idx >= 0 and room_idx < rooms.size():
					var room: RoomInfo = rooms[room_idx] as RoomInfo
					if room:
						target_room_id = room.id if room.id else room.json_room_id
				phase = LifePhase.CLEANUP
				break

		# 2) 是否在建设中（仅当未命中清理时）
		if phase != LifePhase.CLEANUP:
			var construction_rooms: Dictionary = game_main.get("_construction_rooms_in_progress")
			for room_idx in construction_rooms:
				var data: Dictionary = construction_rooms[room_idx]
				var ids: Array = data.get("researcher_ids", [])
				if id in ids:
					var rooms: Array = game_main.get("_rooms")
					if room_idx >= 0 and room_idx < rooms.size():
						var room: RoomInfo = rooms[room_idx] as RoomInfo
						if room:
							target_room_id = room.id if room.id else room.json_room_id
					phase = LifePhase.CONSTRUCTION
					break

		# 3) 常规作息：已在上方用 enrich 得到 work_room_id / housing_room_id
		if phase == LifePhase.WANDER_NO_WORK:
			# 特殊：无住房且 hour >= 22 时若 enrich 本次给出 housing_room_id（如刚建好宿舍），传送到住房并睡觉（下面 22–6 分支会因 has_housing 成立而执行）
			if hour >= HOUR_WORK_START and hour < HOUR_WORK_END:
				if has_work:
					phase = LifePhase.WORK
					target_room_id = work_room_id
				else:
					phase = LifePhase.WANDER_NO_WORK
					target_room_id = ""
			elif hour >= HOUR_WORK_END and hour < HOUR_WANDER_END:
				phase = LifePhase.WANDER_ARCHIVES
				target_room_id = ""
			elif hour >= HOUR_WANDER_END and hour < HOUR_SLEEP_START:
				if has_housing:
					phase = LifePhase.RETURN_HOME
					target_room_id = housing_room_id
				else:
					phase = LifePhase.WANDER_ARCHIVES
					target_room_id = ""
			elif hour >= HOUR_SLEEP_START or hour < HOUR_SLEEP_END:
				if has_housing:
					phase = LifePhase.SLEEP
					target_room_id = housing_room_id
				else:
					phase = LifePhase.SLEEP_IN_PLACE
					target_room_id = ""
			elif hour >= HOUR_SLEEP_END and hour < HOUR_MOVE_TO_WORK_END:
				if has_work:
					phase = LifePhase.MOVE_TO_WORK
					target_room_id = work_room_id
				else:
					phase = LifePhase.WANDER_NO_WORK
					target_room_id = ""

		# 4) 映射到 Researcher3D.Phase 并调用 apply_phase
		var r3d: Node3D = game_main.get_researcher_3d_by_id(id)
		if not r3d or not r3d.has_method("apply_phase"):
			continue

		var api_phase: int = Researcher3D.Phase.WANDER
		var api_target: String = target_room_id

		match phase:
			LifePhase.CLEANUP:
				api_phase = Researcher3D.Phase.CLEANUP
				api_target = target_room_id
			LifePhase.CONSTRUCTION:
				api_phase = Researcher3D.Phase.CONSTRUCTION
				api_target = target_room_id
			LifePhase.WORK:
				api_phase = Researcher3D.Phase.WORK
				api_target = target_room_id
			LifePhase.WANDER_ARCHIVES, LifePhase.WANDER_NO_WORK:
				api_phase = Researcher3D.Phase.WANDER
				api_target = ""
			LifePhase.RETURN_HOME, LifePhase.MOVE_TO_WORK:
				api_phase = Researcher3D.Phase.WANDER
				api_target = target_room_id
			LifePhase.WAIT_AT_HOME:
				api_phase = Researcher3D.Phase.WANDER
				api_target = target_room_id
			LifePhase.SLEEP, LifePhase.SLEEP_IN_PLACE:
				api_phase = Researcher3D.Phase.SLEEP
				api_target = target_room_id if phase == LifePhase.SLEEP else ""

		r3d.apply_phase(api_phase, api_target, {})

		# Phase 5: 表情状态（is_walking = 移动中或处于 RETURN_HOME/MOVE_TO_WORK）
		var is_walking: bool = (r3d.has_method("get_is_moving") and r3d.get_is_moving()) or phase == LifePhase.RETURN_HOME or phase == LifePhase.MOVE_TO_WORK
		## no_house：emoji 用「无住房」= 只要无住房即显示，不限定有工作（侵蚀逻辑的 has_no_housing 仍为「有工作但无住房」）
		var no_house: bool = not has_housing
		var eroded: bool = bool(researcher_dict.get("is_eroded", false))
		var healing: bool = has_housing and eroded
		var got_housing: bool = has_housing and not _last_had_housing.get(id, false)
		var recovered_erosion: bool = not eroded and _last_was_eroded.get(id, false)
		_last_had_housing[id] = has_housing
		_last_was_eroded[id] = eroded
		var shelter_level: int = GameMainShelterHelper.get_shelter_level_for_researcher(game_main, enriched)
		var unsheltered: bool = (shelter_level < 2)
		var emoji_flags: Dictionary = {
			"is_walking": is_walking,
			"phase": api_phase,
			"no_house": no_house,
			"eroded": eroded,
			"healing": healing,
			"unsheltered": unsheltered,
			"got_housing": got_housing,
			"recovered_erosion": recovered_erosion,
		}
		if r3d.has_method("set_emoji_state"):
			r3d.set_emoji_state(emoji_flags)


## 获取指定研究员当前生命周期阶段（供 UI 详情等使用），返回 LifePhase 枚举值
static func get_current_life_phase(game_main: Node2D, researcher_id: int) -> int:
	var personnel_count: int = 0
	if PersonnelErosionCore:
		var personnel: Dictionary = PersonnelErosionCore.get_personnel()
		personnel_count = int(personnel.get("researcher", 0))
	if researcher_id < 0 or researcher_id >= personnel_count:
		return LifePhase.WANDER_NO_WORK

	var researchers: Array = PersonnelErosionCore.get_researchers() if PersonnelErosionCore else []
	var hour: int = GameTime.get_hour() if GameTime else 0
	var id: int = researcher_id

	var cleanup_rooms: Dictionary = game_main.get("_cleanup_rooms_in_progress")
	for room_idx in cleanup_rooms:
		var data: Dictionary = cleanup_rooms[room_idx]
		var ids: Array = data.get("researcher_ids", [])
		if id in ids:
			return LifePhase.CLEANUP

	var construction_rooms: Dictionary = game_main.get("_construction_rooms_in_progress")
	for room_idx in construction_rooms:
		var data: Dictionary = construction_rooms[room_idx]
		var ids: Array = data.get("researcher_ids", [])
		if id in ids:
			return LifePhase.CONSTRUCTION

	var researcher_dict: Dictionary = researchers[id] if id < researchers.size() else {}
	var enriched: Dictionary = GameMainShelterHelper.enrich_researcher_with_rooms(game_main, researcher_dict)
	var work_room_id: String = str(enriched.get("work_room_id", ""))
	var housing_room_id: String = str(enriched.get("housing_room_id", ""))
	var has_work: bool = not work_room_id.is_empty()
	var has_housing: bool = not housing_room_id.is_empty()

	if hour >= HOUR_WORK_START and hour < HOUR_WORK_END:
		if has_work:
			return LifePhase.WORK
		return LifePhase.WANDER_NO_WORK
	elif hour >= HOUR_WORK_END and hour < HOUR_WANDER_END:
		return LifePhase.WANDER_ARCHIVES
	elif hour >= HOUR_WANDER_END and hour < HOUR_SLEEP_START:
		if has_housing:
			return LifePhase.RETURN_HOME
		return LifePhase.WANDER_ARCHIVES
	elif hour >= HOUR_SLEEP_START or hour < HOUR_SLEEP_END:
		if has_housing:
			return LifePhase.SLEEP
		return LifePhase.SLEEP_IN_PLACE
	elif hour >= HOUR_SLEEP_END and hour < HOUR_MOVE_TO_WORK_END:
		if has_work:
			return LifePhase.MOVE_TO_WORK
		return LifePhase.WANDER_NO_WORK
	return LifePhase.WANDER_NO_WORK


## 可闲逛房间：room_00（核心）+ 所有已解锁且已清理的房间
func _build_wanderable_room_list(game_main: Node2D) -> Array[String]:
	var out: Array[String] = ["room_00"]
	var rooms: Array = game_main.get("_rooms")
	for room in rooms:
		var r: RoomInfo = room as RoomInfo
		if not r:
			continue
		if not r.unlocked or r.clean_status != RoomInfo.CleanStatus.CLEANED:
			continue
		var rid: String = r.id if r.id else r.json_room_id
		if rid.is_empty():
			continue
		if rid != "room_00":
			out.append(rid)
	return out

extends PanelContainer
## 探索地图 — 右侧「地区信息」面板：名称、状态、耗时、调查员占位、开始探索。

signal explore_requested(region_id: String)

const _Codec := preload("res://scripts/game/exploration/exploration_state_codec.gd")
const _Rules := preload("res://scripts/game/exploration/exploration_rules.gd")

@onready var _title: Label = get_node_or_null("Margin/VBox/TitleLabel") as Label
@onready var _status: Label = get_node_or_null("Margin/VBox/StatusLabel") as Label
@onready var _duration: Label = get_node_or_null("Margin/VBox/DurationLabel") as Label
@onready var _invest: Label = get_node_or_null("Margin/VBox/InvestLabel") as Label
@onready var _reward: Label = get_node_or_null("Margin/VBox/RewardLabel") as Label
@onready var _btn_explore: Button = get_node_or_null("Margin/VBox/BtnExplore") as Button

var _region_id: String = ""
var _exploration_service: Variant = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _btn_explore:
		_btn_explore.pressed.connect(func() -> void:
			if not _region_id.is_empty():
				explore_requested.emit(_region_id)
		)


func bind_exploration_service(service: Variant) -> void:
	_exploration_service = service


func hide_panel() -> void:
	visible = false
	_region_id = ""


## 根据当前服务状态刷新右侧信息；若地区未解锁则不调用或在外部先判断。
func present_region(region_id: String) -> void:
	_region_id = region_id
	if _exploration_service == null:
		return
	_exploration_service.call("ensure_first_open_initialized")
	var config: Dictionary = _exploration_service.call("get_config_readonly")
	var state: Dictionary = _exploration_service.call("get_runtime_state_readonly")
	var name_zh: String = _display_name_for(config, region_id)
	if _title:
		_title.text = name_zh
	var unlocked: Variant = state.get(_Codec.KEY_UNLOCKED_REGION_IDS, [])
	var explored: Variant = state.get(_Codec.KEY_EXPLORED_REGION_IDS, [])
	var exploring: Variant = state.get(_Codec.KEY_EXPLORING_BY_REGION, {})
	var is_unlocked: bool = unlocked is Array and (unlocked as Array).has(region_id)
	var is_explored: bool = explored is Array and (explored as Array).has(region_id)
	var is_exploring: bool = exploring is Dictionary and (exploring as Dictionary).has(region_id)
	var hours: float = _Rules.get_region_explore_game_hours(config, region_id)
	if hours <= 0.0:
		hours = float(config.get("default_explore_game_hours", 24.0))
	var need_inv: int = int(config.get("explore_investigators_per_region", 1))
	var pool: int = int(state.get(_Codec.KEY_DEBUG_INVESTIGATOR_POOL, 0))
	if _duration:
		_duration.text = "预计探索时间：%.0f 游戏小时" % hours
	if _invest:
		_invest.text = "需要调查员：%d（当前可用：%d）" % [need_inv, pool]
	if _reward:
		_reward.text = "可能获得：待配置"
	if _status:
		if not is_unlocked:
			_status.text = "状态：未解锁"
		elif is_exploring:
			var left: float = 0.0
			if exploring is Dictionary:
				var ent: Variant = (exploring as Dictionary).get(region_id)
				if ent is Dictionary:
					left = float((ent as Dictionary).get("hours_remaining", 0.0))
			_status.text = "状态：探索中（剩余约 %.1f 游戏小时）" % maxf(left, 0.0)
		elif is_explored:
			_status.text = "状态：已探索"
		else:
			_status.text = "状态：已解锁，可开始探索"
	if _btn_explore:
		_btn_explore.disabled = (not is_unlocked) or is_explored or is_exploring or pool < need_inv
		if is_exploring:
			_btn_explore.text = "探索中…"
		elif is_explored:
			_btn_explore.text = "已完成"
		else:
			_btn_explore.text = "开始探索"
	visible = true


static func _display_name_for(config: Dictionary, region_id: String) -> String:
	var catalog: Variant = config.get("regions_placeholder", [])
	if catalog is Array:
		for entry in catalog as Array:
			if entry is Dictionary and str((entry as Dictionary).get("id", "")) == region_id:
				return str((entry as Dictionary).get("display_name_zh", region_id))
	return region_id

extends CanvasLayer
## 主 UI 场景 - 顶层资源条
## 显示：资源-因子、资源-货币、人员 三类数据
## 可挂载至任意主场景，数据通过属性或 Autoload 注入

signal cleanup_button_pressed

@onready var _label_cognition: Label = $TopBar/Content/HBox/Factors/Cognition/Value
@onready var _label_computation: Label = $TopBar/Content/HBox/Factors/Computation/Value
@onready var _label_will: Label = $TopBar/Content/HBox/Factors/Will/Value
@onready var _label_permission: Label = $TopBar/Content/HBox/Factors/Permission/Value
@onready var _label_info: Label = $TopBar/Content/HBox/Currency/Info/Value
@onready var _label_truth: Label = $TopBar/Content/HBox/Currency/Truth/Value
@onready var _label_researcher: Label = $TopBar/Content/HBox/Personnel/Researcher/Value
@onready var _label_eroded: Label = $TopBar/Content/HBox/Personnel/Eroded/Value
@onready var _label_investigator: Label = $TopBar/Content/HBox/Personnel/Investigator/Value

## 资源-因子
var cognition_amount: int = 0:
	set(v):
		cognition_amount = v
		_update_label(_label_cognition, v)
var computation_amount: int = 0:
	set(v):
		computation_amount = v
		_update_label(_label_computation, v)
var will_amount: int = 0:
	set(v):
		will_amount = v
		_update_label(_label_will, v)
var permission_amount: int = 0:
	set(v):
		permission_amount = v
		_update_label(_label_permission, v)

## 资源-货币
var info_amount: int = 0:
	set(v):
		info_amount = v
		_update_label(_label_info, v)
var truth_amount: int = 0:
	set(v):
		truth_amount = v
		_update_label(_label_truth, v)

## 人员（researcher_count=总数，eroded_count=被侵蚀数；显示为 未侵蚀/总数）
var researcher_count: int = 0:
	set(v):
		researcher_count = v
		_update_researcher_display()
var eroded_count: int = 0:
	set(v):
		eroded_count = v
		_update_researcher_display()
		_update_label(_label_eroded, v)
var investigator_count: int = 0:
	set(v):
		investigator_count = v
		_update_label(_label_investigator, v)


func _ready() -> void:
	_refresh_all()
	var btn: Button = get_node_or_null("BottomRightBar/BtnCleanup")
	if btn:
		btn.pressed.connect(_on_cleanup_button_pressed)


func _on_cleanup_button_pressed() -> void:
	cleanup_button_pressed.emit()


func _update_label(lbl: Label, value: int) -> void:
	if lbl:
		lbl.text = str(value)


func _update_researcher_display() -> void:
	if _label_researcher:
		var healthy: int = maxi(0, researcher_count - eroded_count)
		_label_researcher.text = "%d/%d" % [healthy, researcher_count]


func _refresh_all() -> void:
	_update_label(_label_cognition, cognition_amount)
	_update_label(_label_computation, computation_amount)
	_update_label(_label_will, will_amount)
	_update_label(_label_permission, permission_amount)
	_update_label(_label_info, info_amount)
	_update_label(_label_truth, truth_amount)
	_update_researcher_display()
	_update_label(_label_eroded, eroded_count)
	_update_label(_label_investigator, investigator_count)


## 便捷：一次性更新所有数据（供游戏状态层调用）
func set_resources(factors: Dictionary, currency: Dictionary, personnel: Dictionary) -> void:
	cognition_amount = factors.get("cognition", 0)
	computation_amount = factors.get("computation", 0)
	will_amount = factors.get("willpower", 0)
	permission_amount = factors.get("permission", 0)
	info_amount = currency.get("info", 0)
	truth_amount = currency.get("truth", 0)
	researcher_count = personnel.get("researcher", 0)
	eroded_count = personnel.get("eroded", 0)
	investigator_count = personnel.get("investigator", 0)


## 获取当前资源数据（供存档保存调用）
func get_resources() -> Dictionary:
	return {
		"factors": {
			"cognition": cognition_amount,
			"computation": computation_amount,
			"willpower": will_amount,
			"permission": permission_amount,
		},
		"currency": {"info": info_amount, "truth": truth_amount},
		"personnel": {
			"researcher": researcher_count,
			"labor": 0,
			"eroded": eroded_count,
			"investigator": investigator_count,
		},
	}

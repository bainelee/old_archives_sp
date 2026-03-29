extends Node

## 自动化测试驱动：从 user://test_driver/<session>/command.json 读指令，写 response.json。
## 命令实现见 test_driver_actions.gd；解析与工具见 test_driver_context.gd。

const DRIVER_ROOT_DIR := "user://test_driver"
const _TestDriverContextScript := preload("res://scripts/test/test_driver_context.gd")
const _TestDriverActionsScript := preload("res://scripts/test/test_driver_actions.gd")

var _enabled: bool = false
var _busy: bool = false
var _session: String = "default"
var _cmd_dir: String = ""
var _cmd_file: String = ""
var _resp_file: String = ""
var _step_pre_delay_ms: int = 100
## 资源探针（供 TestDriverContext.build_resource_ledger 通过 get/set 读写；无下划线以便跨脚本访问）
var resource_probe_initialized: bool = false
var resource_probe_baseline: Dictionary = {}
var resource_probe_last: Dictionary = {}

var _ctx: RefCounted
var _actions: RefCounted


func test_driver_cmd_dir() -> String:
	## 供 TestDriverActions 读取会话目录
	return _cmd_dir


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var boot_ctx = _TestDriverContextScript.new(self)
	var session_arg: String = boot_ctx.get_user_arg_value("--test-driver-session", "")
	_enabled = boot_ctx.has_flag("--test-driver") or not session_arg.is_empty()
	if not _enabled:
		return
	_ctx = boot_ctx
	_session = _ctx.sanitize_session(session_arg if not session_arg.is_empty() else "default")
	_cmd_dir = "%s/%s" % [DRIVER_ROOT_DIR, _session]
	_cmd_file = "%s/command.json" % _cmd_dir
	_resp_file = "%s/response.json" % _cmd_dir
	_actions = _TestDriverActionsScript.new(self, _ctx)
	_ensure_driver_dir()
	_ctx.write_json(_resp_file, {"status": "ready", "pid": OS.get_process_id(), "session": _session})


func _process(_delta: float) -> void:
	if not _enabled or _busy:
		return
	if not FileAccess.file_exists(_cmd_file):
		return
	_busy = true
	var cmd: Dictionary = _ctx.read_json(_cmd_file)
	DirAccess.remove_absolute(_cmd_file)
	var result: Dictionary = await _execute_command(cmd)
	_ctx.write_json(_resp_file, result)
	_busy = false


func _execute_command(cmd: Dictionary) -> Dictionary:
	var seq: int = int(cmd.get("seq", -1))
	var action: String = str(cmd.get("action", ""))
	var params: Dictionary = cmd.get("params", {})
	var started_ms: int = Time.get_ticks_msec()
	var out: Dictionary = {
		"seq": seq,
		"action": action,
		"status": "ok",
		"data": {},
		"elapsed_ms": 0,
	}
	await _actions.before_step(action, params, _step_pre_delay_ms)
	await _actions.dispatch(action, params, out)

	out["elapsed_ms"] = Time.get_ticks_msec() - started_ms
	return out


func _ensure_driver_dir() -> void:
	_ctx.ensure_dir(_cmd_dir)
	DirAccess.remove_absolute(_cmd_file)
	DirAccess.remove_absolute(_resp_file)

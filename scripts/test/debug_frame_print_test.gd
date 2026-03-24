extends Node

## 自动化测试 [DebugFramePrint]。运行方式：[br]
## [code]Godot --path <项目根> res://scenes/test/debug_frame_print_test.tscn[/code][br]
## 或通过编辑器打开该场景后运行当前场景。[br]
## 成功：stdout 打印 [code][DebugFramePrintTest] PASS[/code]；失败：[code]push_error[/code] 并以非 0 退出码退出（若引擎支持）。

const _LOG_PATH := "user://logs/debug_frame_overlay.txt"
## 须与 [code]debug_frame_print.gd[/code] 中 [member DebugFramePrint.MARKER] 一致。
const _MARKER := "##F>"

var _tick: int = 0
var _finished: bool = false
var _dfp: Node


func _ready() -> void:
	_dfp = get_tree().root.get_node_or_null("DebugFramePrint")
	if _dfp == null:
		push_error("[DebugFramePrintTest] FAIL: 未找到 Autoload DebugFramePrint")
		get_tree().quit(1)
		return
	_dfp.set("enabled", true)
	_dfp.set("write_file", true)
	_dfp.set("emit_to_debug_panel", false)
	_dfp.set("show_floating_overlay", false)


func _process(_delta: float) -> void:
	if _finished:
		return
	# 本节点默认 process_priority=0，早于 DebugFramePrint(100000)，同一帧内先登记再被其刷新。
	_tick += 1
	if _tick == 1:
		_frame1()
	elif _tick == 2:
		_assert_phase1_file()
	elif _tick == 3:
		pass
	elif _tick == 4:
		_assert_empty_file()
		_finished = true
		print("[DebugFramePrintTest] PASS")
		get_tree().quit(0)


func _frame1() -> void:
	_dfp.call("line", "dup", "first")
	_dfp.call("line", "dup", "second")
	_dfp.call("line", "other", "keep")
	if not _dfp.call("capture_if_marked", _MARKER + "|mk|marked-ok"):
		_fail("capture_if_marked 应对带 MARKER 与 |键| 的字符串返回 true")
		return
	if _dfp.call("capture_if_marked", "plain no marker"):
		_fail("capture_if_marked 对无 MARKER 的字符串应返回 false")
		return
	if not _dfp.call("capture_if_marked", _MARKER + "bare|only-pipe-after-key"):
		_fail("capture_if_marked 应对 ##F>key|text 形式返回 true")
		return


func _assert_phase1_file() -> void:
	var text := FileAccess.get_file_as_string(_LOG_PATH)
	if not text.contains("dup: second"):
		_fail("同帧覆盖失败，期望 dup: second，实际:\n%s" % text)
		return
	if text.contains("dup: first"):
		_fail("不应保留 dup: first，实际:\n%s" % text)
		return
	if not text.contains("other: keep"):
		_fail("缺少 other: keep，实际:\n%s" % text)
		return
	if not text.contains("mk: marked-ok"):
		_fail("MARKER+|键| 解析失败，缺少 mk: marked-ok，实际:\n%s" % text)
		return
	if not text.contains("bare: only-pipe-after-key"):
		_fail("缺少 bare: only-pipe-after-key，实际:\n%s" % text)
		return


func _assert_empty_file() -> void:
	var text := FileAccess.get_file_as_string(_LOG_PATH).strip_edges()
	if text != "":
		_fail("静默一帧后文件应被清空，实际: %s" % text.c_escape())
		return


func _fail(msg: String) -> void:
	push_error("[DebugFramePrintTest] FAIL: %s" % msg)
	get_tree().quit(1)

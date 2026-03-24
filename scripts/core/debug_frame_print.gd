extends Node

## 逐帧替换式调试输出（类似 UE 蓝图 debug 抑制）：同一帧内多次 [method line] 同一 [param key] 只保留最后一次；默认推送到 [code]UIMain/DebugInfoPanel[/code] 内滚动区，并写入 [code]user://logs/debug_frame_overlay.txt[/code]。[br]
## **默认不会**出现在编辑器底部「输出」面板；若要在该面板看到内容，请将 [member mirror_to_output] 设为 [code]true[/code]。
##
## 用法：[code]DebugFramePrint.line("cam", "pos=%s" % p)[/code]
## 字符串打标：[member MARKER] 与可选 [code]|键|[/code]，见 [method capture_if_marked]。

signal debug_display_text_changed(display_text: String)

const MARKER := "##F>"

const _LOG_REL := "user://logs/debug_frame_overlay.txt"
## 须高于任意游戏 UI CanvasLayer（如暂停 20、详情 12），否则会被挡住。
const _OVERLAY_LAYER := 10000

## 关闭后 [method line] 与刷新均不生效。
var enabled: bool = true
## 为 true 时向 [signal debug_display_text_changed] 推送聚合文本（供 Debug 面板滚动框）；默认开启。
var emit_to_debug_panel: bool = true
## 为 true 时在视口左上角绘制浮动层（与 Debug 面板独立）；默认关闭，以免重复。
var show_floating_overlay: bool = false
## 为 true 时在展示文本中附带状态行（帧号、本帧行数）；**不写入**日志文件。
var show_overlay_status: bool = true
## 每帧覆盖写入 [code]user://[/code] 下日志文件，便于 Agent 读取。
var write_file: bool = true
## 为 true 时，本帧聚合块非空则 [code]print[/code] 一次（多行），便于在编辑器「输出」面板查看。
var mirror_to_output: bool = false

var _lines: Dictionary = {}
var _overlay_root: CanvasLayer
var _overlay_bg: ColorRect
var _overlay_label: Label


func _ready() -> void:
	process_priority = 100000


func _process(_delta: float) -> void:
	_flush_frame()


## 登记本帧一行；[param key] 在同一帧内重复会覆盖为最新文本。
func line(key: String, text: Variant) -> void:
	if not enabled:
		return
	_lines[str(key)] = str(text)


## 若 [param message] 以 [member MARKER] 开头，则解析可选的 [code]|键|[/code] 并交给 [method line]，返回 [code]true[/code]（表示已消费，无需再 [code]print[/code]）。
func capture_if_marked(message: String) -> bool:
	if not message.begins_with(MARKER):
		return false
	var rest: String = message.substr(MARKER.length())
	if rest.begins_with("|"):
		rest = rest.substr(1)
	var key: String = "default"
	var bar_idx: int = rest.find("|")
	if bar_idx >= 0:
		key = rest.substr(0, bar_idx).strip_edges()
		if key.is_empty():
			key = "default"
		rest = rest.substr(bar_idx + 1)
	line(key, rest)
	return true


func _flush_frame() -> void:
	var block: String = ""
	if not _lines.is_empty():
		var parts: PackedStringArray = []
		for k in _lines.keys():
			parts.append("%s: %s" % [str(k), _lines[k]])
		block = "\n".join(parts)
		_lines.clear()

	if not enabled:
		return

	var display_text: String = block
	if show_overlay_status and not Engine.is_editor_hint():
		var user_key_count: int = 0
		if not block.is_empty():
			user_key_count = block.count("\n") + 1
		var status: String = "[DebugFramePrint] 运行中 | 帧=%d | 本帧行数=%d" % [Engine.get_process_frames(), user_key_count]
		if user_key_count == 0:
			status += "\n（无 line 数据：例：须打开带庇护条调试的房间详情）"
		if display_text.is_empty():
			display_text = status
		else:
			display_text = display_text + "\n---\n" + status

	if emit_to_debug_panel and not Engine.is_editor_hint():
		debug_display_text_changed.emit(display_text)

	if show_floating_overlay and not Engine.is_editor_hint():
		var need_overlay: bool = show_overlay_status or not block.is_empty() or _overlay_label != null
		if need_overlay:
			_ensure_overlay()
		if _overlay_label != null:
			_overlay_label.text = display_text
			if _overlay_bg != null:
				_overlay_bg.visible = not display_text.is_empty()

	if write_file:
		var fa: FileAccess = FileAccess.open(_LOG_REL, FileAccess.WRITE)
		if fa:
			fa.store_string(block)
			fa.close()

	if mirror_to_output and not block.is_empty():
		print("[DebugFramePrint]\n%s" % block)


func _ensure_overlay() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var root: Window = tree.root
	if root == null:
		return
	if _overlay_root != null and is_instance_valid(_overlay_root) and _overlay_root.get_parent() == root:
		return
	if _overlay_root != null and is_instance_valid(_overlay_root):
		_overlay_root.queue_free()
	_overlay_root = CanvasLayer.new()
	_overlay_root.name = "DebugFramePrintLayer"
	_overlay_root.layer = _OVERLAY_LAYER
	var panel: MarginContainer = MarginContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 8.0
	panel.offset_top = 8.0
	panel.offset_right = 520.0
	panel.offset_bottom = 320.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_bg = ColorRect.new()
	_overlay_bg.color = Color(0.0, 0.0, 0.0, 0.65)
	_overlay_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_overlay_bg)
	_overlay_label = Label.new()
	_overlay_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_label.offset_left = 6.0
	_overlay_label.offset_top = 4.0
	_overlay_label.offset_right = -6.0
	_overlay_label.offset_bottom = -4.0
	_overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_label.add_theme_font_size_override("font_size", 13)
	_overlay_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	_overlay_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_overlay_label)
	_overlay_root.add_child(panel)
	root.add_child(_overlay_root)

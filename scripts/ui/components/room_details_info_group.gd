@tool
class_name RoomDetailsInfoGroup
extends Control

const MAX_ENTRIES: int = 4

@export var group_title: String = "":
	set(v):
		group_title = v
		_apply_title()
@export var question_icon: Texture2D:
	set(v):
		question_icon = v
		_apply_title()

@onready var _title_label: Label = $TitleLabel
@onready var _question_icon: TextureRect = $QuestionIcon
@onready var _entry_nodes: Array = [
	$Entries/Entry0,
	$Entries/Entry1,
	$Entries/Entry2,
	$Entries/Entry3,
]

var _last_entries_hash: int = 0


func _enter_tree() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_title()


func set_group_title(title_text: String) -> void:
	group_title = title_text
	_apply_title()


func set_entries(entries: Array) -> void:
	var normalized: Array = _normalize_entries(entries)
	var current_hash: int = normalized.hash()
	if current_hash == _last_entries_hash:
		return
	_last_entries_hash = current_hash
	for i in MAX_ENTRIES:
		var entry_node: Node = _entry_nodes[i]
		if i < normalized.size():
			if entry_node.has_method("set_entry_data"):
				entry_node.set_entry_data(normalized[i])
		else:
			if entry_node.has_method("clear_entry"):
				entry_node.clear_entry()


func clear_group() -> void:
	_last_entries_hash = 0
	for entry_node in _entry_nodes:
		if entry_node is Node and entry_node.has_method("clear_entry"):
			entry_node.clear_entry()


func _apply_title() -> void:
	if not is_inside_tree():
		return
	if _title_label:
		_title_label.text = group_title
	if _question_icon:
		_question_icon.texture = question_icon
		_question_icon.visible = question_icon != null


func _normalize_entries(entries: Array) -> Array:
	var out: Array = []
	for entry in entries:
		if out.size() >= MAX_ENTRIES:
			break
		if entry is Dictionary:
			out.append(entry)
	return out

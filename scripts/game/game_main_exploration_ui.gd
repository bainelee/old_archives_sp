class_name GameMainExplorationUiHelper
extends RefCounted

const _ExplorationMapOverlayScene = preload("res://scenes/ui/exploration_map_overlay.tscn")


static func setup_exploration_map_overlay(game_main: Node2D) -> void:
	if game_main.get("_exploration_map_overlay") != null:
		return
	var overlay_node: Node = _ExplorationMapOverlayScene.instantiate()
	var overlay: CanvasLayer = overlay_node as CanvasLayer
	if overlay == null:
		return
	var mount: Node = game_main.get_node_or_null("InteractiveUiRoot")
	if mount == null:
		mount = game_main
	mount.add_child(overlay)
	game_main.set("_exploration_map_overlay", overlay)
	if overlay.has_method("set_context"):
		overlay.call("set_context", game_main.get("_exploration_service"), game_main)


static func toggle_exploration_map_overlay(game_main: Node2D) -> void:
	var overlay: CanvasLayer = game_main.get("_exploration_map_overlay")
	if overlay == null or not overlay.has_method("toggle_overlay"):
		return
	overlay.call("toggle_overlay")

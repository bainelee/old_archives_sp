class_name ProgressRingOverlayHelper
extends RefCounted
## 进度环覆盖层共用逻辑
## CleanupOverlay、ConstructionOverlay 的 update_progress_rooms / hide_progress 共用

const PROGRESS_RING_SIZE := 80
const PROGRESS_RING_RADIUS := 40.0

static var _progress_ring_script: GDScript

static func _get_script() -> GDScript:
	if _progress_ring_script == null:
		_progress_ring_script = preload("res://scripts/ui/cleanup_progress_ring.gd") as GDScript
	return _progress_ring_script


## 更新进度环显示：rooms_data 为 [{room_index, position, ratio}, ...]
static func update_progress_rooms(container: Control, rings: Dictionary, rooms_data: Array) -> void:
	if not container:
		return
	var script_ref: GDScript = _get_script()
	var active_ids: Dictionary = {}
	for item in rooms_data:
		if item is Dictionary:
			var rid: int = int(item.get("room_index", -1))
			var pos: Vector2 = item.get("position", Vector2.ZERO)
			var ratio: float = clampf(float(item.get("ratio", 0)), 0.0, 1.0)
			active_ids[rid] = true
			if not rings.has(rid):
				var new_ring: Control = Control.new()
				new_ring.set_script(script_ref)
				new_ring.custom_minimum_size = Vector2(PROGRESS_RING_SIZE, PROGRESS_RING_SIZE)
				new_ring.set_anchors_preset(Control.PRESET_TOP_LEFT)
				new_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
				container.add_child(new_ring)
				rings[rid] = new_ring
			var r: Control = rings[rid]
			r.position = pos - Vector2(PROGRESS_RING_RADIUS, PROGRESS_RING_RADIUS)
			r.size = Vector2(PROGRESS_RING_SIZE, PROGRESS_RING_SIZE)
			r.set("progress_ratio", ratio)
			r.visible = true
			r.queue_redraw()
	for rid in rings.duplicate().keys():
		if not active_ids.has(rid):
			var dead_ring: Control = rings[rid]
			if is_instance_valid(dead_ring):
				if dead_ring.get_parent():
					dead_ring.get_parent().remove_child(dead_ring)
				dead_ring.free()
			rings.erase(rid)


static func hide_progress(rings: Dictionary) -> void:
	for rid in rings.duplicate().keys():
		var dead_ring: Control = rings[rid]
		if is_instance_valid(dead_ring):
			if dead_ring.get_parent():
				dead_ring.get_parent().remove_child(dead_ring)
			dead_ring.free()
	rings.clear()

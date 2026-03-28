class_name ExplorationStateCodec
extends RefCounted

## 探索运行时状态与存档块编解码。
## 根存档键名 "exploration"（GameMainSaveHelper）。

const SAVE_ROOT_KEY := "exploration"
const SAVE_VERSION := 2

const KEY_SAVE_VERSION := "save_version"
const KEY_FIRST_OPEN_DONE := "first_open_done"
const KEY_UNLOCKED_REGION_IDS := "unlocked_region_ids"
const KEY_EXPLORED_REGION_IDS := "explored_region_ids"
const KEY_DEBUG_INVESTIGATOR_POOL := "debug_investigator_pool"
const KEY_EXPLORING_BY_REGION := "exploring_by_region"


static func create_default_runtime_state() -> Dictionary:
	var unlocked: Array[String] = []
	var explored: Array[String] = []
	return {
		KEY_FIRST_OPEN_DONE: false,
		KEY_UNLOCKED_REGION_IDS: unlocked,
		KEY_EXPLORED_REGION_IDS: explored,
		KEY_DEBUG_INVESTIGATOR_POOL: 0,
		KEY_EXPLORING_BY_REGION: {},
	}


static func normalize_string_id_array(v: Variant) -> Array[String]:
	var out: Array[String] = []
	if v is Array:
		for item in v as Array:
			out.append(str(item))
	return out


static func normalize_exploring_map(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (raw is Dictionary):
		return out
	for k in (raw as Dictionary).keys():
		var rid: String = str(k)
		if rid.is_empty():
			continue
		var entry: Variant = raw[k]
		if not (entry is Dictionary):
			continue
		var e: Dictionary = entry as Dictionary
		var hours: float = float(e.get("hours_remaining", 0.0))
		var inv: int = int(e.get("investigators_reserved", 0))
		if hours <= 0.0 and inv <= 0:
			continue
		out[rid] = {
			"hours_remaining": hours,
			"investigators_reserved": inv,
		}
	return out


static func encode_for_save(runtime: Dictionary) -> Dictionary:
	var exploring: Dictionary = normalize_exploring_map(runtime.get(KEY_EXPLORING_BY_REGION, {}))
	return {
		KEY_SAVE_VERSION: SAVE_VERSION,
		KEY_FIRST_OPEN_DONE: bool(runtime.get(KEY_FIRST_OPEN_DONE, false)),
		KEY_UNLOCKED_REGION_IDS: normalize_string_id_array(runtime.get(KEY_UNLOCKED_REGION_IDS, [])),
		KEY_EXPLORED_REGION_IDS: normalize_string_id_array(runtime.get(KEY_EXPLORED_REGION_IDS, [])),
		KEY_DEBUG_INVESTIGATOR_POOL: int(runtime.get(KEY_DEBUG_INVESTIGATOR_POOL, 0)),
		KEY_EXPLORING_BY_REGION: exploring,
	}


static func decode_to_runtime(blob: Variant) -> Dictionary:
	if blob == null:
		return create_default_runtime_state()
	if not (blob is Dictionary):
		return create_default_runtime_state()
	var d: Dictionary = (blob as Dictionary).duplicate(true)
	var ver: int = int(d.get(KEY_SAVE_VERSION, 0))
	if ver < 1:
		return create_default_runtime_state()
	var merged: Dictionary = create_default_runtime_state()
	if ver == 1:
		merged[KEY_FIRST_OPEN_DONE] = bool(d.get(KEY_FIRST_OPEN_DONE, false))
		merged[KEY_UNLOCKED_REGION_IDS] = normalize_string_id_array(d.get(KEY_UNLOCKED_REGION_IDS, []))
		merged[KEY_EXPLORED_REGION_IDS] = normalize_string_id_array(d.get(KEY_EXPLORED_REGION_IDS, []))
		merged[KEY_DEBUG_INVESTIGATOR_POOL] = int(d.get(KEY_DEBUG_INVESTIGATOR_POOL, 0))
		merged[KEY_EXPLORING_BY_REGION] = {}
		return merged
	if ver != SAVE_VERSION:
		return create_default_runtime_state()
	merged[KEY_FIRST_OPEN_DONE] = bool(d.get(KEY_FIRST_OPEN_DONE, false))
	merged[KEY_UNLOCKED_REGION_IDS] = normalize_string_id_array(d.get(KEY_UNLOCKED_REGION_IDS, []))
	merged[KEY_EXPLORED_REGION_IDS] = normalize_string_id_array(d.get(KEY_EXPLORED_REGION_IDS, []))
	merged[KEY_DEBUG_INVESTIGATOR_POOL] = int(d.get(KEY_DEBUG_INVESTIGATOR_POOL, 0))
	merged[KEY_EXPLORING_BY_REGION] = normalize_exploring_map(d.get(KEY_EXPLORING_BY_REGION, {}))
	return merged

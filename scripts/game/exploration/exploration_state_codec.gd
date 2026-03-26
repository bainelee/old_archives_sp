class_name ExplorationStateCodec
extends RefCounted

## 探索运行时状态与存档块编解码（P1）。
## 根存档建议键名 "exploration"（由 GameMain 等接入时写入，本阶段未接线）。

const SAVE_ROOT_KEY := "exploration"
const SAVE_VERSION := 1

const KEY_SAVE_VERSION := "save_version"
const KEY_FIRST_OPEN_DONE := "first_open_done"
const KEY_UNLOCKED_REGION_IDS := "unlocked_region_ids"
const KEY_EXPLORED_REGION_IDS := "explored_region_ids"
const KEY_DEBUG_INVESTIGATOR_POOL := "debug_investigator_pool"


static func create_default_runtime_state() -> Dictionary:
	var unlocked: Array[String] = []
	var explored: Array[String] = []
	return {
		KEY_FIRST_OPEN_DONE: false,
		KEY_UNLOCKED_REGION_IDS: unlocked,
		KEY_EXPLORED_REGION_IDS: explored,
		KEY_DEBUG_INVESTIGATOR_POOL: 0,
	}


static func normalize_string_id_array(v: Variant) -> Array[String]:
	var out: Array[String] = []
	if v is Array:
		for item in v as Array:
			out.append(str(item))
	return out


static func encode_for_save(runtime: Dictionary) -> Dictionary:
	var out: Dictionary = {
		KEY_SAVE_VERSION: SAVE_VERSION,
		KEY_FIRST_OPEN_DONE: bool(runtime.get(KEY_FIRST_OPEN_DONE, false)),
		KEY_UNLOCKED_REGION_IDS: normalize_string_id_array(runtime.get(KEY_UNLOCKED_REGION_IDS, [])),
		KEY_EXPLORED_REGION_IDS: normalize_string_id_array(runtime.get(KEY_EXPLORED_REGION_IDS, [])),
		KEY_DEBUG_INVESTIGATOR_POOL: int(runtime.get(KEY_DEBUG_INVESTIGATOR_POOL, 0)),
	}
	return out


static func decode_to_runtime(blob: Variant) -> Dictionary:
	if blob == null:
		return create_default_runtime_state()
	if not (blob is Dictionary):
		return create_default_runtime_state()
	var d: Dictionary = (blob as Dictionary).duplicate(true)
	var ver: int = int(d.get(KEY_SAVE_VERSION, 0))
	if ver != SAVE_VERSION:
		return create_default_runtime_state()
	var merged: Dictionary = create_default_runtime_state()
	merged[KEY_FIRST_OPEN_DONE] = bool(d.get(KEY_FIRST_OPEN_DONE, false))
	merged[KEY_UNLOCKED_REGION_IDS] = normalize_string_id_array(d.get(KEY_UNLOCKED_REGION_IDS, []))
	merged[KEY_EXPLORED_REGION_IDS] = normalize_string_id_array(d.get(KEY_EXPLORED_REGION_IDS, []))
	merged[KEY_DEBUG_INVESTIGATOR_POOL] = int(d.get(KEY_DEBUG_INVESTIGATOR_POOL, 0))
	return merged

extends RefCounted

## 探索、信息外派、真相等尚未写入 DataProviders 的占位实现。
## 功能排期与设计：docs/design/2-gameplay/10-exploration-region-map.md；真相系统见设计文档目录后续条目。

static func exploration_fixed_consumption_entries() -> Array:
	return []


static func information_exploration_output() -> Array:
	return []


static func information_extra_effects() -> Array:
	return []


static func investigator_exploration_assignments() -> Array:
	return []


static func truth_acquired_list() -> Array:
	return []


static func truth_interpreted_list() -> Array:
	return []

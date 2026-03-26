class_name ExplorationTick
extends RefCounted

## 探索时间片占位（P1）。
## 决策：本阶段 **不做** 离线补算；不与 GameTime 对齐推进。


static func tick(_service, _delta_game_hours: float) -> void:
	pass

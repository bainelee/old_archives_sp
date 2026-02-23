class_name FloorTileType
extends RefCounted

## 底板类型枚举
enum Type {
	EMPTY,      ## 空
	WALL,       ## 墙壁/装饰（无交互）
	ROOM_FLOOR  ## 房间底板
}

## 编辑层级
enum EditLevel {
	FLOOR,  ## 一级：底板铺设
	ROOM    ## 二级：房间划分
}

## 选择模式：单选与框选
enum SelectMode {
	SINGLE,  ## 单选：点击单格操作
	BOX      ## 框选：拖拽框选范围批量操作
}

## 操作工具（创造/橡皮擦）
enum PaintTool {
	EMPTY,      ## 空
	WALL,       ## 墙壁
	ROOM_FLOOR, ## 房间底板
	ERASER      ## 橡皮擦（消除格子）
}

static func get_type_name(type: int) -> String:
	match type:
		Type.EMPTY: return "空"
		Type.WALL: return "墙壁/装饰"
		Type.ROOM_FLOOR: return "房间底板"
		_: return "未知"

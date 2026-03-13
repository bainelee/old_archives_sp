extends Node
## 游戏输入处理节点 - process_mode=ALWAYS，确保 tree 暂停时玩家仍可操作镜头、选房、查看详情

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	var gm: Node2D = get_parent() as Node2D
	if gm:
		GameMainInputHelper.process_input(gm, event)

extends Node
## 挂于 GameMain 下，包住时间暂停（tree.paused）时仍需交互的 UI 子树。
## 子节点默认继承本节点 effective process_mode，避免逐层漏设 PROCESS_MODE_ALWAYS。

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

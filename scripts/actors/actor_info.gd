@tool
class_name ActorInfo
extends Node

## 元件信息：供编辑器与游戏逻辑识别 3D 元件。
## 挂载于 3d_actor 场景 root 下。
## display_name 仅用于编辑器；游戏内名称通过 actor_id 从元件表查询。

@export var actor_id: String = ""

@export var display_name: String = ""

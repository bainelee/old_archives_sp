extends RefCounted
class_name GameValuesRef
## 获取 GameValues 单例的引用（避免直接使用 autoload 名称以消除 LSP 的「未声明」误报）
## 通过场景树查找，不依赖全局标识符

static func get_singleton() -> Node:
	var ml = Engine.get_main_loop()
	if ml is SceneTree:
		return (ml as SceneTree).root.get_node_or_null("GameValues")
	return null

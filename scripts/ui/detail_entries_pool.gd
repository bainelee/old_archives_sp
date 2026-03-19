class_name DetailEntriesPool
extends RefCounted
## 详情面板条目对象池
## 复用条目节点（Label、PanelContainer 等），减少频繁创建/销毁开销
## 适用于动态生成消耗/产出条目的详情面板

## 池配置
const DEFAULT_POOL_SIZE := 20  ## 每种类型默认池大小

## 对象池
var _pooled_labels: Array[Label] = []
var _pooled_rows: Array[PanelContainer] = []
var _pooled_hboxes: Array[HBoxContainer] = []

## 使用统计（调试用）
var _created_count := 0
var _reused_count := 0
var _returned_count := 0


## 获取 Label（从池中获取或创建新的）
func acquire_label() -> Label:
	for label in _pooled_labels:
		if is_instance_valid(label) and not label.visible:
			_reused_count += 1
			label.visible = true
			label.text = ""
			return label

	## 池中没有可用，创建新的
	_created_count += 1
	return Label.new()


## 获取条目行容器（PanelContainer）
func acquire_row() -> PanelContainer:
	for row in _pooled_rows:
		if is_instance_valid(row) and not row.visible:
			_reused_count += 1
			row.visible = true
			## 清空子节点
			for child in row.get_children():
				row.remove_child(child)
			return row

	## 池中没有可用，创建新的
	_created_count += 1
	var row := PanelContainer.new()
	return row


## 获取 HBoxContainer（用于条目内部布局）
func acquire_hbox() -> HBoxContainer:
	for hbox in _pooled_hboxes:
		if is_instance_valid(hbox) and not hbox.visible:
			_reused_count += 1
			hbox.visible = true
			## 清空子节点
			for child in hbox.get_children():
				hbox.remove_child(child)
			return hbox

	## 池中没有可用，创建新的
	_created_count += 1
	return HBoxContainer.new()


## 归还 Label 到池
func release_label(label: Label) -> void:
	if not label:
		return
	label.visible = false
	label.text = ""
	if label.get_parent():
		label.get_parent().remove_child(label)
	if not _pooled_labels.has(label):
		_pooled_labels.append(label)
		_returned_count += 1


## 归还条目行到池
func release_row(row: PanelContainer) -> void:
	if not row:
		return
	row.visible = false
	## 移除所有子节点
	for child in row.get_children():
		row.remove_child(child)
		## 递归归还子节点
		if child is Label:
			release_label(child)
		elif child is HBoxContainer:
			release_hbox(child)
	if row.get_parent():
		row.get_parent().remove_child(row)
	if not _pooled_rows.has(row):
		_pooled_rows.append(row)
		_returned_count += 1


## 归还 HBox 到池
func release_hbox(hbox: HBoxContainer) -> void:
	if not hbox:
		return
	hbox.visible = false
	## 移除所有子节点
	for child in hbox.get_children():
		hbox.remove_child(child)
		if child is Label:
			release_label(child)
	if hbox.get_parent():
		hbox.get_parent().remove_child(hbox)
	if not _pooled_hboxes.has(hbox):
		_pooled_hboxes.append(hbox)
		_returned_count += 1


## 清空容器中的所有子节点并归还到池
func release_container_contents(container: Container) -> void:
	if not container:
		return
	var children := container.get_children().duplicate()
	for child in children:
		container.remove_child(child)
		if child is PanelContainer:
			release_row(child)
		elif child is HBoxContainer:
			release_hbox(child)
		elif child is Label:
			release_label(child)
		else:
			## 其他类型直接释放
			if child is Node:
				var n: Node = child as Node
				if n.get_parent():
					n.get_parent().remove_child(n)
				n.free()


## 裁剪池大小（防止无限增长）
func trim_pools(max_size: int = DEFAULT_POOL_SIZE) -> void:
	_trim_pool(_pooled_labels, max_size)
	_trim_pool(_pooled_rows, max_size)
	_trim_pool(_pooled_hboxes, max_size)


func _trim_pool(pool: Array, max_size: int) -> void:
	while pool.size() > max_size:
		var item = pool.pop_back()
		## 关闭阶段优先立即释放，避免 queue_free 来不及执行导致 RID 泄漏
		if is_instance_valid(item) and item is Node:
			var n: Node = item as Node
			if n.get_parent():
				n.get_parent().remove_child(n)
			n.free()


## 清空所有池（仅在场景关闭时调用，避免重复释放）
func clear_all_pools() -> void:
	## 关闭阶段优先立即释放，避免 queue_free 在引擎停机时滞留
	for item in _pooled_labels:
		if is_instance_valid(item) and item is Node:
			var n: Node = item as Node
			if n.get_parent():
				n.get_parent().remove_child(n)
			n.free()
	for item in _pooled_rows:
		if is_instance_valid(item) and item is Node:
			var n: Node = item as Node
			if n.get_parent():
				n.get_parent().remove_child(n)
			n.free()
	for item in _pooled_hboxes:
		if is_instance_valid(item) and item is Node:
			var n: Node = item as Node
			if n.get_parent():
				n.get_parent().remove_child(n)
			n.free()
	_pooled_labels.clear()
	_pooled_rows.clear()
	_pooled_hboxes.clear()


## 获取统计信息
func get_stats() -> Dictionary:
	return {
		"created": _created_count,
		"reused": _reused_count,
		"returned": _returned_count,
		"pool_labels": _pooled_labels.size(),
		"pool_rows": _pooled_rows.size(),
		"pool_hboxes": _pooled_hboxes.size(),
	}


## 重置统计
func reset_stats() -> void:
	_created_count = 0
	_reused_count = 0
	_returned_count = 0

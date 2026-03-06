@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Object:
	var source_path = get_source_file()
	var base_dir = source_path.get_base_dir()
	var glb_basename = source_path.get_file().get_basename()
	
	var mat_dir = base_dir + "/materials"
	
	var dir = DirAccess.open(base_dir)
	if not dir:
		push_error("GLB 材质提取失败: 无法打开目录 " + base_dir)
		return scene
	if not dir.dir_exists("materials"):
		var err = dir.make_dir("materials")
		if err != OK:
			push_error("GLB 材质提取失败: 无法创建 materials 目录 " + mat_dir + " (err=%d)" % err)
			return scene
	
	var processed: Dictionary = {}  # material -> save_path，已处理材质复用
	var used_names: Array[String] = []
		
	_process_node(scene, mat_dir, glb_basename, processed, used_names)
	
	# 更新 .import 以启用 materials/extract，使下次导入时「使用外部」生效
	_update_import_extract(source_path, mat_dir)
	return scene

func _process_node(node: Node, mat_dir: String, glb_basename: String, processed: Dictionary, used_names: Array) -> void:
	if node is MeshInstance3D and node.mesh:
		# 复制 mesh 避免修改导入缓存中的共享资源，确保外部材质引用被正确序列化
		var mesh: ArrayMesh = (node.mesh as ArrayMesh).duplicate()
		node.mesh = mesh
		for i in range(mesh.get_surface_count()):
			var mat = mesh.surface_get_material(i)
			
			if mat and mat is StandardMaterial3D:
				var mat_name: String
				var save_path: String
				
				if mat in processed:
					# 同一材质被多个 surface 共享，从外部路径加载并赋回以建立连接
					save_path = processed[mat]
					var ext_mat = load(save_path) as StandardMaterial3D
					if ext_mat:
						mesh.surface_set_material(i, ext_mat)
					continue
				
				# mat_<glb名称>_<index>，index 从 0 起为该 GLB 中第几个材质
				var base_index := used_names.size()
				mat_name = ("mat_%s_%d" % [glb_basename, base_index]).validate_filename()
				save_path = mat_dir + "/" + mat_name + ".tres"
				
				# 若仍重名则递增 index
				while mat_name in used_names or FileAccess.file_exists(save_path):
					base_index += 1
					mat_name = ("mat_%s_%d" % [glb_basename, base_index]).validate_filename()
					save_path = mat_dir + "/" + mat_name + ".tres"
				used_names.append(mat_name)
				
				# 声明路径接管
				mat.take_over_path(save_path)
				
				# 显式使用 StandardMaterial3D 调用枚举
				mat.diffuse_mode = StandardMaterial3D.DIFFUSE_TOON
				mat.specular_mode = StandardMaterial3D.SPECULAR_TOON
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				# 设置 Stencil Outline 参数
				mat.stencil_mode = StandardMaterial3D.STENCIL_MODE_OUTLINE
				mat.stencil_reference = 1
				mat.stencil_color = Color(0, 0, 0, 1) # #000000 纯黑
				mat.stencil_outline_thickness = 0.02
				
				var err = ResourceSaver.save(mat, save_path, ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
				
				if err == OK:
					processed[mat] = save_path
					# 从外部路径加载并赋回，确保 GLB 与材质建立外部引用连接
					var ext_mat = load(save_path) as StandardMaterial3D
					if ext_mat:
						mesh.surface_set_material(i, ext_mat)
					else:
						mesh.surface_set_material(i, mat)
				else:
					push_error("材质保存失败: " + save_path)
					
	for child in node.get_children():
		_process_node(child, mat_dir, glb_basename, processed, used_names)


func _update_import_extract(source_path: String, mat_dir: String) -> void:
	"""更新 .import 文件，启用 materials/extract 与 extract_path，使下次导入时「使用外部」生效。"""
	var import_path := source_path + ".import"
	var f = FileAccess.open(import_path, FileAccess.READ)
	if not f:
		push_warning("GLB 材质提取: 无法读取 .import 文件 " + import_path)
		return
	var content := f.get_as_text()
	f.close()
	content = content.replace("materials/extract=0", "materials/extract=1")
	content = content.replace("materials/extract_path=\"\"", "materials/extract_path=\"%s\"" % mat_dir)
	f = FileAccess.open(import_path, FileAccess.WRITE)
	if not f:
		push_warning("GLB 材质提取: 无法写入 .import 文件 " + import_path)
		return
	f.store_string(content)
	f.close()

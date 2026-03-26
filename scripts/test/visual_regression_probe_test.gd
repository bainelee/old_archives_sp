@tool
extends Control

const BASELINE_PATH := "user://test_screenshots/visual_ui_button_baseline.png"
const CURRENT_PATH := "user://test_screenshots/visual_ui_button_current.png"
const DIFF_PATH := "user://test_screenshots/visual_ui_button_diff.png"
const DIFF_ANNOTATED_PATH := "user://test_screenshots/visual_ui_button_diff_annotated.png"
const DIFF_THRESHOLD := 0.002

var _button_bg: ColorRect
var _icon: TextureRect
var _label: Label
var _ui_built := false


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		_build_ui()
		_apply_expected_layout()


func _ready() -> void:
	_build_ui()
	# 等待一帧，确保 UI 完成布局后再截图。
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var record_baseline := _has_flag("--record-baseline")
	var assert_baseline := _has_flag("--assert-baseline")
	if record_baseline:
		_apply_expected_layout()
		await RenderingServer.frame_post_draw
		var baseline_capture := _capture_viewport()
		_ensure_parent_dir(BASELINE_PATH)
		var save_err := baseline_capture.save_png(BASELINE_PATH)
		if save_err != OK:
			push_error("[VisualRegressionProbeTest] FAIL visual_regression: cannot save baseline")
			get_tree().quit(1)
			return
		print("[VisualRegressionProbeTest] PASS baseline recorded")
		get_tree().quit(0)
		return

	if not assert_baseline:
		# 预览模式：允许在编辑器/手工运行时查看 UI，不做失败断言。
		_apply_expected_layout()
		print("[VisualRegressionProbeTest] PREVIEW mode")
		return

	# 故意注入视觉错误：icon 与按钮底图左上角对齐，而不是垂直居中对齐。
	var expected_icon_rect := _get_expected_icon_rect()
	_apply_buggy_layout()
	await RenderingServer.frame_post_draw
	var actual_icon_rect := Rect2(_icon.position, _icon.size)
	var current_img := _capture_viewport()
	_ensure_parent_dir(CURRENT_PATH)
	current_img.save_png(CURRENT_PATH)

	if not FileAccess.file_exists(BASELINE_PATH):
		push_error("[VisualRegressionProbeTest] FAIL visual_regression: baseline missing, run with --record-baseline")
		get_tree().quit(1)
		return

	var baseline_img := Image.load_from_file(BASELINE_PATH)
	if baseline_img == null:
		push_error("[VisualRegressionProbeTest] FAIL visual_regression: cannot load baseline image")
		get_tree().quit(1)
		return

	var metrics := _compute_diff_metrics_and_heatmap(current_img, baseline_img)
	var diff := float(metrics.get("diff", 1.0))
	var diff_img: Variant = metrics.get("diff_image", null)
	if diff_img is Image:
		_ensure_parent_dir(DIFF_PATH)
		(diff_img as Image).save_png(DIFF_PATH)
		var annotated := _build_annotated_diff_image(
			current_img,
			diff_img as Image,
			expected_icon_rect,
			actual_icon_rect,
			Rect2(_button_bg.position, _button_bg.size)
		)
		_ensure_parent_dir(DIFF_ANNOTATED_PATH)
		annotated.save_png(DIFF_ANNOTATED_PATH)
	if diff > DIFF_THRESHOLD:
		push_error(
			"[VisualRegressionProbeTest] FAIL visual_regression: baseline mismatch diff=%.6f threshold=%.6f"
			% [diff, DIFF_THRESHOLD]
		)
		get_tree().quit(1)
		return

	print("[VisualRegressionProbeTest] PASS")
	get_tree().quit(0)


func _build_ui() -> void:
	if _ui_built:
		return
	_ui_built = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_button_bg = ColorRect.new()
	_button_bg.name = "ButtonBg"
	_button_bg.color = Color(0.18, 0.20, 0.25, 1.0)
	_button_bg.position = Vector2(500, 300)
	_button_bg.size = Vector2(420, 96)
	add_child(_button_bg)

	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.texture = _make_icon_texture()
	_icon.custom_minimum_size = Vector2(32, 32)
	_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_icon)

	_label = Label.new()
	_label.name = "Text"
	_label.text = "Start Mission"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.position = Vector2(_button_bg.position.x + 72, _button_bg.position.y + 24)
	_label.size = Vector2(300, 48)
	add_child(_label)


func _apply_expected_layout() -> void:
	var expected := _get_expected_icon_rect()
	_icon.position = expected.position
	_icon.size = expected.size


func _apply_buggy_layout() -> void:
	_icon.position = Vector2(_button_bg.position.x + 2.0, _button_bg.position.y + 2.0)
	_icon.size = Vector2(32, 32)


func _get_expected_icon_rect() -> Rect2:
	var y_center := _button_bg.position.y + (_button_bg.size.y - 32.0) * 0.5
	return Rect2(Vector2(_button_bg.position.x + 24.0, y_center), Vector2(32, 32))


func _make_icon_texture() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.25, 0.65, 0.95, 1.0))
	return ImageTexture.create_from_image(img)


func _capture_viewport() -> Image:
	var tex := get_viewport().get_texture()
	return tex.get_image()


func _compute_diff_metrics_and_heatmap(current_img: Image, baseline_img: Image) -> Dictionary:
	if current_img.get_width() != baseline_img.get_width() or current_img.get_height() != baseline_img.get_height():
		return {"diff": 1.0, "diff_image": current_img.duplicate()}
	var x0 := int(_button_bg.position.x - 10.0)
	var y0 := int(_button_bg.position.y - 10.0)
	var x1 := int(_button_bg.position.x + _button_bg.size.x + 10.0)
	var y1 := int(_button_bg.position.y + _button_bg.size.y + 10.0)
	x0 = maxi(0, x0)
	y0 = maxi(0, y0)
	x1 = mini(current_img.get_width() - 1, x1)
	y1 = mini(current_img.get_height() - 1, y1)

	var total := 0.0
	var count := 0
	var heatmap := Image.create(current_img.get_width(), current_img.get_height(), false, Image.FORMAT_RGBA8)
	heatmap.fill(Color(0, 0, 0, 0))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var a := current_img.get_pixel(x, y)
			var b := baseline_img.get_pixel(x, y)
			var dr := absf(a.r - b.r)
			var dg := absf(a.g - b.g)
			var db := absf(a.b - b.b)
			var pixel_diff := dr + dg + db
			total += pixel_diff
			count += 1
			var normalized := clampf(pixel_diff / 3.0, 0.0, 1.0)
			if normalized > 0.001:
				# 差异越大，红色越亮。
				heatmap.set_pixel(x, y, Color(normalized, 0.0, 0.0, clampf(normalized * 1.4, 0.2, 1.0)))
	if count <= 0:
		return {"diff": 1.0, "diff_image": heatmap}
	return {"diff": total / float(count * 3), "diff_image": heatmap}


func _build_annotated_diff_image(
	current_img: Image,
	heatmap: Image,
	expected_icon_rect: Rect2,
	actual_icon_rect: Rect2,
	button_rect: Rect2
) -> Image:
	var out := current_img.duplicate()
	out.convert(Image.FORMAT_RGBA8)
	# 叠加热力图，提升差异可见度。
	for y in range(out.get_height()):
		for x in range(out.get_width()):
			var base: Color = out.get_pixel(x, y)
			var overlay: Color = heatmap.get_pixel(x, y)
			if overlay.a <= 0.001:
				continue
			out.set_pixel(x, y, _blend_rgba(base, overlay))

	# 标注区域：黄色=按钮框，绿色=预期 icon，红色=实际 icon。
	_draw_rect_outline(out, button_rect, Color(1.0, 0.9, 0.1, 1.0), 2)
	_draw_rect_outline(out, expected_icon_rect, Color(0.2, 1.0, 0.2, 1.0), 2)
	_draw_rect_outline(out, actual_icon_rect, Color(1.0, 0.2, 0.2, 1.0), 2)
	return out


func _draw_rect_outline(img: Image, rect: Rect2, color: Color, thickness: int) -> void:
	var x0 := clampi(int(rect.position.x), 0, img.get_width() - 1)
	var y0 := clampi(int(rect.position.y), 0, img.get_height() - 1)
	var x1 := clampi(int(rect.position.x + rect.size.x), 0, img.get_width() - 1)
	var y1 := clampi(int(rect.position.y + rect.size.y), 0, img.get_height() - 1)
	for t in range(thickness):
		var tx0 := clampi(x0 - t, 0, img.get_width() - 1)
		var ty0 := clampi(y0 - t, 0, img.get_height() - 1)
		var tx1 := clampi(x1 + t, 0, img.get_width() - 1)
		var ty1 := clampi(y1 + t, 0, img.get_height() - 1)
		for x in range(tx0, tx1 + 1):
			img.set_pixel(x, ty0, color)
			img.set_pixel(x, ty1, color)
		for y in range(ty0, ty1 + 1):
			img.set_pixel(tx0, y, color)
			img.set_pixel(tx1, y, color)


func _blend_rgba(base: Color, overlay: Color) -> Color:
	var a := clampf(overlay.a, 0.0, 1.0)
	return Color(
		base.r * (1.0 - a) + overlay.r * a,
		base.g * (1.0 - a) + overlay.g * a,
		base.b * (1.0 - a) + overlay.b * a,
		1.0
	)


func _has_flag(flag: String) -> bool:
	for arg in OS.get_cmdline_user_args():
		if str(arg) == flag:
			return true
	return false


func _ensure_parent_dir(path: String) -> void:
	var dir_path := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)

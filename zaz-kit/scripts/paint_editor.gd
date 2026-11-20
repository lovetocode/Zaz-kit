class_name PaintEditor
extends Control

signal finished(result: Image)

const CLEAR := Color(0, 0, 0, 0)
const MARK := Color(1, 1, 1, 1)
const T_KEEP := 0
const T_KILL := 1
const T_UNPAINT := 2
const T_TOUCH_ERASE := 3
const T_TOUCH_RESTORE := 4
const VIEW_NAMES := ["View: paint marks", "View: checkerboard", "View: black", "View: white"]

var base: Image     # original photo
var paint: Image    # green marks: alpha > 0 means keep
var kill: Image     # red marks: alpha > 0 means always delete
var lit: Image      # original pixels where green (for the dim view)
var result: Image
var tex_base: ImageTexture
var tex_paint: ImageTexture
var tex_kill: ImageTexture
var tex_lit: ImageTexture
var tex_result: ImageTexture
var tex_checker: ImageTexture
var undo_stack := []

var canvas: Control
var info: Label
var brush_label: Label
var tol_label: Label
var tol_slider: HSlider
var dim_check: CheckBox
var paint_color: ColorPickerButton
var view_btn: Button
var tool_btns := []

var brush_r := 40
var cur_tool := T_KEEP
var view_mode := 0
var painting := false
var dirty := false
var dirty_result := false
var last_pt := Vector2i.ZERO
var cursor := Vector2(-500, -500)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tex_checker = _make_checker()
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(row)

	canvas = Control.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.clip_contents = true
	canvas.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	canvas.draw.connect(_draw_canvas)
	canvas.gui_input.connect(_canvas_input)
	canvas.resized.connect(canvas.queue_redraw)
	row.add_child(canvas)

	var side := ScrollContainer.new()
	side.custom_minimum_size = Vector2(420, 0)
	side.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(side)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	side.add_child(box)

	info = _label("Paint the parts you want to keep.", box)

	var grp := ButtonGroup.new()
	var names := ["Keep (green)", "Remove (red)", "Unpaint (clear marks)", "Touch-up: erase result", "Touch-up: restore result"]
	var hints := [
		"Keep mode: paint what must survive.",
		"Remove mode: paint what must always disappear.",
		"Unpaint mode: clears green and red marks.",
		"Touch-up erase: erases bits of the finished result.",
		"Touch-up restore: brings back original pixels.",
	]
	for i in names.size():
		var b := Button.new()
		b.text = names[i]
		b.toggle_mode = true
		b.button_group = grp
		b.button_pressed = (i == 0)
		b.custom_minimum_size = Vector2(0, 70)
		b.pressed.connect(_set_tool.bind(i, hints[i]))
		box.add_child(b)
		tool_btns.append(b)

	brush_label = _label("Brush size: 40", box)
	var bs := HSlider.new()
	bs.min_value = 5
	bs.max_value = 150
	bs.step = 1
	bs.value = 40
	bs.custom_minimum_size = Vector2(0, 50)
	bs.value_changed.connect(func(v):
		brush_r = int(v)
		brush_label.text = "Brush size: %d" % int(v))
	box.add_child(bs)

	_label("Keep (green) color:", box)
	paint_color = ColorPickerButton.new()
	paint_color.color = Color(0.1, 0.9, 0.3)
	paint_color.edit_alpha = false
	paint_color.custom_minimum_size = Vector2(0, 60)
	paint_color.color_changed.connect(func(_c): canvas.queue_redraw())
	box.add_child(paint_color)

	dim_check = CheckBox.new()
	dim_check.text = "Dim unpainted areas"
	dim_check.button_pressed = true
	dim_check.toggled.connect(func(_on): canvas.queue_redraw())
	box.add_child(dim_check)

	_btn("Undo", box, _undo)
	_btn("Paint everything (green)", box, _paint_all)
	_btn("Clear all marks", box, _clear_marks)

	tol_label = _label("Removal tolerance: 0.20", box)
	tol_slider = HSlider.new()
	tol_slider.min_value = 0.02
	tol_slider.max_value = 0.6
	tol_slider.step = 0.01
	tol_slider.value = 0.2
	tol_slider.custom_minimum_size = Vector2(0, 50)
	tol_slider.value_changed.connect(func(v): tol_label.text = "Removal tolerance: %.2f" % v)
	box.add_child(tol_slider)

	_btn("Remove background (green kept, red deleted)", box, _remove_keep_painted)
	_btn("Erase everything not green", box, _keep_only)
	view_btn = _btn(VIEW_NAMES[0], box, _cycle_view)
	_btn("Done: use result", box, _done)
	_btn("Cancel", box, func(): visible = false)


# ---------- helpers ----------
func _label(text: String, parent: Node) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


func _btn(text: String, parent: Node, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 70)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _make_checker() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.8, 0.8, 0.8, 1))
	img.fill_rect(Rect2i(0, 0, 16, 16), Color(0.55, 0.55, 0.55, 1))
	img.fill_rect(Rect2i(16, 16, 16, 16), Color(0.55, 0.55, 0.55, 1))
	return ImageTexture.create_from_image(img)


func _update_view_btn() -> void:
	view_btn.text = VIEW_NAMES[view_mode]


func open(img: Image) -> void:
	if img != base:
		base = img
		var w := base.get_width()
		var h := base.get_height()
		paint = Image.create(w, h, false, Image.FORMAT_RGBA8)
		paint.fill(CLEAR)
		kill = paint.duplicate() as Image
		lit = paint.duplicate() as Image
		tex_base = ImageTexture.create_from_image(base)
		tex_paint = ImageTexture.create_from_image(paint)
		tex_kill = ImageTexture.create_from_image(kill)
		tex_lit = ImageTexture.create_from_image(lit)
		undo_stack.clear()
		result = null
		tex_result = null
		view_mode = 0
		cur_tool = T_KEEP
		tool_btns[0].button_pressed = true
		_update_view_btn()
		info.text = "Paint the parts you want to keep."
	visible = true
	canvas.queue_redraw()


func _set_tool(t: int, msg: String) -> void:
	cur_tool = t
	info.text = msg
	if t >= T_TOUCH_ERASE:
		if result == null:
			info.text = "Run a removal first, then touch up the result."
		elif view_mode == 0:
			view_mode = 1
	else:
		view_mode = 0
	_update_view_btn()
	canvas.queue_redraw()


func _cycle_view() -> void:
	if result == null:
		info.text = "Run a removal first to preview the result."
		return
	view_mode = (view_mode + 1) % VIEW_NAMES.size()
	_update_view_btn()
	canvas.queue_redraw()


func _process(_delta: float) -> void:
	if dirty and tex_paint != null:
		dirty = false
		tex_paint.update(paint)
		tex_kill.update(kill)
		tex_lit.update(lit)
		canvas.queue_redraw()
	if dirty_result and tex_result != null:
		dirty_result = false
		tex_result.update(result)
		canvas.queue_redraw()


# ---------- drawing on screen ----------
func _view_rect() -> Rect2:
	var iw := float(base.get_width())
	var ih := float(base.get_height())
	var s := minf(canvas.size.x / iw, canvas.size.y / ih)
	var sz := Vector2(iw, ih) * s
	return Rect2((canvas.size - sz) / 2.0, sz)


func _to_img(pos: Vector2) -> Vector2i:
	var r := _view_rect()
	var f := (pos - r.position) / r.size
	return Vector2i(int(f.x * base.get_width()), int(f.y * base.get_height()))


func _draw_canvas() -> void:
	if base == null:
		return
	var r := _view_rect()
	if view_mode > 0 and tex_result != null:
		match view_mode:
			1:
				canvas.draw_texture_rect(tex_checker, r, true)
			2:
				canvas.draw_rect(r, Color.BLACK)
			3:
				canvas.draw_rect(r, Color.WHITE)
		canvas.draw_texture_rect(tex_result, r, false)
	else:
		if dim_check.button_pressed:
			canvas.draw_texture_rect(tex_base, r, false, Color(0.4, 0.4, 0.4, 1))
			canvas.draw_texture_rect(tex_lit, r, false)
		else:
			canvas.draw_texture_rect(tex_base, r, false)
		var c := paint_color.color
		canvas.draw_texture_rect(tex_paint, r, false, Color(c.r, c.g, c.b, 0.4))
		canvas.draw_texture_rect(tex_kill, r, false, Color(1, 0.15, 0.15, 0.5))
	var sc := r.size.x / base.get_width()
	canvas.draw_arc(cursor, brush_r * sc, 0.0, TAU, 48, Color(0, 0, 0, 0.9), 4.0)
	canvas.draw_arc(cursor, brush_r * sc, 0.0, TAU, 48, Color(1, 1, 1, 0.95), 2.0)


# ---------- input ----------
func _canvas_input(ev: InputEvent) -> void:
	if base == null:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		cursor = ev.position
		if ev.pressed:
			if cur_tool >= T_TOUCH_ERASE:
				if result == null:
					info.text = "Run a removal first, then touch up the result."
					return
				if view_mode == 0:
					view_mode = 1
				_push_undo_result()
			else:
				view_mode = 0
				_push_undo_marks()
			_update_view_btn()
			painting = true
			last_pt = _to_img(ev.position)
			_stamp(last_pt)
		else:
			painting = false
		canvas.queue_redraw()
	elif ev is InputEventMouseMotion:
		cursor = ev.position
		if painting:
			var p := _to_img(ev.position)
			_stroke(last_pt, p)
			last_pt = p
		canvas.queue_redraw()


func _stroke(a: Vector2i, b: Vector2i) -> void:
	var dist := Vector2(a).distance_to(Vector2(b))
	var step := maxf(1.0, brush_r * 0.4)
	var n := int(dist / step)
	for i in range(1, n + 1):
		_stamp(Vector2i(Vector2(a).lerp(Vector2(b), float(i) / n)))
	_stamp(b)


func _stamp(c: Vector2i) -> void:
	var r := brush_r
	var w := base.get_width()
	var h := base.get_height()
	for dy in range(-r, r + 1):
		var y := c.y + dy
		if y < 0 or y >= h:
			continue
		var half := int(sqrt(float(r * r - dy * dy)))
		var x0 := maxi(0, c.x - half)
		var x1 := mini(w - 1, c.x + half)
		if x1 < x0:
			continue
		var span := Rect2i(x0, y, x1 - x0 + 1, 1)
		match cur_tool:
			T_KEEP:
				paint.fill_rect(span, MARK)
				kill.fill_rect(span, CLEAR)
				lit.blit_rect(base, span, Vector2i(x0, y))
			T_KILL:
				kill.fill_rect(span, MARK)
				paint.fill_rect(span, CLEAR)
				lit.fill_rect(span, CLEAR)
			T_UNPAINT:
				paint.fill_rect(span, CLEAR)
				kill.fill_rect(span, CLEAR)
				lit.fill_rect(span, CLEAR)
			T_TOUCH_ERASE:
				result.fill_rect(span, CLEAR)
			T_TOUCH_RESTORE:
				result.blit_rect(base, span, Vector2i(x0, y))
	if cur_tool >= T_TOUCH_ERASE:
		dirty_result = true
	else:
		dirty = true


# ---------- undo ----------
func _add_undo(e: Dictionary) -> void:
	undo_stack.append(e)
	if undo_stack.size() > 5:
		undo_stack.pop_front()


func _push_undo_marks() -> void:
	_add_undo({
		"paint": paint.duplicate() as Image,
		"kill": kill.duplicate() as Image,
		"lit": lit.duplicate() as Image,
	})


func _push_undo_result() -> void:
	var e := {}
	e["result"] = result.duplicate() if result != null else null
	_add_undo(e)


func _undo() -> void:
	if undo_stack.is_empty():
		info.text = "Nothing to undo"
		return
	var e: Dictionary = undo_stack.pop_back()
	if e.has("paint"):
		paint = e["paint"]
		kill = e["kill"]
		lit = e["lit"]
		tex_paint.update(paint)
		tex_kill.update(kill)
		tex_lit.update(lit)
		view_mode = 0
	if e.has("result"):
		result = e["result"]
		if result != null:
			tex_result = ImageTexture.create_from_image(result)
		else:
			tex_result = null
			view_mode = 0
	_update_view_btn()
	info.text = "Undone"
	canvas.queue_redraw()


func _refresh_marks() -> void:
	tex_paint.update(paint)
	tex_kill.update(kill)
	tex_lit.update(lit)
	view_mode = 0
	_update_view_btn()
	canvas.queue_redraw()


func _paint_all() -> void:
	_push_undo_marks()
	paint.fill(MARK)
	kill.fill(CLEAR)
	lit = base.duplicate() as Image
	_refresh_marks()


func _clear_marks() -> void:
	_push_undo_marks()
	paint.fill(CLEAR)
	kill.fill(CLEAR)
	lit.fill(CLEAR)
	_refresh_marks()


# ---------- removal ----------
func _remove_keep_painted() -> void:
	info.text = "Working..."
	await get_tree().process_frame
	_push_undo_result()
	result = BgRemover.remove_bg(base, tol_slider.value, paint, kill)
	_show_result("Removed. Green was protected, red was deleted.")


func _keep_only() -> void:
	if paint.get_used_rect().size.x == 0:
		info.text = "Paint the parts you want to keep first"
		return
	info.text = "Working..."
	await get_tree().process_frame
	_push_undo_result()
	result = BgRemover.keep_only(base, paint)
	_show_result("Kept only the green parts.")


func _show_result(msg: String) -> void:
	tex_result = ImageTexture.create_from_image(result)
	view_mode = 1
	_update_view_btn()
	info.text = msg + " Use the touch-up tools, or Done."
	canvas.queue_redraw()


func _done() -> void:
	if result == null:
		info.text = "Run a removal first, or tap Cancel"
		return
	visible = false
	finished.emit(result)

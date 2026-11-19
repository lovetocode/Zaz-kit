extends Control

const MAX_SIDE := 1200
const CFG := "user://settings.cfg"
const STEPS := [
	["idea", "Idea"],
	["art", "Art made"],
	["seo", "SEO written"],
	["uploaded", "Uploaded to Zazzle"],
	["cutout", "Product photo cut out"],
	["cover", "Cover made"],
]

var confirm_dialog: ConfirmationDialog
var product: Image
var cutout: Image
var photo: Image
var cover: Image
var current_idea := ""
var checks := {}

var name_edit: LineEdit
var design_pick: OptionButton
var idea_label: Label
var desc_edit: LineEdit
var rules_edit: TextEdit
var seo_result: TextEdit
var seo_count: Label
var tol_slider: HSlider
var key_edit: LineEdit
var subject_edit: LineEdit
var size_spin: SpinBox
var product_view: TextureRect
var cover_view: TextureRect
var status: Label
var file_dialog: FileDialog
var pixabay: Pixabay
var words: Words


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var t := Theme.new()
	t.default_font_size = 28
	theme = t

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	status = _label("Ready", box)

	_header("1. Design", box)
	name_edit = _line("Design name (auto-filled)", box)
	design_pick = OptionButton.new()
	design_pick.custom_minimum_size = Vector2(0, 70)
	design_pick.item_selected.connect(_on_design_picked)
	box.add_child(design_pick)
	_refresh_designs()
	
	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Delete this design and all its files?"
	confirm_dialog.confirmed.connect(_delete_design)
	add_child(confirm_dialog)
	_btn("Delete this design", box, func(): confirm_dialog.popup_centered())

	_header("2. Idea", box)
	idea_label = _label("Tap New idea", box)
	_btn("New idea (copies prompt)", box, _new_idea)
	_btn("10 random word ideas", box, func():
		status.text = "Getting words..."
		words.ensure())
	desc_edit = _line("Short description (used for SEO)", box)

	_header("3. SEO", box)
	_label("Your SEO rules (saved):", box)
	rules_edit = TextEdit.new()
	rules_edit.custom_minimum_size = Vector2(0, 160)
	rules_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	rules_edit.text = _cfg_get("seo_rules", "")
	rules_edit.text_changed.connect(func(): _cfg_set("seo_rules", rules_edit.text))
	box.add_child(rules_edit)
	_btn("Copy SEO prompt", box, _copy_seo_prompt)
	seo_result = TextEdit.new()
	seo_result.custom_minimum_size = Vector2(0, 240)
	seo_result.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	seo_result.placeholder_text = "Paste the SEO reply here"
	seo_result.text_changed.connect(_update_count)
	box.add_child(seo_result)
	seo_count = _label("0 characters", box)
	_btn("Paste from clipboard", box, func():
		seo_result.text = DisplayServer.clipboard_get()
		_update_count())
	_btn("Save SEO", box, _save_seo)

	_header("4. Zazzle product photo", box)
	_btn("Load product photo", box, func(): file_dialog.popup_centered_ratio(0.9))
	_label("Tolerance (higher removes more background)", box)
	tol_slider = HSlider.new()
	tol_slider.min_value = 0.02
	tol_slider.max_value = 0.4
	tol_slider.step = 0.01
	tol_slider.value = 0.12
	tol_slider.custom_minimum_size = Vector2(0, 50)
	box.add_child(tol_slider)
	_btn("Remove background", box, _remove_bg)
	product_view = _preview(box)

	_header("5. Cover photo", box)
	key_edit = _line("Pixabay API key (saved)", box)
	key_edit.text = _cfg_get("pixabay_key", "")
	key_edit.text_changed.connect(func(k): _cfg_set("pixabay_key", k))
	subject_edit = _line("Photo subject (blank = random)", box)
	var row := HBoxContainer.new()
	box.add_child(row)
	var size_lbl := _label("Cover size px:", row)
	size_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	size_spin = SpinBox.new()
	size_spin.min_value = 100
	size_spin.max_value = 1000
	size_spin.value = 240
	size_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(size_spin)
	_btn("New cover photo", box, _new_cover_photo)
	_btn("Rebuild cover (after changing size)", box, _make_cover)
	cover_view = _preview(box)

	_header("6. Checklist", box)
	for s in STEPS:
		var cb := CheckBox.new()
		cb.text = s[1]
		cb.toggled.connect(func(_on): _save_state())
		box.add_child(cb)
		checks[s[0]] = cb

	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
	file_dialog.set("use_native_dialog", true)
	file_dialog.file_selected.connect(_on_file)
	add_child(file_dialog)

	pixabay = Pixabay.new()
	add_child(pixabay)
	pixabay.photo_ready.connect(_on_photo)
	pixabay.failed.connect(func(m): status.text = m)
	words = Words.new()
	add_child(words)
	words.ready_list.connect(_on_words_ready)
	words.failed.connect(func(m): status.text = m)


# ---------- UI helpers ----------
func _label(text: String, parent: Node) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


func _header(text: String, parent: Node) -> void:
	var l := _label(text, parent)
	l.add_theme_font_size_override("font_size", 36)
	l.add_theme_color_override("font_color", Color(1, 0.85, 0.4))


func _btn(text: String, parent: Node, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 70)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _line(placeholder: String, parent: Node) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(0, 60)
	parent.add_child(e)
	return e


func _preview(parent: Node) -> TextureRect:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.35, 0.35, 0.4)
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(0, 420)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p.add_child(tr)
	return tr


func _tex(img: Image) -> Texture2D:
	return ImageTexture.create_from_image(img) if img != null else null


# ---------- settings ----------
func _cfg_get(key: String, default := "") -> String:
	var cf := ConfigFile.new()
	if cf.load(CFG) == OK:
		return cf.get_value("app", key, default)
	return default


func _cfg_set(key: String, value: String) -> void:
	var cf := ConfigFile.new()
	cf.load(CFG)
	cf.set_value("app", key, value)
	cf.save(CFG)


# ---------- design folder + checklist ----------
func _ensure_name() -> String:
	if name_edit.text.strip_edges() == "":
		name_edit.text = "design_" + str(int(Time.get_unix_time_from_system()))
	return name_edit.text.strip_edges()


func _state() -> Dictionary:
	var s := {"idea": current_idea, "desc": desc_edit.text, "seo": seo_result.text, "steps": {}}
	for id in checks:
		s["steps"][id] = checks[id].button_pressed
	return s


func _save_state() -> void:
	Designs.save_state(_ensure_name(), _state())


func _mark(id: String) -> void:
	checks[id].set_pressed_no_signal(true)
	_save_state()


func _save_img(img: Image, file_name: String) -> void:
	var path := Designs.design_dir(_ensure_name()).path_join(file_name)
	if img.save_png(path) == OK:
		status.text = "Saved: " + path
	else:
		status.text = "Couldn't save: " + path


func _refresh_designs() -> void:
	design_pick.clear()
	design_pick.add_item("Load a previous design...")
	for d in Designs.list_designs():
		design_pick.add_item(d)


func _try_load(path: String) -> Image:
	if FileAccess.file_exists(path):
		return Image.load_from_file(path)
	return null


func _on_design_picked(idx: int) -> void:
	if idx == 0:
		return
	var n := design_pick.get_item_text(idx)
	name_edit.text = n
	var s := Designs.load_state(n)
	current_idea = s.get("idea", "")
	idea_label.text = current_idea if current_idea != "" else "Tap New idea"
	desc_edit.text = s.get("desc", "")
	seo_result.text = s.get("seo", "")
	_update_count()
	var steps: Dictionary = s.get("steps", {})
	for id in checks:
		checks[id].set_pressed_no_signal(bool(steps.get(id, false)))
	var dir := Designs.design_dir(n)
	cutout = _try_load(dir.path_join("product_cutout.png"))
	cover = _try_load(dir.path_join("cover.png"))
	product_view.texture = _tex(cutout)
	cover_view.texture = _tex(cover)
	status.text = "Loaded " + n


# ---------- idea + SEO ----------
func _new_idea() -> void:
	var idea := Ideas.roll()
	current_idea = idea["prompt"]
	idea_label.text = current_idea
	desc_edit.text = idea["desc"]
	DisplayServer.clipboard_set(current_idea)
	name_edit.text = Designs.slug(idea["subject"]) + "_" + str(int(Time.get_unix_time_from_system()) % 10000)
	_mark("idea")
	_refresh_designs()
	status.text = "Prompt copied. Paste it into Gemini."


func _copy_seo_prompt() -> void:
	DisplayServer.clipboard_set(Seo.build_prompt(rules_edit.text, desc_edit.text))
	status.text = "SEO prompt copied. Paste it to Claude."


func _update_count() -> void:
	seo_count.text = "%d characters" % seo_result.text.length()


func _save_seo() -> void:
	var path := Designs.design_dir(_ensure_name()).path_join("seo.txt")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(seo_result.text)
	_mark("seo")
	status.text = "SEO saved: " + path


# ---------- product photo ----------
func _on_file(path: String) -> void:
	var img := Image.load_from_file(path)
	if img == null:
		status.text = "Couldn't load that file"
		return
	img.convert(Image.FORMAT_RGBA8)
	var m := maxi(img.get_width(), img.get_height())
	if m > MAX_SIDE:
		var s := float(MAX_SIDE) / m
		img.resize(int(img.get_width() * s), int(img.get_height() * s), Image.INTERPOLATE_LANCZOS)
	product = img
	cutout = null
	product_view.texture = _tex(product)
	status.text = "Product photo loaded"


func _remove_bg() -> void:
	if product == null:
		status.text = "Load a product photo first"
		return
	status.text = "Working..."
	await get_tree().process_frame
	cutout = BgRemover.remove_bg(product, tol_slider.value)
	product_view.texture = _tex(cutout)
	_save_img(cutout, "product_cutout.png")
	_mark("cutout")
	if photo != null:
		_make_cover()


# ---------- cover ----------
func _new_cover_photo() -> void:
	var key := key_edit.text.strip_edges()
	if key == "":
		status.text = "Enter your Pixabay key"
		return
	var q := subject_edit.text.strip_edges()
	if q == "":
		q = Ideas.BG_SUBJECTS.pick_random()
		subject_edit.text = q
	pixabay.key = key
	status.text = "Getting photo..."
	pixabay.fetch(q)


func _on_photo(img: Image) -> void:
	photo = img
	_make_cover()


func _make_cover() -> void:
	if photo == null:
		status.text = "Get a cover photo first"
		return
	cover = Mockup.build(photo, cutout, int(size_spin.value))
	cover_view.texture = _tex(cover)
	if cutout == null:
		status.text = "Photo only. Cut out the product photo to add it."
		return
	_save_img(cover, "cover.png")
	_mark("cover")
	
func _on_words_ready() -> void:
	var ideas := words.roll_many(10)
	var lines := PackedStringArray()
	for i in ideas.size():
		lines.append("%d. %s" % [i + 1, ideas[i]["prompt"]])
	var text := "\n".join(lines)
	DisplayServer.clipboard_set(text)
	idea_label.text = text
	status.text = "10 prompts copied"
	
func _delete_design() -> void:
	var n := name_edit.text.strip_edges()
	if n == "":
		return
	Designs.delete_design(n)
	name_edit.text = ""
	cutout = null
	cover = null
	product_view.texture = null
	cover_view.texture = null
	_refresh_designs()
	status.text = "Deleted " + n

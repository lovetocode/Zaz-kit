class_name Words
extends Node

signal ready_list
signal failed(msg: String)


const URL := "https://raw.githubusercontent.com/first20hours/google-10000-english/master/google-10000-english-no-swears.txt"
const CHARACTERS := ["T-rex", "raccoon", "bunny", "sloth", "penguin", "corgi", "owl", "hedgehog", "capybara", "frog", "llama", "otter", "goat", "crab", "dragon", "robot"]
const STYLES := ["flat vector", "vintage woodcut", "pastel watercolor", "retro 70s cartoon", "bold sticker art", "psychedelic marbled"]

var words: Array = []
var _http: HTTPRequest


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_done)
	_load_local()


func _path() -> String:
	var d := Designs.root_dir().path_join("lists")
	DirAccess.make_dir_recursive_absolute(d)
	return d.path_join("words.txt")


func _load_local() -> void:
	words = []
	if not FileAccess.file_exists(_path()):
		return
	for line in FileAccess.get_file_as_string(_path()).split("\n"):
		var w := line.strip_edges()
		if w.length() >= 4:
			words.append(w)


func ensure() -> void:
	if not words.is_empty():
		ready_list.emit()
		return
	if _http.request(URL) != OK:
		failed.emit("Couldn't start the word download")


func _on_done(_r: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if code != 200:
		failed.emit("Word download error %d" % code)
		return
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f:
		f.store_buffer(body)
		f.close()
	_load_local()
	if words.is_empty():
		failed.emit("Word list came back empty")
	else:
		ready_list.emit()


func roll_many(n: int) -> Array:
	var out: Array = []
	for i in n:
		var w: String = words.pick_random()
		var c: String = CHARACTERS.pick_random()
		var st: String = STYLES.pick_random()
		out.append({
			"word": w,
			"prompt": "A cute funny %s inspired by the word '%s', %s style, white background, centered, no text" % [c, w, st],
		})
	return out

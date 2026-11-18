class_name Pixabay
extends Node

signal photo_ready(img: Image)
signal failed(msg: String)

var key := ""
var _search: HTTPRequest
var _dl: HTTPRequest


func _ready() -> void:
	_search = HTTPRequest.new()
	_dl = HTTPRequest.new()
	add_child(_search)
	add_child(_dl)
	_search.request_completed.connect(_on_search)
	_dl.request_completed.connect(_on_download)


func fetch(query: String) -> void:
	var url := "https://pixabay.com/api/?key=%s&q=%s&image_type=photo&per_page=30&safesearch=true" % [key, query.uri_encode()]
	if _search.request(url) != OK:
		failed.emit("Couldn't start the search (busy?)")


func _on_search(_r: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if code != 200:
		failed.emit("Pixabay error %d (check your key)" % code)
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY or data.get("hits", []).is_empty():
		failed.emit("No Pixabay results for that subject")
		return
	var hit = data["hits"].pick_random()
	if _dl.request(hit["webformatURL"]) != OK:
		failed.emit("Couldn't start the download")


func _on_download(_r: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if code != 200:
		failed.emit("Download error %d" % code)
		return
	var img := Image.new()
	var err := img.load_jpg_from_buffer(body)
	if err != OK:
		err = img.load_png_from_buffer(body)
	if err != OK:
		err = img.load_webp_from_buffer(body)
	if err != OK:
		failed.emit("Couldn't read that photo")
		return
	photo_ready.emit(img)

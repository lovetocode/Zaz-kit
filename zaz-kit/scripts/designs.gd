class_name Designs

# One folder per design: product_cutout.png, cover.png, seo.txt, design.json


static func root_dir() -> String:
	var pics := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if pics != "":
		var d := pics.path_join("ZazzleTool")
		if DirAccess.dir_exists_absolute(d) or DirAccess.make_dir_recursive_absolute(d) == OK:
			return d
	var u := ProjectSettings.globalize_path("user://designs")
	DirAccess.make_dir_recursive_absolute(u)
	return u


static func slug(s: String) -> String:
	var out := s.strip_edges().to_lower().validate_filename().replace(" ", "_")
	return out if out != "" else "design"


static func design_dir(design_name: String) -> String:
	var d := root_dir().path_join(slug(design_name))
	DirAccess.make_dir_recursive_absolute(d)
	return d


static func list_designs() -> PackedStringArray:
	return DirAccess.get_directories_at(root_dir())


static func save_state(design_name: String, state: Dictionary) -> void:
	var f := FileAccess.open(design_dir(design_name).path_join("design.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(state, "\t"))


static func load_state(design_name: String) -> Dictionary:
	var p := design_dir(design_name).path_join("design.json")
	if not FileAccess.file_exists(p):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(p))
	return data if typeof(data) == TYPE_DICTIONARY else {}
	
static func delete_design(design_name: String) -> void:
	var d := design_dir(design_name)
	for f in DirAccess.get_files_at(d):
		DirAccess.remove_absolute(d.path_join(f))
	DirAccess.remove_absolute(d)

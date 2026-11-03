extends SceneTree
## Produces a self-contained runtime pack with an explicit file allowlist.
## Credentials, editor plugins, caches unrelated to these assets, and tools are excluded.

var packer := PCKPacker.new()
var included: Dictionary = {}
var problems: Array[String] = []

func _initialize() -> void:
	build.call_deferred()

func build() -> void:
	DirAccess.make_dir_recursive_absolute("res://dist/LoopTownDemo-v8")
	var config := ConfigFile.new()
	config.load("res://project.godot")
	config.erase_section("editor_plugins")
	if config.has_section_key("autoload","_mcp_game_helper"):
		config.erase_section_key("autoload","_mcp_game_helper")
	config.set_value("application","config/name","回环镇 Loop Town")
	config.set_value("network","tls/certificate_bundle_override","res://assets/config/ca-bundle.crt")
	config.set_value("debug","file_logging/enable_file_logging",false)
	var sanitized: String = "res://docs/exploration-demo/portable-project-v8.godot"
	config.save(sanitized)
	var target: String = "res://dist/LoopTownDemo-v8/LoopTownDemo.pck"
	var error: Error = packer.pck_start(target)
	if error != OK:
		push_error("Cannot create PCK: %d" % error)
		quit(1)
		return
	add("res://project.godot", sanitized)
	add("res://icon.svg")
	add("res://assets/config/ca-bundle.crt")
	add("res://.godot/global_script_class_cache.cfg")
	for folder: String in ["res://scripts","res://autoload","res://data", "res://scenes/exploration", "res://assets/environments/exploration", "res://assets/audio"]:
		walk(folder)
	add("res://assets/ui/exploration/chinese.tres")
	error = packer.flush()
	if error != OK:
		problems.append("PCK flush failed: %d" % error)
	var manifest := FileAccess.open("res://docs/exploration-demo/runtime-pack-files.json",FileAccess.WRITE)
	manifest.store_string(JSON.stringify(included.keys(),"  "))
	manifest.close()
	print("RUNTIME_PACK ",included.size()," files; ",problems.size()," problems; ",ProjectSettings.globalize_path(target))
	for problem: String in problems:
		push_error(problem)
	quit(0 if problems.is_empty() else 1)

func walk(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		problems.append("Directory missing: "+path)
		return
	for file: String in directory.get_files():
		if file.get_extension() in ["gd","tscn","tres","json","png","wav","ogg","svg","gdshader","import"]:
			add(path+"/"+file)
	for folder: String in directory.get_directories():
		walk(path+"/"+folder)

func add(path: String, physical_path: String = "") -> void:
	if included.has(path):
		return
	if physical_path.is_empty():
		physical_path = path
	if not FileAccess.file_exists(physical_path):
		problems.append("File missing: "+physical_path)
		return
	var error: Error = packer.add_file(path,physical_path)
	if error != OK:
		problems.append("Pack failed: "+path)
		return
	included[path] = true
	if path.ends_with(".import"):
		var config := ConfigFile.new()
		if config.load(path)==OK and config.has_section_key("remap","path"):
			add(str(config.get_value("remap","path")))

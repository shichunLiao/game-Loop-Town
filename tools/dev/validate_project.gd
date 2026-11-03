extends SceneTree

## 开发期校验脚本（临时）：检查所有脚本能否解析、关键类能否实例化。
## 用法：
##   & godot --headless --path <项目> --script res://.tools/validate_project.gd

const SCRIPT_DIRS: Array[String] = [
	"res://scripts",
	"res://autoload",
]

var _checked: int = 0
var _failed: int = 0


func _initialize() -> void:
	print("=== 脚本解析校验 ===")
	for dir in SCRIPT_DIRS:
		_walk(dir)

	print("")
	print("=== 关键类实例化 ===")
	_check_classes()

	print("")
	print("检查脚本数: %d，失败: %d" % [_checked, _failed])
	quit(0 if _failed == 0 else 1)


func _walk(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		print("  跳过（不存在）: %s" % path)
		return
	for sub in dir.get_directories():
		_walk("%s/%s" % [path, sub])
	for file in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		var full := "%s/%s" % [path, file]
		_check_script(full)


func _check_script(path: String) -> void:
	_checked += 1
	var script := load(path)
	if script == null:
		_failed += 1
		print("  FAIL 无法加载: %s" % path)
		return
	# can_instantiate() 为 false 说明解析阶段就出错了。
	if script is Script and not (script as Script).can_instantiate():
		_failed += 1
		print("  FAIL 解析错误: %s" % path)
		return
	print("  ok   %s" % path)


func _check_classes() -> void:
	# 注意：ClassDB 只包含引擎原生类，自定义 class_name 不在其中。
	# 正确做法是读 ProjectSettings.get_global_class_list()。
	var registered: Dictionary = {}
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		registered[String(entry.get("class", ""))] = String(entry.get("path", ""))

	var classes: Array[String] = [
		"State", "StateMachine", "DamageInfo", "HealthComponent",
		"HitBox", "HurtBox", "HitEffect", "CameraShaker",
		"Actor", "PlayerController", "MemoryData", "ItemData",
		"DialogueLine", "DialogueSequence", "MapData", "SaveData",
		"WorldStateProfile",
	]
	for class_name_value in classes:
		if registered.has(class_name_value):
			print("  ok   类已注册: %s -> %s" % [class_name_value, registered[class_name_value]])
		else:
			print("  FAIL 类未注册: %s" % class_name_value)
			_failed += 1

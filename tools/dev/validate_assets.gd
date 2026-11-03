extends SceneTree

## 资源库校验：确认每个资源定义都能被 Godot 真正加载，且字段完整。
##
## 这一条很关键 —— 定义了但加载不了等于没定义。
##
## 用法：
##   godot --headless --path <项目> --script res://tools/dev/validate_assets.gd

var _failures: int = 0
var _checked: int = 0


func _initialize() -> void:
	_deferred()


func _deferred() -> void:
	await process_frame
	await process_frame
	print("=== 资源库校验开始 ===")

	_check_actors()
	_check_environments()
	_check_props()
	_check_manifest()

	print("")
	print("=== 校验结束：检查 %d 项，失败 %d 项 ===" % [_checked, _failures])
	quit(0 if _failures == 0 else 1)


# ---------------------------------------------------------------------------

func _check_actors() -> void:
	var dir := "res://data/assets/actors"
	var files := _list(dir, ".tres")
	if files.is_empty():
		_fail("角色定义目录为空：%s" % dir)
		return
	print("角色定义 %d 份：" % files.size())
	for path in files:
		_checked += 1
		var definition := load(path) as ActorDefinition
		if definition == null:
			_fail("加载失败或类型不对：%s" % path)
			continue
		var anims := definition.animations.size()
		if definition.id == &"":
			_fail("%s 缺少 id" % path)
			continue
		if anims == 0:
			_fail("%s（%s）没有任何动画" % [path, definition.id])
			continue
		# 每个动画的贴图必须真的能取到，且宽度能被帧数整除
		var bad := 0
		var total_frames := 0
		for entry: Variant in definition.animations:
			var anim := entry as AnimationEntry
			if anim == null:
				bad += 1
				continue
			total_frames += anim.frames
			if anim.texture == null:
				_fail("%s 的动画 %s 贴图缺失或路径错误（%s）"
					% [definition.id, anim.name, anim.path])
				bad += 1
				continue
			if anim.frames > 0 and anim.texture.get_width() % anim.frames != 0:
				_fail("%s 的动画 %s 图集宽度 %d 不能被帧数 %d 整除"
					% [definition.id, anim.name, anim.texture.get_width(), anim.frames])
				bad += 1
		if bad == 0:
			print("  ok  %-14s %-28s 动画 %d 个 / 共 %d 帧  体型 %dx%d"
				% [definition.id, definition.display_name, anims, total_frames,
				   int(definition.body_size.x), int(definition.body_size.y)])


func _check_environments() -> void:
	var dir := "res://data/assets/environments"
	var files := _list(dir, ".tres")
	if files.is_empty():
		_fail("环境层定义目录为空：%s" % dir)
		return
	print("环境层定义 %d 份：" % files.size())
	for path in files:
		_checked += 1
		var definition := load(path) as EnvironmentDefinition
		if definition == null:
			_fail("加载失败或类型不对：%s" % path)
			continue
		if definition.map_id == &"":
			_fail("%s 缺少 map_id" % path)
			continue
		var bad := 0
		for layer: Variant in definition.layers:
			var typed := layer as EnvironmentLayer
			if typed == null or typed.texture == null:
				bad += 1
				continue
		if bad == 0:
			print("  ok  %-18s %d 层背景" % [definition.map_id, definition.layer_count()])
		else:
			_fail("%s 有 %d 层背景贴图缺失" % [definition.map_id, bad])


func _check_props() -> void:
	var dir := "res://data/assets/props"
	var files := _list(dir, ".tres")
	if files.is_empty():
		_fail("道具定义目录为空：%s" % dir)
		return
	print("道具定义 %d 份：" % files.size())
	var ok_count := 0
	for path in files:
		_checked += 1
		var definition := load(path) as PropDefinition
		if definition == null:
			_fail("加载失败或类型不对：%s" % path)
			continue
		if definition.id == &"" or definition.display_name.is_empty():
			_fail("%s 缺少 id 或 display_name" % path)
			continue
		if definition.icon == null:
			_fail("%s 图标贴图缺失（%s）" % [definition.id, definition.texture_path])
			continue
		if definition.usage.is_empty():
			_fail("%s 缺少用途说明（美术不知道画多细）" % definition.id)
			continue
		ok_count += 1
	print("  ok  %d/%d 个道具定义完整（含图标与用途说明）" % [ok_count, files.size()])


func _check_manifest() -> void:
	var path := "res://data/assets/manifest.json"
	_checked += 1
	if not FileAccess.file_exists(path):
		_fail("缺少资源总清单：%s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("无法读取总清单")
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		_fail("总清单不是合法 JSON")
		return
	var data: Dictionary = parsed
	var actors: Array = data.get("actors", [])
	var environments: Array = data.get("environments", [])
	var props: Array = data.get("props", [])
	var vfx: Array = data.get("vfx", [])
	var ui: Array = data.get("ui", [])
	var audio: Dictionary = data.get("audio", {})
	var audio_total := 0
	for group: Variant in audio.keys():
		audio_total += int((audio[group] as Dictionary).get("files", []).size())
	print("总清单：角色 %d / 环境 %d / 道具 %d / 特效 %d / UI %d / 音频 %d"
		% [actors.size(), environments.size(), props.size(), vfx.size(),
		   ui.size(), audio_total])
	if actors.is_empty() or props.is_empty() or audio_total == 0:
		_fail("总清单内容不完整")


# ---------------------------------------------------------------------------

func _list(dir: String, suffix: String) -> Array[String]:
	var out: Array[String] = []
	var handle := DirAccess.open(dir)
	if handle == null:
		return out
	for name: String in handle.get_files():
		var clean := name.trim_suffix(".remap")
		if clean.ends_with(suffix):
			out.append("%s/%s" % [dir, clean])
	out.sort()
	return out


func _fail(message: String) -> void:
	_failures += 1
	print("  FAIL %s" % message)

class_name MirrorPuzzle
extends PuzzleBase

## 镜面反射谜题（提示词【十三】：把 7 面镜子的光线集中到未完成的蜡像上）。
##
## 规则对所有谜题实例统一：
##   - 每面镜子有一个正确档位（0..7）
##   - 玩家转动镜子，当**全部**镜子都在正确档位时解谜成功
##   - 光线只用 Line2D 画出来，从光源按镜子顺序折线前进；
##     第 N 面镜子没对准，光就在那里断掉 —— 断在哪里，玩家就知道该动哪一面。
##
## 这样“光路”本身就是进度指示器，不需要额外的 UI。

signal beam_updated(reached_mirror_count: int, total: int)

## 镜子场景路径（可为空：为空时由本节点自己生成镜子）。
@export_file("*.tscn") var mirror_scene_path: String = ""
## 光路线宽。
@export var beam_width: float = 3.0
## 光颜色。
@export var beam_color: Color = Color(1.0, 0.88, 0.6, 0.9)
## 光线起点（相对本节点）。
@export var light_source_offset: Vector2 = Vector2(-320.0, -120.0)
## 镜子的排列间距与高度。
@export var mirror_spacing: float = 108.0
@export var mirror_base_offset: Vector2 = Vector2(-180.0, -40.0)

var mirrors: Array[Mirror] = []
var _beam: Line2D = null
var _source_marker: Node2D = null
## 玩家已经观察到“光路断了”的位置，用于提示。
var _reached_count: int = 0


func _puzzle_ready() -> void:
	_collect_or_spawn_mirrors()
	_ensure_beam()
	_assign_required_angles()
	_connect_mirrors()
	_redraw_beam()


## 收集场景里已有的镜子；没有就按配置生成 7 面。
func _collect_or_spawn_mirrors() -> void:
	mirrors.clear()
	for child in get_children():
		var mirror := child as Mirror
		if mirror != null:
			mirrors.append(mirror)

	if not mirrors.is_empty():
		return

	var mirror_script := load("res://scripts/puzzles/mirror.gd")
	var count := 7
	for i in count:
		var mirror := Area2D.new()
		mirror.name = "Mirror%d" % (i + 1)
		mirror.set_script(mirror_script)
		mirror.position = light_source_offset + mirror_base_offset + Vector2(mirror_spacing * float(i), 0.0)
		add_child(mirror)
		mirrors.append(mirror as Mirror)


func _ensure_beam() -> void:
	_beam = get_node_or_null("Beam") as Line2D
	if _beam == null:
		_beam = Line2D.new()
		_beam.name = "Beam"
		_beam.width = beam_width
		_beam.default_color = beam_color
		_beam.z_index = 5
		add_child(_beam)

	_source_marker = get_node_or_null("LightSource") as Node2D
	if _source_marker == null:
		_source_marker = Node2D.new()
		_source_marker.name = "LightSource"
		_source_marker.position = light_source_offset
		add_child(_source_marker)


## 设定每面镜子的正确档位。
## 刻意做成“不是全 0”：否则谜题开局就是解，玩家不会察觉到自己在做什么。
func _assign_required_angles() -> void:
	var pattern: Array[int] = [2, 5, 1, 6, 3, 4, 7]
	for i in mirrors.size():
		var mirror := mirrors[i]
		if mirror == null:
			continue
		mirror.required_angle_index = pattern[i % pattern.size()]
		mirror.reflect_direction = Vector2.RIGHT.rotated(deg_to_rad(45.0 * float(mirror.required_angle_index)))
		# 初始档位刻意错开，且保证初始状态不是已解。
		mirror.angle_index = posmod(mirror.required_angle_index + 1 + (i % 3), 8)
		mirror.rotatable = true
		mirror._apply_angle()


func _connect_mirrors() -> void:
	for mirror in mirrors:
		if mirror == null:
			continue
		if not mirror.rotated.is_connected(_on_mirror_rotated):
			mirror.rotated.connect(_on_mirror_rotated)


func _on_mirror_rotated(_mirror: Mirror, _angle_index: int) -> void:
	_redraw_beam()
	notify_progress()


# ---------------------------------------------------------------------------
# 判定
# ---------------------------------------------------------------------------

func check_condition() -> bool:
	if mirrors.is_empty():
		return false
	for mirror in mirrors:
		if mirror == null or not mirror.is_correct():
			return false
	return true


func get_progress() -> float:
	if mirrors.is_empty():
		return 0.0
	var correct := 0
	for mirror in mirrors:
		if mirror != null and mirror.is_correct():
			correct += 1
	return float(correct) / float(mirrors.size())


func _apply_solved_state(solved: bool) -> void:
	for mirror in mirrors:
		if mirror == null:
			continue
		mirror.rotatable = not solved
		if solved:
			mirror.angle_index = mirror.required_angle_index
			mirror._apply_angle()
	_redraw_beam()


func _on_solved() -> void:
	# 光集中到未完成蜡像上 → 蜡像融化 → 露出骸骨。
	_melt_wax_figure()
	AudioManager.play_sfx("light_focus")
	AudioManager.play_bell(true)


func _melt_wax_figure() -> void:
	var figure := get_node_or_null("WaxFigure") as Node2D
	if figure == null:
		return
	var tween := create_tween()
	tween.set_parallel(true)
	# 融化：向下塌陷 + 淡出 + 泛红。
	tween.tween_property(figure, "scale", Vector2(1.2, 0.15), 2.0)
	tween.tween_property(figure, "modulate:a", 0.0, 2.0)
	tween.tween_property(figure, "modulate", Color(1.0, 0.5, 0.35), 1.0)
	await tween.finished
	# 露出里面的东西。
	var remains := get_node_or_null("Remains") as Node2D
	if remains != null:
		remains.visible = true
		var reveal := create_tween()
		reveal.tween_property(remains, "modulate:a", 1.0, 1.2)


# ---------------------------------------------------------------------------
# 光路绘制
# ---------------------------------------------------------------------------

## 从光源出发，沿镜子顺序前进；遇到没对准的镜子就断掉。
## 玩家看到光断在哪里，就知道该去转哪一面。
func _redraw_beam() -> void:
	if _beam == null:
		return

	var points := PackedVector2Array()
	var current := _source_marker.position if _source_marker != null else light_source_offset
	points.append(current)
	_reached_count = 0

	for mirror in mirrors:
		if mirror == null:
			continue
		# 光只朝右前进（本谜题的约定），因此镜子必须排在光源右侧。
		var target := mirror.position
		points.append(target)
		if not mirror.is_correct():
			# 断在这里。
			break
		_reached_count += 1
		current = target

	_beam.points = points

	# 全部对准后，把光引到蜡像上。
	if _reached_count == mirrors.size() and not mirrors.is_empty():
		var figure := get_node_or_null("WaxFigure") as Node2D
		if figure != null:
			var final_points := points.duplicate()
			final_points.append(figure.position)
			_beam.points = final_points

	beam_updated.emit(_reached_count, mirrors.size())

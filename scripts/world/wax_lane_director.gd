class_name WaxLaneDirector
extends Node

## 蜡像巷的“蜡像追踪”导演（提示词【十三】）。
##
## 这是第一章的核心恐怖节奏，必须严格按下面的顺序推进：
##   玩家经过一条岔路 → 随机一尊蜡像换姿势
##   第二次经过同一段 → 这尊蜡像距离玩家更近
##   第三次        → 它直接站在玩家的路径上
##
## 之所以独立成一个“导演”节点：蜡像本身只该知道“我怎么动”，
## 而“什么时候动、动哪一尊”是关卡节奏问题（提示词【二十七】第 1 条）。

signal statue_encroached(statue: WaxStatue, level: int)
signal attack_triggered(phase: int)

## 每经过一条“岔路标记”就推进一次的触发点横向位置（相对地图）。
@export var trigger_positions: PackedFloat32Array = PackedFloat32Array()
## 走过多少个触发点后开始触发蜡像围攻。
@export var ambush_after_triggers: int = 3
## 触发围攻时同时苏醒的蜡像数量。
@export var ambush_statue_count: int = 4
## 蜡像敌人场景路径。
@export_file("*.tscn") var wax_dummy_scene_path: String = ""
## 玩家距离蜡像多近时会“发现”它移动过（太远玩家看不见）。
@export var visible_distance: float = 420.0

var statues: Array[WaxStatue] = []
var triggers_passed: int = 0
var ambush_fired: bool = false

var _player: Node2D = null
var _last_trigger_index: int = -1


func _ready() -> void:
	add_to_group(&"wax_lane_director")
	# 等一帧再收集：蜡像可能与本节点在同一批内容里创建。
	_collect_statues.call_deferred()


## 收集同一张地图里的蜡像。只收自己的祖先链下的，避免拿到别的地图的。
func _collect_statues() -> void:
	statues.clear()
	var my_map := _find_map_root()
	for node in get_tree().get_nodes_in_group(&"wax_statue"):
		var statue := node as WaxStatue
		if statue == null or not is_instance_valid(statue):
			continue
		if my_map == null or my_map.is_ancestor_of(statue):
			statues.append(statue)


func _find_map_root() -> Node:
	var node: Node = get_parent()
	while node != null:
		if node.has_method("use_exit") and node.has_method("place_player_at_spawn"):
			return node
		node = node.get_parent()
	return null


## 蜡像数量（供 QA 校验使用）。
func get_statue_count() -> int:
	return statues.size()


func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
		if _player == null:
			return

	if triggers_passed >= ambush_after_triggers and not ambush_fired:
		_fire_ambush()
		return

	var index := _current_trigger_index(_player.global_position.x)
	if index > _last_trigger_index:
		_last_trigger_index = index
		triggers_passed += 1
		_advance_one_statue()


func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group(&"player")
	if players.is_empty():
		return null
	return players[0] as Node2D


func _current_trigger_index(player_x: float) -> int:
	var index := -1
	for i in trigger_positions.size():
		if player_x >= trigger_positions[i]:
			index = i
	return index


## 推进一尊蜡像：优先选玩家身后、且离得足够近（玩家回头能看见）的那一尊。
func _advance_one_statue() -> void:
	if statues.is_empty():
		return
	var candidate := _pick_statue()
	if candidate == null:
		return

	var player_position := _player.global_position
	var level := candidate.get_encroach_level() + 1
	if level >= 3:
		candidate.stand_in_path(player_position)
	else:
		candidate.encroach(player_position, level)
	statue_encroached.emit(candidate, candidate.get_encroach_level())


func _pick_statue() -> WaxStatue:
	# 候选：玩家身后（已经走过）、且在可视范围内的蜡像。
	var behind: Array[WaxStatue] = []
	var near: Array[WaxStatue] = []
	for statue in statues:
		if statue == null or not is_instance_valid(statue):
			continue
		var distance := statue.global_position.distance_to(_player.global_position)
		if distance > visible_distance:
			continue
		near.append(statue)
		if statue.global_position.x <= _player.global_position.x:
			behind.append(statue)
	if not behind.is_empty():
		return behind[randi() % behind.size()]
	if not near.is_empty():
		return near[randi() % near.size()]
	return null


# ---------------------------------------------------------------------------
# 围攻
# ---------------------------------------------------------------------------

## 玩家走到蜡像馆附近时，路边的蜡像一起苏醒攻击。
func _fire_ambush() -> void:
	ambush_fired = true
	attack_triggered.emit(triggers_passed)
	AudioManager.play_sfx("wax_crack")

	var awakened := 0
	var sorted := statues.duplicate()
	sorted.sort_custom(func(a: WaxStatue, b: WaxStatue) -> bool:
		if a == null or b == null:
			return false
		return a.global_position.distance_to(_player.global_position) \
			< b.global_position.distance_to(_player.global_position)
	)

	for statue in sorted:
		if awakened >= ambush_statue_count:
			break
		if statue == null or not is_instance_valid(statue):
			continue
		_spawn_wax_dummy_at(statue.global_position)
		statue.queue_free()
		awakened += 1

	# 剩下的蜡像继续盯着玩家。
	for statue in sorted:
		if statue == null or not is_instance_valid(statue):
			continue
		statue.watch_distance = maxf(statue.watch_distance, 520.0)


func _spawn_wax_dummy_at(spawn_position: Vector2) -> void:
	var host := get_parent()
	if host == null:
		host = self

	var dummy: Node2D = null
	if not wax_dummy_scene_path.is_empty() and ResourceLoader.exists(wax_dummy_scene_path):
		var packed := load(wax_dummy_scene_path) as PackedScene
		if packed != null:
			dummy = packed.instantiate() as Node2D
	if dummy == null:
		# 没有敌人场景时用工厂现场构造，保证围攻一定会发生。
		# 苏醒的都是会跳扑的突进型，让“被你发现之后它扑过来”这件事更明确。
		dummy = ActorFactory.make_wax_dummy(spawn_position, WaxDummy.Variant.LUNGER, 340.0, 0.0)
	if dummy == null:
		return

	host.add_child(dummy)
	dummy.global_position = spawn_position

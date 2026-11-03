class_name WaxStatue
extends Node2D

## 蜡像（提示词【十三】）—— 第一章最重要的恐怖来源，而且**不用 jump scare**。
##
## 设计要求的三个层次，全部在这里实现：
##   1. 玩家靠近时头部缓慢转动 / 眼睛跟随玩家
##   2. 玩家经过一条岔路后，随机一尊蜡像换姿势
##   3. 第二次经过：距离玩家更近。第三次：直接站在玩家路径上
##
## 关键在于“玩家自己发现它移动了”，所以本类**不做任何提示**，
## 不闪、不响、不转向玩家正面，只是在你转身之后换了位置。

signal pose_changed(statue: WaxStatue, pose_index: int)
signal encroached(statue: WaxStatue, level: int)

## 蜡像的三个姿势贴图（由美术资源提供，缺失时用程序化剪影兜底）。
const POSE_TEXTURES: Array[String] = [
	"res://assets/props/wax_statue_a.png",
	"res://assets/props/wax_statue_b.png",
	"res://assets/props/wax_statue_c.png",
]

## 当前姿势下标。
@export var pose_index: int = 0
## 头部转向的灵敏度。
@export var head_turn_speed: float = 1.4
## 玩家在此距离内时蜡像会“看着你”。
@export var watch_distance: float = 190.0
## 逼近层级：0 = 原位，1 = 换姿势，2 = 更近，3 = 站在路上。
@export var encroach_level: int = 0
## 每提升一级逼近，朝玩家方向移动多少像素。
@export var encroach_step: float = 68.0

var is_watching: bool = false

var _sprite: Sprite2D = null
var _head: Node2D = null
var _base_scale_x: float = 1.0


func _ready() -> void:
	add_to_group(&"wax_statue")
	_ensure_visual()
	_apply_pose()


func _ensure_visual() -> void:
	_sprite = get_node_or_null("Sprite2D") as Sprite2D
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite2D"
		add_child(_sprite)

	if _sprite.texture == null:
		for path in POSE_TEXTURES:
			if ResourceLoader.exists(path):
				_sprite.texture = load(path) as Texture2D
				break

	# 头部单独一层，用来做“头慢慢转过来”的效果。
	_head = get_node_or_null("Head") as Node2D
	if _head == null:
		_head = Node2D.new()
		_head.name = "Head"
		add_child(_head)

	_base_scale_x = scale.x


func _process(delta: float) -> void:
	var player := _find_player()
	if player == null:
		return
	var distance := global_position.distance_to(player.global_position)
	var should_watch := distance <= watch_distance
	if should_watch != is_watching:
		is_watching = should_watch
	if not is_watching:
		return

	# 头部缓慢转向玩家：慢到玩家只能“感觉”到，而不是看到。
	var to_player := player.global_position.x - global_position.x
	var target_rotation := clampf(to_player / watch_distance, -1.0, 1.0) * 0.5
	_head.rotation = lerp_angle(_head.rotation, target_rotation, delta * head_turn_speed)

	if _head.has_method("queue_redraw"):
		_head.call("queue_redraw")


func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group(&"player")
	if players.is_empty():
		return null
	return players[0] as Node2D


# ---------------------------------------------------------------------------
# 换姿势 / 逼近
# ---------------------------------------------------------------------------

## 换一个姿势。玩家背对它时调用，效果最好。
func change_pose(new_index: int = -1) -> void:
	var previous := pose_index
	if new_index < 0:
		new_index = (pose_index + 1) % 3
	if new_index == previous:
		new_index = (new_index + 1) % 3
	pose_index = new_index
	_apply_pose()
	pose_changed.emit(self, pose_index)


func _apply_pose() -> void:
	if _sprite == null:
		return
	# 三个姿势来自三张贴图；没有贴图时用缩放差异表达“它换了姿势”。
	var path := POSE_TEXTURES[pose_index % POSE_TEXTURES.size()]
	if ResourceLoader.exists(path):
		_sprite.texture = load(path) as Texture2D
	else:
		var widen := 1.0 + 0.08 * float(pose_index)
		_sprite.scale = Vector2(widen, 1.0)
	if _head != null:
		_head.position = Vector2(0.0, -46.0)


## 提升逼近层级：蜡像朝玩家方向靠近，并且停在玩家的必经之路上。
func encroach(player_position: Vector2, level: int = -1) -> void:
	var new_level := level if level >= 0 else mini(encroach_level + 1, 3)
	if new_level == encroach_level:
		return
	encroach_level = new_level

	# 每次逼近都换一个姿势 —— 玩家回来时会发现它“不一样了”。
	change_pose()

	var direction := 1.0 if player_position.x >= global_position.x else -1.0
	var distance := encroach_step * float(new_level)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position:x", position.x + direction * distance, 0.9)

	encroached.emit(self, encroach_level)


## 第 3 级时蜡像直接站到玩家路径上（横向贴到玩家前方一点）。
func stand_in_path(player_position: Vector2, offset_x: float = 46.0) -> void:
	var direction := 1.0 if player_position.x >= global_position.x else -1.0
	var target_x := player_position.x - direction * offset_x
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position:x", target_x, 0.7)
	encroach_level = 3


func get_encroach_level() -> int:
	return encroach_level

extends State

## 镇民被玩家碰到时的「卡顿」状态 — 提示词【十二】的核心演出。
##
## 时长 0.2~0.5 秒。结束后**继续执行原动作**（通过 enter 的 resume 数据传递），
## 让玩家自己发现：「它刚才是不是停了一下？」

var _remaining: float = 0.0


func enter(_previous_state: StringName = &"", _data: Dictionary = {}) -> void:
	var townsman := owner_node as Townsman
	if townsman == null:
		return
	_remaining = randf_range(townsman.stagger_min_time, townsman.stagger_max_time)
	# 卡顿时不播放新动作，而是停在当前帧 —— 这是「冻住」的关键。
	if townsman.sprite != null:
		townsman.sprite.pause()
	# 卡顿时面向玩家：他们在看你，这一点很重要。
	var player := _find_player(townsman)
	if player != null:
		townsman.face_position(player.global_position)


func physics_update(delta: float) -> StringName:
	var townsman := owner_node as Townsman
	if townsman == null:
		return &""

	if townsman.is_dead:
		return &"death"

	townsman.velocity.x = 0.0
	townsman.apply_gravity_and_move(delta)

	_remaining -= delta
	if _remaining <= 0.0:
		if townsman.sprite != null:
			townsman.sprite.play()
		# resume = true 让 task 状态沿用被打断前的动作。
		return &"task"
	return &""


func exit() -> Dictionary:
	var townsman := owner_node as Townsman
	return {"resume": true} if townsman != null else {}


func _find_player(townsman: Townsman) -> Node2D:
	var players := townsman.get_tree().get_nodes_in_group(&"player")
	if players.is_empty():
		return null
	return players[0] as Node2D

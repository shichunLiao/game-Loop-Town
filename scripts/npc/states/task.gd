extends State

## 镇民的重复动作状态（提示词【十二】：每个人有自己的重复动作，必须循环播放）。
##
## 关键效果在这里体现：被打断（staggered）之后会回到本状态，
## 并且默认**继续执行原动作**，而不是重新开始——这就是「卡顿后若无其事地继续」。
##
## 注意：文件名 task.gd 就是状态名 &"task"，不要改名。

## 动作播完后原地停留多久再做下一个动作。
const PAUSE_BETWEEN_ACTIONS: float = 0.35

var _elapsed: float = 0.0


func enter(_previous_state: StringName = &"", data: Dictionary = {}) -> void:
	_elapsed = 0.0
	var townsman := owner_node as Townsman
	if townsman == null:
		return

	# 从卡顿回来时，继续执行被打断前的那个动作。
	if data.has("resume") and bool(data["resume"]):
		play_animation(townsman.current_action, true)
		return

	townsman.current_action = townsman.pick_action()
	townsman.action_remaining = townsman.roll_action_duration()
	play_animation(townsman.current_action, true)


func physics_update(delta: float) -> StringName:
	var townsman := owner_node as Townsman
	if townsman == null:
		return &""

	if townsman.is_dead:
		return &"death"

	townsman.velocity.x = 0.0
	townsman.apply_gravity_and_move(delta)

	# 转头看向附近的玩家：全镇都在「看着你」。
	var player := _find_player(townsman)
	if player != null:
		var distance := townsman.global_position.distance_to(player.global_position)
		if distance < 120.0:
			townsman.face_position(player.global_position)

	# HOSTILE 镇民发现玩家会直接翻脸。
	if townsman.is_hostile() and townsman.is_target_valid() and townsman.is_aware:
		return &"chase"

	_elapsed += delta
	townsman.action_remaining -= delta
	if townsman.action_remaining <= 0.0 and _elapsed >= PAUSE_BETWEEN_ACTIONS:
		# 挑下一个动作，继续循环。
		townsman.current_action = townsman.pick_action()
		townsman.action_remaining = townsman.roll_action_duration()
		play_animation(townsman.current_action, true)
		_elapsed = 0.0
	return &""


func _find_player(townsman: Townsman) -> Node2D:
	var players := townsman.get_tree().get_nodes_in_group(&"player")
	if players.is_empty():
		return null
	return players[0] as Node2D

extends State

## 莫里斯的待机：未开战时站在原地做蜡像，玩家进入竞技场后开战。
##
## 提示词【十三】：玩家走进蜡像馆深处看到他正在不断制作蜡像，
## 其中第 247 尊永远无法完成 —— 待机动画用 task 表达“一直在做”。

const IDLE_ANIMATION: StringName = &"idle"
const TASK_ANIMATION: StringName = &"spray"

var _elapsed: float = 0.0


func enter(_previous_state: StringName = &"", _data: Dictionary = {}) -> void:
	_elapsed = 0.0
	play_animation(TASK_ANIMATION if has_animation(TASK_ANIMATION) else IDLE_ANIMATION)


func physics_update(delta: float) -> StringName:
	var morris := owner_node as Morris
	if morris == null:
		return &""

	morris.update_timers(delta)

	if morris.is_dead:
		return &"death"

	# 玩家走进竞技场 → 开战。
	if not morris.is_engaged and morris.is_player_inside_arena():
		morris.engage()
		return &"chase"

	_elapsed += delta
	morris.velocity.x = move_toward(morris.velocity.x, 0.0, 600.0 * delta)
	morris.apply_gravity_and_move(delta)

	# 未开战时面对玩家的方向，让玩家感到“他知道你来了”。
	if morris.is_target_valid():
		var to_target := (morris.target as Node2D).global_position.x - morris.global_position.x
		if absf(to_target) > 6.0:
			morris.set_facing(1 if to_target > 0.0 else -1)
	return &""


func has_animation(animation_name: StringName) -> bool:
	var morris := owner_node as Morris
	return morris != null and morris.has_animation(animation_name)

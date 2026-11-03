extends State

## 莫里斯的追击：靠近玩家，并按当前阶段决定出哪一招。
##
## 招式选择是“状态机挑状态”，不是一堆 if/else 塞在一个动作里：
##   - 有热蜡冷却完毕且在射程内 → spray
##   - 二阶段且还没有替身       → summon
##   - 贴脸                    → melee

const CHASE_ANIMATION: StringName = &"walk"
## 进入近战的贴身距离。
const MELEE_DISTANCE: float = 62.0
## 高于这个距离才考虑喷蜡（避免贴脸放远程）。
const SPRAY_MIN_DISTANCE: float = 90.0


func enter(_previous_state: StringName = &"", _data: Dictionary = {}) -> void:
	play_animation(CHASE_ANIMATION)


func physics_update(delta: float) -> StringName:
	var morris := owner_node as Morris
	if morris == null:
		return &""

	morris.update_timers(delta)

	if morris.is_dead:
		return &"death"

	if not morris.is_engaged:
		return &"idle"

	if not morris.is_target_valid():
		return &"idle"

	var distance := morris.distance_to_target_x()

	# 二阶段：优先召唤替身（这是本阶段的解谜核心，必须先出现）。
	if morris.phase_at_least(2) and morris.decoys.is_empty() and not morris.has_summoned():
		return &"summon"

	# 喷蜡：有冷却、且在合适距离。
	if morris.can_spray() and distance >= SPRAY_MIN_DISTANCE:
		return &"spray"

	if distance <= MELEE_DISTANCE:
		return &"melee"

	morris.move_toward_target(delta, morris.move_speed, MELEE_DISTANCE * 0.8)
	morris.apply_gravity_and_move(delta)
	return &""

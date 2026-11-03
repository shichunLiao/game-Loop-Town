extends State

## 蜡像的追击状态：在基础追击之上，LUNGER 变体会伺机跳扑。
##
## 之所以单独一份而不是改基类：跳扑是蜡像特有的行为，
## 不该污染所有敌人的追击逻辑（提示词【二十七】第 1 条：单一职责）。

const CHASE_ANIMATION: StringName = &"walk"
const LOSE_GRACE: float = 1.2

var _lost_timer: float = 0.0


func enter(_previous_state: StringName = &"", _data: Dictionary = {}) -> void:
	_lost_timer = 0.0
	play_animation(CHASE_ANIMATION)


func physics_update(delta: float) -> StringName:
	var dummy := owner_node as WaxDummy
	if dummy == null:
		return &""

	if dummy.is_dead:
		return &"death"

	# 跳扑优先于普通挥拳：这是 LUNGER 的辨识特征。
	if dummy.can_lunge():
		return &"jump_lunge"

	if not dummy.is_target_valid():
		_lost_timer += delta
		if _lost_timer >= LOSE_GRACE:
			return &"idle"
	else:
		_lost_timer = 0.0

	if dummy.is_target_valid() and dummy.distance_to_target_x() <= dummy.attack_range:
		return &"attack"

	dummy.move_toward_target(delta)
	dummy.apply_gravity_and_move(delta)
	return &""

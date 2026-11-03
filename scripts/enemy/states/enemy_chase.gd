extends State

## 敌人追击：朝玩家移动，进入攻击距离后转入攻击。

const CHASE_ANIMATION: StringName = &"walk"
## 追击时允许的小幅跳跃越过障碍的高度差。
const STEP_UP_CHECK_HEIGHT: float = 26.0
## 追击中失去目标后额外坚持的时间（秒）。
const LOSE_GRACE: float = 1.2

var _lost_timer: float = 0.0


func enter(_previous_state: StringName = &"", _data: Dictionary = {}) -> void:
	_lost_timer = 0.0
	play_animation(CHASE_ANIMATION)


func physics_update(delta: float) -> StringName:
	var enemy := owner_node as EnemyBase
	if enemy == null:
		return &""

	if enemy.is_dead:
		return &"death"

	if not enemy.is_target_valid():
		_lost_timer += delta
		if _lost_timer >= LOSE_GRACE:
			return &"idle"
	else:
		_lost_timer = 0.0

	# 进入攻击距离。
	if enemy.is_target_valid() and enemy.distance_to_target_x() <= enemy.attack_range:
		return &"attack"

	enemy.move_toward_target(delta)
	enemy.apply_gravity_and_move(delta)
	return &""

extends State

## 敌人待机：没有目标时原地观察，周期性张望。

## 待机多久后转入巡逻（秒）。0 表示原地不动。
const IDLE_DURATION: float = 1.6
## 张望时是否播放动画。
const IDLE_ANIMATION: StringName = &"idle"

var _elapsed: float = 0.0


func enter(_previous_state: StringName = &"", _data: Dictionary = {}) -> void:
	_elapsed = 0.0
	play_animation(IDLE_ANIMATION)


func physics_update(delta: float) -> StringName:
	var enemy := owner_node as EnemyBase
	if enemy == null:
		return &""

	if enemy.is_dead:
		return &"death"

	if enemy.is_target_valid() and enemy.is_aware:
		return &"chase"

	_elapsed += delta
	enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 700.0 * delta)
	enemy.apply_gravity_and_move(delta)

	# 站桩型敌人（patrol_radius = 0）永远停在 idle。
	if enemy.patrol_radius <= 0.0:
		return &""
	if _elapsed >= IDLE_DURATION:
		return &"patrol"
	return &""

extends State

## 敌人巡逻：在出生点附近来回走动，发现玩家后转入追击。

## 走多久后停下来张望（秒）。
const PATROL_DURATION: float = 3.2
## 巡逻时播放的动画。
const PATROL_ANIMATION: StringName = &"walk"

var _elapsed: float = 0.0


func enter(_previous_state: StringName = &"", _data: Dictionary = {}) -> void:
	_elapsed = 0.0
	play_animation(PATROL_ANIMATION)


func physics_update(delta: float) -> StringName:
	var enemy := owner_node as EnemyBase
	if enemy == null:
		return &""

	if enemy.is_dead:
		return &"death"

	if enemy.is_target_valid() and enemy.is_aware:
		return &"chase"

	_elapsed += delta
	enemy.patrol(delta)
	enemy.apply_gravity_and_move(delta)

	if _elapsed >= PATROL_DURATION:
		return &"idle"
	return &""

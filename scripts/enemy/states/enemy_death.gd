extends State

## 敌人死亡：播放死亡动画后由 EnemyBase 自行移除。

## 死亡姿态保持时间（秒）。
const HOLD_TIME: float = 1.4

var _elapsed: float = 0.0
var _removed: bool = false


func enter(_previous_state: StringName = &"", _data: Dictionary = {}) -> void:
	_elapsed = 0.0
	_removed = false
	play_animation(&"death", true)

	var enemy := owner_node as EnemyBase
	if enemy == null:
		return
	if enemy.hit_box != null:
		enemy.hit_box.deactivate()
	if enemy.hurt_box != null:
		enemy.hurt_box.set_deferred("monitorable", false)


func physics_update(delta: float) -> StringName:
	var enemy := owner_node as EnemyBase
	if enemy == null:
		return &""

	_elapsed += delta
	# 死亡后保留重力，避免空中死亡悬停。
	enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 500.0 * delta)
	enemy.apply_gravity_and_move(delta)

	if not _removed and _elapsed >= HOLD_TIME:
		_removed = true
		if enemy.remove_on_death and is_instance_valid(enemy):
			enemy.queue_free()
	return &""

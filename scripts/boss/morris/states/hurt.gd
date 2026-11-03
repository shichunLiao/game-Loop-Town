extends State

## 莫里斯受击：硬直极短且**不打断喷蜡**。
##
## 原因：如果 Boss 会被每一次攻击打断，玩家只要连打就能锁死他，
## 三个阶段的设计就全部失去意义。因此 Boss 的硬直是“反馈”而非“控制”。

const STUN_TIME: float = 0.12

var _remaining: float = 0.0


func enter(_previous_state: StringName = &"", data: Dictionary = {}) -> void:
	_remaining = STUN_TIME
	var morris := owner_node as Morris
	if morris == null:
		return
	play_animation(&"hit", true)
	if data.has("knockback"):
		var direction := Vector2.RIGHT
		if data.has("direction") and data["direction"] is Vector2:
			direction = data["direction"]
		# Boss 的击退大幅削弱，否则会被推到墙角。
		morris.velocity.x = direction.x * float(data["knockback"]) * 0.18


func physics_update(delta: float) -> StringName:
	var morris := owner_node as Morris
	if morris == null:
		return &""
	morris.update_timers(delta)
	if morris.is_dead:
		return &"death"

	_remaining -= delta
	morris.velocity.x = move_toward(morris.velocity.x, 0.0, 700.0 * delta)
	morris.apply_gravity_and_move(delta)

	if _remaining <= 0.0:
		return &"chase"
	return &""

extends State

## 敌人受击：短暂硬直 + 击退，然后回到战斗。
##
## 提示词【六】要求敌人被命中后有闪白与受击反馈，闪白由 Actor 统一处理，
## 这里负责硬直与“该不该被打断”的判定。

## 硬直时长（秒）。
const STUN_TIME: float = 0.16
## 是否会在受击时打断自己的攻击（霸体敌人设为 false）。
const INTERRUPTIBLE: bool = true

var _stun_remaining: float = 0.0
var _knockback: float = 0.0


func enter(_previous_state: StringName = &"", data: Dictionary = {}) -> void:
	_stun_remaining = STUN_TIME
	_knockback = 0.0
	if data.has("knockback"):
		_knockback = float(data["knockback"])
	play_animation(&"hit", true)

	var enemy := owner_node as EnemyBase
	if enemy == null:
		return
	if enemy.hit_box != null:
		enemy.hit_box.deactivate()
	# 被击退时会短暂丢失朝向意图，保留速度方向即可。
	if _knockback > 0.0 and data.has("direction") and data["direction"] is Vector2:
		var direction: Vector2 = data["direction"]
		enemy.velocity.x = direction.x * _knockback


func physics_update(delta: float) -> StringName:
	var enemy := owner_node as EnemyBase
	if enemy == null:
		return &""

	if enemy.is_dead:
		return &"death"

	_stun_remaining -= delta
	enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 800.0 * delta)
	enemy.apply_gravity_and_move(delta)

	if _stun_remaining <= 0.0:
		if enemy.is_aware and enemy.is_target_valid():
			return &"chase"
		return &"idle"
	return &""

extends State

## 受击状态：短暂失去控制并被打退。
##
## 由 PlayerController 的 damaged 信号触发切换（外部调用 change_state(&"hit")）。

## 硬直时长（秒）。必须短，否则连续受击会变成“无法操作”。
const STUN_TIME: float = 0.18
## 受击时的重力倍率（略高，落地更快，减少空中被连打）。
const GRAVITY_SCALE: float = 1.15

var _stun_remaining: float = 0.0
var _direction: Vector2 = Vector2.RIGHT


func enter(_previous_state: StringName = &"", data: Dictionary = {}) -> void:
	_stun_remaining = STUN_TIME
	play_animation(&"hit", true)
	AudioManager.play_sfx("hurt")

	var player := owner_node as PlayerController
	if player == null:
		return

	_direction = Vector2.RIGHT
	if data.has("direction") and data["direction"] is Vector2:
		_direction = data["direction"]

	# 击退：水平为主导，给一点竖直抬升让受击“跳”一下。
	var knockback: float = 220.0
	if data.has("knockback"):
		knockback = float(data["knockback"])
	player.velocity.x = _direction.x * knockback
	if player.is_on_floor():
		player.velocity.y = -knockback * 0.28


func physics_update(delta: float) -> StringName:
	var player := owner_node as PlayerController
	if player == null:
		return &""

	if player.is_dead:
		return &"death"

	_stun_remaining -= delta
	player.velocity.x = move_toward(player.velocity.x, 0.0, 900.0 * delta)
	player.apply_gravity_and_move(delta, GRAVITY_SCALE)

	if _stun_remaining <= 0.0:
		if not player.is_on_floor():
			return &"fall"
		return &"idle" if is_zero_approx(player.get_move_input()) else &"run"
	return &""

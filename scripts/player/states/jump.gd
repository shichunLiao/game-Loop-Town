extends State

## 跳跃上升状态。实现可变跳跃高度：松开跳跃键就把上升速度削掉。

## 上升阶段允许的空中水平加速度倍率（略低于地面，但不能太迟钝）。
const AIR_CONTROL_SCALE: float = 0.72


func enter(_previous_state: StringName = &"", _data: Dictionary = {}) -> void:
	var player := owner_node as PlayerController
	if player == null:
		return
	play_animation(&"jump")
	player.velocity.y = -player.jump_velocity
	AudioManager.play_sfx("jump")


func exit() -> Dictionary:
	return {}


func physics_update(delta: float) -> StringName:
	var player := owner_node as PlayerController
	if player == null:
		return &""

	if player.is_dead:
		return &"death"

	# 可变跳跃高度：一松手就削顶。
	if player.is_jump_just_released() and player.velocity.y < -player.jump_release_speed:
		player.velocity.y = -player.jump_release_speed

	# 空中可以攻击（方向攻击含斜上与斜下）。
	if player.has_buffered_attack() or player.is_attack_just_pressed():
		return &"attack"

	_apply_horizontal(player, delta)

	player.apply_gravity_and_move(delta)

	# 开始下落就切换到 fall，让动画与手感分层清晰。
	if player.velocity.y >= 0.0:
		return &"fall"
	if player.is_on_floor():
		return &"idle"
	return &""


func _apply_horizontal(player: PlayerController, delta: float) -> void:
	var direction := player.get_move_input()
	var accel := player.air_acceleration * AIR_CONTROL_SCALE
	if is_zero_approx(direction):
		player.velocity.x = move_toward(player.velocity.x, 0.0, player.air_deceleration * delta)
		return
	player.set_facing(int(signf(direction)))
	player.velocity.x = move_toward(player.velocity.x, direction * player.move_speed, accel * delta)

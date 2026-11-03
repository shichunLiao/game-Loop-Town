extends State

## 下落状态。


func enter(_previous_state: StringName = &"", _data: Dictionary = {}) -> void:
	play_animation(&"fall")


func physics_update(delta: float) -> StringName:
	var player := owner_node as PlayerController
	if player == null:
		return &""

	if player.is_dead:
		return &"death"

	# 落地缓冲：落地前按下的跳跃会在这一帧立刻生效。
	if player.is_on_floor():
		if player.has_buffered_jump() or player.is_jump_just_pressed():
			player.consume_jump_buffer()
			player.consume_coyote()
			return &"jump"
		AudioManager.play_sfx("land")
		return &"idle" if is_zero_approx(player.get_move_input()) else &"run"

	if player.has_buffered_attack() or player.is_attack_just_pressed():
		return &"attack"

	_apply_horizontal(player, delta)
	player.apply_gravity_and_move(delta)

	# 走下斜坡 / 走出平台边缘时用土狼时间允许补跳。
	if player.is_jump_just_pressed() and player.can_use_coyote():
		player.consume_coyote()
		return &"jump"
	return &""


func _apply_horizontal(player: PlayerController, delta: float) -> void:
	var direction := player.get_move_input()
	if is_zero_approx(direction):
		player.velocity.x = move_toward(player.velocity.x, 0.0, player.air_deceleration * delta)
		return
	player.set_facing(int(signf(direction)))
	player.velocity.x = move_toward(
		player.velocity.x,
		direction * player.move_speed,
		player.air_acceleration * 0.6 * delta
	)

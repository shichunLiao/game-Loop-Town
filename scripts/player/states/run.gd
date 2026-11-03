extends State

## 跑动状态：有水平输入且在地面上。


func enter(_previous_state: StringName = &"", _data: Dictionary = {}) -> void:
	play_animation(&"run")


func physics_update(delta: float) -> StringName:
	var player := owner_node as PlayerController
	if player == null:
		return &""

	if player.is_dead:
		return &"death"

	if player.is_jump_just_pressed() or player.has_buffered_jump():
		if player.is_on_floor() or player.can_use_coyote():
			player.consume_jump_buffer()
			player.consume_coyote()
			return &"jump"
		player.buffer_jump()

	if player.has_buffered_attack() or player.is_attack_just_pressed():
		return &"attack"

	if player.is_interact_just_pressed():
		return &"interact"

	var direction := player.get_move_input()
	if is_zero_approx(direction):
		# 松开方向：立刻转入待机，由 idle 负责减速。
		return &"idle"

	player.set_facing(int(signf(direction)))
	var target_speed := direction * player.move_speed
	player.velocity.x = move_toward(player.velocity.x, target_speed, player.acceleration * delta)

	player.apply_gravity_and_move(delta)

	# 跑出平台边缘：允许土狼时间内的跳跃，超时后转入下落。
	if not player.is_on_floor() and not player.can_use_coyote():
		return &"fall"
	return &""

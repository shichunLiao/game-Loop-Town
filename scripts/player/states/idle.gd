extends State

## 待机状态：玩家没有水平输入且在地面上。
##
## 职责很小：选择 Playing 动画、把速度收干、监听“该走了”的条件。

const DECELERATE_RATE: float = 3000.0
## 低于该水平速度才播放 Idle，避免走动时动画闪烁。
const IDLE_SPEED_THRESHOLD: float = 12.0


func enter(_previous_state: StringName = &"", _data: Dictionary = {}) -> void:
	play_animation(&"idle")


func physics_update(delta: float) -> StringName:
	var player := owner_node as PlayerController
	if player == null:
		return &""

	if player.is_dead:
		return &"death"

	# 受击优先级由 hurt_box 直接切状态，这里只处理主动行为。
	if player.is_jump_just_pressed() or player.has_buffered_jump():
		return _try_jump(player)

	if player.has_buffered_attack() or player.is_attack_just_pressed():
		return &"attack"

	if player.is_interact_just_pressed():
		return &"interact"

	var direction := player.get_move_input()
	if not is_zero_approx(direction):
		return &"run"

	# 收干残余速度，保证“停得住、不漂移”。
	player.velocity.x = move_toward(player.velocity.x, 0.0, DECELERATE_RATE * delta)

	if not player.is_on_floor():
		return &"fall"

	player.apply_gravity_and_move(delta)
	if absf(player.velocity.x) > IDLE_SPEED_THRESHOLD:
		return &"run"
	return &""


func _try_jump(player: PlayerController) -> StringName:
	# 条件不满足时把缓冲留着，落地瞬间能自动起跳。
	if not player.is_on_floor() and not player.can_use_coyote():
		player.buffer_jump()
		return &""
	player.consume_jump_buffer()
	player.consume_coyote()
	return &"jump"

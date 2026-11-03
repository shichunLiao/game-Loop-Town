extends State

## 攀爬状态（提示词【五】：攀爬在第三章使用；Demo 里第四章钟楼与井壁也会用到）。
##
## 判定方式：玩家身边存在属于 &"climbable" 组的 Area2D 时即可攀附。
## 井壁藤蔓、钟楼齿轮边缘都挂这个组，不需要为每种地形写一套判定。

## 攀爬时上下移动速度。
const CLIMB_SPEED: float = 150.0
## 左右横移速度（在藤蔓上小幅调整位置）。
const SHIFT_SPEED: float = 90.0
## 离开攀爬面时的推力。
const DETACH_PUSH: float = 180.0
## 贴着攀爬面时的抓取水平距离。
const GRAB_DISTANCE: float = 22.0

var _climbable: Area2D = null


func enter(previous_state: StringName = &"", _data: Dictionary = {}) -> void:
	var player := owner_node as PlayerController
	if player == null:
		return
	# 从跳跃切进来时要立刻止住速度，避免“弹一下就掉”。
	if previous_state == &"jump":
		player.velocity.y = 0.0
	player.velocity.x = 0.0
	play_animation(&"climb")


func physics_update(delta: float) -> StringName:
	var player := owner_node as PlayerController
	if player == null:
		return &""

	if player.is_dead:
		return &"death"

	_climbable = player.find_nearby_climbable(GRAB_DISTANCE)

	# 离开攀爬面：自然脱落。
	if _climbable == null:
		return &"fall"

	if player.is_jump_just_pressed():
		# 蹬墙跳：向背后弹开。
		var climb_side := _climbable.global_position.x
		var push_direction := -1.0 if climb_side > player.global_position.x else 1.0
		player.velocity = Vector2(push_direction * DETACH_PUSH, -player.jump_velocity * 0.92)
		player.set_facing(int(push_direction))
		player.consume_jump_buffer()
		return &"jump"

	if player.has_buffered_attack() or player.is_attack_just_pressed():
		return &"attack"

	# 垂直攀爬。
	var vertical := player.get_vertical_input()
	if absf(vertical) > 0.01:
		player.velocity.y = vertical * CLIMB_SPEED
	else:
		# 无输入时轻微下滑，制造“抓不住”的压力感（井底关卡需要）。
		player.velocity.y = 26.0

	# 水平微调。
	var horizontal := player.get_move_input()
	player.velocity.x = horizontal * SHIFT_SPEED

	# 攀爬中不受重力，直接移动。
	player.move_and_slide()

	# 攀爬状态下不能转身离开攀爬面。
	if not is_zero_approx(horizontal):
		player.set_facing(int(signf(horizontal)))

	# 落地则结束攀爬。
	if player.is_on_floor() and vertical > 0.5:
		return &"idle"
	return &""


func exit() -> Dictionary:
	_climbable = null
	return {}

extends State

## 攻击状态 — 提示词【六】的核心要求：
##   攻击必须拥有 **前摇 / 生效帧 / 后摇**，绝不允许整段动画都算判定。
##
## 实现方式：三段定时器链。生效帧的开关直接驱动 HitBox 的 activate/deactivate，
## 因此“哪几帧能打到人”是可精确控制的，与动画长度解耦。
##
## 连击：一段最多 combo_length 刀，每刀之间共享 combo 窗口；超过就回到第一刀。

enum Phase { WINDUP, ACTIVE, RECOVERY, FINISHED }

## 前摇 / 生效 / 后摇时长（秒）。第九刀起会按 combo 微调，让连击有节奏。
const WINDUP_TIME: float = 0.075
const ACTIVE_TIME: float = 0.095
const RECOVERY_TIME: float = 0.135

var _phase: Phase = Phase.FINISHED
var _timer: Timer = null
var _player: PlayerController = null


func enter(previous_state: StringName = &"", _data: Dictionary = {}) -> void:
	_player = owner_node as PlayerController
	if _player == null:
		return

	# 连击计数：只有在窗口内连续攻击才算下一刀。
	if previous_state != &"attack":
		_player.combo_index = 0
	_player.combo_index = (_player.combo_index % maxi(_player.combo_length, 1)) + 1
	_player.combo_reset_timer = 0.45

	_player.consume_attack_buffer()
	_player.read_attack_direction()
	_player.begin_attack()

	play_animation(&"attack", true)
	AudioManager.play_sfx("attack_swing")

	if _timer == null:
		_timer = Timer.new()
		_timer.name = "AttackPhaseTimer"
		_timer.one_shot = true
		_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(_timer)
		_timer.timeout.connect(_on_phase_timeout)

	_enter_phase(Phase.WINDUP)


func exit() -> Dictionary:
	if _timer != null:
		_timer.stop()
	_phase = Phase.FINISHED
	if _player != null and _player.hit_box != null:
		_player.hit_box.deactivate()
	return {}


func physics_update(delta: float) -> StringName:
	if _player == null:
		return &""

	if _player.is_dead:
		return &"death"

	if _phase == Phase.FINISHED:
		return _next_state()

	# 后摇期间允许用方向键微调，但不允许移动加速（避免“边挥边跑”）。
	if _phase == Phase.RECOVERY:
		var direction := _player.get_move_input()
		if not is_zero_approx(direction):
			_player.set_facing(int(signf(direction)))
			_player.velocity.x = move_toward(_player.velocity.x, 0.0, 1400.0 * delta)
		else:
			_player.velocity.x = move_toward(_player.velocity.x, 0.0, 2000.0 * delta)

	_player.apply_gravity_and_move(delta)
	return &""


func _enter_phase(phase: Phase) -> void:
	_phase = phase
	match phase:
		Phase.WINDUP:
			if _player.hit_box != null:
				_player.hit_box.deactivate()
			_start_timer(WINDUP_TIME)
		Phase.ACTIVE:
			if _player.hit_box != null:
				_player.hit_box.activate()
			_start_timer(ACTIVE_TIME)
		Phase.RECOVERY:
			if _player.hit_box != null:
				_player.hit_box.deactivate()
			_start_timer(RECOVERY_TIME)
		Phase.FINISHED:
			_phase = Phase.FINISHED


func _start_timer(duration: float) -> void:
	if _timer == null:
		return
	_timer.start(duration)


func _on_phase_timeout() -> void:
	match _phase:
		Phase.WINDUP:
			_enter_phase(Phase.ACTIVE)
		Phase.ACTIVE:
			_enter_phase(Phase.RECOVERY)
		Phase.RECOVERY:
			# 后摇结束时若已经缓冲了下一刀，直接续上连击。
			if _player != null and _player.has_buffered_attack():
				_enter_phase(Phase.WINDUP)
				_player.consume_attack_buffer()
				_player.combo_index = (_player.combo_index % maxi(_player.combo_length, 1)) + 1
				play_animation(&"attack", true)
				return
			_enter_phase(Phase.FINISHED)
		Phase.FINISHED:
			pass


## 攻击结束后回到哪个状态。
func _next_state() -> StringName:
	if _player == null:
		return &"idle"
	if not _player.is_on_floor():
		return &"fall"
	if is_zero_approx(_player.get_move_input()):
		return &"idle"
	return &"run"

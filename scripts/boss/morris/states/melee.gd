extends State

## 莫里斯的近战：挥拳。遵守前摇 / 生效帧 / 后摇。

enum Phase { WINDUP, ACTIVE, RECOVERY, DONE }

const WINDUP_TIME: float = 0.38
const ACTIVE_TIME: float = 0.14
const RECOVERY_TIME: float = 0.36

var _phase: Phase = Phase.DONE
var _timer: Timer = null
var _morris: Morris = null


func enter(_previous_state: StringName = &"", _data: Dictionary = {}) -> void:
	_morris = owner_node as Morris
	if _morris == null:
		return
	play_animation(&"spray" if _morris.has_animation(&"spray") else &"attack", true)
	_morris.velocity.x = 0.0
	if _timer == null:
		_timer = Timer.new()
		_timer.name = "MeleeTimer"
		_timer.one_shot = true
		add_child(_timer)
		_timer.timeout.connect(_on_phase_timeout)
	_enter_phase(Phase.WINDUP)


func exit() -> Dictionary:
	if _timer != null:
		_timer.stop()
	_phase = Phase.DONE
	if _morris != null and _morris.hit_box != null:
		_morris.hit_box.deactivate()
	return {}


func physics_update(delta: float) -> StringName:
	if _morris == null:
		return &""
	_morris.update_timers(delta)
	if _morris.is_dead:
		return &"death"

	_morris.velocity.x = move_toward(_morris.velocity.x, 0.0, 1400.0 * delta)
	_morris.apply_gravity_and_move(delta)

	if _phase == Phase.DONE:
		return &"chase"
	return &""


func _enter_phase(phase: Phase) -> void:
	_phase = phase
	match phase:
		Phase.WINDUP:
			if _morris.hit_box != null:
				_morris.hit_box.deactivate()
			_start(WINDUP_TIME)
		Phase.ACTIVE:
			if _morris.hit_box != null:
				# 近战伤害略低于热蜡，鼓励玩家躲蜡而不是贴身硬拼。
				_morris.hit_box.configure(
					maxi(_morris.attack_damage - 2, 4), 240.0, 0.06, &"normal"
				)
				_morris.hit_box.activate()
			_start(ACTIVE_TIME)
		Phase.RECOVERY:
			if _morris.hit_box != null:
				_morris.hit_box.deactivate()
			_start(RECOVERY_TIME)
		Phase.DONE:
			pass


func _start(duration: float) -> void:
	if _timer != null:
		_timer.start(duration)


func _on_phase_timeout() -> void:
	match _phase:
		Phase.WINDUP:
			_enter_phase(Phase.ACTIVE)
		Phase.ACTIVE:
			_enter_phase(Phase.RECOVERY)
		Phase.RECOVERY:
			_enter_phase(Phase.DONE)
		Phase.DONE:
			pass

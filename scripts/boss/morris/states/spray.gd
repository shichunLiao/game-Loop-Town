extends State

## 莫里斯的喷蜡（提示词【十三】PHASE 1）。
##
## 四种喷法按距离与朝向选择：左喷 / 右喷 / 高位喷射 / 地面流蜡。
## 地面流蜡是唯一“必须跳起来躲”的招式，用来打破玩家一直贴地的习惯。

enum Phase { WINDUP, ACTIVE, RECOVERY, DONE }

const WINDUP_TIME: float = 0.44
const ACTIVE_TIME: float = 0.36
const RECOVERY_TIME: float = 0.42
## 整个喷蜡过程中每隔多久发射一波。
const VOLLEY_INTERVAL: float = 0.16

var _phase: Phase = Phase.DONE
var _timer: Timer = null
var _volley_timer: Timer = null
var _morris: Morris = null
var _pattern: StringName = &"high"
var _volleys_left: int = 0


func enter(_previous_state: StringName = &"", _data: Dictionary = {}) -> void:
	_morris = owner_node as Morris
	if _morris == null:
		return
	play_animation(&"spray" if _morris.has_animation(&"spray") else &"attack", true)
	_morris.velocity.x = 0.0
	_pattern = _choose_pattern(_morris)
	_volleys_left = 3

	if _timer == null:
		_timer = Timer.new()
		_timer.name = "SprayTimer"
		_timer.one_shot = true
		add_child(_timer)
		_timer.timeout.connect(_on_phase_timeout)
	if _volley_timer == null:
		_volley_timer = Timer.new()
		_volley_timer.name = "VolleyTimer"
		_volley_timer.one_shot = false
		add_child(_volley_timer)
		_volley_timer.timeout.connect(_on_volley)
	_enter_phase(Phase.WINDUP)


func exit() -> Dictionary:
	if _timer != null:
		_timer.stop()
	if _volley_timer != null:
		_volley_timer.stop()
	_phase = Phase.DONE
	return {}


func physics_update(delta: float) -> StringName:
	if _morris == null:
		return &""
	_morris.update_timers(delta)
	if _morris.is_dead:
		return &"death"

	# 喷蜡时原地不动 —— 前摇必须是可以被读懂、被绕后的。
	_morris.velocity.x = move_toward(_morris.velocity.x, 0.0, 1500.0 * delta)

	# 前摇阶段缓慢转向玩家，让喷的方向有迹可循。
	if _phase == Phase.WINDUP and _morris.is_target_valid():
		var to_target := (_morris.target as Node2D).global_position.x - _morris.global_position.x
		if absf(to_target) > 8.0:
			_morris.set_facing(1 if to_target > 0.0 else -1)

	_morris.apply_gravity_and_move(delta)

	if _phase == Phase.DONE:
		return &"chase"
	return &""


## 按当前阶段与距离挑一种喷法。
## 三阶段之后才会出现“地面流蜡”，因为它最难躲。
func _choose_pattern(morris: Morris) -> StringName:
	var vertical := 0.0
	if morris.is_target_valid():
		vertical = (morris.target as Node2D).global_position.y - morris.global_position.y

	var roll := randf()
	if morris.phase_at_least(3) and roll < 0.3:
		return &"floor"
	if vertical < -60.0:
		# 玩家在上方：高位喷射。
		return &"high"
	if roll < 0.5:
		return &"left"
	return &"right"


func _enter_phase(phase: Phase) -> void:
	_phase = phase
	match phase:
		Phase.WINDUP:
			_start(WINDUP_TIME)
		Phase.ACTIVE:
			_volleys_left = 3
			_volley_timer.start(VOLLEY_INTERVAL)
			_on_volley()
			_start(ACTIVE_TIME)
		Phase.RECOVERY:
			_volley_timer.stop()
			_start(RECOVERY_TIME)
		Phase.DONE:
			pass


func _on_volley() -> void:
	if _morris == null or _morris.is_dead:
		if _volley_timer != null:
			_volley_timer.stop()
		return
	if _volleys_left <= 0:
		_volley_timer.stop()
		return
	_volleys_left -= 1
	_morris.fire_wax_spray(_pattern)


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

extends State

## 敌人攻击：同样遵守“前摇 / 生效帧 / 后摇”，与玩家保持一致的规则。
##
## 这一点很重要：提示词【六】要求攻击不能整段都算判定，敌人也必须守这条规则，
## 否则玩家会觉得“被打得莫名其妙”。

enum Phase { WINDUP, ACTIVE, RECOVERY, DONE }

## 一个敌人只能有一种攻击时，直接用这三个常量。
const WINDUP_TIME: float = 0.34
const ACTIVE_TIME: float = 0.12
const RECOVERY_TIME: float = 0.30
## 攻击后的冷却，避免贴脸连续挥。
const COOLDOWN: float = 0.55

var _phase: Phase = Phase.DONE
var _cooldown: float = 0.0
var _timer: Timer = null
var _enemy: EnemyBase = null


func enter(_previous_state: StringName = &"", _data: Dictionary = {}) -> void:
	_enemy = owner_node as EnemyBase
	_cooldown = 0.0
	if _enemy == null:
		return

	play_animation(&"attack", true)
	_enemy.velocity.x = 0.0

	if _timer == null:
		_timer = Timer.new()
		_timer.name = "EnemyAttackTimer"
		_timer.one_shot = true
		add_child(_timer)
		_timer.timeout.connect(_on_phase_timeout)

	_enter_phase(Phase.WINDUP)


func exit() -> Dictionary:
	if _timer != null:
		_timer.stop()
	_phase = Phase.DONE
	if _enemy != null and _enemy.hit_box != null:
		_enemy.hit_box.deactivate()
	return {}


func physics_update(delta: float) -> StringName:
	if _enemy == null:
		return &""

	if _enemy.is_dead:
		return &"death"

	if _cooldown > 0.0:
		_cooldown = maxf(_cooldown - delta, 0.0)

	# 前摇阶段仍然可以缓慢转身，但不再移动（否则前摇毫无意义）。
	if _phase == Phase.WINDUP and _enemy.is_target_valid():
		var to_target := (_enemy.target as Node2D).global_position.x - _enemy.global_position.x
		if absf(to_target) > 4.0:
			_enemy.set_facing(1 if to_target > 0.0 else -1)
			if _enemy.hit_box != null:
				_enemy.hit_box.position.x = absf(_enemy.hit_box.position.x) * float(_enemy.facing)

	_enemy.velocity.x = move_toward(_enemy.velocity.x, 0.0, 1500.0 * delta)
	_enemy.apply_gravity_and_move(delta)

	if _phase == Phase.DONE and _cooldown <= 0.0:
		if _enemy.is_target_valid() and _enemy.distance_to_target_x() <= _enemy.attack_range:
			# 还在范围内：再来一次。
			_enter_phase(Phase.WINDUP)
			play_animation(&"attack", true)
			return &""
		return &"chase"
	return &""


func _enter_phase(phase: Phase) -> void:
	_phase = phase
	match phase:
		Phase.WINDUP:
			if _enemy != null and _enemy.hit_box != null:
				_enemy.hit_box.deactivate()
			_start(WINDUP_TIME)
		Phase.ACTIVE:
			if _enemy != null and _enemy.hit_box != null:
				_enemy.hit_box.configure(
					_enemy.attack_damage,
					200.0,
					0.05,
					&"normal"
				)
				_enemy.hit_box.activate()
			_start(ACTIVE_TIME)
		Phase.RECOVERY:
			if _enemy != null and _enemy.hit_box != null:
				_enemy.hit_box.deactivate()
			_start(RECOVERY_TIME)
		Phase.DONE:
			_cooldown = COOLDOWN


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

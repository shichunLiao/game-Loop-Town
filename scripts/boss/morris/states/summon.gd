extends State

## 莫里斯的召唤：二阶段开始时召唤蜡像替身。
##
## 召唤本身很慢，给玩家时间观察 —— 因为这一阶段的重点不是躲，
## 而是**分辨哪一只是真身**（提示词【十三】：只有真身有眼睛里的高光）。

const SUMMON_TIME: float = 1.6

var _timer: Timer = null
var _morris: Morris = null


func enter(_previous_state: StringName = &"", _data: Dictionary = {}) -> void:
	_morris = owner_node as Morris
	if _morris == null:
		return
	play_animation(&"summon" if _morris.has_animation(&"summon") else &"idle", true)
	_morris.velocity.x = 0.0
	_morris.mark_summoned()

	if _timer == null:
		_timer = Timer.new()
		_timer.name = "SummonTimer"
		_timer.one_shot = true
		add_child(_timer)
		_timer.timeout.connect(_on_summon_done)
	_timer.start(SUMMON_TIME)


func exit() -> Dictionary:
	if _timer != null:
		_timer.stop()
	return {}


func physics_update(delta: float) -> StringName:
	if _morris == null:
		return &""
	_morris.update_timers(delta)
	if _morris.is_dead:
		return &"death"

	_morris.velocity.x = move_toward(_morris.velocity.x, 0.0, 1600.0 * delta)
	_morris.apply_gravity_and_move(delta)
	return &""


func _on_summon_done() -> void:
	if _morris == null or _morris.is_dead:
		return
	# 真正的召唤发生在这一刻：替身出现，真身混在其中。
	_morris.spawn_decoys_now()
	_morris.state_machine.change_state(&"chase")
